// Moved out of app target to avoid duplicate-basenames build collision.
// This file was removed from the app target; keep here for reference.
import SwiftUI
import AVFoundation

/// A SwiftUI view that presents the camera and scans QR codes.
struct QRCodeScannerView: View {
    @Binding var scannedCode: String?
    @Binding var isScanning: Bool

    @State private var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        ZStack {
            Group {
                switch authorizationStatus {
                case .authorized:
                    CameraPreviewView { code in
                        // When a code is found, assign and stop scanning
                        DispatchQueue.main.async {
                            self.scannedCode = code
                            self.isScanning = false
                        }
                        // Process via shared QRCodeService
                        QRCodeService.shared.processScannedCode(code)
                    }
                case .notDetermined:
                    Text("Requesting camera access...")
                        .onAppear { requestPermission() }
                case .denied, .restricted:
                    VStack(spacing: 12) {
                        Text("Camera access is required to scan QR codes.")
                            .multilineTextAlignment(.center)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    .padding()
                @unknown default:
                    Text("Camera unavailable")
                }
            }

            // Overlay: viewfinder
            VStack {
                Spacer()
                HStack { Spacer() }
            }
            .overlay(
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height) * 0.6
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.9), lineWidth: 3)
                        .frame(width: side, height: side)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            )

            // Close button in top-right
            VStack {
                HStack {
                    Spacer()
                    Button(action: { isScanning = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }

    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }
}

// MARK: - Camera Preview UIViewControllerRepresentable
fileprivate struct CameraPreviewView: UIViewControllerRepresentable {
    typealias UIViewControllerType = ScannerViewController

    var onFoundCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onFoundCode = onFoundCode
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        // No-op
    }

    static func dismantleUIViewController(_ uiViewController: ScannerViewController, coordinator: ()) {
        uiViewController.stopSession()
    }
}

// MARK: - ScannerViewController
fileprivate class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onFoundCode: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSessionIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        guard let videoDevice = AVCaptureDevice.default(for: .video) else { return }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }

            let metadataOutput = AVCaptureMetadataOutput()
            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            }

            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.videoGravity = .resizeAspectFill
            if let layer = previewLayer {
                layer.frame = view.layer.bounds
                view.layer.addSublayer(layer)
            }

            session.startRunning()
            isConfigured = true
        } catch {
            print("Failed to configure camera: \(error)")
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = first.stringValue else { return }

        // Stop session before calling handler to prevent duplicates
        stopSession()
        onFoundCode?(stringValue)
    }

    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    deinit {
        stopSession()
    }
}

// MARK: - Previews
struct QRCodeScannerView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeScannerView(scannedCode: .constant(nil), isScanning: .constant(true))
    }
}




