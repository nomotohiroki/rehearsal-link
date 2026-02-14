import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

struct AudioLoadService: Sendable {
    enum AudioLoadError: Error {
        case fileSelectionCancelled
        case failedToLoadFile(Error)
        case invalidFormat
    }

    @MainActor
    func selectAudioFile() async throws -> URL {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.audio, .mp3, .wav]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        let response = await openPanel.begin()
        guard response == .OK, let url = openPanel.url else {
            throw AudioLoadError.fileSelectionCancelled
        }
        return url
    }

    @MainActor
    func selectAndLoadFile() async throws -> AudioData {
        let url = try await selectAudioFile()
        return try await loadAudio(from: url)
    }

    func loadAudio(from url: URL) async throws -> AudioData {
        return try await Task.detached(priority: .userInitiated) {
            print("AudioLoadService: Loading file from \(url.lastPathComponent)")
            do {
                let audioFile = try AVAudioFile(forReading: url)
                return AudioData(url: url, audioFile: audioFile)
            } catch {
                print("AudioLoadService: Failed to load. Error: \(error)")
                throw AudioLoadError.failedToLoadFile(error)
            }
        }.value
    }
}
