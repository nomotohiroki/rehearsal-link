import SwiftUI

struct AISettingsView: View {
    @ObservedObject private var config = LLMConfigurationService.shared
    @State private var apiKeys: [LLMProvider: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Active Provider", selection: $config.selectedProvider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Default Model", selection: $config.selectedModelId) {
                        ForEach(LLMModel.allModels.filter { $0.provider == config.selectedProvider }) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Label("AI Provider Settings", systemImage: "cpu")
                }

                Section {
                    ForEach(LLMProvider.allCases) { provider in
                        HStack {
                            Text(provider.rawValue)
                                .frame(width: 100, alignment: .leading)
                            SecureField("API Key", text: Binding(
                                get: { apiKeys[provider] ?? "" },
                                set: { apiKeys[provider] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Save API Keys") {
                            for (provider, key) in apiKeys {
                                config.setAPIKey(key, for: provider)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 8)
                } header: {
                    Label("API Keys", systemImage: "key.fill")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("About AI Features", systemImage: "info.circle")
                            .font(.headline)
                        Text("API keys are used to communicate with LLM providers for text normalization and summarization.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Your keys are stored locally in your app's preferences.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 400)
        .onAppear {
            for provider in LLMProvider.allCases {
                apiKeys[provider] = config.getAPIKey(for: provider)
            }
        }
    }
}

#Preview {
    AISettingsView()
}
