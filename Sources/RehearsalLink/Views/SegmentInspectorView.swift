import SwiftUI

struct SegmentInspectorView: View {
    @ObservedObject var viewModel: MainViewModel
    let segment: AudioSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header & Metadata Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Segment Details")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        viewModel.selectedSegmentId = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .help("Return to Rehearsal Summary")
                }

                VStack(alignment: .leading, spacing: 12) {
                    // Type & Label
                    HStack(spacing: 12) {
                        Picker("Type", selection: Binding(
                            get: { segment.type },
                            set: { newType in viewModel.updateSegmentType(id: segment.id, type: newType) }
                        )) {
                            Label("Performance", systemImage: "music.note").tag(SegmentType.performance)
                            Label("Conversation", systemImage: "bubble.left.and.bubble.right.fill").tag(SegmentType.conversation)
                            Label("Silence", systemImage: "zzz").tag(SegmentType.silence)
                        }
                        .labelsHidden()
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 140)

                        TextField("Segment Label", text: Binding(
                            get: { segment.label ?? "" },
                            set: { newLabel in viewModel.updateSegmentLabel(id: segment.id, label: newLabel) }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    // Time & Export Exclusion
                    HStack {
                        Label(formatTime(segment.startTime), systemImage: "clock")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)

                        Text("(\(String(format: "%.1f", segment.duration))s)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        Toggle(isOn: Binding(
                            get: { segment.isExcludedFromExport },
                            set: { newValue in viewModel.updateSegmentExportExclusion(id: segment.id, isExcluded: newValue) }
                        )) {
                            Text("Exclude")
                                .font(.caption)
                        }
                        .toggleStyle(.checkbox)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(segment.isExcludedFromExport ? .red : .primary)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            // Transcription Section (Fills the rest of the window)
            if segment.type == .conversation {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label("Transcription", systemImage: "waveform.and.mic")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundColor(.secondary)
                            .symbolRenderingMode(.hierarchical)

                        Spacer()

                        if viewModel.isTranscribing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            HStack(spacing: 8) {
                                if segment.transcription != nil {
                                    Menu {
                                        Button(action: {
                                            viewModel.normalizeSegmentWithAI(id: segment.id)
                                        }) {
                                            Label("Fix Typos (AI)", systemImage: "wand.and.stars")
                                        }
                                    } label: {
                                        Label("AI Actions", systemImage: "sparkles")
                                            .labelStyle(.iconOnly)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }

                                Button(action: {
                                    viewModel.transcribeSegment(id: segment.id)
                                }) {
                                    Text(segment.transcription == nil ? "Transcribe" : "Re-transcribe")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if segment.transcription != nil {
                        TextEditor(text: Binding(
                            get: { segment.transcription ?? "" },
                            set: { newText in viewModel.updateTranscription(id: segment.id, text: newText) }
                        ))
                        .font(.system(.body))
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fills remaining space
                        .padding(8)
                        .background(.background)
                    } else if !viewModel.isTranscribing {
                        VStack(spacing: 8) {
                            Image(systemName: "text.badge.plus")
                                .font(.largeTitle)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.secondary)
                            Text("No transcription yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.background)
                    }
                }
            } else {
                // Non-conversation placeholder
                ContentUnavailableView(
                    "Non-Speech Segment",
                    systemImage: segment.type == .performance ? "music.note" : "zzz",
                    description: Text("Transcription is only available for conversation segments.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
