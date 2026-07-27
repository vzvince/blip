import Foundation
import Blip

@main
struct BlipCLI {
    static func main() async {
        let env = ProcessInfo.processInfo.environment
        let base = URL(string: env["BLIP_URL"] ?? "http://127.0.0.1:9042")!
        var args = Array(ProcessInfo.processInfo.arguments.dropFirst())

        func consumeFlag(_ name: String) -> String? {
            if let idx = args.firstIndex(of: name), idx + 1 < args.count {
                return args.remove(at: idx + 1)
            }
            return nil
        }

        guard let cmd = args.first else {
            print("usage: blip push|ls|focus|clear  (env: BLIP_URL=http://127.0.0.1:PORT)")
            return
        }
        args.removeFirst()
        do {
            let req: URLRequest
            switch cmd {
            case "push":
                let source = consumeFlag("-s") ?? consumeFlag("--source") ?? "unknown"
                let title  = consumeFlag("-t") ?? consumeFlag("--title") ?? ""
                let body   = consumeFlag("-b") ?? consumeFlag("--body") ?? ""
                let ws     = consumeFlag("--workspace-id")
                let sf     = consumeFlag("--surface-id")
                let pri    = consumeFlag("--priority")
                req = CLIRequestBuilder.push(base: base, source: source, title: title, body: body,
                                             workspaceId: ws, surfaceId: sf, priority: pri)
            case "ls":
                req = CLIRequestBuilder.ls(base: base)
            case "focus":
                guard !args.isEmpty else { print("usage: blip focus <id>"); return }
                req = CLIRequestBuilder.focus(base: base, id: args.joined(separator: " "))
            case "clear":
                req = CLIRequestBuilder.clear(base: base)
            default:
                print("unknown subcommand: \(cmd)")
                return
            }
            try await fetch(req, verboseFor: cmd)
        } catch {
            print("blip: \(error)")
        }
    }
}

func fetch(_ req: URLRequest, verboseFor cmd: String) async throws {
    let (data, resp) = try await URLSession.shared.data(for: req)
    let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
    if cmd == "ls", let s = String(data: data, encoding: .utf8), !s.isEmpty {
        print(s)
    }
    guard (200..<300).contains(status) else {
        throw NSError(domain: "blip", code: status, userInfo: [NSLocalizedDescriptionKey: "HTTP \(status)"])
    }
}
