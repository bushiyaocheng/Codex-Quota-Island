import Foundation

enum AppServerError: LocalizedError {
    case notStarted
    case disconnected
    case malformedResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notStarted: "Codex 数据服务尚未启动"
        case .disconnected: "与 Codex 数据服务的连接已断开"
        case .malformedResponse: "Codex 返回了无法识别的数据"
        case let .server(message): message
        }
    }
}

final class AppServerClient: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.codex-island.app-server")
    private var process: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var nextID = 1
    private var callbacks: [Int: (Result<[String: Any], Error>) -> Void] = [:]

    func start(executableURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            self.stopLocked()

            let process = Process()
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = executableURL
            process.arguments = ["app-server", "--stdio"]
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    self?.queue.async { self?.handleDisconnectLocked() }
                    return
                }
                self?.queue.async { self?.consumeLocked(data) }
            }

            process.terminationHandler = { [weak self] _ in
                self?.queue.async { self?.handleDisconnectLocked() }
            }

            do {
                try process.run()
                self.process = process
                self.input = inputPipe.fileHandleForWriting
                self.sendLocked(
                    method: "initialize",
                    params: [
                        "clientInfo": [
                            "name": "codex-island",
                            "title": "Codex Island",
                            "version": "0.1.0"
                        ],
                        "capabilities": ["experimentalApi": true]
                    ]
                ) { result in
                    switch result {
                    case .success:
                        completion(.success(()))
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            } catch {
                self.stopLocked()
                completion(.failure(error))
            }
        }
    }

    func readRateLimits(completion: @escaping (Result<RateLimitsResponse, Error>) -> Void) {
        queue.async {
            self.sendLocked(method: "account/rateLimits/read", params: NSNull()) { result in
                do {
                    let object = try result.get()
                    let data = try JSONSerialization.data(withJSONObject: object)
                    let response = try JSONDecoder().decode(RateLimitsResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    func stop() {
        queue.async { self.stopLocked() }
    }

    private func sendLocked(
        method: String,
        params: Any,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let input, process?.isRunning == true else {
            completion(.failure(AppServerError.notStarted))
            return
        }

        let id = nextID
        nextID += 1
        callbacks[id] = completion

        let message: [String: Any] = ["id": id, "method": method, "params": params]
        do {
            var data = try JSONSerialization.data(withJSONObject: message)
            data.append(0x0A)
            try input.write(contentsOf: data)
        } catch {
            callbacks.removeValue(forKey: id)?(.failure(error))
        }
    }

    private func consumeLocked(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<newline]
            buffer.removeSubrange(...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let id = object["id"] as? Int,
                  let callback = callbacks.removeValue(forKey: id)
            else { continue }

            if let error = object["error"] as? [String: Any] {
                let message = error["message"] as? String ?? "Codex 数据服务返回错误"
                callback(.failure(AppServerError.server(message)))
            } else if let result = object["result"] as? [String: Any] {
                callback(.success(result))
            } else {
                callback(.failure(AppServerError.malformedResponse))
            }
        }
    }

    private func handleDisconnectLocked() {
        guard process != nil else { return }
        let pending = callbacks.values
        callbacks.removeAll()
        stopLocked()
        pending.forEach { $0(.failure(AppServerError.disconnected)) }
    }

    private func stopLocked() {
        process?.terminationHandler = nil
        if process?.isRunning == true { process?.terminate() }
        process = nil
        input = nil
        buffer.removeAll(keepingCapacity: false)
        let pending = callbacks.values
        callbacks.removeAll()
        pending.forEach { $0(.failure(AppServerError.disconnected)) }
    }
}
