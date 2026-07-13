import SwiftUI

enum IslandPalette {
    static let background = Color(red: 0.035, green: 0.037, blue: 0.045)
    static let blue = Color(red: 0.31, green: 0.58, blue: 1.0)
    static let cyan = Color(red: 0.32, green: 0.82, blue: 0.90)
}

extension QuotaWindowKind {
    var accent: Color {
        switch self {
        case .fiveHour: IslandPalette.cyan
        case .weekly: IslandPalette.blue
        case .duration, .unknown: IslandPalette.blue
        }
    }
}

extension QuotaTone {
    func color(normal: Color) -> Color {
        switch self {
        case .normal: normal
        case .warning: Color(red: 1.0, green: 0.61, blue: 0.18)
        case .critical: Color(red: 1.0, green: 0.27, blue: 0.25)
        }
    }
}

struct QuotaRing: View {
    let percent: Int
    let healthyColor: Color

    private var color: Color {
        QuotaTone(remainingPercent: percent).color(normal: healthyColor)
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

struct QuotaRow: View {
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
        QuotaTone(remainingPercent: percent).color(normal: accent)
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
