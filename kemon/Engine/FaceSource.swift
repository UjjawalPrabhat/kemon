//
//  FaceSource.swift
//  kemon
//
//  Abstraction over "something that produces EmotionReadings from the front
//  camera", so KemonEngine can drive either the Core ML + Vision pipeline
//  (CameraController) or ARKit face-tracking (ARFaceController) interchangeably.
//

import Foundation

/// Which analysis pipeline is active. Exposed as an A/B switch in the UI.
enum AnalysisMode: String, CaseIterable, Identifiable, Sendable {
    case model = "Model"   // Core ML classifier + Vision-landmark smile
    case arkit = "ARKit"   // ARFaceTrackingConfiguration blendshapes

    var id: String { rawValue }
}

protocol FaceSource: AnyObject {
    /// Delivered on the main actor with each new reading. The property itself is
    /// nonisolated because the sources run on background capture/AR queues.
    nonisolated var onReading: (@MainActor (EmotionReading) -> Void)? { get set }
    nonisolated func start()
    nonisolated func stop()
}
