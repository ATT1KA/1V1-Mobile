import SwiftUI

struct RedemptionSheetView: View {
    @StateObject private var redemptionService = RedemptionService.shared
    @StateObject private var pointsService = PointsService.shared
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Balance")) {
                    HStack {
                        Text("You have")
                        Spacer()
                        Text("\(pointsService.currentBalance) pts")
                    }
                }

                Section(header: Text("Rewards")) {
                    ForEach(redemptionService.availableRewards, id: \.id) { reward in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(reward.name)
                                Text(reward.description ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                if redemptionService.userUnlocks.contains(reward.id) {
                                    Text("Owned")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("\(reward.pointsCost)")
                                Button("Redeem") {
                                    Task {
                                        do {
                                            if let userId = AuthService.shared.currentUser?.id {
                                                try await redemptionService.redeemReward(userId: userId, rewardId: reward.id.uuidString)
                                                await pointsService.fetchUserBalance(userId: userId)
                                                // show simple success
                                            }
                                        } catch {
                                            print("Redeem error: \(error)")
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(redemptionService.userUnlocks.contains(reward.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Redeem Points")
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() })
            .task {
                await redemptionService.fetchAvailableRewards()
                if let userId = AuthService.shared.currentUser?.id {
                    await redemptionService.getUserUnlocks(userId: userId)
                }
            }
        }
    }
}

struct RedemptionSheetView_Previews: PreviewProvider {
    static var previews: some View {
        RedemptionSheetView()
    }
}


