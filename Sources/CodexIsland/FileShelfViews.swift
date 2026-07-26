import AppKit
import QuickLookThumbnailing
import SwiftUI

struct FileShelfPanel: View {
    @ObservedObject var shelf: FileShelfStore
    @ObservedObject var panel: PanelViewState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "tray.full")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(IslandPalette.blue.opacity(0.86))
                Text("文件暂存")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))

                Text("\(shelf.items.count)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(IslandPalette.cyan)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(IslandPalette.blue.opacity(0.14))
                    .clipShape(Capsule())

                Spacer()

                Button("清空") {
                    shelf.clear()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))

                Button {
                    shelf.chooseFiles()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9.5, weight: .semibold))
                        .frame(width: 21, height: 21)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.78))
                .help("选择文件")
            }
            .padding(.horizontal, 14)
            .frame(height: 34)

            populatedShelf
                .frame(height: 66)
        }
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    private var populatedShelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(shelf.items) { item in
                    FileShelfCard(item: item, shelf: shelf, panel: panel)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(panel.isDropTargeted ? IslandPalette.blue.opacity(0.10) : .clear)
        )
        .overlay {
            if panel.isDropTargeted {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(IslandPalette.cyan.opacity(0.65), lineWidth: 1)
                    .padding(.horizontal, 10)
            }
        }
    }
}

struct FileDropPrompt: View {
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(IslandPalette.cyan)

            Text("松手即可暂存")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IslandPalette.blue.opacity(0.09))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    IslandPalette.cyan.opacity(0.65),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
    }
}

private struct FileShelfCard: View {
    let item: FileShelfItem
    @ObservedObject var shelf: FileShelfStore
    @ObservedObject var panel: PanelViewState

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                FileThumbnail(item: item)

                FileDragSource(
                    fileURL: item.url,
                    onDragBegan: panel.beginFileDrag,
                    onDragEnded: { accepted in
                        shelf.completeOutboundDrag(of: item, accepted: accepted)
                        panel.endFileDrag()
                    }
                )
                .contentShape(Rectangle())
                .help("拖到 Codex 输入框")
            }
            .frame(width: 46, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button {
                    shelf.remove(item)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .frame(width: 15, height: 15)
                        .background(.black.opacity(0.72))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.82))
                .offset(x: 4, y: -4)
                .help("移除")
            }

            Text(item.displayName)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 54)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName)，成功拖出后会从暂存移除")
    }
}

private struct FileThumbnail: View {
    let item: FileShelfItem
    @State private var thumbnail: NSImage?

    var body: some View {
        Image(nsImage: thumbnail ?? fallbackIcon)
            .resizable()
            .aspectRatio(contentMode: item.isImage ? .fill : .fit)
            .frame(width: 46, height: 40)
            .background(Color.white.opacity(0.055))
            .task(id: item.id) {
                await loadThumbnail()
            }
    }

    private var fallbackIcon: NSImage {
        let icon = NSWorkspace.shared.icon(forFile: item.url.path)
        icon.size = NSSize(width: 40, height: 40)
        return icon
    }

    private func loadThumbnail() async {
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: 92, height: 80),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: item.isImage ? [.thumbnail] : [.icon]
        )
        guard let representation = try? await QLThumbnailGenerator.shared
            .generateBestRepresentation(for: request) else { return }
        thumbnail = representation.nsImage
    }
}
