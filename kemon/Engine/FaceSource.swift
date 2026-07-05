//
//  FaceSource.swift
//  kemon
//
//  Abstraction over "something that produces EmotionReadings from the camera",
//  so KemonEngine can drive the Core ML + Vision pipeline (CameraController)
//  without hard-wiring the concrete type.
//

import Foundation

protocol FaceSource: AnyObject {
    /// Delivered on the main actor with each new reading. The property itself is
    /// nonisolated because the sources run on background capture/AR queues.
    nonisolated var onReading: (@MainActor (EmotionReading) -> Void)? { get set }
    nonisolated func start()
    nonisolated func stop()
}
