import SwiftUI
import Combine

struct MatchEndConfirmationView: View {
    let duel: Duel
    let opponentDisplayName: String?
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var titleText: String { "End Match" }

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

        parts.append("⚠️ Important: After ending the match, you'll have exactly \(Constants.VerificationWindow.seconds) seconds to submit your scoreboard screenshot. Both players must submit within this time window or the match will be forfeited.")
        parts.append("📸 Have your scoreboard screenshot ready.")

        return parts.joined(separator: "\n")
    }

    @State private var secondsRemaining: Int = Constants.VerificationWindow.seconds
    private let timer = Timer.publish(every: 1, on: .main, in: .common)
    @State private var cancellable: Cancellable?
    @State private var timerActive: Bool = true

    private func formatSeconds(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    var body: some View {
        ConfirmationContainer {
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

                // Prominent countdown display
                VStack(spacing: 6) {
                    Text(formatSeconds(secondsRemaining))
                        .font(.title)
                        .fontWeight(.heavy)
                        .foregroundColor(.orange)

                    Text("Starts after you end the match")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))

                    Text("Verification window")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .onReceive(timer) { _ in
                    guard timerActive else { return }
                    if secondsRemaining > 0 {
                        secondsRemaining -= 1
                    }
                }
                .onAppear {
                    // reset whenever the view appears
                    secondsRemaining = Constants.VerificationWindow.seconds
                    timerActive = true
                    cancellable = timer.connect()
                }
                .onDisappear {
                    // pause timer when dismissed and cancel the publisher
                    timerActive = false
                    cancellable?.cancel()
                }

                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(role: .destructive) {
                        dismiss()
                        onConfirm()
                    } label: {
                        Text("End Match")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .tint(.red)
                }
            }
        }
    }
}

struct MatchEndConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        MatchEndConfirmationView(duel: Duel(
            id: "test",
            challengerId: "a",
            opponentId: "b",
            gameType: "Game",
            gameMode: "Mode",
            status: .inProgress,
            createdAt: Date(),
            acceptedAt: nil,
            startedAt: nil,
            endedAt: nil,
            winnerId: nil,
            loserId: nil,
            challengerScore: nil,
            opponentScore: nil,
            verificationStatus: .pending,
            verificationMethod: nil,
            disputeStatus: nil,
            expiresAt: Date(),
            challengeMessage: nil
        ), opponentDisplayName: "Opponent") {
            // preview action
        }
        .preferredColorScheme(.dark)
    }
}


