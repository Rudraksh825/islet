import Foundation
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "MediaRemote")

// MediaRemote private framework access via dlopen/dlsym.
// Do NOT import MediaRemote as a module.

typealias MRMediaRemoteGetNowPlayingInfoFunction =
    @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void

typealias MRMediaRemoteRegisterForNowPlayingNotificationsFunction =
    @convention(c) (DispatchQueue) -> Void

typealias MRMediaRemoteSendCommandFunction =
    @convention(c) (UInt32, AnyObject?) -> Bool

// Known info dictionary keys (resolved via dlsym)
enum MRMediaRemoteKeys {
    static let title      = "kMRMediaRemoteNowPlayingInfoTitle"
    static let artist     = "kMRMediaRemoteNowPlayingInfoArtist"
    static let album      = "kMRMediaRemoteNowPlayingInfoAlbum"
    static let artworkData = "kMRMediaRemoteNowPlayingInfoArtworkData"
    static let elapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"
    static let duration   = "kMRMediaRemoteNowPlayingInfoDuration"
    static let playbackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"
}

// MRMediaRemote command constants
enum MRCommand: UInt32 {
    case play        = 0
    case pause       = 1
    case togglePlayPause = 2
    case stop        = 3
    case nextTrack   = 4
    case previousTrack = 5
}

final class MediaRemoteBridge {

    static let shared = MediaRemoteBridge()

    private let handle: UnsafeMutableRawPointer?
    private let getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction?
    private let registerForNotifications: MRMediaRemoteRegisterForNowPlayingNotificationsFunction?
    private let sendCommand: MRMediaRemoteSendCommandFunction?

    // Notification name posted by MediaRemote when now-playing changes
    static let nowPlayingInfoDidChangeNotification = Notification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification")
    static let nowPlayingPlaybackQueueDidChangeNotification = Notification.Name("kMRMediaRemoteNowPlayingPlaybackQueueDidChangeNotification")

    private init() {
        handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        if handle == nil {
            os_log(.debug, log: log, "Failed to open MediaRemote framework")
            getNowPlayingInfo = nil
            registerForNotifications = nil
            sendCommand = nil
            return
        }

        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getNowPlayingInfo = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        } else {
            getNowPlayingInfo = nil
        }

        if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            registerForNotifications = unsafeBitCast(sym, to: MRMediaRemoteRegisterForNowPlayingNotificationsFunction.self)
        } else {
            registerForNotifications = nil
        }

        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(sym, to: MRMediaRemoteSendCommandFunction.self)
        } else {
            sendCommand = nil
        }
    }

    var isAvailable: Bool { handle != nil && getNowPlayingInfo != nil }

    func fetchNowPlayingInfo(on queue: DispatchQueue = .main, completion: @escaping ([String: Any]) -> Void) {
        guard let fn = getNowPlayingInfo else { completion([:]); return }
        fn(queue, completion)
    }

    func registerForNotifications(on queue: DispatchQueue = .main) {
        registerForNotifications?(queue)
    }

    @discardableResult
    func send(command: MRCommand) -> Bool {
        return sendCommand?(command.rawValue, nil) ?? false
    }

    // Helper: resolve a string key stored as a CFString* via dlsym
    func resolveKey(_ name: String) -> String? {
        guard let sym = dlsym(handle, name) else { return nil }
        let ptr = sym.assumingMemoryBound(to: CFString.self)
        return ptr.pointee as String
    }
}
