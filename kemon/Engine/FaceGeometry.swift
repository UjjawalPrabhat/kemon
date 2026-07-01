//
//  FaceGeometry.swift
//  kemon
//
//  Model-free facial measurements from Vision face landmarks. Used to detect a
//  smile geometrically (mouth-corner elevation), which is far more robust while
//  singing than a static-image emotion classifier: a smile pulls the mouth
//  corners UP and OUT whether or not the mouth is open.
//

import Vision
import CoreGraphics

enum FaceGeometry {

    /// A smile score in 0...1 derived from how high the mouth corners sit
    /// relative to the mouth's vertical centre, scaled by mouth width.
    ///
    /// Landmark points are normalised to the face box with the y-axis pointing
    /// UP, so corners rising above centre gives a positive lift.
    nonisolated static func smileScore(from landmarks: VNFaceLandmarks2D?) -> Double {
        guard let lips = landmarks?.outerLips else { return 0 }
        let pts = lips.normalizedPoints
        guard pts.count >= 4 else { return 0 }

        // Mouth corners = the extreme-x points; lips span between them.
        guard let left = pts.min(by: { $0.x < $1.x }),
              let right = pts.max(by: { $0.x < $1.x }),
              let topY = pts.map(\.y).max(),
              let botY = pts.map(\.y).min() else { return 0 }

        let width = hypot(right.x - left.x, right.y - left.y)
        guard width > 0.0001 else { return 0 }

        let centreY = (topY + botY) / 2
        let cornerY = (left.y + right.y) / 2

        // Corner lift normalised by mouth width. Empirically ~0 for a neutral
        // mouth, positive for a smile, negative for a frown/downturn.
        let lift = Double((cornerY - centreY) / width)

        // Map the useful lift range onto 0...1. Tune `neutralLift`/`smileLift`
        // against the on-screen debug readout if smiles read too low/high.
        let neutralLift = -0.02   // lift at a relaxed mouth
        let smileLift    = 0.22   // lift at a clear smile
        let score = (lift - neutralLift) / (smileLift - neutralLift)
        return min(max(score, 0), 1)
    }
}
