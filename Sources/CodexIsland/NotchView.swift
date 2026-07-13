import SwiftUI

struct NotchRootView: View {
    @ObservedObject var usage: UsageController
    @ObservedObject var panel: PanelViewState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sideWidth: CGFloat = 70
    private var islandWidth: CGFloat { panel.notchWidth + sideWidth * 2 }
    private var islandHeight: CGFloat {
        panel.isExpanded ? panel.expandedHeight : panel.compactHeight
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
        .frame(width: islandWidth, height: panel.expandedHeight, alignment: .top)
        .ignoresSafeArea()
    }

    private var islandSurface: some View {
        ZStack(alignment: .top) {
            IslandPalette.background

            detailPanel
                .padding(.top, panel.compactHeight)
                .opacity(panel.isExpanded ? 1 : 0)
                .blur(radius: panel.isExpanded ? 0 : 7)
                .scaleEffect(panel.isExpanded ? 1 : 0.985, anchor: .top)
                .allowsHitTesting(panel.isExpanded)
                .animation(detailAnimation, value: panel.isExpanded)

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
        .animation(surfaceAnimation, value: panel.isExpanded)
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

    private var surfaceAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.01)
            : .smooth(duration: 0.36)
    }

    private var detailAnimation: Animation {
        guard !reduceMotion else { return .linear(duration: 0.01) }
        return .easeOut(duration: panel.isExpanded ? 0.22 : 0.12)
            .delay(panel.isExpanded ? 0.09 : 0)
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
            if let quota = usage.snapshot?.compactWindow {
                QuotaRing(percent: quota.usage.remainingPercent, healthyColor: quota.kind.accent)
                Text("\(quota.usage.remainingPercent)%")
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        QuotaTone(remainingPercent: quota.usage.remainingPercent).color(normal: .white)
                    )
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
            Text(usage.snapshot?.compactWindow?.usage.remainingResetText(at: usage.now) ?? "--")
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
                if quotaWindows.isEmpty {
                    HStack(spacing: 8) {
                        if case .loading = usage.state {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white.opacity(0.7))
                        }
                        Text(emptyQuotaText)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.52))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 48)
                } else {
                    ForEach(Array(quotaWindows.enumerated()), id: \.offset) { index, quota in
                        QuotaRow(
                            title: quota.kind.title,
                            window: quota.usage,
                            resetText: quota.usage.resetDate.map {
                                "\(Self.fullDate.string(from: $0)) 重置"
                            } ?? "重置时间未知",
                            accent: quota.kind.accent
                        )

                        if index < quotaWindows.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.08))
                                .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            if let resetCredits = usage.snapshot?.resetCredits {
                HStack {
                    Label("可用重置", systemImage: "arrow.counterclockwise.circle")
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundStyle(IslandPalette.cyan.opacity(0.76))
                    Spacer()
                    Text("\(resetCredits) 次")
                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            footer
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
    }

    private var quotaWindows: [QuotaWindow] {
        usage.snapshot?.windows ?? []
    }

    private var emptyQuotaText: String {
        switch usage.state {
        case .loading: "正在读取额度"
        case .ready, .stale, .hidden: "暂无额度数据"
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
