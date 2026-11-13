import AppKit
import Foundation

/// Checks GitHub Releases and installs newer builds in place (TCC-stable).
@MainActor
enum AppUpdater {
    static let githubRepo = "KlarseQ/KidPlay"
    private static let userAgent = "KidPlay-Updater"

    enum Outcome: Equatable {
        case upToDate
        case skipped(String)
        case updated(String)
        case failed(String)
    }

    struct ReleaseInfo {
        let tag: String
        let version: String
        let zipURL: URL
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ?? "0"
    }

    /// Running from a real .app (not bare `swift run` binary).
    static var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static func checkAndInstallIfNeeded(
        status: (@MainActor (String) -> Void)? = nil
    ) async -> Outcome {
        guard isBundledApp else {
            return .skipped("Обновления только для KidPlay.app")
        }

        status?("Проверка обновлений…")

        let release: ReleaseInfo
        do {
            guard let latest = try await fetchLatestRelease() else {
                return .upToDate
            }
            release = latest
        } catch {
            return .failed("Не удалось проверить обновления: \(error.localizedDescription)")
        }

        guard isNewer(release.version, than: currentVersion) else {
            return .upToDate
        }

        status?("Скачиваю \(release.version)…")

        do {
            let zipURL = try await download(release.zipURL)
            defer { try? FileManager.default.removeItem(at: zipURL) }

            status?("Устанавливаю \(release.version)…")
            try installZip(zipURL, into: Bundle.main.bundleURL)
            relaunch(appURL: Bundle.main.bundleURL)
            return .updated(release.version)
        } catch {
            return .failed("Обновление не удалось: \(error.localizedDescription)")
        }
    }

    // MARK: - GitHub

    private static func fetchLatestRelease() async throws -> ReleaseInfo? {
        guard let api = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest") else {
            return nil
        }
        var request = URLRequest(url: api, timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            return nil
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let tag = (json?["tag_name"] as? String) ?? ""
        let version = normalizeVersion(tag)
        guard !version.isEmpty else { return nil }

        let assets = json?["assets"] as? [[String: Any]] ?? []
        let zipAsset = assets.first { asset in
            let name = (asset["name"] as? String)?.lowercased() ?? ""
            return name.hasSuffix(".zip") && name.contains("kidplay")
        }
        guard
            let urlString = zipAsset?["browser_download_url"] as? String,
            let zipURL = URL(string: urlString)
        else {
            throw NSError(
                domain: "KidPlay.Updater",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "В релизе нет zip-архива"]
            )
        }

        return ReleaseInfo(tag: tag, version: version, zipURL: zipURL)
    }

    private static func download(_ url: URL) async throws -> URL {
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("KidPlay-update-\(UUID().uuidString).zip")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }

    // MARK: - Install

    private static func installZip(_ zipURL: URL, into appURL: URL) throws {
        let fm = FileManager.default
        let extractDir = fm.temporaryDirectory.appendingPathComponent("KidPlay-extract-\(UUID().uuidString)")
        try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: extractDir) }

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", zipURL.path, extractDir.path]
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else {
            throw NSError(
                domain: "KidPlay.Updater",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Не удалось распаковать архив"]
            )
        }

        guard let newApp = findApp(in: extractDir) else {
            throw NSError(
                domain: "KidPlay.Updater",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "В архиве нет KidPlay.app"]
            )
        }

        let newBinary = newApp.appendingPathComponent("Contents/MacOS/KidPlay")
        let newPlist = newApp.appendingPathComponent("Contents/Info.plist")
        let destBinary = appURL.appendingPathComponent("Contents/MacOS/KidPlay")
        let destPlist = appURL.appendingPathComponent("Contents/Info.plist")

        guard fm.fileExists(atPath: newBinary.path) else {
            throw NSError(
                domain: "KidPlay.Updater",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "В архиве нет бинарника"]
            )
        }

        // In-place binary/plist swap keeps TCC association.
        try fm.createDirectory(
            at: destBinary.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fm.fileExists(atPath: destBinary.path) {
            try fm.removeItem(at: destBinary)
        }
        try fm.copyItem(at: newBinary, to: destBinary)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destBinary.path)

        if fm.fileExists(atPath: newPlist.path) {
            if fm.fileExists(atPath: destPlist.path) {
                try fm.removeItem(at: destPlist)
            }
            try fm.copyItem(at: newPlist, to: destPlist)
        }

        let sign = Process()
        sign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        sign.arguments = [
            "--force", "--deep", "--sign", "-",
            "--identifier", "xyz.klarseq.KidPlay",
            appURL.path,
        ]
        try? sign.run()
        sign.waitUntilExit()

        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-dr", "com.apple.quarantine", appURL.path]
        try? xattr.run()
        xattr.waitUntilExit()
    }

    private static func findApp(in directory: URL) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let url as URL in enumerator {
            if url.pathExtension == "app", url.lastPathComponent == "KidPlay.app" {
                return url
            }
        }
        return nil
    }

    private static func relaunch(appURL: URL) {
        let script = """
        #!/bin/bash
        sleep 0.8
        open "\(appURL.path)"
        """
        let helper = FileManager.default.temporaryDirectory
            .appendingPathComponent("kidplay-relaunch-\(UUID().uuidString).sh")
        try? script.write(to: helper, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [helper.path]
        try? task.run()

        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Versions

    static func normalizeVersion(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("v") {
            s = String(s.dropFirst())
        }
        return s
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        compareVersions(normalizeVersion(candidate), normalizeVersion(current)) > 0
    }

    /// -1 / 0 / 1
    static func compareVersions(_ a: String, _ b: String) -> Int {
        let ap = a.split(separator: ".").map { Int($0) ?? 0 }
        let bp = b.split(separator: ".").map { Int($0) ?? 0 }
        let n = max(ap.count, bp.count)
        for i in 0..<n {
            let av = i < ap.count ? ap[i] : 0
            let bv = i < bp.count ? bp[i] : 0
            if av != bv { return av > bv ? 1 : -1 }
        }
        return 0
    }
}
