import Foundation
import AppKit

// All possible display modes for the island, ordered by priority (highest first).
enum IslandMode: Equatable {
    case avConference
    case buildStatus
    case notification(title: String, body: String, appName: String, appIcon: NSImage?)
    case airDrop(fileName: String)
    case nowPlaying
    case volume(level: Double, isMuted: Bool)
    case fileRecovery(fileName: String, trashURL: URL, originalURL: URL)
    case network
    case weather
    case systemStats
    case clipboard
    case colorSampler(color: NSColor)
    case stdout
    case collapsed

    var priority: Int {
        switch self {
        case .avConference:   return 14
        case .buildStatus:    return 13
        case .notification:   return 12
        case .airDrop:        return 11
        case .nowPlaying:     return 10
        case .volume:         return 9
        case .fileRecovery:   return 8
        case .network:        return 7
        case .weather:        return 6
        case .systemStats:    return 5
        case .clipboard:      return 4
        case .colorSampler:   return 3
        case .stdout:         return 2
        case .collapsed:      return 0
        }
    }

    // Auto-dismiss timeout in seconds. nil = stays until explicitly dismissed.
    var autoDismissInterval: TimeInterval? {
        switch self {
        case .volume:       return 2.5
        case .notification: return 5.0
        case .fileRecovery: return 30.0
        case .weather:      return 8.0
        case .colorSampler: return 10.0
        case .airDrop:      return 15.0
        default:            return nil
        }
    }

    static func == (lhs: IslandMode, rhs: IslandMode) -> Bool {
        switch (lhs, rhs) {
        case (.avConference, .avConference): return true
        case (.buildStatus, .buildStatus): return true
        case (.notification, .notification): return true
        case (.airDrop, .airDrop): return true
        case (.nowPlaying, .nowPlaying): return true
        case (.volume, .volume): return true
        case (.fileRecovery, .fileRecovery): return true
        case (.network, .network): return true
        case (.weather, .weather): return true
        case (.systemStats, .systemStats): return true
        case (.clipboard, .clipboard): return true
        case (.colorSampler, .colorSampler): return true
        case (.stdout, .stdout): return true
        case (.collapsed, .collapsed): return true
        default: return false
        }
    }
}
