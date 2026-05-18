import Foundation
import UIKit
import PDFKit

@MainActor
final class DocumentStore: ObservableObject {
    @Published var documents: [ScanDocument] = []

    private let storageDir: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageDir = docs.appendingPathComponent("IphoneScanner", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Save

    @discardableResult
    func save(pages: [UIImage], name: String, format: SaveFormat = .pdf) -> ScanDocument {
        let id = UUID()
        let dir = storageDir.appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var fileURLs: [URL] = []

        switch format {
        case .pdf:
            if let url = savePDF(pages: pages, to: dir, name: name) {
                fileURLs = [url]
            }
        case .jpeg:
            fileURLs = saveJPEGs(pages: pages, to: dir, name: name)
        case .both:
            if let url = savePDF(pages: pages, to: dir, name: name) {
                fileURLs.append(url)
            }
            fileURLs += saveJPEGs(pages: pages, to: dir, name: name)
        }

        var thumbnailURL: URL?
        if let firstImage = pages.first, let data = firstImage.jpegData(compressionQuality: 0.5) {
            let thumbURL = dir.appendingPathComponent("thumb.jpg")
            try? data.write(to: thumbURL)
            thumbnailURL = thumbURL
        }

        let doc = ScanDocument(
            id: id,
            name: name,
            pageCount: pages.count,
            fileURLs: fileURLs,
            thumbnailURL: thumbnailURL
        )
        documents.insert(doc, at: 0)
        persist()
        return doc
    }

    // MARK: - Add pages to existing document

    func addPage(_ image: UIImage, to document: ScanDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        let dir = storageDir.appendingPathComponent(document.id.uuidString)

        // Append to existing PDF if one exists
        if let pdfURL = documents[index].fileURLs.first(where: { $0.pathExtension == "pdf" }),
           let existing = PDFDocument(url: pdfURL) {
            let merged = PDFDocument()
            for i in 0..<existing.pageCount {
                if let page = existing.page(at: i) { merged.insert(page, at: merged.pageCount) }
            }
            if let newPage = PDFPage(image: image) { merged.insert(newPage, at: merged.pageCount) }
            merged.write(to: pdfURL)
        } else {
            // JPEG-only doc: add new JPEG file
            let pageNum = documents[index].pageCount + 1
            let url = dir.appendingPathComponent("\(documents[index].name)_\(pageNum).jpg")
            if let data = image.jpegData(compressionQuality: 0.85) {
                try? data.write(to: url)
                documents[index].fileURLs.append(url)
            }
        }

        // Update thumbnail if first page had none
        if documents[index].thumbnailURL == nil,
           let data = image.jpegData(compressionQuality: 0.5) {
            let thumbURL = dir.appendingPathComponent("thumb.jpg")
            try? data.write(to: thumbURL)
            documents[index].thumbnailURL = thumbURL
        }

        documents[index].pageCount += 1
        persist()
    }

    // MARK: - Delete page

    func deletePage(at pageIndex: Int, from document: ScanDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }

        // Only PDF-backed documents support page-level deletion
        guard let pdfURL = documents[index].fileURLs.first(where: { $0.pathExtension == "pdf" }),
              let pdf = PDFDocument(url: pdfURL),
              pdf.pageCount > 1 else {
            // Last page → delete the whole document
            delete(document)
            return
        }

        pdf.removePage(at: pageIndex)
        pdf.write(to: pdfURL)
        documents[index].pageCount = pdf.pageCount

        // Regenerate thumbnail from new first page
        if pageIndex == 0, let firstPage = pdf.page(at: 0) {
            let dir = storageDir.appendingPathComponent(document.id.uuidString)
            let bounds = firstPage.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: bounds.size)
            let img = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(bounds)
                ctx.cgContext.translateBy(x: 0, y: bounds.size.height)
                ctx.cgContext.scaleBy(x: 1, y: -1)
                firstPage.draw(with: .mediaBox, to: ctx.cgContext)
            }
            if let data = img.jpegData(compressionQuality: 0.5) {
                let thumbURL = dir.appendingPathComponent("thumb.jpg")
                try? data.write(to: thumbURL)
                documents[index].thumbnailURL = thumbURL
            }
        }

        persist()
    }

    // MARK: - Delete

    func delete(_ document: ScanDocument) {
        let dir = storageDir.appendingPathComponent(document.id.uuidString)
        try? FileManager.default.removeItem(at: dir)
        documents.removeAll { $0.id == document.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets { delete(documents[index]) }
    }

    // MARK: - Private helpers

    private func savePDF(pages: [UIImage], to dir: URL, name: String) -> URL? {
        let pdf = PDFDocument()
        for image in pages {
            if let page = PDFPage(image: image) {
                pdf.insert(page, at: pdf.pageCount)
            }
        }
        let url = dir.appendingPathComponent("\(name).pdf")
        return pdf.write(to: url) ? url : nil
    }

    private func saveJPEGs(pages: [UIImage], to dir: URL, name: String) -> [URL] {
        pages.enumerated().compactMap { i, image in
            guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
            let suffix = pages.count > 1 ? "_\(i + 1)" : ""
            let url = dir.appendingPathComponent("\(name)\(suffix).jpg")
            return (try? data.write(to: url)) != nil ? url : nil
        }
    }

    private func persist() {
        let indexURL = storageDir.appendingPathComponent("index.json")
        if let data = try? JSONEncoder().encode(documents) {
            try? data.write(to: indexURL)
        }
    }

    private func load() {
        let indexURL = storageDir.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([ScanDocument].self, from: data)
        else { return }

        // Absolute paths stored in JSON become stale when the app container UUID rotates
        // (reinstall, simulator reset, etc.). Rebuild every URL from the current storageDir
        // using only the stable last-two components: <doc-uuid>/<filename>.
        documents = decoded.map { doc in
            var fixed = doc
            fixed.fileURLs = doc.fileURLs.map { rebased($0) }
            fixed.thumbnailURL = doc.thumbnailURL.map { rebased($0) }
            return fixed
        }
    }

    private func rebased(_ url: URL) -> URL {
        let parts = url.pathComponents.suffix(2)   // ["<doc-uuid>", "filename.ext"]
        return parts.reduce(storageDir) { $0.appendingPathComponent($1) }
    }
}

enum SaveFormat: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case jpeg = "JPEG"
    case both = "PDF + JPEG"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .jpeg: return "photo.fill"
        case .both: return "doc.on.doc.fill"
        }
    }
}
