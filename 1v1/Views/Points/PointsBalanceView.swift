import SwiftUI

struct PointsBalanceView: View {
    @StateObject private var pointsService = PointsService.shared
    @State private var showingRedemption = false

    var body: some View {
        HStack {
            Image(systemName: "gift.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundColor(.yellow)
            VStack(alignment: .leading) {
                Text("Points")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(pointsService.currentBalance)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Spacer()
            Button(action: { showingRedemption = true }) {
                Text("Redeem")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingRedemption) {
            RedemptionSheetView()
        }
        .task {
            if let userId = AuthService.shared.currentUser?.id {
                await pointsService.start(for: userId)
            }
        }
    }
}

struct PointsBalanceView_Previews: PreviewProvider {
    static var previews: some View {
        PointsBalanceView()
    }
}


