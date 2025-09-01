import SwiftUI

struct MatchStartConfirmationView: View {
    let duel: Duel
    let opponentDisplayName: String?
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var titleText: String { "Start Match" }

    private var bodyMessage: String {
        var parts: [String] = []
        parts.append("\(duel.gameType) - \(duel.gameMode)")

        if let opponent = opponentDisplayName, !opponent.isEmpty {
            parts.append("vs \(opponent)")
        } else {
            parts.append("vs Opponent")
        }

        if let msg = duel.challengeMessage, !msg.isEmpty {
            parts.append("\"\(msg)\"")
        }

        parts.append("\nAre you ready to begin?")
        return parts.joined(separator: "\n")
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e"), Color(hex: "#0f3460")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(titleText)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(bodyMessage)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button("Start Match") {
                            dismiss()
                            onConfirm()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MatchStartConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        MatchStartConfirmationView(duel: Duel(id: "test", challengerId: "a", opponentId: "b", gameType: "Game", gameMode: "Mode", status: .accepted, createdAt: Date(), expiresAt: Date()), opponentDisplayName: "Opponent") {
            // preview action
        }
        .preferredColorScheme(.dark)
    }
}


