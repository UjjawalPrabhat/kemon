//
//  CameraPreview.swift
//  kemon
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
#else
// Placeholder so the project also compiles for "Designed for iPad" on Mac.
struct CameraPreview: View {
    let session: AVCaptureSession
    var body: some View { Color.black }
}
#endif
