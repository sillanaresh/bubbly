import AppKit
import Foundation

enum BubbleSoundPreset: String, CaseIterable {
    case waterDrop
    case softBloop
    case jellyPop
    case budak
    case bubbleChime
    case muted

    var title: String {
        switch self {
        case .waterDrop: "Water Drop"
        case .softBloop: "Soft Bloop"
        case .jellyPop: "Jelly Pop"
        case .budak: "Budak"
        case .bubbleChime: "Bubble Chime"
        case .muted: "No Sound"
        }
    }

    static func from(id: String) -> BubbleSoundPreset {
        BubbleSoundPreset(rawValue: id) ?? .waterDrop
    }
}

enum BubbleSoundVolume: String, CaseIterable {
    case soft
    case normal
    case loud

    var title: String {
        switch self {
        case .soft: "Soft"
        case .normal: "Normal"
        case .loud: "Loud"
        }
    }

    var multiplier: Float {
        switch self {
        case .soft: 0.55
        case .normal: 1.0
        case .loud: 1.55
        }
    }

    static func from(id: String) -> BubbleSoundVolume {
        BubbleSoundVolume(rawValue: id) ?? .normal
    }
}

final class BubbleSoundPlayer {
    private var soundBanks: [BubbleSoundPreset: [NSSound]] = [:]
    private var indexes: [BubbleSoundPreset: Int] = [:]

    init() {
        for preset in BubbleSoundPreset.allCases where preset != .muted {
            let data = Self.makeBubbleWav(for: preset)
            let sounds = (0..<4).compactMap { _ in NSSound(data: data) }
            sounds.forEach { sound in
                sound.volume = volume(for: preset)
            }
            soundBanks[preset] = sounds
        }
    }

    func play(presetID: String, volumeID: String) {
        let preset = BubbleSoundPreset.from(id: presetID)
        guard preset != .muted, let sounds = soundBanks[preset], !sounds.isEmpty else {
            return
        }

        let index = indexes[preset, default: 0]
        let sound = sounds[index]
        indexes[preset] = (index + 1) % sounds.count
        sound.volume = min(volume(for: preset) * BubbleSoundVolume.from(id: volumeID).multiplier, 1)
        sound.stop()
        sound.currentTime = 0
        sound.play()
    }

    private func volume(for preset: BubbleSoundPreset) -> Float {
        switch preset {
        case .waterDrop: 0.34
        case .softBloop: 0.28
        case .jellyPop: 0.36
        case .budak: 0.38
        case .bubbleChime: 0.30
        case .muted: 0
        }
    }

    private static func makeBubbleWav(for preset: BubbleSoundPreset) -> Data {
        let sampleRate = 44_100
        let duration = 0.42
        let sampleCount = Int(Double(sampleRate) * duration)
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)

        for frame in 0..<sampleCount {
            let t = Double(frame) / Double(sampleRate)
            let value = signal(for: preset, at: t)
            let softened = tanh(value) * 0.64
            samples.append(Int16(max(-1, min(1, softened)) * Double(Int16.max)))
        }

        var data = Data()
        data.appendASCII("RIFF")
        data.appendUInt32LE(UInt32(36 + samples.count * 2))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendUInt32LE(16)
        data.appendUInt16LE(1)
        data.appendUInt16LE(1)
        data.appendUInt32LE(UInt32(sampleRate))
        data.appendUInt32LE(UInt32(sampleRate * 2))
        data.appendUInt16LE(2)
        data.appendUInt16LE(16)
        data.appendASCII("data")
        data.appendUInt32LE(UInt32(samples.count * 2))

        for sample in samples {
            data.appendUInt16LE(UInt16(bitPattern: sample))
        }

        return data
    }

    private static func signal(for preset: BubbleSoundPreset, at t: Double) -> Double {
        switch preset {
        case .waterDrop:
            droplet(t, start: 0.00, duration: 0.13, startFrequency: 610, endFrequency: 980, gain: 0.74) +
                droplet(t, start: 0.08, duration: 0.16, startFrequency: 420, endFrequency: 760, gain: 0.42) +
                droplet(t, start: 0.19, duration: 0.12, startFrequency: 760, endFrequency: 1180, gain: 0.28)
        case .softBloop:
            droplet(t, start: 0.00, duration: 0.20, startFrequency: 280, endFrequency: 430, gain: 0.70) +
                droplet(t, start: 0.14, duration: 0.15, startFrequency: 330, endFrequency: 520, gain: 0.32)
        case .jellyPop:
            droplet(t, start: 0.00, duration: 0.09, startFrequency: 340, endFrequency: 220, gain: 0.90) +
                droplet(t, start: 0.05, duration: 0.13, startFrequency: 720, endFrequency: 980, gain: 0.40)
        case .budak:
            droplet(t, start: 0.00, duration: 0.07, startFrequency: 190, endFrequency: 140, gain: 1.00) +
                droplet(t, start: 0.045, duration: 0.10, startFrequency: 520, endFrequency: 360, gain: 0.54) +
                droplet(t, start: 0.12, duration: 0.10, startFrequency: 760, endFrequency: 900, gain: 0.26)
        case .bubbleChime:
            droplet(t, start: 0.00, duration: 0.17, startFrequency: 820, endFrequency: 1220, gain: 0.56) +
                droplet(t, start: 0.11, duration: 0.20, startFrequency: 1040, endFrequency: 1460, gain: 0.34)
        case .muted:
            0
        }
    }

    private static func droplet(
        _ t: Double,
        start: Double,
        duration: Double,
        startFrequency: Double,
        endFrequency: Double,
        gain: Double
    ) -> Double {
        guard t >= start, t <= start + duration else {
            return 0
        }

        let progress = (t - start) / duration
        let frequency = startFrequency + (endFrequency - startFrequency) * progress
        let envelope = sin(progress * .pi) * exp(-progress * 2.35)
        let wobble = sin(2 * .pi * 9 * progress) * 0.025
        return sin(2 * .pi * frequency * (t - start) + wobble) * envelope * gain
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }
}
