import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Scan filters

enum ScanFilter: String, CaseIterable, Identifiable {
    case enhance   = "Enhance"
    case original  = "Original"
    case lighten   = "Lighten"
    case grayscale = "Grayscale"
    case eco       = "Eco"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .enhance:   return "wand.and.stars"
        case .original:  return "photo"
        case .lighten:   return "sun.max"
        case .grayscale: return "circle.lefthalf.filled"
        case .eco:       return "leaf"
        }
    }

    private static let ctx = CIContext(options: [.useSoftwareRenderer: false])

    func apply(to image: UIImage) -> UIImage {
        guard let ci = CIImage(image: image) else { return image }
        let output: CIImage?
        switch self {
        case .original:
            return image
        case .enhance:
            let c = CIFilter.colorControls()
            c.inputImage = ci; c.saturation = 0; c.contrast = 1.6; c.brightness = 0.08
            let s = CIFilter.unsharpMask()
            s.inputImage = c.outputImage; s.radius = 2.0; s.intensity = 0.9
            output = s.outputImage
        case .lighten:
            let c = CIFilter.colorControls()
            c.inputImage = ci; c.saturation = 0; c.brightness = 0.30; c.contrast = 1.1
            output = c.outputImage
        case .grayscale:
            let c = CIFilter.colorControls()
            c.inputImage = ci; c.saturation = 0; c.contrast = 1.0; c.brightness = 0
            output = c.outputImage
        case .eco:
            let c = CIFilter.colorControls()
            c.inputImage = ci; c.saturation = 0; c.contrast = 1.3; c.brightness = 0.12
            output = c.outputImage
        }
        guard let out = output,
              let cg  = Self.ctx.createCGImage(out, from: out.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }
}

// MARK: - New document scan flow: camera → review → auto-save → document detail

struct ScannerFlowView: View {
    @EnvironmentObject var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    @State private var pendingImages: [UIImage] = []
    @State private var savedDocID: UUID? = nil
    @State private var screen: Screen = .camera

    enum Screen { case camera, review, document }

    var body: some View {
        switch screen {
        case .camera:
            CameraView { captured in
                pendingImages = captured
                screen = .review
            } onCancel: {
                dismiss()
            }
            .ignoresSafeArea()

        case .review:
            if !pendingImages.isEmpty {
                PageReviewView(
                    rawImages: pendingImages,
                    onRetake: {
                        pendingImages = []
                        screen = .camera
                    },
                    onDone: { filteredImages in
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd HH.mm"
                        let name = "Scan \(f.string(from: Date()))"
                        let doc = store.save(pages: filteredImages, name: name)
                        savedDocID = doc.id
                        screen = .document
                    }
                )
            }

        case .document:
            if let docID = savedDocID {
                DocumentDetailView(documentID: docID)
                    .environmentObject(store)
            }
        }
    }
}

// MARK: - Add-page flow (from DocumentDetailView)

struct AddPageScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onDone: ([UIImage]) -> Void

    @State private var pendingImages: [UIImage] = []
    @State private var screen: Screen = .camera

    enum Screen { case camera, review }

    var body: some View {
        switch screen {
        case .camera:
            CameraView { captured in
                pendingImages = captured
                screen = .review
            } onCancel: {
                dismiss()
            }
            .ignoresSafeArea()

        case .review:
            if !pendingImages.isEmpty {
                PageReviewView(
                    rawImages: pendingImages,
                    onRetake: {
                        pendingImages = []
                        screen = .camera
                    },
                    onDone: { filteredImages in
                        onDone(filteredImages)
                        dismiss()
                    }
                )
            }
        }
    }
}

// MARK: - Single-page review with filter selector
// Shows first page as preview; applies selected filter to ALL pages on confirm.

struct PageReviewView: View {
    let rawImages: [UIImage]
    let onRetake: () -> Void
    let onDone: ([UIImage]) -> Void

    @State private var selectedFilter: ScanFilter = .enhance
    @State private var previewImage: UIImage

    init(rawImages: [UIImage],
         onRetake: @escaping () -> Void,
         onDone: @escaping ([UIImage]) -> Void) {
        self.rawImages = rawImages
        self.onRetake  = onRetake
        self.onDone    = onDone
        _previewImage  = State(initialValue: ScanFilter.enhance.apply(to: rawImages[0]))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                documentPreview
                filterBar
                actionBar
            }
        }
        .onChange(of: selectedFilter) { _, newFilter in
            Task.detached(priority: .userInitiated) {
                let result = newFilter.apply(to: self.rawImages[0])
                await MainActor.run { self.previewImage = result }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button("Retake", action: onRetake)
                .foregroundStyle(.white)
                .padding(.horizontal)
            Spacer()
            Text(rawImages.count > 1 ? "\(rawImages.count) pages" : "1 page")
                .foregroundStyle(.white)
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 70)
        }
        .frame(height: 52)
        .background(Color.black.opacity(0.8))
    }

    private var documentPreview: some View {
        Image(uiImage: previewImage)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ScanFilter.allCases) { filter in
                    FilterChip(filter: filter, rawImage: rawImages[0],
                               isSelected: selectedFilter == filter) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 94)
        .background(Color(.systemGray6))
    }

    private var actionBar: some View {
        HStack {
            Spacer()
            Button {
                let filter = selectedFilter
                let images = rawImages
                Task.detached(priority: .userInitiated) {
                    let results = images.map { filter.apply(to: $0) }
                    await MainActor.run { onDone(results) }
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.teal)
                    .clipShape(Circle())
            }
            Spacer()
        }
        .frame(height: 72)
        .background(Color.black.opacity(0.9))
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
    }
}

// MARK: - Filter thumbnail chip

struct FilterChip: View {
    let filter: ScanFilter
    let rawImage: UIImage
    let isSelected: Bool
    let action: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Group {
                    if let thumb = thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.systemGray4)
                            .overlay { ProgressView().tint(.gray) }
                    }
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isSelected ? Color.teal : Color.clear, lineWidth: 2.5)
                )

                Text(filter.rawValue)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .teal : .secondary)
            }
            .padding(.horizontal, 6)
        }
        .task {
            thumbnail = await makeThumbnail()
        }
    }

    private func makeThumbnail() async -> UIImage {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let small = resize(rawImage, to: CGSize(width: 108, height: 108))
                cont.resume(returning: filter.apply(to: small))
            }
        }
    }

    private func resize(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return result
    }
}
