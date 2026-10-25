//
//  GeneralSettingsPane.swift
//  WritingTools
//
//  Created by Arya Mirsepasi on 04.11.25.
//

import SwiftUI
import KeyboardShortcuts
import AppKit

struct GeneralSettingsPane<SaveButton: View>: View {
    @Bindable var appState: AppState
    @Bindable var settings = AppSettings.shared
    @Binding var needsSaving: Bool
    @Binding var showingCommandsManager: Bool
    var showOnlyApiSetup: Bool
    let saveButton: SaveButton

    @State private var isCustomExplanationLanguage = false

    /// Preset explanation languages; "" follows the app's interface language.
    // Computed: generic types can't have static stored properties.
    private static var explanationLanguagePresets: [String] {
        ["", "Simplified Chinese", "Traditional Chinese", "English"]
    }
    private static var customLanguageTag: String { "__custom__" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General Settings")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            ViewThatFits(in: .vertical) {
                generalContent
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    generalContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if !showOnlyApiSetup {
                saveButton
            }
        }
        .sheet(isPresented: $showingCommandsManager) {
            CommandsView(commandManager: appState.commandManager)
        }
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Keyboard Shortcuts") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Set a global shortcut to quickly activate Writing Tools.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .center, spacing: 12) {
                        Text("Activate Writing Tools:")
                            .frame(width: 180, alignment: .leading)
                            .foregroundStyle(.primary)
                        KeyboardShortcuts.Recorder(
                            for: .showPopup,
                            onChange: { _ in
                                needsSaving = true
                            }
                        )
                        .accessibilityLabel("Activate Writing Tools shortcut")
                        .accessibilityHint("Sets the global shortcut to open Writing Tools.")
                        .help("Choose a convenient key combination to bring up Writing Tools from anywhere.")
                    }
                    .padding(.vertical, 2)
                }
            }

            GroupBox("Commands") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Manage your writing tools and assign keyboard shortcuts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button(action: {
                        showingCommandsManager = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet.rectangle")
                            Text("Manage Commands")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color(.controlBackgroundColor))
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Manage Commands")
                    .accessibilityHint("Open the Commands Manager to add, edit, or remove commands.")
                    .help("Open the Commands Manager to add, edit, or remove commands.")

                    Toggle(isOn: $settings.openCustomCommandsInResponseWindow) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Open custom prompts in response window")
                            Text("When unchecked, custom prompts will replace selected text inline")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .accessibilityLabel("Open custom prompts in response window")
                    .accessibilityHint("When off, custom prompts replace selected text inline.")
                    .onChange(of: settings.openCustomCommandsInResponseWindow) { _, _ in
                        needsSaving = true
                    }
                    .help("Choose whether custom prompts open in a separate response window or replace text inline.")

                    Toggle(isOn: $settings.enableICloudCommandSync) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Sync commands with iCloud")
                            Text("Keep your command list in sync across your signed-in Apple devices.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: settings.enableICloudCommandSync) { _, _ in
                        needsSaving = true
                    }
                    .help("Uses iCloud key-value storage to sync command edits across devices.")
                }
            }

            GroupBox("Review Mode") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Commands set to \"Review changes first\" show edits as a word-level diff. If a command also explains edits on request, explanations use this language.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .center, spacing: 12) {
                        Text("Explanation language:")
                            .frame(width: 180, alignment: .leading)
                        Picker("", selection: explanationLanguageSelection) {
                            Text("Follow app language").tag("")
                            Text("Simplified Chinese").tag("Simplified Chinese")
                            Text("Traditional Chinese").tag("Traditional Chinese")
                            Text("English").tag("English")
                            Text("Other…").tag(Self.customLanguageTag)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 220)
                        .accessibilityLabel("Explanation language")
                    }

                    if showsCustomLanguageField {
                        HStack(alignment: .center, spacing: 12) {
                            Text("Language name:")
                                .frame(width: 180, alignment: .leading)
                            TextField("e.g. Japanese", text: $settings.explanationLanguage)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                                .onChange(of: settings.explanationLanguage) { _, _ in
                                    needsSaving = true
                                }
                        }
                    }
                }
            }

            GroupBox("Onboarding") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You can rerun the onboarding flow to review permissions and quickly configure the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button {
                            restartOnboarding()
                        } label: {
                            Label("Restart Onboarding", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Restart onboarding")
                        .accessibilityHint("Open the onboarding window to review permissions and setup.")
                        .help("Open the onboarding window to set up WritingTools again.")

                        Spacer()
                    }
                }
            }
        }
    }

    private var showsCustomLanguageField: Bool {
        isCustomExplanationLanguage
            || !Self.explanationLanguagePresets.contains(settings.explanationLanguage)
    }

    private var explanationLanguageSelection: Binding<String> {
        Binding(
            get: {
                showsCustomLanguageField ? Self.customLanguageTag : settings.explanationLanguage
            },
            set: { newValue in
                if newValue == Self.customLanguageTag {
                    isCustomExplanationLanguage = true
                } else {
                    isCustomExplanationLanguage = false
                    settings.explanationLanguage = newValue
                }
                needsSaving = true
            }
        )
    }

    private func restartOnboarding() {
        // Mark onboarding as not completed
        settings.hasCompletedOnboarding = false
        WindowManager.shared.showOnboarding(appState: appState, title: "Onboarding")
        NSApp.keyWindow?.close()
        WindowManager.shared.closeSettingsWindow()
    }
}
