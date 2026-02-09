import SwiftUI

struct ProjectSummaryView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Rehearsal Summary", systemImage: "sparkles.rectangle.stack")
                        .font(.headline)
                        .symbolRenderingMode(.hierarchical)

                    Spacer()

                    if viewModel.isTranscribing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        HStack(spacing: 8) {
                            if viewModel.projectSummary != nil {
                                Button(action: { isEditing.toggle() }) {
                                    Label(isEditing ? "View" : "Edit", systemImage: isEditing ? "eye" : "pencil")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            Button(action: {
                                viewModel.summarizeRehearsalWithAI()
                            }) {
                                Label("Generate", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                Text("Overall summary of the rehearsal session.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let summary = viewModel.projectSummary {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(isEditing ? "Editing Markdown" : "AI Generated Summary")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(summary, forType: .string)
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.link)
                                .controlSize(.small)
                            }

                            if isEditing {
                                TextEditor(text: Binding(
                                    get: { viewModel.projectSummary ?? "" },
                                    set: { viewModel.projectSummary = $0 }
                                ))
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 500)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                            } else {
                                RichTextView(markdown: summary)
                                    .frame(minHeight: 600)
                                    .background(.background)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.secondary)

            Text("No summary generated yet.")
                .font(.headline)

            Text("Make sure you have transcribed the conversation segments first, then click 'Generate' to create an AI summary.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Generate Summary Now") {
                viewModel.summarizeRehearsalWithAI()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isTranscribing)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
