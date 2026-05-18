import SwiftUI
import PDFKit

struct DocumentDetailView: View {
    @EnvironmentObject var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    let documentID: UUID

    @State private var isSharing = false
    @State private var showDeleteAlert = false
    @State private var showAddPage = false
    @State private var pageVersion = 0
    @State private var pageImages: [UIImage] = []

    private var document: ScanDocument? {
        store.documents.first { $0.id == documentID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let doc = document {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(pageImages.enumerated()), id: \.offset) { idx, image in
                                PageFullWidthCell(
                                    image: image,
                                    pageNumber: idx + 1,
                                    onDelete: {
                                        store.deletePage(at: idx, from: doc)
                                        if store.documents.first(where: { $0.id == documentID }) == nil {
                                            dismiss()
                                        } else {
                                            loadPages(for: doc)
                                        }
                                    }
                                )
                            }

                            Button {
                                showAddPage = true
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 34))
                                    Text("Add Page")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundStyle(.teal)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            }
                        }
                        .padding(16)
                    }
                    .navigationTitle(doc.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarItems(doc) }
                    .sheet(isPresented: $showAddPage) {
                        AddPageScannerView { newImages in
                            for image in newImages {
                                store.addPage(image, to: doc)
                            }
                            pageVersion += 1
                            if let updated = store.documents.first(where: { $0.id == documentID }) {
                                loadPages(for: updated)
                            }
                        }
                        .ignoresSafeArea()
                    }
                    .alert("Delete Document?", isPresented: $showDeleteAlert) {
                        Button("Delete", role: .destructive) {
                            store.delete(doc)
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete \"\(doc.name)\".")
                    }
                    .task(id: documentID) {
                        loadPages(for: doc)
                    }
                    .onChange(of: pageVersion) { _, _ in
                        if let updated = store.documents.first(where: { $0.id == documentID }) {
                            loadPages(for: updated)
                        }
                    }
                } else {
                    Text("Document not found")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func loadPages(for doc: ScanDocument) {
        guard let pdfURL = doc.fileURLs.first(where: { $0.pathExtension == "pdf" }),
              let pdf = PDFDocument(url: pdfURL) else {
            pageImages = doc.fileURLs
                .filter { $0.pathExtension == "jpg" }
                .compactMap { UIImage(contentsOfFile: $0.path) }
            return
        }
        Task.detached(priority: .userInitiated) {
            let screenWidth = await UIScreen.main.bounds.width
            let pageCount = pdf.pageCount
            var result: [UIImage] = []
            result.reserveCapacity(pageCount)
            for i in 0..<pageCount {
                guard let page = pdf.page(at: i) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                let scale = screenWidth / bounds.width
                let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                let renderer = UIGraphicsImageRenderer(size: size)
                let img = renderer.image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))
                    ctx.cgContext.translateBy(x: 0, y: size.height)
                    ctx.cgContext.scaleBy(x: scale, y: -scale)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }
                result.append(img)
            }
            await MainActor.run { pageImages = result }
        }
    }

    private func shareDocument(_ doc: ScanDocument) {
        guard let source = doc.fileURLs.first(where: { $0.pathExtension == "pdf" }) ?? doc.fileURLs.first else {
            isSharing = false
            return
        }
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(source.lastPathComponent)
        try? FileManager.default.removeItem(at: temp)
        do {
            try FileManager.default.copyItem(at: source, to: temp)
        } catch {
            isSharing = false
            return
        }
        let ac = UIActivityViewController(activityItems: [temp], applicationActivities: nil)
        ac.completionWithItemsHandler = { _, _, _, _ in isSharing = false }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            isSharing = false
            return
        }
        var presenter = root
        while let p = presenter.presentedViewController { presenter = p }
        presenter.present(ac, animated: true)
    }

    @ToolbarContentBuilder
    private func toolbarItems(_ doc: ScanDocument) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                isSharing = true
                shareDocument(doc)
            } label: {
                if isSharing {
                    ProgressView().tint(.primary)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .disabled(isSharing)
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash").foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Full-width page cell

struct PageFullWidthCell: View {
    let image: UIImage
    let pageNumber: Int
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .overlay(alignment: .bottom) {
                    Text("Page \(pageNumber)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(.bottom, 8)
                }

            Button(action: onDelete) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .offset(x: 6, y: -6)
        }
    }
}
