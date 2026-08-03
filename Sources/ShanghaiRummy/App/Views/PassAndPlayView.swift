import SwiftUI

/// Between-turn privacy interstitial for hot-seat mode. Hides the game so the
/// outgoing player's hand isn't visible when the next player takes the device.
struct PassAndPlayView: View {
    let nextPlayerName: String
    let onReady: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Pass the device")
                .font(.title.bold())
            Text("Hand to **\(nextPlayerName)**")
                .font(.title2)
                .multilineTextAlignment(.center)
            Text("Everyone else, look away!")
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                onReady()
            } label: {
                Text("I'm \(nextPlayerName) — ready")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    PassAndPlayView(nextPlayerName: "Alice") {}
}
