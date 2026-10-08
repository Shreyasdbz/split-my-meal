import SwiftUI
import UIKit

/// Displays the stored receipt with native pinch zoom and system sharing.
struct ReceiptViewer: View {
    @Environment(\.dismiss) private var dismiss
    private let image: UIImage?
    @State private var showShare = false
    @State private var zoomScale: CGFloat = 1

    init(data: Data) {
        image = ReceiptPhoto.preview(data)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    ZoomableReceipt(image: image, zoomScale: $zoomScale)
                        .accessibilityLabel("Receipt photo. Pinch to zoom.")
                } else {
                    ContentUnavailableView("Receipt unavailable", systemImage: "photo", description: Text("This saved photo couldn’t be opened. Replace it in the meal editor.").foregroundStyle(Color.mealSecondaryText))
                }
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Zoom out", systemImage: "minus.magnifyingglass") { zoomScale = max(1, zoomScale - 1) }
                        .disabled(zoomScale <= 1 || image == nil)
                    Spacer()
                    Text("\(Int(zoomScale * 100))%")
                        .monospacedDigit()
                        .accessibilityLabel("Zoom \(Int(zoomScale * 100)) percent")
                    Spacer()
                    Button("Zoom in", systemImage: "plus.magnifyingglass") { zoomScale = min(6, zoomScale + 1) }
                        .disabled(zoomScale >= 6 || image == nil)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Share", systemImage: "square.and.arrow.up") { showShare = true }
                        .disabled(image == nil)
                        .accessibilityIdentifier("share-receipt")
                }
            }
            .sheet(isPresented: $showShare) {
                if let image { ReceiptShareSheet(image: image) }
            }
        }
    }
}

private struct ReceiptShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

private struct ZoomableReceipt: UIViewRepresentable {
    let image: UIImage
    @Binding var zoomScale: CGFloat
    func makeCoordinator() -> Coordinator { Coordinator(zoomScale: $zoomScale) }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = ReceiptScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 6
        scroll.bouncesZoom = true
        scroll.backgroundColor = .systemBackground
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "Receipt photo"
        imageView.accessibilityIdentifier = "receipt-photo"
        scroll.addSubview(imageView)
        scroll.receiptView = imageView
        context.coordinator.imageView = imageView
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scroll
        return scroll
    }

    func updateUIView(_ view: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        context.coordinator.zoomScale = $zoomScale
        if abs(view.zoomScale - zoomScale) > 0.01 {
            context.coordinator.isProgrammaticZoom = true
            view.setZoomScale(zoomScale, animated: false)
            context.coordinator.isProgrammaticZoom = false
        }
        view.setNeedsLayout()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?
        var zoomScale: Binding<CGFloat>
        var isProgrammaticZoom = false
        init(zoomScale: Binding<CGFloat>) { self.zoomScale = zoomScale }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard !isProgrammaticZoom else { return }
            zoomScale.wrappedValue = scrollView.zoomScale
        }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        @objc func doubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }
            let animated = !UIAccessibility.isReduceMotionEnabled
            if scrollView.zoomScale > 1 {
                scrollView.setZoomScale(1, animated: animated)
            } else {
                let point = recognizer.location(in: imageView)
                let size = CGSize(width: scrollView.bounds.width / 3, height: scrollView.bounds.height / 3)
                scrollView.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: animated)
            }
        }
    }
}

/// Reflows the base image after resizing while preserving user zoom between ordinary updates.
private final class ReceiptScrollView: UIScrollView {
    weak var receiptView: UIImageView?
    private var lastSize: CGSize = .zero
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let receiptView, bounds.size != lastSize else { return }
        lastSize = bounds.size
        setZoomScale(1, animated: false)
        receiptView.frame = CGRect(origin: .zero, size: bounds.size)
        contentSize = bounds.size
    }
}
