import Foundation
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "Build")

final class BuildMonitor: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var errorCount: Int = 0
    @Published var warningCount: Int = 0
    @Published var lastLines: [String] = []
    @Published var success: Bool? = nil
    @Published var stdoutLines: [String] = []

    private let socketPath = "/tmp/com.islet.build.sock"
    private var serverSocket: Int32 = -1
    private let serverQueue = DispatchQueue(label: "com.islet.build.server", qos: .utility)
    private let errorPattern = try! NSRegularExpression(pattern: #"error:"#)
    private let warningPattern = try! NSRegularExpression(pattern: #"warning:"#)

    func start() {
        startSocketServer()

        // Also tail log file if configured
        let logPath = SystemConfig.shared.buildLogFilePath
        if !logPath.isEmpty {
            tailFile(at: logPath)
        }
    }

    func stop() {
        if serverSocket != -1 {
            Darwin.close(serverSocket)
            serverSocket = -1
            unlink(socketPath)
        }
    }

    // MARK: - Unix domain socket server
    private func startSocketServer() {
        serverQueue.async { [weak self] in
            guard let self = self else { return }

            // Clean up old socket
            unlink(self.socketPath)

            let sock = socket(AF_UNIX, SOCK_STREAM, 0)
            guard sock >= 0 else {
                os_log(.debug, log: log, "Failed to create socket")
                return
            }
            self.serverSocket = sock

            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)
            self.socketPath.withCString { ptr in
                withUnsafeMutablePointer(to: &addr.sun_path) { dest in
                    dest.withMemoryRebound(to: CChar.self, capacity: 108) { destChar in
                        _ = strcpy(destChar, ptr)
                    }
                }
            }

            let bindResult = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    Darwin.bind(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard bindResult == 0 else {
                os_log(.debug, log: log, "Failed to bind socket: %d", errno)
                return
            }

            Darwin.listen(sock, 5)

            while self.serverSocket != -1 {
                let clientSock = Darwin.accept(sock, nil, nil)
                guard clientSock >= 0 else { break }
                self.serverQueue.async { self.handleClient(clientSock) }
            }
        }
    }

    private func handleClient(_ clientSock: Int32) {
        defer { Darwin.close(clientSock) }
        var buffer = Data(count: 4096)
        var accumulated = ""

        while true {
            let bytesRead = buffer.withUnsafeMutableBytes { ptr in
                Darwin.recv(clientSock, ptr.baseAddress!, 4096, 0)
            }
            if bytesRead <= 0 { break }
            accumulated += String(data: buffer.prefix(bytesRead), encoding: .utf8) ?? ""
        }

        // Parse JSON payload: {"mode": "build"|"log", "line": "..."}
        for line in accumulated.components(separatedBy: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let mode = json["mode"],
                  let lineText = json["line"] else { continue }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch mode {
                case "build":
                    self.processBuildLine(lineText)
                case "log":
                    self.stdoutLines.insert(lineText, at: 0)
                    if self.stdoutLines.count > 100 { self.stdoutLines.removeLast() }
                default:
                    break
                }
            }
        }
    }

    private func processBuildLine(_ line: String) {
        isRunning = true
        success = nil

        let range = NSRange(line.startIndex..., in: line)
        if errorPattern.firstMatch(in: line, range: range) != nil {
            errorCount += 1
        }
        if warningPattern.firstMatch(in: line, range: range) != nil {
            warningCount += 1
        }

        if line.contains("BUILD SUCCEEDED") {
            isRunning = false
            success = true
        } else if line.contains("BUILD FAILED") {
            isRunning = false
            success = false
        }

        lastLines.insert(line, at: 0)
        if lastLines.count > 3 { lastLines.removeLast() }
    }

    private func tailFile(at path: String) {
        let handle = FileHandle(forReadingAtPath: path)
        handle?.seekToEndOfFile()
        handle?.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.processBuildLine(text)
            }
        }
    }
}
