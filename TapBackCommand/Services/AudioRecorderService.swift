//
//  AudioRecorderService.swift
//  TapBack Command
//
//  Wraps AVAudioRecorder: configures the session, records to an .m4a file
//  in Documents/Audio and publishes a live metering level for the waveform.
//

import Foundation
import AVFoundation

@MainActor
final class AudioRecorderService: NSObject, ObservableObject {

    @Published private(set) var isRecording = false
    /// Normalised 0...1 power level, updated ~20x/sec while recording.
    @Published private(set) var level: CGFloat = 0
    @Published private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var currentFileName: String?

    // MARK: - Permission

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Recording

    /// Begins recording. Returns the destination filename, or nil on failure.
    @discardableResult
    func startRecording() -> String? {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            return nil
        }

        let fileName = "\(UUID().uuidString).m4a"
        let url = StorageService.shared.audioURL(named: fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.delegate = self
            recorder.record()
            self.recorder = recorder
            self.currentFileName = fileName
            self.isRecording = true
            self.elapsed = 0
            startMetering()
            return fileName
        } catch {
            return nil
        }
    }

    /// Stops recording and returns the saved filename.
    @discardableResult
    func stopRecording() -> String? {
        recorder?.stop()
        stopMetering()
        isRecording = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let name = currentFileName
        recorder = nil
        return name
    }

    // MARK: - Metering

    private func startMetering() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateMeter() }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func updateMeter() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        elapsed = recorder.currentTime

        // Convert dB (-160...0) to a pleasant 0...1 curve.
        let power = recorder.averagePower(forChannel: 0)
        let clamped = max(power, -50)
        let normalized = (clamped + 50) / 50          // 0...1 linear
        level = CGFloat(pow(normalized, 1.6))         // ease for nicer motion

        // Hard stop at max duration.
        if elapsed >= Constants.Recording.maxDuration {
            _ = stopRecording()
        }
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // No-op: state is driven explicitly by start/stop.
    }
}
