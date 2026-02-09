import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showInspector = true
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: File & Project Management
            List {
                Section {
                    if let audioData = viewModel.audioData {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(audioData.fileName, systemImage: "waveform.circle.fill")
                                .font(.headline)
                                .symbolRenderingMode(.hierarchical)

                            VStack(alignment: .leading, spacing: 4) {
                                InfoRow(label: "Duration", value: formatTime(audioData.duration))
                                InfoRow(label: "Format", value: audioData.url.pathExtension.uppercased())
                                InfoRow(label: "Segments", value: "\(viewModel.segments.count)")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 32))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.secondary)
                            Text("No audio selected")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } header: {
                    Text("Current Session")
                }

                Section("Library") {
                    Button(action: { viewModel.selectFile() }) {
                        Label("Import Audio...", systemImage: "plus.circle.fill")
                    }
                    .disabled(viewModel.isLoading)

                    Button(action: { viewModel.loadProject() }) {
                        Label("Open Project...", systemImage: "folder.fill")
                    }
                    .disabled(viewModel.isLoading)

                    Button(action: { viewModel.saveProject() }) {
                        Label("Save Project", systemImage: "square.and.arrow.down")
                    }
                    .disabled(viewModel.isLoading || viewModel.audioData == nil)
                }

                Section("Processing") {
                    Button(action: { viewModel.normalizeAndReanalyze() }) {
                        Label("Normalize Audio", systemImage: "waveform.badge.plus")
                    }
                    .disabled(viewModel.isLoading || viewModel.audioData == nil)

                    Button(action: { viewModel.transcribeAllConversations() }) {
                        Label("Batch Transcribe", systemImage: "waveform.and.mic")
                    }
                    .disabled(viewModel.isLoading || viewModel.audioData == nil || viewModel.isBatchTranscribing)

                    Button(action: {
                        viewModel.summarizeRehearsalWithAI()
                    }) {
                        Label("Generate Summary", systemImage: "sparkles.rectangle.stack")
                    }
                    .disabled(viewModel.isLoading || viewModel.audioData == nil || viewModel.isTranscribing)

                    Button(action: {
                        openSettings()
                    }) {
                        Label("AI Settings", systemImage: "brain.head.profile")
                    }
                }
                .symbolRenderingMode(.hierarchical)

                Section("Export") {
                    Button(action: { viewModel.exportSegments(type: .performance) }) {
                        Label("Export Performance", systemImage: "music.note")
                    }
                    Button(action: { viewModel.exportSegments(type: .conversation) }) {
                        Label("Export Conversation", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                    Button(action: { viewModel.exportAllTranscriptions() }) {
                        Label("Export Text (.txt)", systemImage: "doc.text.fill")
                    }
                }
                .symbolRenderingMode(.hierarchical)
                .disabled(viewModel.isLoading || viewModel.audioData == nil)
            }
            .navigationTitle("RehearsalLink")
            .background(.thinMaterial)

        } detail: {
            // Detail: Waveform Area & Transport
            ZStack {
                if let audioData = viewModel.audioData {
                    VStack(spacing: 0) {
                        // Waveform Area
                        waveformArea(audioData: audioData)
                            .frame(maxHeight: .infinity)
                            .background(.background)

                        Divider()

                        // Transport Bar
                        transportBar()
                            .padding()
                            .background(.ultraThinMaterial)
                    }
                } else if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label("No Audio Loaded", systemImage: "waveform")
                    } description: {
                        Text("Open an audio file or project to get started.")
                    } actions: {
                        HStack {
                            Button("Open Audio") {
                                viewModel.selectFile()
                            }
                            Button("Open Project") {
                                viewModel.loadProject()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(viewModel.audioData?.fileName ?? "RehearsalLink")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showInspector.toggle() }) {
                        Label("Toggle Inspector", systemImage: "sidebar.right")
                    }
                    .help("Toggle Inspector")
                }
            }
        }
        .inspector(isPresented: $showInspector) {
            Group {
                if let selectedId = viewModel.selectedSegmentId,
                   let segment = viewModel.segments.first(where: { $0.id == selectedId }) {
                    SegmentInspectorView(viewModel: viewModel, segment: segment)
                } else {
                    ProjectSummaryView(viewModel: viewModel)
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 350, max: 500)
        }
        .alert("Project Found", isPresented: $viewModel.showProjectDetectedAlert) {
            Button("Load Project") {
                viewModel.loadDetectedProject()
            }
            Button("Load Audio Only") {
                viewModel.loadAudioOnly()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A project file was found for this audio. Would you like to load the existing project or start fresh?")
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            if let provider = providers.first {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            viewModel.handleFile(at: url)
                        }
                    }
                }
                return true
            }
            return false
        }
    }

    private func waveformArea(audioData: AudioData) -> some View {
        VStack(spacing: 0) {
            zoomControls()
            waveformScrollView(audioData: audioData)
        }
        .overlay(alignment: .bottom) {
            batchTranscriptionOverlay()
        }
    }

    private func zoomControls() -> some View {
        HStack {
            Button(action: { viewModel.zoomOut() }) {
                Image(systemName: "minus.magnifyingglass")
            }
            .disabled(viewModel.zoomLevel <= 1.0)
            .buttonStyle(.borderless)

            Slider(value: $viewModel.zoomLevel, in: 1.0 ... 50.0)
                .frame(width: 150)

            Button(action: { viewModel.zoomIn() }) {
                Image(systemName: "plus.magnifyingglass")
            }
            .disabled(viewModel.zoomLevel >= 50.0)
            .buttonStyle(.borderless)

            Button("Reset") {
                viewModel.resetZoom()
            }
            .buttonStyle(.link)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func waveformScrollView(audioData: AudioData) -> some View {
        GeometryReader { outerGeometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    let baseWidth = outerGeometry.size.width
                    let totalWidth = max(baseWidth, baseWidth * CGFloat(viewModel.zoomLevel))
                    let playbackPosition = currentPlaybackPosition()

                    ZStack(alignment: .leading) {
                        waveformView(audioData: audioData, totalWidth: totalWidth, playbackPosition: playbackPosition)
                        playheadMarker(totalWidth: totalWidth, playbackPosition: playbackPosition)
                    }
                    .padding(.vertical)
                    .overlay {
                        analysisOverlay()
                    }
                }
                .onChange(of: viewModel.zoomLevel) {
                    scrollToPlayhead(proxy: proxy, animated: true)
                }
                .onChange(of: viewModel.currentTime) {
                    if viewModel.isPlaying {
                        scrollToPlayhead(proxy: proxy, animated: false)
                    }
                }
            }
        }
    }

    private func currentPlaybackPosition() -> Double {
        guard let duration = viewModel.audioData?.duration, duration > 0 else { return 0 }
        let progress = viewModel.currentTime / duration
        return progress.isFinite ? max(0, min(1, progress)) : 0
    }

    private func waveformView(audioData: AudioData, totalWidth: CGFloat, playbackPosition: Double) -> some View {
        WaveformView(
            samples: viewModel.waveformSamples,
            segments: viewModel.segments,
            selectedSegmentId: viewModel.selectedSegmentId,
            totalDuration: audioData.duration,
            width: totalWidth,
            playbackPosition: playbackPosition,
            onSeek: { progress in
                viewModel.seek(progress: progress)
            },
            onSelectSegment: { id in
                viewModel.selectedSegmentId = id
                showInspector = true
            },
            onUpdateSegmentType: { id, type in
                viewModel.updateSegmentType(id: id, type: type)
            },
            onMoveBoundary: { index, newTime in
                viewModel.moveBoundary(index: index, newTime: newTime)
            },
            onMergeWithNext: { id in
                viewModel.mergeWithNext(id: id)
            }
        )
        .frame(width: totalWidth)
    }

    private func playheadMarker(totalWidth: CGFloat, playbackPosition: Double) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
                .frame(width: totalWidth * CGFloat(playbackPosition))
            Rectangle()
                .fill(Color.clear)
                .frame(width: 1)
                .id("playhead")
            Spacer(minLength: 0)
        }
        .frame(width: totalWidth, alignment: .leading)
    }

    @ViewBuilder
    private func analysisOverlay() -> some View {
        if viewModel.isAnalyzing {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                VStack {
                    ProgressView()
                        .controlSize(.large)
                    Text("Analyzing audio...")
                        .font(.caption)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func scrollToPlayhead(proxy: ScrollViewProxy, animated: Bool) {
        let action = { proxy.scrollTo("playhead", anchor: .center) }
        if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 0.1)) { action() }
            }
        } else {
            action()
        }
    }

    @ViewBuilder
    private func batchTranscriptionOverlay() -> some View {
        if viewModel.isBatchTranscribing {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "waveform.and.mic")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.accentColor)
                    Text("Transcribing all conversations...")
                        .font(.system(.subheadline, weight: .medium))
                    Spacer()
                    Text("\(Int(viewModel.batchTranscriptionProgress * 100))%")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                ProgressView(value: viewModel.batchTranscriptionProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(width: 320)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.bottom, 30)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func transportBar() -> some View {
        HStack(spacing: 24) {
            Spacer()

            Button(action: {
                viewModel.isLoopingEnabled.toggle()
            }) {
                Image(systemName: viewModel.isLoopingEnabled ? "repeat.circle.fill" : "repeat.circle")
                    .font(.system(size: 24))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(viewModel.isLoopingEnabled ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Loop selected segment")
            .disabled(viewModel.selectedSegmentId == nil)

            Button(action: {
                viewModel.togglePlayback()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 48))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)

            Button(action: {
                viewModel.stopPlayback()
            }) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 24))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Text(formatTime(viewModel.currentTime))
                .font(.system(.title3, design: .monospaced, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 12) {
                Button(action: {
                    viewModel.splitSegment(at: viewModel.currentTime)
                }) {
                    Label("Split", systemImage: "scissors.circle.fill")
                }
                .buttonStyle(.bordered)
                .symbolRenderingMode(.hierarchical)
                .help("Split segment at playhead")

                Button(action: {
                    if let selectedId = viewModel.selectedSegmentId {
                        viewModel.mergeWithNext(id: selectedId)
                    }
                }) {
                    Label("Merge", systemImage: "rectangle.and.arrow.up.right.and.arrow.down.left.slash")
                }
                .buttonStyle(.bordered)
                .symbolRenderingMode(.hierarchical)
                .disabled(viewModel.selectedSegmentId == nil || viewModel.selectedSegmentId == viewModel.segments.last?.id)
                .help("Merge selected segment with the next one")
            }

            Spacer()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }

    private struct InfoRow: View {
        let label: String
        let value: String

        var body: some View {
            HStack {
                Text(label)
                Spacer()
                Text(value)
                    .foregroundColor(.primary)
            }
        }
    }
}
