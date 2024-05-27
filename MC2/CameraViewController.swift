import Foundation
import SwiftUI
import AVFoundation
import CoreML
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var permissionGranted = false
    private var captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var previewLayer = AVCaptureVideoPreviewLayer()
    var screenRect: CGRect! = nil
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    var ballDetectRequest: VNCoreMLRequest?
    var boundingBoxLayers = [CAShapeLayer]()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("view did appear")
    }
    
    func useCoreMLModel() {
        // Load the CoreML model
        guard let model = try? VNCoreMLModel(for: best_v2(configuration: MLModelConfiguration()).model) else {
            print("Failed to load CoreML model")
            return
        }
        
        // Create a request for the model
        ballDetectRequest = VNCoreMLRequest(model: model)
        ballDetectRequest!.imageCropAndScaleOption = .scaleFit
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("view did load")
        checkPermission()
        
        sessionQueue.async { [unowned self] in
            guard self.permissionGranted else { return }
            self.setupCaptureSession()
            print("Session running")
        }
        
        useCoreMLModel()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
            // Handle the case where permission is denied
            DispatchQueue.main.async {
                self.showPermissionDeniedAlert()
            }
        }
    }
    
    func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    func showPermissionDeniedAlert() {
        let alert = UIAlertController(title: "Camera Permission Denied", message: "Please enable camera access in settings to use this feature.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func setupCaptureSession() {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            print("\(currentCameraPosition == .front ? "Front" : "Back") camera not available.")
            return
        }
        
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Could not create video device input.")
            return
        }
        
        captureSession.inputs.forEach { input in
            captureSession.removeInput(input)
        }
        
        guard captureSession.canAddInput(videoDeviceInput) else {
            print("Could not add video device input to the session.")
            return
        }
        captureSession.addInput(videoDeviceInput)
        
        screenRect = UIScreen.main.bounds
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        previewLayer.videoGravity = .resizeAspectFill
        
        if currentCameraPosition == .front {
            previewLayer.connection?.videoOrientation = .landscapeLeft
        } else {
            previewLayer.connection?.videoOrientation = .landscapeRight
        }
        
        let dataOutput = AVCaptureVideoDataOutput()
        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
            // Add a video data output
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        }
        
        let captureConnection = dataOutput.connection(with: .video)
        captureConnection?.preferredVideoStabilizationMode = .standard
        // Always process the frames
        captureConnection?.isEnabled = true
        captureSession.commitConfiguration()
                
        captureSession.startRunning()
        
        DispatchQueue.main.async { [weak self] in
            self?.view.layer.sublayers?.removeAll(where: { $0 is AVCaptureVideoPreviewLayer })
            if let previewLayer = self?.previewLayer {
                self?.view.layer.addSublayer(previewLayer)
            }
        }
    }
    
    func switchCamera() {
        sessionQueue.async { [unowned self] in
            self.currentCameraPosition = (self.currentCameraPosition == .back) ? .front : .back
            self.setupCaptureSession()
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("handle image")
        
        guard let ballDetectRequest = ballDetectRequest else {
            print("ball detect not yet running")
            return
        }
        
        do {
            let visionHandler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .right, options: [:])
            try visionHandler.perform([ballDetectRequest])
            if let results = ballDetectRequest.results as? [VNDetectedObjectObservation] {
                print("ball detected")
                
                // Filter out classification results with low confidence
                let filteredResults = results.filter { $0.confidence > 0.8 }
                
                DispatchQueue.main.async { [weak self] in
                    self?.drawBoundingBoxes(for: filteredResults)
                }
            }
        } catch {
            print("Error performing Vision request: \(error)")
        }
    }
    
    private func drawBoundingBoxes(for results: [VNDetectedObjectObservation]) {
        // Remove any existing bounding boxes
        self.view.layer.sublayers?.removeAll(where: { $0 is CAShapeLayer })
        
        for result in results {
            let boundingBox = result.boundingBox
            let convertedBoundingBox = self.previewLayer.layerRectConverted(fromMetadataOutputRect: boundingBox)
            let squareBoundingBox = self.convertToSquare(boundingBox: convertedBoundingBox)
            let shapeLayer = self.createBoundingBoxLayer(with: squareBoundingBox)
            self.view.layer.addSublayer(shapeLayer)
            
            // Get the four points around the bounding box
            let points = self.getFourPoints(from: squareBoundingBox)
            print("Bounding box points: \(points)")
        }
    }
    
    private func convertToSquare(boundingBox: CGRect) -> CGRect {
        let width = max(boundingBox.width, boundingBox.height)
        let height = width
        
        let x = boundingBox.midX - width / 2
        let y = boundingBox.midY - height / 2
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func createBoundingBoxLayer(with rect: CGRect) -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = rect
        shapeLayer.borderColor = UIColor.red.cgColor
        shapeLayer.borderWidth = 2.0
        return shapeLayer
    }
    
    private func getFourPoints(from rect: CGRect) -> [CGPoint] {
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        return [topLeft, topRight, bottomLeft, bottomRight]
    }
}

struct HostedViewController: UIViewControllerRepresentable {
    @Binding var viewController: ViewController?
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let viewController = ViewController()
        DispatchQueue.main.async {
            self.viewController = viewController
        }
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}

