//
//  CameraPreview.swift
//  Melodash
//
//  Bridges the AVCaptureSession into SwiftUI via an AVCaptureVideoPreviewLayer.
//  The layer only renders frames — the ML frame stream is a separate output on
//  the same session (see CameraController).
//

import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
#elseif os(macOS)
import AppKit

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        if nsView.previewLayer.session !== session {
            nsView.previewLayer.session = session
        }
    }

    /// A layer-backed NSView whose backing layer IS the capture preview layer,
    /// mirroring the iOS `PreviewView`.
    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        init() {
            super.init(frame: .zero)
            wantsLayer = true
            layer = previewLayer
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}
#else
// Fallback so the project still compiles on other platforms.
struct CameraPreview: View {
    let session: AVCaptureSession
    var body: some View { Color.black }
}
#endif
