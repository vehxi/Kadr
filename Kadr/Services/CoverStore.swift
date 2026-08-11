import AppKit
import Foundation

actor CoverStore {
    static let shared = CoverStore()

    private let fileManager: FileManager
    private let directoryURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let kadrDirectory = applicationSupport
            .appendingPathComponent("Kadr", isDirectory: true)
            .appendingPathComponent("Covers", isDirectory: true)
        let legacyDirectory = applicationSupport
            .appendingPathComponent("My Movies", isDirectory: true)
            .appendingPathComponent("Covers", isDirectory: true)

        if !fileManager.fileExists(atPath: kadrDirectory.path),
           fileManager.fileExists(atPath: legacyDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: kadrDirectory.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fileManager.moveItem(at: legacyDirectory, to: kadrDirectory)
                self.directoryURL = kadrDirectory
            } catch {
                self.directoryURL = legacyDirectory
            }
        } else {
            self.directoryURL = kadrDirectory
        }
    }

    func write(_ jpegData: Data) throws -> String {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let filename = "\(UUID().uuidString).jpg"
        let destination = directoryURL.appendingPathComponent(filename)
        try jpegData.write(to: destination, options: [.atomic, .completeFileProtection])
        return filename
    }

    func delete(filename: String?) throws {
        guard let filename else { return }
        let url = directoryURL.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func url(for filename: String?) -> URL? {
        guard let filename else { return nil }
        return directoryURL.appendingPathComponent(filename)
    }

    func removeOrphans(referencedFilenames: Set<String>) throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        let files = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for file in files where !referencedFilenames.contains(file.lastPathComponent) {
            try fileManager.removeItem(at: file)
        }
    }
}
