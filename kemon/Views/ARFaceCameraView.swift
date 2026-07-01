//
//  ARFaceCameraView.swift
//  kemon
//
//  Renders the ARKit face-tracking session's camera feed. The session itself is
//  owned and run by ARFaceController; this view only displays it.
//

import SwiftUI

#if os(iOS) && canImport(ARKit)
import ARKit

struct ARFaceCameraView: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session = session
        view.automaticallyUpdatesLighting = true
        view.rendersContinuously = true
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        if uiView.session !== session { uiView.session = session }
    }
}
#endif
