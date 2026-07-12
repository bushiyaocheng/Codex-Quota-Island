import Foundation
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
