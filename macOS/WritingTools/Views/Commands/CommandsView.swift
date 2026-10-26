import SwiftUI
import Observation

struct CommandsView: View {
    @Bindable var commandManager: CommandManager
    @Bindable private var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isAddingNew = false
    @State private var editingCommand: CommandModel?
    @State private var newCommand = CommandModel(name: "", prompt: "", icon: "text.bubble")
    @State private var showingResetAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with enhanced styling
            HStack {
                Text("Manage Commands")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close")
                .accessibilityLabel("Close commands manager")
                .accessibilityHint("Dismiss the commands window")
            }
            .padding()
            
            // Command list with section header
            VStack(alignment: .leading, spacing: 8) {
                Text("Checked commands appear in the popup. Drag to change their order.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)

                commandsListView
            }

            Divider()

            // Action buttons with enhanced styling
            HStack {
                Button(action: { isAddingNew = true }) {
                    Label("Add Custom Command", systemImage: "plus.circle.fill")
                        .font(.body)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer()

                Button(action: { showingResetAlert = true }) {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Reset all built-in commands to their original state, including restoring any that were deleted")
            }
            .padding()
        }
        .frame(minWidth: 520, idealWidth: 600, maxWidth: 840, minHeight: 420, idealHeight: 500, maxHeight: 820)
        .windowBackground(useGradient: settings.useGradientTheme)
        .sheet(isPresented: $isAddingNew) {
            CommandEditor(
                command: $newCommand,
                onSave: {
                    commandManager.addCommand(newCommand)
                    newCommand = CommandModel(name: "", prompt: "", icon: "text.bubble")
                    isAddingNew = false
                },
                onCancel: {
                    newCommand = CommandModel(name: "", prompt: "", icon: "text.bubble")
                    isAddingNew = false
                },
                commandManager: commandManager
            )
            // Force SwiftUI to recreate CommandEditor each time the sheet opens,
            // preventing stale @State values from a previous session.
            .id(newCommand.id)
        }
        .sheet(item: $editingCommand) { command in
            EditCommandSheet(
                original: command,
                commandManager: commandManager,
                onDismiss: { editingCommand = nil }
            )
        }
        .alert("Reset Built-in Commands", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                commandManager.resetToDefaults()
            }
        } message: {
            Text("This will reset all built-in commands to their original settings, restore any deleted built-in commands, and keep your custom commands. This action cannot be undone.")
        }
    }
    
    var commandsListView: some View {
        List {
            ForEach(commandManager.commands) { command in
                CommandRow(
                    command: command,
                    onToggleVisibility: { isShown in
                        commandManager.setHidden(!isShown, for: command)
                    },
                    onEdit: { command in editingCommand = command },
                    onDelete: { command in commandManager.deleteCommand(command) }
                )
            }
            .onMove { source, destination in
                commandManager.moveCommand(fromOffsets: source, toOffset: destination)
            }
        }
        .listStyle(.inset)
        .overlay(
            Group {
                if commandManager.commands.isEmpty {
                    VStack {
                        Image(systemName: "plus.circle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No commands")
                            .foregroundStyle(.secondary)
                        Text("Add one, or reset to the defaults")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        )
    }
}

struct CommandRow: View {
    let command: CommandModel
    let onToggleVisibility: (Bool) -> Void
    let onEdit: (CommandModel) -> Void
    let onDelete: (CommandModel) -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 16) {
            Toggle(
                "Show in popup",
                isOn: Binding(
                    get: { !command.isHidden },
                    set: { onToggleVisibility($0) }
                )
            )
            .toggleStyle(.checkbox)
            .labelsHidden()
            .help(command.isHidden
                  ? "Hidden from the popup. Its keyboard shortcut still works."
                  : "Shown in the popup")
            .accessibilityLabel("Show \(command.name) in popup")

            // Icon with consistent size and styling
            Image(systemName: command.icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(command.name)
                    .font(.headline)
                    .foregroundStyle(command.isHidden ? .secondary : .primary)
                
                Text(command.isBuiltIn ? "Built-in" : "Custom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(command.isBuiltIn ?
                                  Color.blue.opacity(0.2) :
                                  Color.green.opacity(0.2))
                    )
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { onEdit(command) }) {
                    Image(systemName: "pencil")
                        .font(.body)
                        .foregroundStyle(.blue)
                        .frame(width: 28, height: 28)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(.circle)
                }
                .buttonStyle(.plain)
                .help("Edit command")
                .accessibilityLabel("Edit \(command.name)")
                .accessibilityHint("Open editor for this command")
                
                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(Color.red.opacity(0.1))
                        .clipShape(.circle)
                }
                .buttonStyle(.plain)
                .help("Delete command")
                .accessibilityLabel("Delete \(command.name)")
                .accessibilityHint("Remove this command")
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .alert("Delete Command", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete(command)
            }
        } message: {
            Text("Are you sure you want to delete \"\(command.name)\"? This action cannot be undone.")
        }
    }
}

/// Wrapper view that owns a mutable @State copy of the command being edited,
/// so the Binding round-trip works correctly inside CommandEditor.
private struct EditCommandSheet: View {
    let original: CommandModel
    let commandManager: CommandManager
    let onDismiss: () -> Void

    @State private var commandCopy: CommandModel

    init(original: CommandModel, commandManager: CommandManager, onDismiss: @escaping () -> Void) {
        self.original = original
        self.commandManager = commandManager
        self.onDismiss = onDismiss
        _commandCopy = State(initialValue: original)
    }

    var body: some View {
        CommandEditor(
            command: $commandCopy,
            onSave: {
                commandManager.updateCommand(commandCopy)
                onDismiss()
            },
            onCancel: {
                onDismiss()
            },
            commandManager: commandManager
        )
    }
}

#Preview {
    CommandsView(commandManager: CommandManager())
}
