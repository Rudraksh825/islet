import Foundation
import AppKit

enum ClipboardItem: Codable, Identifiable {
    case text(String)
    case url(URL)
    case file(URL)
    case image(Data) // NSImage serialized as PNG data

    var id: String {
        switch self {
        case .text(let s):  return "text:\(s.prefix(64))"
        case .url(let u):   return "url:\(u.absoluteString)"
        case .file(let u):  return "file:\(u.path)"
        case .image(let d): return "image:\(d.hashValue)"
        }
    }

    var preview: String {
        switch self {
        case .text(let s):  return s.prefix(80).description
        case .url(let u):   return u.host ?? u.absoluteString
        case .file(let u):  return u.lastPathComponent
        case .image:        return "Image"
        }
    }

    var nsImage: NSImage? {
        guard case .image(let data) = self else { return nil }
        return NSImage(data: data)
    }

    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try c.decode(String.self, forKey: .value))
        case "url":
            self = .url(try c.decode(URL.self, forKey: .value))
        case "file":
            self = .file(try c.decode(URL.self, forKey: .value))
        case "image":
            self = .image(try c.decode(Data.self, forKey: .value))
        default:
            self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let s):
            try c.encode("text", forKey: .type)
            try c.encode(s, forKey: .value)
        case .url(let u):
            try c.encode("url", forKey: .type)
            try c.encode(u, forKey: .value)
        case .file(let u):
            try c.encode("file", forKey: .type)
            try c.encode(u, forKey: .value)
        case .image(let d):
            try c.encode("image", forKey: .type)
            try c.encode(d, forKey: .value)
        }
    }
}
