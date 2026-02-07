import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // Main Workspace
                VStack(spacing: 0) {
                    if let audioData = viewModel.audioData {
                        // File Info Header
                        HStack {
                            Text(audioData.fileName)
                                .font(.headline)
                            Spacer()
                            Text("Total: \(formatTime(audioData.duration))")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        
                        // Waveform Area
                        VStack(spacing: 0) {
                            // Zoom Controls
                            HStack {
                                Button(action: { viewModel.zoomOut() }) {
                                    Image(systemName: "minus.magnifyingglass")
                                }
                                .disabled(viewModel.zoomLevel <= 1.0)
                                
                                Slider(value: $viewModel.zoomLevel, in: 1.0...50.0)
                                    .frame(width: 150)
                                
                                Button(action: { viewModel.zoomIn() }) {
                                    Image(systemName: "plus.magnifyingglass")
                                }
                                .disabled(viewModel.zoomLevel >= 50.0)
                                
                                Button("Reset") {
                                    viewModel.resetZoom()
                                }
                                .buttonStyle(.link)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            GeometryReader { outerGeometry in
                                ScrollView(.horizontal, showsIndicators: true) {
                                    let baseWidth = outerGeometry.size.width
                                    let totalWidth = max(baseWidth, baseWidth * CGFloat(viewModel.zoomLevel))
                                    
                                    WaveformView(
                                        samples: viewModel.waveformSamples,
                                        segments: viewModel.segments,
                                        selectedSegmentId: viewModel.selectedSegmentId,
                                        totalDuration: audioData.duration,
                                        width: totalWidth,
                                        playbackPosition: {
                                            guard audioData.duration > 0 else { return 0 }
                                            let progress = viewModel.currentTime / audioData.duration
                                            return progress.isFinite ? max(0, min(1, progress)) : 0
                                        }(),
                                        onSeek: { progress in
                                            viewModel.seek(progress: progress)
                                        },
                                        onSelectSegment: { id in
                                            viewModel.selectedSegmentId = id
                                        },
                                        onUpdateSegmentType: { id, type in
                                            viewModel.updateSegmentType(id: id, type: type)
                                        },
                                        onMoveBoundary: { index, newTime in
                                            viewModel.moveBoundary(index: index, newTime: newTime)
                                        }
                                    )
                                    .frame(width: totalWidth)
                                    .padding(.vertical)
                                    .overlay {
                                        if viewModel.isAnalyzing {
                                            ZStack {
                                                Color.black.opacity(0.3)
                                                VStack {
                                                    ProgressView()
                                                        .controlSize(.large)
                                                    Text("Analyzing audio...")
                                                        .font(.caption)
                                                        .foregroundColor(.white)
                                                        .padding(.top, 4)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(height: 340) // Adjust height to accommodate padding and scrollbar
                        }
                        .background(Color.black.opacity(0.1))
                        
                        Divider()
                        
                        // Transport Bar
                        HStack(spacing: 24) {
                            Spacer()
                            
                            Button(action: {
                                viewModel.isLoopingEnabled.toggle()
                            }) {
                                Image(systemName: "repeat")
                                    .font(.title2)
                                    .foregroundColor(viewModel.isLoopingEnabled ? .accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Loop selected segment")
                            .disabled(viewModel.selectedSegmentId == nil)
                            
                            Button(action: {
                                viewModel.togglePlayback()
                            }) {
                                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 44))
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                viewModel.stopPlayback()
                            }) {
                                Image(systemName: "stop.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            
                            Text(formatTime(viewModel.currentTime))
                                .font(.title2)
                                .monospacedDigit()
                                .frame(width: 120, alignment: .center)
                                .background(Color.black.opacity(0.1))
                                .cornerRadius(8)
                            
                            Button(action: {
                                viewModel.splitSegment(at: viewModel.currentTime)
                            }) {
                                Label("Split", systemImage: "scissors")
                            }
                            .help("Split segment at playhead")
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor))
                        
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
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                            .padding()
                    }
                }
                .frame(minWidth: 600)
                
                // Inspector Panel
                if viewModel.audioData != nil {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Inspector")
                            .font(.headline)
                            .padding(.bottom, 10)
                        
                        if let selectedId = viewModel.selectedSegmentId,
                           let segment = viewModel.segments.first(where: { $0.id == selectedId }) {
                            
                            Group {
                                VStack(alignment: .leading) {
                                    Text("Label")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    TextField("Segment Label", text: Binding(
                                        get: { segment.label ?? "" },
                                        set: { newLabel in viewModel.updateSegmentLabel(id: segment.id, label: newLabel) }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("Type")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Picker("Type", selection: Binding(
                                        get: { segment.type },
                                        set: { newType in viewModel.updateSegmentType(id: segment.id, type: newType) }
                                    )) {
                                        Text("Performance").tag(SegmentType.performance)
                                        Text("Conversation").tag(SegmentType.conversation)
                                        Text("Silence").tag(SegmentType.silence)
                                    }
                                    .labelsHidden()
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("Start Time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatTime(segment.startTime))
                                        .font(.body)
                                        .monospacedDigit()
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("End Time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatTime(segment.endTime))
                                        .font(.body)
                                        .monospacedDigit()
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("Duration")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.2f s", segment.duration))
                                        .font(.body)
                                }
                            }
                            
                        } else {
                            Text("No segment selected")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .frame(width: 250)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
            .navigationTitle("RehearsalLink")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { viewModel.selectFile() }) {
                        Label("Open Audio", systemImage: "music.note.list")
                    }
                    .disabled(viewModel.isLoading)
                    
                    Button(action: { viewModel.loadProject() }) {
                        Label("Open Project", systemImage: "folder")
                    }
                    .disabled(viewModel.isLoading)
                    
                    Button(action: { viewModel.saveProject() }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .disabled(viewModel.isLoading || viewModel.audioData == nil)
                    
                    Menu {
                        Button("Export Performance Only") {
                            viewModel.exportSegments(type: .performance)
                        }
                        Button("Export Conversation Only") {
                            viewModel.exportSegments(type: .conversation)
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.isLoading || viewModel.audioData == nil)
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}