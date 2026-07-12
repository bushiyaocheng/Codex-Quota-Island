import AppKit
import SwiftUI

@MainActor
final class PanelViewState: ObservableObject {
    static let expandedHeight: CGFloat = 244

    @Published private(set) var isExpanded: Bool
    @Published var notchWidth: CGFloat = 180
    @Published var compactHeight: CGFloat = 34
    let startsExpanded: Bool

    init() {
        startsExpanded = ProcessInfo.processInfo.arguments.contains("--expanded")
        isExpanded = startsExpanded
    }

    func toggleClickExpansion() {
        guard !startsExpanded else { return }
        isExpanded.toggle()
    }

    func setHovering(_ hovering: Bool) {
        guard !startsExpanded else { return }
        isExpanded = hovering
    }

    func resetInteractionExpansion() {
        guard !startsExpanded else { return }
        isExpanded = false
    }
}

struct NotchRootView: View {
    @ObservedObject var usage: UsageController
    @ObservedObject var panel: PanelViewState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sideWidth: CGFloat = 70
    private var islandWidth: CGFloat { panel.notchWidth + sideWidth * 2 }
    private var islandHeight: CGFloat {
        panel.isExpanded ? PanelViewState.expandedHeight : panel.compactHeight
    }

    var body: some View {
        ZStack(alignment: .top) {
            islandSurface

            compactBar
                .frame(width: islandWidth, height: panel.compactHeight)
                .background(panel.isExpanded ? IslandPalette.background : Color.clear)
                .overlay(alignment: .bottom) {
                    if panel.isExpanded {
                        IslandPalette.background
                            .frame(height: 1)
                            .offset(y: 0.5)
                    }
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        .frame(width: islandWidth, height: PanelViewState.expandedHeight, alignment: .top)
        .ignoresSafeArea()
    }

    private var islandSurface: some View {
        ZStack(alignment: .top) {
            IslandPalette.background

            detailPanel
                .padding(.top, panel.compactHeight)
                .opacity(panel.isExpanded ? 1 : 0)
                .allowsHitTesting(panel.isExpanded)
                .animation(.easeOut(duration: 0.15).delay(panel.isExpanded ? 0.055 : 0), value: panel.isExpanded)

        }
        .frame(width: islandWidth, height: islandHeight, alignment: .top)
        .clipShape(islandShape)
        .overlay {
            islandShape
                .stroke(
                    IslandPalette.blue.opacity(panel.isExpanded ? 0.28 : 0),
                    lineWidth: 0.8
                )
        }
        .overlay(alignment: .top) {
            IslandPalette.background
                .frame(height: 1)
        }
        .shadow(color: IslandPalette.blue.opacity(panel.isExpanded ? 0.08 : 0), radius: 16, y: 8)
        .shadow(color: .black.opacity(panel.isExpanded ? 0.38 : 0), radius: 26, y: 14)
        .animation(reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.22), value: panel.isExpanded)
    }

    private var islandShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: panel.isExpanded ? 22 : 11,
            bottomTrailingRadius: panel.isExpanded ? 22 : 11,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    private var compactBar: some View {
        Button {
            guard ExpansionPreference.mode == .click else { return }
            panel.toggleClickExpansion()
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
    }

    private var compactMetric: some View {
        HStack(spacing: 4) {
            if let window = usage.snapshot?.fiveHour {
                QuotaRing(percent: window.remainingPercent, healthyColor: IslandPalette.blue)
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
        .offset(x: -4)
    }

    private var resetMetric: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(IslandPalette.blue.opacity(0.78))
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
                    (Text("CODEX").foregroundColor(IslandPalette.blue.opacity(0.9))
                        + Text(" 额度").foregroundColor(.white.opacity(0.48)))
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .tracking(1.1)
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
                        resetText: fiveHour.resetDate.map { "\(Self.fullDate.string(from: $0)) 重置" } ?? "重置时间未知",
                        accent: IslandPalette.cyan
                    )
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.horizontal, 4)

                if let weekly = usage.snapshot?.weekly {
                    QuotaRow(
                        title: "本周额度",
                        window: weekly,
                        resetText: weekly.resetDate.map { "\(Self.fullDate.string(from: $0)) 重置" } ?? "重置时间未知",
                        accent: IslandPalette.blue
                    )
                }
            }
            .padding(.horizontal, 10)

            HStack {
                Label("可用重置", systemImage: "arrow.counterclockwise.circle")
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundStyle(IslandPalette.cyan.opacity(0.76))
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
                    .foregroundStyle(IslandPalette.cyan.opacity(0.48))
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

enum ExpansionMode: String {
    case click
    case hover
}

enum ExpansionPreference {
    static let storageKey = "islandExpansionMode"
    private static let legacyClickStorageKey = "clickExpansionEnabled"
    private static let legacyHoverStorageKey = "hoverExpansionEnabled"

    static var mode: ExpansionMode {
        get {
            let defaults = UserDefaults.standard
            if let rawValue = defaults.string(forKey: storageKey),
               let mode = ExpansionMode(rawValue: rawValue) {
                return mode
            }

            if defaults.bool(forKey: legacyClickStorageKey),
               !defaults.bool(forKey: legacyHoverStorageKey) {
                return .click
            }
            return .hover
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.rawValue, forKey: storageKey)
            defaults.set(newValue == .click, forKey: legacyClickStorageKey)
            defaults.set(newValue == .hover, forKey: legacyHoverStorageKey)
        }
    }

    static func select(_ mode: ExpansionMode) {
        let defaults = UserDefaults.standard
        guard self.mode != mode else { return }
        defaults.set(mode.rawValue, forKey: storageKey)
        defaults.set(mode == .click, forKey: legacyClickStorageKey)
        defaults.set(mode == .hover, forKey: legacyHoverStorageKey)
    }
}

private enum IslandPalette {
    static let background = Color(red: 0.035, green: 0.037, blue: 0.045)
    static let blue = Color(red: 0.31, green: 0.58, blue: 1.0)
    static let cyan = Color(red: 0.32, green: 0.82, blue: 0.90)
}

private struct QuotaRing: View {
    let percent: Int
    let healthyColor: Color

    private var color: Color {
        switch QuotaTone(remainingPercent: percent) {
        case .normal: healthyColor
        case .warning, .critical: QuotaTone(remainingPercent: percent).color
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 1.7)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(
                    color,
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
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(accent.opacity(0.48))
                    highlightedResetText
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                }
            }

            Spacer(minLength: 8)

            DetailQuotaRing(percent: window.remainingPercent, accent: accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private var highlightedResetText: Text {
        guard resetText.hasSuffix("重置") else {
            return Text(resetText).foregroundColor(.white.opacity(0.72))
        }

        let time = resetText.dropLast(2).trimmingCharacters(in: .whitespaces)
        return Text("\(time) ").foregroundColor(accent.opacity(0.94))
            + Text("重置").foregroundColor(.white.opacity(0.82))
    }
}

private struct DetailQuotaRing: View {
    let percent: Int
    let accent: Color

    private var color: Color {
        switch QuotaTone(remainingPercent: percent) {
        case .normal: accent
        case .warning, .critical: QuotaTone(remainingPercent: percent).color
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.035))
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 2.4)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percent)%")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.94))
        }
        .frame(width: 42, height: 42)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("剩余 \(percent)%")
    }
}
