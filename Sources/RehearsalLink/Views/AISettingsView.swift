import SwiftUI

struct AISettingsView: View {
    @ObservedObject private var config = LLMConfigurationService.shared
    @State private var apiKeys: [LLMProvider: String] = [:]
    @State private var modelIDs: [LLMProvider: String] = [:]

    var body: some View {
        TabView {
            aiSettingsTab
                .tabItem {
                    Label("AI Services", systemImage: "brain.head.profile")
                }
        }
        .frame(width: 500, height: 520)
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
                    Button("Save All Settings") {
                        saveSettings()
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
        .formStyle(.columns) // macOS標準の「左ラベル・右コントロール」形式
        .padding(24) // コンテンツ周囲に適切な余白を確保
    }

    private func loadSettings() {
        for provider in LLMProvider.allCases {
            apiKeys[provider] = config.getAPIKey(for: provider)
            modelIDs[provider] = config.getModelID(for: provider)
        }
    }

    private func saveSettings() {
        for provider in LLMProvider.allCases {
            if let key = apiKeys[provider] {
                config.setAPIKey(key, for: provider)
            }
            if let modelID = modelIDs[provider] {
                config.setModelID(modelID, for: provider)
            }
        }
    }

    private func defaultSuggestion(for provider: LLMProvider) -> String {
        switch provider {
        case .openai: return "gpt-4o-mini"
        case .anthropic: return "claude-3-5-sonnet-latest"
        case .gemini: return "gemini-2.0-flash-exp"
        }
    }
}

#Preview {
    AISettingsView()
}
