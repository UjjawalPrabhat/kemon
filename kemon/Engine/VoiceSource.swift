//
//  VoiceSource.swift
//  kemon
//
//  Abstraction over "something that produces VoiceReadings from the microphone",
//  the audio analogue of `FaceSource`. Keeping it a protocol lets KemonEngine
//  treat mic analysis exactly like face analysis, and lets the pitch backend
//  (autocorrelation now, YIN/CoreML later) change without touching the engine.
//

import Foundation

protocol VoiceSource: AnyObject {
    /// Delivered on the main actor with each new reading. The property itself is
    /// nonisolated because the source runs on a realtime audio thread.
    nonisolated var onReading: (@MainActor (VoiceReading) -> Void)? { get set }
    nonisolated func start()
    nonisolated func stop()
}
