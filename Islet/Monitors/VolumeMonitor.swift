import Foundation
import CoreAudio
import AudioToolbox
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "Volume")

// kAudioHardwareServiceDeviceProperty_VirtualMainVolume lives in AudioToolbox on newer SDKs
// Use the raw 4CC value directly: 'vvol' = 0x76766F6C
private let kVirtualMainVolume = AudioObjectPropertySelector(0x76766F6C)

final class VolumeMonitor: ObservableObject {
    @Published var volume: Double = 0.5
    @Published var isMuted: Bool = false

    private var deviceID: AudioDeviceID = kAudioObjectUnknown

    func start() {
        deviceID = defaultOutputDevice()
        guard deviceID != kAudioObjectUnknown else {
            os_log(.debug, log: log, "No default output device found")
            return
        }

        readCurrentVolume()
        readCurrentMute()
        addPropertyListeners()
    }

    func stop() {}

    // MARK: - Read current state
    private func readCurrentVolume() {
        var address = AudioObjectPropertyAddress(
            mSelector: kVirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        // Fallback to kAudioHardwareServiceDeviceProperty_VirtualMainVolume if available
        if !AudioObjectHasProperty(deviceID, &address) {
            address.mSelector = kAudioDevicePropertyVolumeScalar
        }
        var vol: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &vol) == noErr {
            DispatchQueue.main.async { self.volume = Double(vol) }
        }
    }

    private func readCurrentMute() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &muted) == noErr {
            DispatchQueue.main.async { self.isMuted = muted != 0 }
        }
    }

    // MARK: - Property listeners
    private func addPropertyListeners() {
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kVirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if !AudioObjectHasProperty(deviceID, &volumeAddress) {
            volumeAddress.mSelector = kAudioDevicePropertyVolumeScalar
        }
        AudioObjectAddPropertyListenerBlock(deviceID, &volumeAddress, nil) { [weak self] _, _ in
            self?.readCurrentVolume()
        }

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(deviceID, &muteAddress, nil) { [weak self] _, _ in
            self?.readCurrentMute()
        }
    }

    // MARK: - Helpers
    private func defaultOutputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }
}
