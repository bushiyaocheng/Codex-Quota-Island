import Foundation
import SwiftUI

@MainActor
final class PanelViewState: ObservableObject {
    private static let twoWindowExpandedHeight: CGFloat = 244
    private static let quotaRowIncrement: CGFloat = 49
    private static let resetCreditsHeight: CGFloat = 34

    @Published private(set) var isExpanded: Bool
    @Published private(set) var expandedHeight: CGFloat = twoWindowExpandedHeight
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

    func updateContent(windowCount: Int, showsResetCredits: Bool) {
        let visibleWindowCount = max(1, windowCount)
        let windowDelta = CGFloat(visibleWindowCount - 2) * Self.quotaRowIncrement
        let creditsDelta = showsResetCredits ? 0 : -Self.resetCreditsHeight
        let newHeight = Self.twoWindowExpandedHeight + windowDelta + creditsDelta
        guard expandedHeight != newHeight else { return }
        expandedHeight = newHeight
    }
}
