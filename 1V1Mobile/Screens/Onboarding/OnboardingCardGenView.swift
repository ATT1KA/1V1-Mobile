import SwiftUI

struct OnboardingCardGenView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var isGenerating = false
    @State private var generatedCard: UserCard?
    @State private var showCardPreview = false
    @State private var generationTimer: Timer?
    @State private var timeRemaining = 60
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Text("Generate Your Player Card")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Create a unique card that represents your gaming style")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if let card = generatedCard {
                    // Card Preview
                    VStack(spacing: 20) {
                        Text("Your Generated Card")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        PlayerCardView(card: card)
                            .frame(height: 200)
                            .padding(.horizontal)
                        
                        Button("Regenerate Card") {
                            generateCard()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                } else {
                    // Card Generation Options
                    VStack(spacing: 24) {
                        // Card Name
                        VStack(spacing: 16) {
                            Text("Card Name (Optional)")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TextField("Enter a custom name for your card", text: $coordinator.onboardingData.cardName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                        }
                        .padding(.horizontal)
                        
                        // Card Description
                        VStack(spacing: 16) {
                            Text("Card Description (Optional)")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TextField("Describe your gaming style", text: $coordinator.onboardingData.cardDescription, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                        }
                        .padding(.horizontal)
                        
                        // Rarity Selection
                        VStack(spacing: 16) {
                            Text("Card Rarity")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                ForEach(CardRarity.allCases, id: \.self) { rarity in
                                    Button(action: {
                                        coordinator.onboardingData.selectedRarity = rarity
                                    }) {
                                        VStack(spacing: 8) {
                                            Text(rarity.displayName)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            
                                            Text("Power: \(rarity.power)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(coordinator.onboardingData.selectedRarity == rarity ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(coordinator.onboardingData.selectedRarity == rarity ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Generate Button
                        Button(action: generateCard) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                
                                Text("Generate Card")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isGenerating)
                        .padding(.horizontal)
                        
                        // Timer Display (if generating)
                        if isGenerating {
                            VStack(spacing: 8) {
                                Text("Generating your card...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("\(timeRemaining)s remaining")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                
                // Complete Button (only show if card is generated)
                if generatedCard != nil {
                    Button(action: {
                        coordinator.onboardingData.hasGeneratedCard = true
                    }) {
                        HStack {
                            Text("Complete Onboarding")
                                .fontWeight(.semibold)
                            
                            Image(systemName: "checkmark")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .onDisappear {
            stopTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            stopTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            stopTimer()
        }
    }
    
    private func generateCard() {
        isGenerating = true
        timeRemaining = 60
        startTimer()
        
        // Simulate card generation with a delay (under 60 seconds)
        let generationTime = Double.random(in: 2.0...5.0) // Random time between 2-5 seconds
        
        DispatchQueue.main.asyncAfter(deadline: .now() + generationTime) {
            let cardData = coordinator.onboardingData.generateCardData()
            
            generatedCard = UserCard(
                id: UUID().uuidString,
                userId: coordinator.onboardingData.username,
                cardName: cardData.name,
                cardDescription: cardData.description,
                rarity: cardData.rarity,
                power: cardData.rarity.power + Int.random(in: 0...20)
            )
            
            isGenerating = false
            stopTimer()
        }
    }
    
    private func startTimer() {
        generationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                stopTimer()
                isGenerating = false
            }
        }
    }
    
    private func stopTimer() {
        generationTimer?.invalidate()
        generationTimer = nil
    }
}

// MARK: - Player Card View

struct PlayerCardView: View {
    let card: UserCard
    
    var body: some View {
        VStack(spacing: 0) {
            // Card Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.cardName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(card.rarity.displayName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("POWER")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("\(card.power)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: card.rarity.color),
                        Color(hex: card.rarity.color).opacity(0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Card Body
            VStack(alignment: .leading, spacing: 12) {
                Text("Description")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(card.cardDescription)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Card Footer
                HStack {
                    Text("1V1 Mobile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("ID: \(String(card.id.prefix(8)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
