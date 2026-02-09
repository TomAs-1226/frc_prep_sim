import AVFoundation
import AudioToolbox

// MARK: - Sound Manager
// Programmatic sound synthesis — no imported audio assets required.
// Uses AudioToolbox for haptic-style feedback sounds and AVAudioEngine for tones.

@MainActor
final class SoundManager {

    static let shared = SoundManager()
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isEnabled: Bool = true

    private init() {
        setupEngine()
    }

    private func setupEngine() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.3

        do {
            try engine.start()
            self.audioEngine = engine
            self.playerNode = player
        } catch {
            // Silent fallback — sounds are optional
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    // MARK: - Play Sound Events

    func play(_ event: SoundEvent) {
        guard isEnabled else { return }

        switch event {
        case .score:
            playTone(frequency: 880, duration: 0.12, volume: 0.25)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
                self?.playTone(frequency: 1108, duration: 0.15, volume: 0.2)
            }
        case .miss:
            playTone(frequency: 330, duration: 0.2, volume: 0.15)
        case .collision:
            playNoise(duration: 0.06, volume: 0.1)
        case .matchStart:
            playTone(frequency: 660, duration: 0.3, volume: 0.3)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.playTone(frequency: 880, duration: 0.4, volume: 0.3)
            }
        case .matchEnd:
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) { [weak self] in
                    self?.playTone(frequency: 440 + Double(i) * 220, duration: 0.15, volume: 0.25)
                }
            }
        case .periodChange:
            playTone(frequency: 550, duration: 0.25, volume: 0.2)
        case .callout:
            playTone(frequency: 784, duration: 0.08, volume: 0.15)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.playTone(frequency: 988, duration: 0.1, volume: 0.15)
            }
        case .climb:
            playTone(frequency: 440, duration: 0.5, volume: 0.2)
        case .stall:
            playTone(frequency: 220, duration: 0.3, volume: 0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.playTone(frequency: 185, duration: 0.3, volume: 0.15)
            }
        case .countdown:
            playTone(frequency: 660, duration: 0.1, volume: 0.2)
        }
    }

    // MARK: - Tone Generator

    private func playTone(frequency: Double, duration: Double, volume: Float) {
        guard let engine = audioEngine, let player = playerNode, engine.isRunning else { return }

        let sampleRate = 44100.0
        let sampleCount = Int(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(sampleCount)) else { return }

        buffer.frameLength = UInt32(sampleCount)
        guard let data = buffer.floatChannelData?[0] else { return }

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let envelope = min(1.0, min(t / 0.005, (duration - t) / 0.02))  // Attack/release
            let sample = sin(2.0 * .pi * frequency * t) * envelope * Double(volume)
            data[i] = Float(sample)
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func playNoise(duration: Double, volume: Float) {
        guard let engine = audioEngine, let player = playerNode, engine.isRunning else { return }

        let sampleRate = 44100.0
        let sampleCount = Int(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(sampleCount)) else { return }

        buffer.frameLength = UInt32(sampleCount)
        guard let data = buffer.floatChannelData?[0] else { return }

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let envelope = max(0, 1.0 - t / duration)
            data[i] = Float.random(in: -1...1) * volume * Float(envelope)
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}
