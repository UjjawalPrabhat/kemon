//
//  ARFaceController.swift
//  kemon
//
//  ARKit face-tracking source. Uses the TrueDepth camera's blendshape
//  coefficients — Apple's live-tuned facial measurements (the ones that drive
//  Animoji) — which stay reliable while the singer's mouth is moving.
//
//  Blendshape → emotion mapping:
//    happy     ← mouthSmileLeft / mouthSmileRight
//    sad       ← mouthFrownLeft / mouthFrownRight (+ browInnerUp)
//    energetic ← browDownLeft / browDownRight (intense / "angry" brow)
//    neutral   ← whatever's left
//

#if canImport(ARKit)
import ARKit

nonisolated final class ARFaceController: NSObject, ARSessionDelegate, FaceSource, @unchecked Sendable {

    let session = ARSession()
    var onReading: (@MainActor (EmotionReading) -> Void)?

    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    override init() {
        super.init()
        session.delegate = self
    }

    func start() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        session.pause()
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        emit(Self.reading(from: face.blendShapes))
    }

    private func emit(_ reading: EmotionReading) {
        guard let onReading else { return }
        Task { @MainActor in onReading(reading) }
    }

    // MARK: - Mapping

    /// Baseline `neutral` score. Kept low (not `1 - max(others)`) so a moderate
    /// expression can actually win the argmax. Raise it if the badge feels too
    /// twitchy; lower it if emotions are hard to trigger.
    static let neutralBaseline = 0.18

    static func reading(
        from shapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]
    ) -> EmotionReading {
        func v(_ key: ARFaceAnchor.BlendShapeLocation) -> Double {
            shapes[key]?.doubleValue ?? 0
        }

        let happy = (v(.mouthSmileLeft) + v(.mouthSmileRight)) / 2
        // Sadness is led by the inner-brow raise (browInnerUp) — the reliable
        // signal; the mouth frown is a weak, hard-to-produce add-on.
        let sad = min(1, v(.browInnerUp) * 1.0
                        + (v(.mouthFrownLeft) + v(.mouthFrownRight)) / 2 * 0.6)
        let energetic = min(1, (v(.browDownLeft) + v(.browDownRight)) / 2)

        // Dominant is picked from the raw scores vs a low neutral baseline, so
        // e.g. sad ≈ 0.4 beats neutral instead of losing to a 0.6 complement.
        var confidences: [Emotion: Double] = [
            .happy: happy, .sad: sad, .energetic: energetic, .neutral: neutralBaseline,
        ]
        let dominant = confidences.max { $0.value < $1.value }?.key ?? .neutral

        // Normalise for the scoring matrix (argmax is unchanged by scaling).
        let total = confidences.values.reduce(0, +)
        if total > 0 { for (k, val) in confidences { confidences[k] = val / total } }

        return EmotionReading(
            dominant: dominant,
            confidences: confidences,
            faceDetected: true,
            mediaTime: 0,
            smile: happy
        )
    }
}
#endif
