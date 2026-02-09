import SwiftUI

struct ProjectSummaryView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (Fixed at top)
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

            // Content Area (Flexible and Fills available space)
            Group {
                if let summary = viewModel.projectSummary {
                    VStack(alignment: .leading, spacing: 0) {
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
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        if isEditing {
                            TextEditor(text: Binding(
                                get: { viewModel.projectSummary ?? "" },
                                set: { viewModel.projectSummary = $0 }
                            ))
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill space
                            .padding(8)
                            .background(.background)
                        } else {
                            RichTextView(markdown: summary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill space
                                .background(.background)
                        }
                    }
                } else {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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
                .padding(.horizontal, 40)

            Button("Generate Summary Now") {
                viewModel.summarizeRehearsalWithAI()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isTranscribing)
        }
    }
}
