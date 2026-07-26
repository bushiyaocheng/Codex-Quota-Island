import Foundation
import SwiftUI

@MainActor
final class PanelViewState: ObservableObject {
    private static let twoWindowExpandedHeight: CGFloat = 244
    private static let fileShelfExpandedHeight: CGFloat = 142
    private static let fileDropExpandedHeight: CGFloat = 132
    private static let quotaRowIncrement: CGFloat = 49
    private static let resetCreditsHeight: CGFloat = 34

    @Published private(set) var isExpanded: Bool
    @Published private(set) var isDropTargeted = false
    @Published private(set) var hasShelfItems = false
    @Published private(set) var expandedHeight: CGFloat = twoWindowExpandedHeight
    @Published var notchWidth: CGFloat = 180
    @Published var compactHeight: CGFloat = 34
    let startsExpanded: Bool

    private var isClickExpanded: Bool
    private var isHovering = false
    private var isDraggingFile = false
    private var quotaExpandedHeight: CGFloat = twoWindowExpandedHeight

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
        isClickExpanded = false
        isHovering = false
        isDropTargeted = false
        isDraggingFile = false
        updateExpandedHeight()
        updateExpansion()
    }

    func setDropTargeted(_ targeted: Bool) {
        isDropTargeted = targeted
        updateExpandedHeight()
        updateExpansion()
    }

    func completeFileDrop() {
        isDropTargeted = false
        updateExpandedHeight()
        updateExpansion()
    }

    func setShelfItemCount(_ count: Int) {
        hasShelfItems = count > 0
        updateExpandedHeight()
        updateExpansion()
    }

    func beginFileDrag() {
        isDraggingFile = true
        updateExpansion()
    }

    func endFileDrag() {
        isDraggingFile = false
        updateExpansion()
    }

    func updateContent(windowCount: Int, showsResetCredits: Bool) {
        let visibleWindowCount = max(1, windowCount)
        let windowDelta = CGFloat(visibleWindowCount - 2) * Self.quotaRowIncrement
        let creditsDelta = showsResetCredits ? 0 : -Self.resetCreditsHeight
        let newHeight = Self.twoWindowExpandedHeight + windowDelta + creditsDelta
        guard quotaExpandedHeight != newHeight else { return }
        quotaExpandedHeight = newHeight
        updateExpandedHeight()
    }

    private func updateExpansion() {
        guard !startsExpanded else {
            isExpanded = true
            return
        }

        let interactionExpansion: Bool
        switch ExpansionPreference.mode {
        case .click:
            interactionExpansion = isClickExpanded
        case .hover:
            interactionExpansion = isHovering
        }
        isExpanded = interactionExpansion
            || isDropTargeted
            || hasShelfItems
            || isDraggingFile
    }

    private func updateExpandedHeight() {
        let newHeight: CGFloat
        if hasShelfItems {
            newHeight = Self.fileShelfExpandedHeight
        } else if isDropTargeted {
            newHeight = Self.fileDropExpandedHeight
        } else {
            newHeight = quotaExpandedHeight
        }
        guard expandedHeight != newHeight else { return }
        expandedHeight = newHeight
    }
}
