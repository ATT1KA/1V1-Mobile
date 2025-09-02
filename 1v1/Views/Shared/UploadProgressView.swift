import SwiftUI

struct UploadProgressView: View {
    @Binding var progress: Double // 0.0 - 1.0
    var speedText: String? = nil
    var estimatedTimeRemaining: TimeInterval? = nil
    var fileSizeText: String? = nil
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(x: 1, y: 2)

            HStack {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)

                Spacer()

                if let speed = speedText {
                    Text(speed)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            if let eta = estimatedTimeRemaining {
                Text("ETA: \(formatTime(eta))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }

            if let fileInfo = fileSizeText {
                Text(fileInfo)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }

            if let onCancel = onCancel {
                Button(action: onCancel) {
                    Text("Cancel Upload")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && time > 0 else { return "--:--" }
        let secs = Int(time)
        let minutes = secs / 60
        let seconds = secs % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct UploadProgressView_Previews: PreviewProvider {
    static var previews: some View {
        UploadProgressView(progress: .constant(0.42), speedText: "120 KB/s", estimatedTimeRemaining: 8, fileSizeText: "1.2MB / 4.8MB")
            .preferredColorScheme(.dark)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}


