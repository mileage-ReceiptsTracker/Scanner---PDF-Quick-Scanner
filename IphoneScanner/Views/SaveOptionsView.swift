import SwiftUI
import PDFKit

struct SaveOptionsView: View {
    @EnvironmentObject var store: DocumentStore
    let pages: [UIImage]
    let onDone: () -> Void

    @State private var docName = ""
    @State private var selectedFormat: SaveFormat = .pdf
    @State private var isSaving = false
    @State private var isPreparingShare = false
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    @FocusState private var nameFieldFocused: Bool

    private var defaultName: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH.mm"
        return "Scan \(f.string(from: Date()))"
    }

    private var shareName: String {
        docName.trimmingCharacters(in: .whitespaces).isEmpty ? defaultName : docName
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pages (\(pages.count))") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                                VStack(spacing: 5) {
                                    Image(uiImage: page)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 88, height: 118)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                                    Text("\(i + 1)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section("Document Name") {
                    TextField("e.g. Receipt, Contract…", text: $docName)
                        .focused($nameFieldFocused)
                }

                Section("Save Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(SaveFormat.allCases) { fmt in
                            Label(fmt.rawValue, systemImage: fmt.icon).tag(fmt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        prepareAndShare()
                    } label: {
                        if isPreparingShare {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Preparing PDF…")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isPreparingShare)
                }
            }
            .navigationTitle("Save Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { onDone() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving { ProgressView() }
                        else { Text("Save").bold() }
                    }
                    .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func prepareAndShare() {
        print("[Share] prepareAndShare called, pages: \(pages.count)")
        isPreparingShare = true
        let name = shareName
        let images = pages
        Task.detached(priority: .userInitiated) {
            let pdf = PDFDocument()
            for image in images {
                if let page = PDFPage(image: image) { pdf.insert(page, at: pdf.pageCount) }
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
            let success = pdf.write(to: url)
            print("[Share] PDF write success: \(success), path: \(url.path)")
            await MainActor.run {
                isPreparingShare = false
                if success {
                    shareURL = url
                    showShareSheet = true
                    print("[Share] showShareSheet = true")
                } else {
                    print("[Share] PDF write failed")
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let name = docName.trimmingCharacters(in: .whitespaces).isEmpty ? defaultName : docName
        Task { @MainActor in
            store.save(pages: pages, name: name, format: selectedFormat)
            isSaving = false
            onDone()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
