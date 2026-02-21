import Foundation
import CoreAudio
import AVFoundation
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "AVSession")

// CoreMediaIO API changed significantly across SDK versions.
// Using AVCaptureDevice observation which is stable and public.

final class AVSessionMonitor: ObservableObject {
    @Published var cameraActive: Bool = false
    @Published var micActive: Bool = false
    @Published var appName: String = ""

    private var micDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var isMicMuted: Bool = false
    private var observations: [NSKeyValueObservation] = []

    func start() {
        setupCameraMonitoring()
        setupMicMonitoring()
    }

    func stop() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
    }

    // MARK: - Camera via AVCaptureDevice
    private func setupCameraMonitoring() {
        // macOS 14.0+ provides isUsed / isConnected observations on AVCaptureDevice
        // For broader compatibility use notification-based approach
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureDeviceWasConnected(_:)),
            name: AVCaptureDevice.wasConnectedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureDeviceWasDisconnected(_:)),
            name: AVCaptureDevice.wasDisconnectedNotification,
            object: nil
        )

        // Poll initial state
        let videoDevices = AVCaptureDevice.devices(for: .video)
        for device in videoDevices {
            let obs = device.observe(\.isInUseByAnotherApplication, options: [.new]) { [weak self] dev, _ in
                DispatchQueue.main.async { self?.cameraActive = dev.isInUseByAnotherApplication }
            }
            observations.append(obs)
        }
    }

    @objc private func captureDeviceWasConnected(_ n: Notification) {}
    @objc private func captureDeviceWasDisconnected(_ n: Notification) {
        DispatchQueue.main.async { self.cameraActive = false }
    }

    // MARK: - Mic via CoreAudio
    private func setupMicMonitoring() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        guard deviceID != kAudioObjectUnknown else { return }
        micDeviceID = deviceID

        var runAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(deviceID, &runAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.checkMicState()
        }
    }

    private func checkMicState() {
        guard micDeviceID != kAudioObjectUnknown else { return }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(micDeviceID, &addr, 0, nil, &size, &isRunning)
        DispatchQueue.main.async { self.micActive = isRunning != 0 }
    }

    // MARK: - Mic mute toggle
    func toggleMicMute() {
        guard micDeviceID != kAudioObjectUnknown else { return }
        isMicMuted.toggle()
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muted: UInt32 = isMicMuted ? 1 : 0
        AudioObjectSetPropertyData(micDeviceID, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muted)
    }
}
