#!/usr/bin/env swift
import Foundation
import AppKit

let schemePrefix = "agent-config://"

enum HandlerError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let message):
            return message
        }
    }
}

func reportError(_ error: Any) {
    FileHandle.standardError.write("Error: \(error)\n".data(using: .utf8)!)
    NSLog("AgentConfigHandler error: \(error)")
}

func isSafeSlug(_ name: String) -> Bool {
    name.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil
}

func isSafeRuleFilename(_ name: String) -> Bool {
    name.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*\.md$"#, options: .regularExpression) != nil
}

func firstExistingBuildRoot(homeDir: URL, env: [String: String]) -> URL {
    if let override = env["AGENT_CONFIG_REPO_DIR"], !override.isEmpty {
        return URL(fileURLWithPath: override)
    }

    let candidates = [
        URL(fileURLWithPath: "/opt/homebrew/opt/agent-config/libexec"),
        URL(fileURLWithPath: "/usr/local/opt/agent-config/libexec"),
        homeDir.appendingPathComponent("agent-config"),
    ]

    for candidate in candidates
        where FileManager.default.isExecutableFile(atPath: candidate.appendingPathComponent("build.sh").path) {
        return candidate
    }

    return homeDir.appendingPathComponent("agent-config")
}

enum InstallKind {
    case agents
    case rule
    case skill

    var label: String {
        switch self {
        case .agents:
            return "agent config"
        case .rule:
            return "rule"
        case .skill:
            return "skill"
        }
    }
}

func install(from deeplink: String) throws {
    guard deeplink.hasPrefix(schemePrefix) else {
        throw HandlerError.message("Invalid deeplink format. Expected \(schemePrefix)https://...")
    }

    let encodedOrRawURL = String(deeplink.dropFirst(schemePrefix.count))
    let url = encodedOrRawURL.hasPrefix("https://")
        ? encodedOrRawURL
        : (encodedOrRawURL.removingPercentEncoding ?? encodedOrRawURL)

    guard let sourceURL = URL(string: url),
          sourceURL.scheme == "https",
          sourceURL.host?.isEmpty == false
    else {
        throw HandlerError.message("URL must start with https://")
    }

    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let env = ProcessInfo.processInfo.environment
    let repoDir = firstExistingBuildRoot(homeDir: homeDir, env: env)
    let configRoot = env["AGENT_CONFIG_ROOT"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
        ?? homeDir.appendingPathComponent(".agent-config")

    let buildScript = repoDir.appendingPathComponent("build.sh")

    let pathComponents = sourceURL.pathComponents.filter { $0 != "/" }
    let destPath: URL
    let installKind: InstallKind

    if let agentConfigIndex = pathComponents.firstIndex(of: ".agent-config"),
       agentConfigIndex + 1 == pathComponents.count - 1,
       pathComponents[agentConfigIndex + 1] == "AGENTS.md" {
        installKind = .agents
        destPath = configRoot.appendingPathComponent("AGENTS.md")
    } else if let skillsIndex = pathComponents.firstIndex(of: "skills"),
       skillsIndex + 2 == pathComponents.count - 1,
       pathComponents[skillsIndex + 2] == "SKILL.md" {
        let skillName = pathComponents[skillsIndex + 1]
        guard isSafeSlug(skillName) else {
            throw HandlerError.message("Invalid skill name. Expected a safe slug")
        }
        installKind = .skill
        destPath = configRoot
            .appendingPathComponent("skills")
            .appendingPathComponent(skillName)
            .appendingPathComponent("SKILL.md")
    } else {
        let filename = sourceURL.lastPathComponent
        guard isSafeRuleFilename(filename) else {
            throw HandlerError.message("Invalid rule filename. Expected a safe .md basename")
        }
        installKind = .rule
        destPath = configRoot.appendingPathComponent("rules").appendingPathComponent(filename)
    }

    try FileManager.default.createDirectory(at: destPath.deletingLastPathComponent(), withIntermediateDirectories: true)

    print("Downloading \(installKind.label) from \(url)...")

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
    let tempPath = destPath.deletingLastPathComponent()
        .appendingPathComponent(".\(destPath.lastPathComponent).download.\(UUID().uuidString)")
    task.arguments = ["-fsSL", url, "-o", tempPath.path]
    defer {
        try? FileManager.default.removeItem(at: tempPath)
    }

    try task.run()
    task.waitUntilExit()

    guard task.terminationStatus == 0 else {
        throw HandlerError.message("Download failed")
    }

    let attrs = try FileManager.default.attributesOfItem(atPath: tempPath.path)
    let fileSize = attrs[.size] as? Int ?? 0
    guard fileSize > 0 else {
        throw HandlerError.message("Downloaded file is empty")
    }

    if FileManager.default.fileExists(atPath: destPath.path) {
        try FileManager.default.removeItem(at: destPath)
    }
    try FileManager.default.moveItem(at: tempPath, to: destPath)

    print("Saved to \(destPath.path)")

    let rustBuildScript = repoDir.appendingPathComponent("target/release/agent-config-build")
guard FileManager.default.isExecutableFile(atPath: rustBuildScript.path) else {
    throw HandlerError.message("Rust build binary not found at \(rustBuildScript.path). Run 'cargo build --release' in agent-config directory.")
}

print("Running Rust build binary...")
let buildTask = Process()
buildTask.executableURL = rustBuildScript
buildTask.currentDirectoryURL = repoDir
var buildEnv = env
buildEnv["AGENT_CONFIG_ROOT"] = configRoot.path
buildTask.environment = buildEnv
try buildTask.run()
buildTask.waitUntilExit()

guard buildTask.terminationStatus == 0 else {
    throw HandlerError.message("Rust build failed")
}

print("Done! \(installKind.label.capitalized) installed and synced.")
}

final class DeeplinkAppDelegate: NSObject, NSApplicationDelegate {
    var didReceiveURL = false

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        didReceiveURL = true

        guard let deeplink = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            reportError("Missing URL in Apple Event")
            NSApp.terminate(nil)
            return
        }

        do {
            try install(from: deeplink)
        } catch {
            reportError(error)
        }

        NSApp.terminate(nil)
    }
}

if let deeplink = CommandLine.arguments.dropFirst().first {
    do {
        try install(from: deeplink)
        exit(0)
    } catch {
        reportError(error)
        exit(1)
    }
}

let delegate = DeeplinkAppDelegate()
NSAppleEventManager.shared().setEventHandler(
    delegate,
    andSelector: #selector(DeeplinkAppDelegate.handleGetURLEvent(_:withReplyEvent:)),
    forEventClass: AEEventClass(kInternetEventClass),
    andEventID: AEEventID(kAEGetURL)
)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.delegate = delegate

DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
    if !delegate.didReceiveURL {
        reportError("No deeplink received")
        NSApp.terminate(nil)
    }
}

app.run()
