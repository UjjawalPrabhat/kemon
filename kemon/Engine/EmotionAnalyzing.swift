//
//  EmotionAnalyzing.swift
//  kemon
//
//  The seam between the camera pipeline and the ML model.
//
//  The app is written entirely against this protocol so it compiles and runs
//  whether or not the trained model is present. KemonEngine loads
//  CoreMLEmotionAnalyzer if `EmotionClassifier.mlmodel(c)` is in the bundle,
//  and otherwise falls back to PlaceholderEmotionAnalyzer.
//

import CoreVideo
import CoreML
import Vision
import ImageIO

protocol EmotionAnalyzing: AnyObject, Sendable {
    /// Classify the expression inside `face` on the given frame.
    /// Called on a background queue — implementations must be thread-safe.
    nonisolated func analyze(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        face: VNFaceObservation
    ) throws -> EmotionReading
}

// MARK: - Placeholder (works with no model)

/// Derives a plausible, *interactive* emotion from the geometry of the detected
/// face box so the full pipeline is demoable before the Core ML model exists:
/// lean in / fill the frame → "energetic", sit back → "neutral", off-centre →
/// "sad". This is NOT real emotion recognition — it exists only so the scoring,
/// lyrics and UI can be built and reviewed end-to-end.
nonisolated final class PlaceholderEmotionAnalyzer: EmotionAnalyzing {
    func analyze(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        face: VNFaceObservation
    ) throws -> EmotionReading {
        let box = face.boundingBox
        let fill = min(max(box.height, 0), 1)              // how much of the frame the face occupies
        let centreOffset = abs(box.midX - 0.5) * 2         // 0 centred, 1 at the edge

        var scores: [Emotion: Double] = [
            .energetic: fill,
            .neutral:   1 - fill,
            .sad:       centreOffset,
            .happy:     max(0, fill - centreOffset),
        ]

        // Normalise to a probability vector.
        let total = scores.values.reduce(0, +)
        if total > 0 { for (k, v) in scores { scores[k] = v / total } }

        let dominant = scores.max { $0.value < $1.value }?.key ?? .neutral
        return EmotionReading(
            dominant: dominant,
            confidences: scores,
            faceDetected: true,
            mediaTime: 0
        )
    }
}

// MARK: - Core ML + Vision (the real thing)

/// Real analyzer backed by a Create ML image classifier, cropped to the face by
/// Vision. Loads the model by name at runtime so this type compiles even before
/// the model is added to the project.
///
/// To enable: train an image classifier with folders `Happy`, `Sad`, `Angry`,
/// `Neutral`, name the exported model `EmotionClassifier.mlmodel`, and drop it
/// into the `kemon/` folder. KemonEngine picks it up automatically.
nonisolated final class CoreMLEmotionAnalyzer: EmotionAnalyzing, @unchecked Sendable {

    private let model: VNCoreMLModel

    /// Maps the classifier's raw class names (case-insensitive) onto Kemon's
    /// emotions. "Angry" is intentionally folded into `.energetic` per the
    /// karaoke scoring model. Extend this if you rename your training folders.
    private let labelMap: [String: Emotion] = [
        "happy":      .happy,
        "joy":        .happy,
        "sad":        .sad,
        "angry":      .energetic,
        "energetic":  .energetic,
        "passionate": .energetic,
        "neutral":    .neutral,
    ]

    init() throws {
        // Xcode compiles KemonEmotionClassifier.mlmodel → KemonEmotionClassifier.mlmodelc.
        guard let url = Bundle.main.url(forResource: "KemonEmotionClassifier",
                                        withExtension: "mlmodelc") else {
            throw AnalyzerError.modelNotFound
        }
        let config = MLModelConfiguration()
        let mlModel = try MLModel(contentsOf: url, configuration: config)
        model = try VNCoreMLModel(for: mlModel)
    }

    func analyze(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        face: VNFaceObservation
    ) throws -> EmotionReading {
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .centerCrop
        // Let Vision crop to the face for us — no manual pixel-buffer maths.
        // Pad the box a little so brow / mouth / jaw context isn't clipped.
        request.regionOfInterest = Self.padded(face.boundingBox, by: 0.25)

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: orientation,
                                            options: [:])
        try handler.perform([request])

        let observations = (request.results as? [VNClassificationObservation]) ?? []
        var confidences: [Emotion: Double] = [:]
        for obs in observations {
            if let emotion = labelMap[obs.identifier.lowercased()] {
                confidences[emotion, default: 0] += Double(obs.confidence)
            }
        }

        guard let dominant = confidences.max(by: { $0.value < $1.value })?.key else {
            // Model produced no mappable labels — treat as face-present neutral.
            return EmotionReading(dominant: .neutral,
                                  confidences: [.neutral: 1.0],
                                  faceDetected: true,
                                  mediaTime: 0)
        }
        return EmotionReading(dominant: dominant,
                              confidences: confidences,
                              faceDetected: true,
                              mediaTime: 0)
    }

    /// Grows a normalised rect by `fraction` on every side, clamped to [0, 1].
    private static func padded(_ rect: CGRect, by fraction: CGFloat) -> CGRect {
        let dx = rect.width * fraction
        let dy = rect.height * fraction
        let expanded = rect.insetBy(dx: -dx, dy: -dy)
        let clampedX = max(0, expanded.minX)
        let clampedY = max(0, expanded.minY)
        return CGRect(
            x: clampedX,
            y: clampedY,
            width: min(1 - clampedX, expanded.width),
            height: min(1 - clampedY, expanded.height)
        )
    }

    enum AnalyzerError: Error { case modelNotFound }
}
