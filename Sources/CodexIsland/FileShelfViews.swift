import AppKit
import QuickLookThumbnailing
import SwiftUI

struct FileShelfSection: View {
    @ObservedObject var shelf: FileShelfStore
    @ObservedObject var panel: PanelViewState

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.horizontal, 14)

            HStack(spacing: 6) {
                Image(systemName: "tray.full")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(IslandPalette.blue.opacity(0.86))
                Text("文件暂存")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))

                if !shelf.items.isEmpty {
                    Text("\(shelf.items.count)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(IslandPalette.cyan)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(IslandPalette.blue.opacity(0.14))
                        .clipShape(Capsule())
                }

                Spacer()

                if !shelf.items.isEmpty {
                    Button("清空") {
                        shelf.clear()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                }

                Button {
                    if shelf.chooseFiles() > 0 {
                        panel.revealShelf()
                    }
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
            .frame(height: 30)

            Group {
                if shelf.items.isEmpty {
                    emptyShelf
                } else {
                    populatedShelf
                }
            }
            .frame(height: 62)

            Text(shelf.items.isEmpty ? shelf.notice : "把缩略图拖到 Codex 输入框即可发送")
                .font(.system(size: 9.5, weight: .regular, design: .rounded))
                .foregroundStyle(
                    panel.isDropTargeted
                        ? IslandPalette.cyan.opacity(0.92)
                        : .white.opacity(0.34)
                )
                .lineLimit(1)
                .frame(height: 18)
        }
    }

    private var emptyShelf: some View {
        HStack(spacing: 8) {
            Image(systemName: panel.isDropTargeted ? "arrow.down.doc.fill" : "photo.on.rectangle.angled")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(
                    panel.isDropTargeted
                        ? IslandPalette.cyan
                        : IslandPalette.blue.opacity(0.58)
                )
            Text(panel.isDropTargeted ? "松手即可暂存" : "拖入图片或文件")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(panel.isDropTargeted ? 0.9 : 0.54))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    panel.isDropTargeted
                        ? IslandPalette.blue.opacity(0.16)
                        : Color.white.opacity(0.025)
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    panel.isDropTargeted
                        ? IslandPalette.cyan.opacity(0.7)
                        : Color.white.opacity(0.10),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
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
                    onDragEnded: panel.endFileDrag
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
        .accessibilityLabel("\(item.displayName)，可拖到 Codex")
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
