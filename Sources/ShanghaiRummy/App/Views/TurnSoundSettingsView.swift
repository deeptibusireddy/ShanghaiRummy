import SwiftUI

struct TurnSoundSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TurnSoundPreferences.enabledKey)
    private var soundsEnabled = true
    @AppStorage(TurnSoundPreferences.selectedSoundKey)
    private var selectedSoundRawValue =
        TurnNotificationSound.classic.rawValue
    @State private var isShowingPlaybackError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $soundsEnabled) {
                        Label(
                            "Turn Sounds",
                            systemImage: soundsEnabled
                                ? "speaker.wave.2.fill"
                                : "speaker.slash.fill"
                        )
                    }
                    .accessibilityIdentifier("turn-sounds-enabled")
                } footer: {
                    Text(
                        "Turn alerts still use a short haptic when sound is "
                            + "off."
                    )
                }

                Section {
                    ForEach(TurnNotificationSound.allCases) { sound in
                        Button {
                            selectedSoundRawValue = sound.rawValue
                            preview(sound)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: sound.symbolName)
                                    .font(.title3)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(sound.displayName)
                                        .font(.headline)
                                    Text(sound.detail)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedSound == sound {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }

                                Image(systemName: "play.fill")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(sound.displayName). \(sound.detail). "
                                + "Select and preview."
                        )
                        .accessibilityIdentifier(
                            "turn-sound-\(sound.rawValue)"
                        )
                    }
                } header: {
                    Text("Notification Tone")
                } footer: {
                    Text(
                        "Tap any tone to select and preview it. Previewing "
                            + "still works while turn sounds are switched off."
                    )
                }
            }
            .navigationTitle("Turn Sounds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("close-turn-sound-settings")
                }
            }
        }
        .accessibilityIdentifier("turn-sound-settings-view")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: soundsEnabled) { _, isEnabled in
            if isEnabled {
                preview(selectedSound)
            }
        }
        .alert(
            "Sound Unavailable",
            isPresented: $isShowingPlaybackError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "The selected notification tone could not be played. "
                    + "Please try another tone."
            )
        }
    }

    private var selectedSound: TurnNotificationSound {
        TurnNotificationSound(rawValue: selectedSoundRawValue)
            ?? .classic
    }

    private func preview(_ sound: TurnNotificationSound) {
        if !TurnSoundPlayer.shared.play(sound) {
            isShowingPlaybackError = true
        }
    }
}
