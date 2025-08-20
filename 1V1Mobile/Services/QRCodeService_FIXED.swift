import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Supabase
import AVFoundation

@MainActor
class QRCodeService: ObservableObject {
    @Published var generatedQRImage: UIImage?
    @Published var scannedProfile: UserProfile?
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    private let context = CIContext()
    
    // MARK: - QR Code Generation
    func generateQRCode(for profile: UserProfile) {
        do {
            let profileData = try JSONEncoder().encode(profile)
            let profileString = String(data: profileData, encoding: .utf8) ?? ""
            
            // Validate QR code size (max ~3KB for reliable scanning)
            if profileString.count > 3000 {
                errorMessage = "Profile data too large for QR code. Consider using URL-based sharing."
                return
            }
            
            // Create QR code filter
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(profileString.utf8)
            filter.correctionLevel = "M" // Medium error correction
            
            guard let outputImage = filter.outputImage else {
                errorMessage = "Failed to generate QR code"
                return
            }
            
            // Scale the QR code for better quality
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            // Convert to UIImage
            guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
                errorMessage = "Failed to create QR code image"
                return
            }
            
            generatedQRImage = UIImage(cgImage: cgImage)
            errorMessage = nil
            
        } catch {
            errorMessage = "Error generating QR code: \(error.localizedDescription)"
        }
    }
    
    func generateQRCodeURL(for profile: UserProfile) {
        // Create a URL-based QR code for easier sharing
        let profileURL = "1v1mobile://profile/\(profile.userId)"
        
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(profileURL.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else {
            errorMessage = "Failed to generate QR code"
            return
        }
        
        // Scale the QR code for better quality
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        // Convert to UIImage
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            errorMessage = "Failed to create QR code image"
            return
        }
        
        generatedQRImage = UIImage(cgImage: cgImage)
        errorMessage = nil
    }
    
    // MARK: - QR Code Scanning
    func scanQRCode(from image: UIImage) {
        guard let ciImage = CIImage(image: image) else {
            errorMessage = "Invalid image for QR code scanning"
            return
        }
        
        // Create QR code detector
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        guard let features = detector?.features(in: ciImage) as? [CIQRCodeFeature] else {
            errorMessage = "No QR code found in image"
            return
        }
        
        guard let qrFeature = features.first,
              let messageString = qrFeature.messageString else {
            errorMessage = "Invalid QR code data"
            return
        }
        
        // Parse the QR code data
        processScannedCode(messageString)
    }
    
    // MARK: - QR Code Processing
    func processScannedCode(_ code: String) {
        // Clear previous errors
        errorMessage = nil
        
        // Try to parse as JSON profile data first
        if let jsonData = code.data(using: .utf8),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: jsonData) {
            scannedProfile = profile
            shareProfile(profile)
            return
        }
        
        // Try to parse as URL
        if let url = URL(string: code),
           url.scheme == "1v1mobile",
           url.host == "profile",
           let profileId = url.pathComponents.last {
            Task {
                await fetchProfileFromId(profileId)
            }
            return
        }
        
        errorMessage = "Invalid QR code format"
    }
    
    private func fetchProfileFromId(_ profileId: String) async {
        do {
            let response = try await supabaseService.client
                .from("profiles")
                .select("*")
                .eq("id", value: profileId)
                .single()
                .execute()
            
            if let data = response.data,
               let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
                await MainActor.run {
                    self.scannedProfile = profile
                    self.shareProfile(profile)
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Profile not found"
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch profile: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Profile Sharing
    func shareProfile(_ profile: UserProfile) {
        Task {
            do {
                // Log the sharing event to Supabase
                let shareData: [String: Any] = [
                    "user_id": profile.userId,
                    "shared_at": ISO8601DateFormatter().string(from: Date()),
                    "share_method": "qr_code",
                    "profile_data": try JSONEncoder().encode(profile)
                ]
                
                let response = try await supabaseService.client
                    .from("profile_shares")
                    .insert(shareData)
                    .execute()
                
                print("Profile share logged: \(response)")
            } catch {
                print("Error logging profile share: \(error)")
            }
        }
    }
    
    // MARK: - Utility Methods
    func clearQRCode() {
        generatedQRImage = nil
        errorMessage = nil
    }
    
    func clearScannedProfile() {
        scannedProfile = nil
        errorMessage = nil
    }
    
    // MARK: - QR Code Validation
    func isValidQRCode(_ data: String) -> Bool {
        // Check if it's a valid JSON profile
        if let jsonData = data.data(using: .utf8),
           let _ = try? JSONDecoder().decode(UserProfile.self, from: jsonData) {
            return true
        }
        
        // Check if it's a valid 1V1Mobile URL
        if let url = URL(string: data),
           url.scheme == "1v1mobile",
           url.host == "profile",
           !url.pathComponents.isEmpty {
            return true
        }
        
        return false
    }
}

// MARK: - QR Code Scanner View
struct QRCodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var isScanning: Bool
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let scanner = QRScannerViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QRScannerViewControllerDelegate {
        let parent: QRCodeScannerView
        
        init(_ parent: QRCodeScannerView) {
            self.parent = parent
        }
        
        func qrScannerViewController(_ controller: QRScannerViewController, didScanCode code: String) {
            parent.scannedCode = code
            parent.isScanning = false
            parent.dismiss()
        }
        
        func qrScannerViewControllerDidCancel(_ controller: QRScannerViewController) {
            parent.isScanning = false
            parent.dismiss()
        }
    }
}

// MARK: - QR Scanner View Controller
protocol QRScannerViewControllerDelegate: AnyObject {
    func qrScannerViewController(_ controller: QRScannerViewController, didScanCode code: String)
    func qrScannerViewControllerDidCancel(_ controller: QRScannerViewController)
}

class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerViewControllerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    private func setupCamera() {
        // Check camera permission first
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCaptureSession()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.failed()
                    }
                }
            }
        case .denied, .restricted:
            failed()
        @unknown default:
            failed()
        }
    }
    
    private func setupCaptureSession() {
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            failed()
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            failed()
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }
        
        self.captureSession = captureSession
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        
        // Add cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        cancelButton.layer.cornerRadius = 8
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func startScanning() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.startRunning()
        }
    }
    
    private func stopScanning() {
        captureSession?.stopRunning()
    }
    
    private func failed() {
        let alert = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        captureSession = nil
    }
    
    @objc private func cancelTapped() {
        delegate?.qrScannerViewControllerDidCancel(self)
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.qrScannerViewController(self, didScanCode: stringValue)
        }
    }
}
