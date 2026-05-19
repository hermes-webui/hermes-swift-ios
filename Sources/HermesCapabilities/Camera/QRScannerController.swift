import UIKit
import AVFoundation
import HermesCore

/// UIViewController that runs an AVCaptureSession against the back camera and emits any QR string it detects.
/// Lifecycle:
///   - Configures the session lazily on `viewDidLoad`
///   - Starts the session on `viewWillAppear` (off-main per AVFoundation requirements)
///   - Stops on `viewWillDisappear`
/// Permission is assumed already granted by the caller — present this only after `CameraCapability.requestPermission()` returns `.granted`.
public final class QRScannerController: UIViewController {

    /// Called once per scan with the detected payload. Implementations should immediately stop scanning
    /// (via `pause()`) if a single result is sufficient — otherwise the same QR will fire repeatedly.
    public var onResult: ((String) -> Void)?

    /// Called when configuration fails (no camera, in-use, etc.).
    public var onError: ((Error) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let sessionQueue = DispatchQueue(label: "com.hermeswebui.qrscanner.session")
    private var configured = false
    private var paused = false

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        addReticle()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if !self.session.isRunning && !self.paused {
                self.session.startRunning()
            }
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    /// Stop emitting further `onResult` callbacks and pause the camera — call after the first successful scan
    /// when you want to dismiss the scanner before the user-visible transition completes.
    public func pause() {
        paused = true
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(QRScannerError.noCameraAvailable)
            }
            return
        }
        session.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(QRScannerError.metadataOutputUnavailable)
            }
            return
        }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)

        // Set object types AFTER adding to the session — AVFoundation populates availableMetadataObjectTypes
        // only once the output is attached.
        if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(QRScannerError.qrUnsupported)
            }
        }
    }

    private func addReticle() {
        let reticle = UIView()
        reticle.translatesAutoresizingMaskIntoConstraints = false
        reticle.layer.borderColor = UIColor.white.cgColor
        reticle.layer.borderWidth = 2
        reticle.layer.cornerRadius = 12
        view.addSubview(reticle)

        let hint = UILabel()
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.text = "Align the QR code from your Mac inside the frame"
        hint.textColor = .white
        hint.numberOfLines = 0
        hint.textAlignment = .center
        hint.font = .preferredFont(forTextStyle: .callout)
        view.addSubview(hint)

        NSLayoutConstraint.activate([
            reticle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            reticle.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            reticle.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
            reticle.heightAnchor.constraint(equalTo: reticle.widthAnchor),

            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            hint.topAnchor.constraint(equalTo: reticle.bottomAnchor, constant: 24),
        ])
    }
}

extension QRScannerController: AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput,
                               didOutput metadataObjects: [AVMetadataObject],
                               from connection: AVCaptureConnection) {
        guard !paused else { return }
        for obj in metadataObjects {
            if let readable = obj as? AVMetadataMachineReadableCodeObject,
               readable.type == .qr,
               let value = readable.stringValue {
                Loggers.capabilities.info("QR detected (\(value.count, privacy: .public) chars)")
                onResult?(value)
                return  // emit at most one result per delegate fire
            }
        }
    }
}

public enum QRScannerError: Error, LocalizedError {
    case noCameraAvailable
    case metadataOutputUnavailable
    case qrUnsupported

    public var errorDescription: String? {
        switch self {
        case .noCameraAvailable:        return "No camera is available on this device."
        case .metadataOutputUnavailable: return "This device cannot configure a QR metadata output."
        case .qrUnsupported:            return "This device does not support QR detection."
        }
    }
}
