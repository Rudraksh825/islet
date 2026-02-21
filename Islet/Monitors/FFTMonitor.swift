import Foundation
import AVFoundation
import Accelerate
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "FFT")

final class FFTMonitor: ObservableObject {
    @Published var bins: [Double] = Array(repeating: 0, count: 32)

    private let audioEngine = AVAudioEngine()
    private let bufferSize: AVAudioFrameCount = 1024
    private let numBins = 32
    private var isRunning = false
    private let fftQueue = DispatchQueue(label: "com.islet.fft", qos: .userInteractive)

    func start() {
        requestMicPermission()
    }

    func stop() {
        if isRunning {
            audioEngine.mainMixerNode.removeTap(onBus: 0)
            audioEngine.stop()
            isRunning = false
        }
    }

    private func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            if granted {
                DispatchQueue.main.async { self?.startEngine() }
            } else {
                os_log(.debug, log: log, "Microphone permission denied — FFT disabled")
            }
        }
    }

    private func startEngine() {
        let mixer = audioEngine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)

        mixer.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        do {
            try audioEngine.start()
            isRunning = true
        } catch {
            os_log(.debug, log: log, "AVAudioEngine start failed: %{public}@", error.localizedDescription)
        }
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        fftQueue.async { [weak self] in
            guard let self = self else { return }
            let n = vDSP_Length(frameCount)
            let log2n = vDSP_Length(log2(Double(frameCount)))

            var window = [Float](repeating: 0, count: frameCount)
            vDSP_hann_window(&window, n, Int32(vDSP_HANN_NORM))

            var windowed = [Float](repeating: 0, count: frameCount)
            vDSP_vmul(channelData, 1, window, 1, &windowed, 1, n)

            var realParts = [Float](repeating: 0, count: frameCount / 2)
            var imagParts = [Float](repeating: 0, count: frameCount / 2)
            var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)

            windowed.withUnsafeBufferPointer { ptr in
                ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: frameCount / 2) { complexPtr in
                    vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(frameCount / 2))
                }
            }

            guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return }
            defer { vDSP_destroy_fftsetup(fftSetup) }

            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

            var magnitudes = [Float](repeating: 0, count: frameCount / 2)
            vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(frameCount / 2))

            // Log-space bin mapping
            let binCount = self.numBins
            let halfFrame = frameCount / 2
            var result = [Double](repeating: 0, count: binCount)
            for i in 0..<binCount {
                let start = Int(pow(Double(halfFrame), Double(i) / Double(binCount)))
                let end   = min(Int(pow(Double(halfFrame), Double(i + 1) / Double(binCount))), halfFrame - 1)
                let slice = magnitudes[start...end]
                let avg = slice.reduce(0, +) / Float(max(slice.count, 1))
                result[i] = min(Double(avg) / 100.0, 1.0)
            }

            DispatchQueue.main.async { self.bins = result }
        }
    }
}
