import SwiftUI

struct AISettingsView: View {
    @ObservedObject private var config = LLMConfigurationService.shared
    @State private var apiKeys: [LLMProvider: String] = [:]
    @State private var modelIDs: [LLMProvider: String] = [:]
    @State private var systemPrompts: [LLMTask: String] = [:]

    var body: some View {
        TabView {
            aiSettingsTab
                .tabItem {
                    Label("AI Services", systemImage: "brain.head.profile")
                }

            promptSettingsTab
                .tabItem {
                    Label("System Prompts", systemImage: "doc.text.magnifyingglass")
                }
        }
        .frame(width: 600, height: 720)
        .onAppear {
            loadSettings()
        }
    }

    private var aiSettingsTab: some View {
        Form {
            Section {
                Picker("Active Provider:", selection: $config.selectedProvider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
            }

            Divider()
                .padding(.vertical, 10)

            ForEach(LLMProvider.allCases) { provider in
                Section {
                    Text(provider.rawValue)
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .padding(.bottom, 2)

                    SecureField("API Key:", text: Binding(
                        get: { apiKeys[provider] ?? "" },
                        set: { apiKeys[provider] = $0 }
                    ))

                    TextField("Model ID:", text: Binding(
                        get: { modelIDs[provider] ?? "" },
                        set: { modelIDs[provider] = $0 }
                    ))
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button("Save AI Settings") {
                        saveAISettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 10)
            }

            Section {
                Text("API keys are required for automated text normalization and rehearsal summarization. Settings are stored locally.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.columns)
        .padding(24)
    }

    private var promptSettingsTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(LLMTask.allCases) { task in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(task.rawValue)
                                    .font(.headline)
                                Spacer()
                                Button("Reset to Default") {
                                    systemPrompts[task] = task.defaultSystemPrompt
                                }
                                .buttonStyle(.link)
                                .font(.caption)
                            }

                            TextEditor(text: Binding(
                                get: { systemPrompts[task] ?? "" },
                                set: { systemPrompts[task] = $0 }
                            ))
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 220)
                            .scrollContentBackground(.hidden)
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Text("These prompts define how the AI behaves.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Save Prompts") {
                    savePromptSettings()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    private func loadSettings() {
        for provider in LLMProvider.allCases {
            apiKeys[provider] = config.getAPIKey(for: provider)
            modelIDs[provider] = config.getModelID(for: provider)
        }
        for task in LLMTask.allCases {
            systemPrompts[task] = config.getSystemPrompt(for: task)
        }
    }

    private func saveAISettings() {
        for provider in LLMProvider.allCases {
            if let key = apiKeys[provider] {
                config.setAPIKey(key, for: provider)
            }
            if let modelID = modelIDs[provider] {
                config.setModelID(modelID, for: provider)
            }
        }
    }

    private func savePromptSettings() {
        for task in LLMTask.allCases {
            if let prompt = systemPrompts[task] {
                config.setSystemPrompt(prompt, for: task)
            }
        }
    }
}

#Preview {
    AISettingsView()
}
