import SwiftUI

struct GalleryView: View {
    @EnvironmentObject var store: DocumentStore
    @Binding var showScanner: Bool
    @State private var selectedDoc: ScanDocument?

    var body: some View {
        Group {
            if store.documents.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.documents) { doc in
                        DocumentRow(document: doc)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedDoc = doc }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.delete(doc)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $selectedDoc) { doc in
            DocumentDetailView(documentID: doc.id)
                .environmentObject(store)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.teal.opacity(0.7))
            Text("No Scans Yet")
                .font(.title2).bold()
            Text("Tap the camera button below to scan your first document.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

struct DocumentRow: View {
    let document: ScanDocument
    @State private var thumbnail: UIImage? = nil

    var body: some View {
        HStack(spacing: 14) {
            thumbnailView
                .frame(width: 52, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 5) {
                Text(document.name)
                    .font(.body)
                    .lineLimit(1)
                Text(document.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "doc")
                        .font(.caption2)
                    Text("\(document.pageCount) page\(document.pageCount == 1 ? "" : "s")")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .task(id: document.id) {
            guard let path = document.thumbnailURL?.path else { return }
            let image = await Task.detached(priority: .utility) {
                UIImage(contentsOfFile: path)
            }.value
            thumbnail = image
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let img = thumbnail {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray5))
                .overlay {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
