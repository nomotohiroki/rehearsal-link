import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
class ProjectService {
    enum ProjectError: Error {
        case fileSelectionCancelled
        case failedToSave(Error)
        case failedToLoad(Error)
        case invalidData
    }

    private let projectUTI: UTType = {
        if let type = UTType("com.example.rehearsallink") {
            return type
        }
        return UTType(exportedAs: "com.example.rehearsallink", conformingTo: .json)
    }()

    @MainActor
    func saveProject(audioFileURL: URL, segments: [AudioSegment], summary: String? = nil) async throws {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [projectUTI, .json]
        savePanel.nameFieldStringValue = audioFileURL.deletingPathExtension().lastPathComponent + ".rehearsallink"

        let response = await savePanel.begin()
        guard response == .OK, let url = savePanel.url else {
            throw ProjectError.fileSelectionCancelled
        }

        let project = RehearsalLinkProject(audioFileURL: audioFileURL, segments: segments, summary: summary)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(project)
            try data.write(to: url)
        } catch {
            throw ProjectError.failedToSave(error)
        }
    }

    @MainActor
    func loadProject() async throws -> RehearsalLinkProject {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [projectUTI, .json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        let response = await openPanel.begin()
        guard response == .OK, let url = openPanel.url else {
            throw ProjectError.fileSelectionCancelled
        }

        return try await loadProject(from: url)
    }

    func loadProject(from url: URL) async throws -> RehearsalLinkProject {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(RehearsalLinkProject.self, from: data)
        } catch {
            throw ProjectError.failedToLoad(error)
        }
    }
}
