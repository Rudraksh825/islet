import Foundation
import Darwin

// island-notify: CLI tool that pipes stdin lines to the Islet Unix socket.
// Usage:
//   xcodebuild 2>&1 | island-notify --mode build
//   tail -f /var/log/system.log | island-notify --mode log

let socketPath = "/tmp/com.islet.build.sock"

// Parse --mode argument
var mode = "log"
var args = CommandLine.arguments.dropFirst()
var iter = args.makeIterator()
while let arg = iter.next() {
    if arg == "--mode", let val = iter.next() {
        mode = val
    }
}

// Connect to the Unix socket
let sock = socket(AF_UNIX, SOCK_STREAM, 0)
guard sock >= 0 else {
    fputs("island-notify: failed to create socket\n", stderr)
    exit(1)
}

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
socketPath.withCString { ptr in
    withUnsafeMutablePointer(to: &addr.sun_path) { dest in
        dest.withMemoryRebound(to: CChar.self, capacity: 108) { destChar in
            _ = strcpy(destChar, ptr)
        }
    }
}

let connectResult = withUnsafePointer(to: &addr) { ptr in
    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
        connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
}

guard connectResult == 0 else {
    fputs("island-notify: could not connect to Islet (\(socketPath)). Is the app running?\n", stderr)
    exit(1)
}

// Read stdin line by line and send each as JSON
while let line = readLine(strippingNewline: true) {
    let payload: [String: String] = ["mode": mode, "line": line]
    if let data = try? JSONSerialization.data(withJSONObject: payload),
       var str = String(data: data, encoding: .utf8) {
        str += "\n"
        str.withCString { ptr in
            _ = send(sock, ptr, strlen(ptr), 0)
        }
    }
}

close(sock)
