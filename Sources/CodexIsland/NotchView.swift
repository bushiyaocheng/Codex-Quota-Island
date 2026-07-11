import AppKit
import SwiftUI

@MainActor
final class PanelViewState: ObservableObject {
    @Published var isExpanded: Bool
    @Published var notchWidth: CGFloat = 180
    @Published var compactHeight: CGFloat = 34
    let startsExpanded: Bool

    init() {
        startsExpanded = ProcessInfo.processInfo.arguments.contains("--expanded")
        isExpanded = startsExpanded
    }
}

struct NotchRootView: View {
    @ObservedObject var usage: UsageController
    @ObservedObject var panel: PanelViewState
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sideWidth: CGFloat = 70
    private let expandedHeight: CGFloat = 244
    private var islandWidth: CGFloat { panel.notchWidth + sideWidth * 2 }
    private var islandHeight: CGFloat { panel.isExpanded ? expandedHeight : panel.compactHeight }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                Color(red: 0.035, green: 0.037, blue: 0.041)
                detailPanel
                    .padding(.top, panel.compactHeight)
                    .opacity(panel.isExpanded ? 1 : 0)
                    .allowsHitTesting(panel.isExpanded)
                    .animation(.easeOut(duration: 0.14).delay(panel.isExpanded ? 0.06 : 0), value: panel.isExpanded)
            }
            .frame(width: islandWidth, height: islandHeight, alignment: .top)
            .clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: panel.isExpanded ? 22 : 11,
                    bottomTrailingRadius: panel.isExpanded ? 22 : 11,
                    topTrailingRadius: 0
                )
            )
            .shadow(color: .black.opacity(panel.isExpanded ? 0.38 : 0), radius: 26, y: 14)
            .animation(reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.22), value: panel.isExpanded)

            compactBar
                .frame(width: islandWidth, height: panel.compactHeight)
                .position(x: islandWidth / 2, y: panel.compactHeight / 2)
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        .frame(width: islandWidth, height: expandedHeight, alignment: .top)
        .ignoresSafeArea()
    }

    private var compactBar: some View {
        Button {
            panel.isExpanded.toggle()
        } label: {
            HStack(spacing: 0) {
                compactMetric
                    .frame(width: sideWidth, alignment: .center)

                Color.clear
                    .frame(width: panel.notchWidth)

                resetMetric
                    .frame(width: sideWidth, alignment: .center)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("立即刷新") { usage.refresh() }
            Button(launchAtLogin.isEnabled ? "关闭登录时启动" : "登录时启动") {
                launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
            }
            Divider()
            Button("退出 Codex Island") { NSApplication.shared.terminate(nil) }
        }
    }

    private var compactMetric: some View {
        HStack(spacing: 4) {
            if let window = usage.snapshot?.fiveHour {
                QuotaRing(percent: window.remainingPercent)
                Text("\(window.remainingPercent)%")
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(QuotaTone(remainingPercent: window.remainingPercent).color)
            } else {
                ProgressView().controlSize(.small).tint(.white)
            }
        }
        .padding(.horizontal, 5)
        .frame(height: panel.compactHeight)
    }

    private var resetMetric: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.38))
            Text(usage.snapshot?.fiveHour.remainingResetText(at: usage.now) ?? "--")
                .font(.system(size: 12.5, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .monospacedDigit()
        }
        .padding(.horizontal, 5)
        .frame(height: panel.compactHeight)
    }

    private var detailPanel: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CODEX 额度")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.48))
                    Text("使用状态")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    usage.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10.5, weight: .medium))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                if let fiveHour = usage.snapshot?.fiveHour {
                    QuotaRow(
                        title: "5 小时额度",
                        window: fiveHour,
                        resetText: fiveHour.resetDate.map { "\(Self.fullDate.string(from: $0)) 重置" } ?? "重置时间未知"
                    )
                }

                Divider().overlay(Color.white.opacity(0.08))

                if let weekly = usage.snapshot?.weekly {
                    QuotaRow(
                        title: "本周额度",
                        window: weekly,
                        resetText: weekly.resetDate.map { "\(Self.fullDate.string(from: $0)) 重置" } ?? "重置时间未知"
                    )
                }
            }
            .background(Color.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .padding(.horizontal, 10)

            HStack {
                Label("可用重置", systemImage: "arrow.counterclockwise.circle")
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                Spacer()
                Text("\(usage.snapshot?.resetCredits ?? 0) 次")
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            footer
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)

            Spacer()

            if let date = usage.snapshot?.fetchedAt {
                Text("更新于 \(Self.detailTime.string(from: date))")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.32))
            }
        }
    }

    private var statusColor: Color {
        switch usage.state {
        case .ready: Color(red: 0.33, green: 0.82, blue: 0.54)
        case .loading: Color.white.opacity(0.5)
        case .stale: Color(red: 1.0, green: 0.61, blue: 0.18)
        case .hidden: .clear
        }
    }

    private var statusText: String {
        switch usage.state {
        case .ready: "已连接 Codex"
        case .loading: "正在读取额度"
        case let .stale(message): message
        case .hidden: "Codex 未运行"
        }
    }

    private static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    private static let detailTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

private struct QuotaRing: View {
    let percent: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 1.7)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(
                    QuotaTone(remainingPercent: percent).color,
                    style: StrokeStyle(lineWidth: 1.7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 11, height: 11)
    }
}

private struct QuotaRow: View {
    let title: String
    let window: UsageWindow
    let resetText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                Spacer()
                Text("剩余 \(window.remainingPercent)%")
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.30))
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.36))
                Text(resetText)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))

                Spacer()

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.05))
                        Capsule()
                            .fill(QuotaTone(remainingPercent: window.remainingPercent).color.opacity(0.28))
                            .frame(width: proxy.size.width * CGFloat(window.remainingPercent) / 100)
                    }
                }
                .frame(width: 64, height: 2.5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
