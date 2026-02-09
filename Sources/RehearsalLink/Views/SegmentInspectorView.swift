import SwiftUI

struct SegmentInspectorView: View {
    @ObservedObject var viewModel: MainViewModel
    let segment: AudioSegment

    var body: some View {
        ScrollView {
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
                .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Type")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundColor(.secondary)
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
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start Time")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(formatTime(segment.startTime))
                            .font(.system(.body, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f s", segment.duration))
                            .font(.system(.body, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Label")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("Segment Label", text: Binding(
                        get: { segment.label ?? "" },
                        set: { newLabel in viewModel.updateSegmentLabel(id: segment.id, label: newLabel) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                Toggle(isOn: Binding(
                    get: { segment.isExcludedFromExport },
                    set: { newValue in viewModel.updateSegmentExportExclusion(id: segment.id, isExcluded: newValue) }
                )) {
                    Label("Exclude from Export", systemImage: "xmark.bin.fill")
                }
                .toggleStyle(.checkbox)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(segment.isExcludedFromExport ? .red : .primary)

                if segment.type == .conversation {
                    Divider()
                        .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 12) {
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
                                        .help("AI-powered text processing")
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

                        if segment.transcription != nil {
                            TextEditor(text: Binding(
                                get: { segment.transcription ?? "" },
                                set: { newText in viewModel.updateTranscription(id: segment.id, text: newText) }
                            ))
                            .font(.system(.body))
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
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
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}
