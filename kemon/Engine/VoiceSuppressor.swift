//
//  VoiceSuppressor.swift
//  kemon
//
//  Turns a stereo mix into a vocal-suppressed buffer. The foundation ships the
//  crude-but-instant center-channel canceller; an on-device Demucs (CoreML)
//  separator can drop in later behind the same `VocalSeparating` protocol
//  without touching LocalAudioEngine.
//

import AVFoundation
import Accelerate

/// Produces a vocal-suppressed version of a decoded mix.
protocol VocalSeparating: Sendable {
    /// Returns a new buffer with the lead vocal attenuated, or nil if the input
    /// can't be processed (e.g. mono source — nothing to cancel).
    func suppressVocals(in buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer?
}

/// Removes center-panned content (where lead vocals usually sit) by taking the
/// stereo difference: `0.5·(L − R)`, written to BOTH output channels so the
/// buffer keeps the source's stereo format — this lets LocalAudioEngine swap
/// between the original and suppressed buffers on the same player-node
/// connection without a format change. Crude (it also removes other
/// center-panned parts like bass/kick) but real-time-free and model-free —
/// enough to prove the toggle UX.
nonisolated struct CenterChannelSuppressor: VocalSeparating {

    func suppressVocals(in buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard buffer.format.channelCount >= 2,
              let channels = buffer.floatChannelData else { return nil }

        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return nil }

        // Same format as the input so the player-node connection is unchanged.
        guard let out = AVAudioPCMBuffer(pcmFormat: buffer.format,
                                         frameCapacity: buffer.frameCapacity),
              let outData = out.floatChannelData else { return nil }

        let left = channels[0]
        let right = channels[1]

        // diff = 0.5·(L − R) into channel 0, then copy to every other channel.
        let ch0 = outData[0]
        vDSP_vsub(right, 1, left, 1, ch0, 1, vDSP_Length(frames))
        var half: Float = 0.5
        vDSP_vsmul(ch0, 1, &half, ch0, 1, vDSP_Length(frames))

        for c in 1..<Int(buffer.format.channelCount) {
            memcpy(outData[c], ch0, frames * MemoryLayout<Float>.stride)
        }

        out.frameLength = buffer.frameLength
        return out
    }
}
