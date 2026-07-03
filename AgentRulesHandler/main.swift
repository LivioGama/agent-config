#!/usr/bin/env swift
import Foundation

// Get the URL from the deeplink
let deeplink = CommandLine.arguments.dropFirst().first ?? ""

guard deeplink.hasPrefix("agent-rules://") else {
    FileHandle.standardError.write("Error: Invalid deeplink format\n".data(using: .utf8)!)
    exit(1)
}

let url = String(deeplink.dropFirst("agent-rules://".count))

guard url.hasPrefix("http://") || url.hasPrefix("https://") else {
    FileHandle.standardError.write("Error: URL must start with http:// or https://\n".data(using: .utf8)!)
    exit(1)
}

let homeDir = FileManager.default.homeDirectoryForCurrentUser
var repoDir = homeDir.appendingPathComponent("agent-config")
if !FileManager.default.fileExists(atPath: repoDir.path) {
    repoDir = homeDir.appendingPathComponent("agent-rules")
}

// Determine if this is a skill or rule based on URL path
let isSkill = url.contains("/skills/") && url.hasSuffix("SKILL.md")
let destDir: URL
if isSkill {
    destDir = repoDir.appendingPathComponent(".agent-config/skills")
} else {
    destDir = repoDir.appendingPathComponent(".agent-config/rules")
}

let buildScript = repoDir.appendingPathComponent("build.sh")

// Create destination directory if needed
try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

// Extract path structure from URL
guard let urlComponents = URL(string: url) else {
    FileHandle.standardError.write("Error: Invalid URL\n".data(using: .utf8)!)
    exit(1)
}

let urlPath = urlComponents.path
var destPath: URL

if isSkill {
    // Extract skill name from path like "skills/my-skill/SKILL.md"
    let pathComponents = urlPath.components(separatedBy: "/")
    if let skillsIndex = pathComponents.firstIndex(of: "skills"),
       skillsIndex + 2 < pathComponents.count {
        let skillName = pathComponents[skillsIndex + 1]
        destPath = destDir.appendingPathComponent(skillName).appendingPathComponent("SKILL.md")
        try FileManager.default.createDirectory(at: destPath.deletingLastPathComponent(), withIntermediateDirectories: true)
    } else {
        FileHandle.standardError.write("Error: Invalid skill path format\n".data(using: .utf8)!)
        exit(1)
    }
} else {
    // Extract filename for rules
    let filename = urlComponents.lastPathComponent
    destPath = destDir.appendingPathComponent(filename)
}

// Download the file
print("Downloading \(isSkill ? "skill" : "rule") from \(url)...")

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
task.arguments = ["-fsSL", url, "-o", destPath.path]

do {
    try task.run()
    task.waitUntilExit()

    guard task.terminationStatus == 0 else {
        FileHandle.standardError.write("Error: Download failed\n".data(using: .utf8)!)
        exit(1)
    }

    // Check file is not empty
    let attrs = try FileManager.default.attributesOfItem(atPath: destPath.path)
    let fileSize = attrs[.size] as? Int ?? 0
    guard fileSize > 0 else {
        FileHandle.standardError.write("Error: Downloaded file is empty\n".data(using: .utf8)!)
        try FileManager.default.removeItem(at: destPath)
        exit(1)
    }

    print("Saved to \(destPath.path)")

    // Run build script
    print("Running build.sh...")
    let buildTask = Process()
    buildTask.executableURL = buildScript
    buildTask.currentDirectoryURL = repoDir
    try buildTask.run()
    buildTask.waitUntilExit()

    guard buildTask.terminationStatus == 0 else {
        FileHandle.standardError.write("Error: build.sh failed\n".data(using: .utf8)!)
        exit(1)
    }

    print("Done! \(isSkill ? "Skill" : "Rule") installed and synced.")

} catch {
    FileHandle.standardError.write("Error: \(error)\n".data(using: .utf8)!)
    exit(1)
}
