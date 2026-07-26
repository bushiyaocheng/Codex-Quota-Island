import Foundation
import SwiftUI

@MainActor
final class PanelViewState: ObservableObject {
    private static let twoWindowExpandedHeight: CGFloat = 360
    private static let quotaRowIncrement: CGFloat = 49
    private static let resetCreditsHeight: CGFloat = 34

    @Published private(set) var isExpanded: Bool
    @Published private(set) var isDropTargeted = false
    @Published private(set) var expandedHeight: CGFloat = twoWindowExpandedHeight
    @Published var notchWidth: CGFloat = 180
    @Published var compactHeight: CGFloat = 34
    let startsExpanded: Bool

    private var isClickExpanded: Bool
    private var isHovering = false
    private var isDraggingFile = false

    init() {
        startsExpanded = ProcessInfo.processInfo.arguments.contains("--expanded")
        isExpanded = startsExpanded
        isClickExpanded = startsExpanded
    }

    func toggleClickExpansion() {
        guard !startsExpanded else { return }
        isClickExpanded.toggle()
        updateExpansion()
    }

    func setHovering(_ hovering: Bool) {
        guard !startsExpanded else { return }
        isHovering = hovering
        updateExpansion()
    }

    func resetInteractionExpansion() {
        guard !startsExpanded else { return }
        isClickExpanded = false
        isHovering = false
        isDropTargeted = false
        isDraggingFile = false
        updateExpansion()
    }

    func setDropTargeted(_ targeted: Bool) {
        guard !startsExpanded else { return }
        isDropTargeted = targeted
        updateExpansion()
    }

    func completeFileDrop() {
        guard !startsExpanded else { return }
        isDropTargeted = false
        revealShelf()
    }

    func revealShelf() {
        guard !startsExpanded else { return }
        switch ExpansionPreference.mode {
        case .click:
            isClickExpanded = true
        case .hover:
            isHovering = true
        }
        updateExpansion()
    }

    func beginFileDrag() {
        guard !startsExpanded else { return }
        isDraggingFile = true
        updateExpansion()
    }

    func endFileDrag() {
        guard !startsExpanded else { return }
        isDraggingFile = false
        updateExpansion()
    }

    func updateContent(windowCount: Int, showsResetCredits: Bool) {
        let visibleWindowCount = max(1, windowCount)
        let windowDelta = CGFloat(visibleWindowCount - 2) * Self.quotaRowIncrement
        let creditsDelta = showsResetCredits ? 0 : -Self.resetCreditsHeight
        let newHeight = Self.twoWindowExpandedHeight + windowDelta + creditsDelta
        guard expandedHeight != newHeight else { return }
        expandedHeight = newHeight
    }

    private func updateExpansion() {
        let interactionExpansion: Bool
        switch ExpansionPreference.mode {
        case .click:
            interactionExpansion = isClickExpanded
        case .hover:
            interactionExpansion = isHovering
        }
        isExpanded = interactionExpansion || isDropTargeted || isDraggingFile
    }
}
