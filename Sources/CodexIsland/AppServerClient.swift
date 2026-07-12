import Foundation

enum AppServerError: LocalizedError {
    case notStarted
    case disconnected
    case malformedResponse
    case server(String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .notStarted: "Codex 数据服务尚未启动"
        case .disconnected: "与 Codex 数据服务的连接已断开"
        case .malformedResponse: "Codex 返回了无法识别的数据"
        case let .server(message): message
        case let .timedOut(method): "Codex 数据请求超时：\(method)"
        }
    }
}

final class AppServerClient: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.codex-island.app-server")
    private let requestTimeout: TimeInterval
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var errorOutput: FileHandle?
    private var buffer = JSONLineBuffer()
    private var nextID = 1
    private var callbacks: [Int: (Result<[String: Any], Error>) -> Void] = [:]
    private var timeoutWorkItems: [Int: DispatchWorkItem] = [:]
    private var disconnectHandler: ((Error) -> Void)?

    init(requestTimeout: TimeInterval = 10) {
        self.requestTimeout = requestTimeout
    }

    func start(
        executableURL: URL,
        onDisconnect: @escaping (Error) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        queue.async {
            self.stopLocked()
            self.disconnectHandler = onDisconnect

            let process = Process()
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = executableURL
            process.arguments = ["app-server", "--stdio"]
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            let output = outputPipe.fileHandleForReading
            let errorOutput = errorPipe.fileHandleForReading
            self.output = output
            self.errorOutput = errorOutput

            output.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    self?.queue.async { self?.handleDisconnectLocked() }
                    return
                }
                self?.queue.async { self?.consumeLocked(data) }
            }

            errorOutput.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }
                AppLog.appServer.debug("Drained \(data.count, privacy: .public) stderr bytes")
            }

            process.terminationHandler = { [weak self] _ in
                self?.queue.async { self?.handleDisconnectLocked() }
            }

            do {
                try process.run()
                self.process = process
                self.input = inputPipe.fileHandleForWriting
                AppLog.appServer.info("Started Codex app-server")
                self.sendLocked(
                    method: "initialize",
                    params: [
                        "clientInfo": [
                            "name": "codex-island",
                            "title": "Codex Island",
                            "version": Bundle.main.object(
                                forInfoDictionaryKey: "CFBundleShortVersionString"
                            ) as? String ?? "development"
                        ],
                        "capabilities": ["experimentalApi": true]
                    ]
                ) { result in
                    switch result {
                    case .success:
                        AppLog.appServer.info("Initialized Codex app-server")
                        completion(.success(()))
                    case let .failure(error):
                        AppLog.appServer.error("Initialization failed: \(error.localizedDescription, privacy: .private)")
                        completion(.failure(error))
                    }
                }
            } catch {
                AppLog.appServer.error("Failed to start app-server: \(error.localizedDescription, privacy: .private)")
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

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self, self.callbacks[id] != nil else { return }
            AppLog.appServer.error("Request timed out: \(method, privacy: .public)")
            self.completeRequestLocked(id: id, result: .failure(AppServerError.timedOut(method)))
            self.stopLocked()
        }
        timeoutWorkItems[id] = timeoutWorkItem
        queue.asyncAfter(deadline: .now() + requestTimeout, execute: timeoutWorkItem)

        let message: [String: Any] = ["id": id, "method": method, "params": params]
        do {
            var data = try JSONSerialization.data(withJSONObject: message)
            data.append(0x0A)
            try input.write(contentsOf: data)
        } catch {
            completeRequestLocked(id: id, result: .failure(error))
        }
    }

    private func consumeLocked(_ data: Data) {
        for line in buffer.append(data) {
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let id = object["id"] as? Int,
                  callbacks[id] != nil
            else { continue }

            if let error = object["error"] as? [String: Any] {
                let message = error["message"] as? String ?? "Codex 数据服务返回错误"
                completeRequestLocked(id: id, result: .failure(AppServerError.server(message)))
            } else if let result = object["result"] as? [String: Any] {
                completeRequestLocked(id: id, result: .success(result))
            } else {
                completeRequestLocked(id: id, result: .failure(AppServerError.malformedResponse))
            }
        }
    }

    private func completeRequestLocked(id: Int, result: Result<[String: Any], Error>) {
        timeoutWorkItems.removeValue(forKey: id)?.cancel()
        callbacks.removeValue(forKey: id)?(result)
    }

    private func handleDisconnectLocked() {
        guard process != nil else { return }
        let hadPendingRequests = !callbacks.isEmpty
        let disconnectHandler = disconnectHandler
        AppLog.appServer.notice("Codex app-server disconnected")
        stopLocked()
        if !hadPendingRequests {
            disconnectHandler?(AppServerError.disconnected)
        }
    }

    private func stopLocked() {
        output?.readabilityHandler = nil
        errorOutput?.readabilityHandler = nil
        process?.terminationHandler = nil
        try? input?.close()
        if process?.isRunning == true { process?.terminate() }
        process = nil
        input = nil
        output = nil
        errorOutput = nil
        buffer.removeAll()
        let pending = Array(callbacks.values)
        callbacks.removeAll()
        timeoutWorkItems.values.forEach { $0.cancel() }
        timeoutWorkItems.removeAll()
        disconnectHandler = nil
        pending.forEach { $0(.failure(AppServerError.disconnected)) }
    }
}
