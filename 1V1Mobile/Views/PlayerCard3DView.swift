import SwiftUI
import UIKit
import CoreNFC

struct PlayerCard3DView: View {
    let user: User
    @ObservedObject var profileService: UserProfileService
    @EnvironmentObject var authService: AuthService
    
    @State private var dragOffset = CGSize.zero
    @State private var rotationXY: (x: Double, y: Double) = (0, 0)
    @State private var isEditing = false
    @State private var editedUsername: String = ""
    @State private var showingImagePicker = false
    @State private var pendingImage: UIImage?
    @State private var showingQRCode = false
    @State private var showingNFCScanner = false
    @State private var showingQRScanner = false
    @State private var scannedCode: String?
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingOnlineSharing = false
    
    // Services
    @StateObject private var nfcService = NFCService()
    @StateObject private var qrService = QRCodeService()
    
    // 3D effect parameters
    private let maxRotation: Double = 15
    private let maxOffset: CGFloat = 20
    private let animationDuration: Double = 0.3
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#1a1a2e"),
                        Color(hex: "#16213e"),
                        Color(hex: "#0f3460")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Card content
                PlayerCardContent(
                    user: user,
                    profileService: profileService,
                    isEditing: $isEditing,
                    editedUsername: $editedUsername,
                    showingImagePicker: $showingImagePicker,
                    showingQRCode: $showingQRCode,
                    showingNFCScanner: $showingNFCScanner,
                    showingQRScanner: $showingQRScanner,
                    nfcService: nfcService,
                    qrService: qrService
                )
                .padding(20)
            }
            .frame(height: 400)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .rotation3DEffect(
                .degrees(rotationXY.x),
                axis: (x: 1, y: 0, z: 0)
            )
            .rotation3DEffect(
                .degrees(rotationXY.y),
                axis: (x: 0, y: 1, z: 0)
            )
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation
                        let progressX = translation.x / 100
                        let progressY = translation.y / 100
                        
                        rotationXY.y = Double(progressX * maxRotation)
                        rotationXY.x = Double(-progressY * maxRotation)
                        
                        dragOffset = CGSize(
                            width: translation.x * 0.1,
                            height: translation.y * 0.1
                        )
                        
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: animationDuration)) {
                            rotationXY = (0, 0)
                            dragOffset = .zero
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isEditing.toggle()
                    if isEditing {
                        editedUsername = user.username ?? ""
                    }
                }
            }
            .overlay(
                Group {
                    if profileService.isLoading {
                        Color.black.opacity(0.3)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            )
                    }
                }
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $pendingImage)
        }
        .sheet(isPresented: $showingQRCode) {
            QRCodeDisplayView(qrService: qrService, user: user, profileService: profileService)
        }
        .sheet(isPresented: $showingNFCScanner) {
            NFCScannerView(nfcService: nfcService)
        }
        .sheet(isPresented: $showingQRScanner) {
            QRCodeScannerView(scannedCode: $scannedCode, isScanning: $showingQRScanner)
        }
        .sheet(isPresented: $showingOnlineSharing) {
            OnlineSharingView(profile: UserProfile(
                from: user,
                stats: profileService.userStats,
                card: profileService.userCard,
                achievements: profileService.achievements
            ))
        }
        .onChange(of: pendingImage) { newImage in
            if let image = newImage {
                Task {
                    await saveProfileImage(image)
                }
            }
        }
        .onChange(of: scannedCode) { code in
            if let code = code {
                // Process scanned QR code properly
                qrService.processScannedCode(code)
                scannedCode = nil
            }
        }
        .onChange(of: nfcService.errorMessage) { error in
            if let error = error {
                errorMessage = error
                showingErrorAlert = true
            }
        }
        .onChange(of: qrService.errorMessage) { error in
            if let error = error {
                errorMessage = error
                showingErrorAlert = true
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveProfileImage(_ image: UIImage) async {
        let success = await authService.updateProfileImage(image)
        if success {
            // Refresh profile data
            await profileService.syncUserData()
        }
        pendingImage = nil
    }
    
    private func shareProfileViaNFC() async {
        let profile = UserProfile(
            from: user,
            stats: profileService.userStats,
            card: profileService.userCard,
            achievements: profileService.achievements
        )
        
        await nfcService.shareProfile(profile)
    }
}

// MARK: - Card Content
private struct PlayerCardContent: View {
    let user: User
    @ObservedObject var profileService: UserProfileService
    @Binding var isEditing: Bool
    @Binding var editedUsername: String
    @Binding var showingImagePicker: Bool
    @Binding var showingQRCode: Bool
    @Binding var showingNFCScanner: Bool
    @Binding var showingQRScanner: Bool
    @ObservedObject var nfcService: NFCService
    @ObservedObject var qrService: QRCodeService
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with avatar and name
            HStack(spacing: 16) {
                // Profile Image with QR Code Toggle and Image Editing
                Button(action: {
                    showingQRCode.toggle()
                }) {
                    if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .onLongPressGesture {
                    showingImagePicker = true
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .overlay(
                    // QR Code indicator
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "qrcode")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    if isEditing {
                        TextField("Username", text: $editedUsername)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                Task {
                                    await saveUsername()
                                }
                            }
                    } else {
                        Text(user.username ?? "Player")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    if let stats = profileService.userStats {
                        Text(stats.rank ?? "Bronze")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color(hex: "#FFD700"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#FFD700").opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            
            // Stats Grid
            if let stats = profileService.userStats {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatTile(title: "Wins", value: "\(stats.wins)", color: .green)
                    StatTile(title: "Losses", value: "\(stats.losses)", color: .red)
                    StatTile(title: "Win Rate", value: "\(Int(stats.winRate * 100))%", color: .blue)
                    StatTile(title: "Games", value: "\(stats.totalGames)", color: .orange)
                    StatTile(title: "Best Score", value: "\(stats.bestScore)", color: .purple)
                    StatTile(title: "Play Time", value: "\(stats.totalPlayTime/60)h", color: .cyan)
                }
            }
            
            // Achievements/Trophies
            if !profileService.achievements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Achievements")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(profileService.achievements.prefix(5)) { achievement in
                                TrophyBadge(achievement: achievement)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            
            // Sharing Buttons
            HStack(spacing: 16) {
                // Online Share Button
                Button(action: {
                    showingOnlineSharing = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                        Text("Share Online")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.3))
                    .cornerRadius(8)
                }
                
                // NFC Share Button
                Button(action: {
                    Task {
                        await shareProfileViaNFC()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "wave.3.right")
                            .font(.caption)
                        Text("NFC Share")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(8)
                }
                
                // QR Scan Button
                Button(action: {
                    showingQRScanner = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.caption)
                        Text("Scan QR")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.3))
                    .cornerRadius(8)
                }
                
                // NFC Scan Button
                Button(action: {
                    showingNFCScanner = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "wave.3.left")
                            .font(.caption)
                        Text("NFC Scan")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
    }
    
    private func saveUsername() async {
        if let userId = user.id {
            let success = await profileService.updateDisplayName(editedUsername, userId: userId)
            if success {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isEditing = false
                }
            }
        }
    }
    
    private func shareProfileViaNFC() async {
        let profile = UserProfile(
            from: user,
            stats: profileService.userStats,
            card: profileService.userCard,
            achievements: profileService.achievements
        )
        
        await nfcService.shareProfile(profile)
    }
}

// MARK: - Supporting Components
private struct StatTile: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}

private struct TrophyBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: achievement.icon ?? "trophy.fill")
                .font(.title2)
                .foregroundColor(Color(hex: "#FFD700"))
            
            Text(achievement.title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(width: 60, height: 60)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Image Picker
private struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - QR Code Display View
struct QRCodeDisplayView: View {
    @ObservedObject var qrService: QRCodeService
    let user: User
    @ObservedObject var profileService: UserProfileService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let qrImage = qrService.generatedQRImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 250, maxHeight: 250)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                } else {
                    ProgressView("Generating QR Code...")
                        .frame(maxWidth: 250, maxHeight: 250)
                }
                
                VStack(spacing: 8) {
                    Text("Share Your Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tap the QR code to share it with friends")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .onAppear {
                let profile = UserProfile(
                    from: user,
                    stats: profileService.userStats,
                    card: profileService.userCard,
                    achievements: profileService.achievements
                )
                qrService.generateQRCode(for: profile)
            }
        }
    }
}

// MARK: - NFC Scanner View
struct NFCScannerView: View {
    @ObservedObject var nfcService: NFCService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if nfcService.isScanning {
                    VStack(spacing: 16) {
                        Image(systemName: "wave.3.left")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: nfcService.isScanning)
                        
                        Text("Scanning for NFC Tags...")
                            .font(.headline)
                        
                        Text("Hold your device near an NFC tag to scan a profile")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else if let profile = nfcService.lastScannedProfile {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Profile Found!")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name: \(profile.displayName)")
                            Text("Games: \(profile.totalGames)")
                            Text("Win Rate: \(Int(profile.winRate * 100))%")
                            Text("Rank: \(profile.rank)")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                if let errorMessage = nfcService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("NFC Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Scan") { nfcService.startScanning() }
            )
            .onAppear {
                nfcService.startScanning()
            }
            .onDisappear {
                nfcService.stopScanning()
            }
        }
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
