import Foundation
import SwiftUI
import AVFoundation
import CoreML
import Vision

func bestCaptureDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice {
    if UserDefaults.standard.bool(forKey: "use_telephoto"), let device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: position) {
        return device
    } else if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: position) {
        return device
    } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
        return device
    } else {
        fatalError("Expected back camera device is not available.")
    }
}


class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var permissionGranted = false
    private var captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var previewLayer = AVCaptureVideoPreviewLayer()
    var screenRect: CGRect! = nil
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInitiated,
                                                     attributes: [], autoreleaseFrequency: .workItem)
    private lazy var videoDevice = bestCaptureDevice(position: currentCameraPosition)
    
    var ballDetectRequest: VNCoreMLRequest?
    var boundingBoxLayers = [CAShapeLayer]()
    
    let minimumZoom: CGFloat = 1.0
    let maximumZoom: CGFloat = 10.0
    var lastZoomFactor: CGFloat = 1.0
    
    override func viewDidAppear(_ animated: Bool) {
        print("view did appear")
        useCoreMLModel()
    }
    
    func useCoreMLModel() {
        // Load the CoreML model
        guard let model = try? VNCoreMLModel(for: best_v2(configuration: .init()).model) else {
            print("Failed to load CoreML model")
            return
        }
        model.featureProvider = ThresholdProvider()
        
        // Create a request for the model
        ballDetectRequest = VNCoreMLRequest(model: model)
        ballDetectRequest!.imageCropAndScaleOption = .scaleFill
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("view did load")
        checkPermission()
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
        view.addGestureRecognizer(pinchGesture)
        
        sessionQueue.async { [unowned self] in
            guard permissionGranted else { return }
            setupCaptureSession()
            print("Session running")
        }
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    
    func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            permissionGranted = granted
            sessionQueue.resume()
        }
    }
    
    func setupCaptureSession(){
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        videoDevice = bestCaptureDevice(position: currentCameraPosition)
        
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
            previewLayer.connection?.videoRotationAngle = 180
        } else {
            previewLayer.connection?.videoRotationAngle = 0
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
            self?.view.layer.addSublayer(self!.previewLayer)
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
            let visionHandler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .downMirrored, options: [:])
            try visionHandler.perform([ballDetectRequest])
            if let results = ballDetectRequest.results as? [VNRecognizedObjectObservation] {
                // Filter out classification results with low confidence
                DispatchQueue.main.async { [weak self] in
                    // Remove any existing bounding boxes and labels
                    self?.view.layer.sublayers?.removeAll(where: { $0 is CAShapeLayer })
                    self?.view.layer.sublayers?.removeAll(where: { $0 is CATextLayer })
                    
                    // handle the filtered results
                    self?.handleResult(for: results)
                }
            }
        } catch {
            print("Error performing Vision request: \(error)")
        }
    }
    
    private func handleResult(for results: [VNRecognizedObjectObservation]) {
        //TODO: handle score
        for result in results {
            drawBoundingBoxes(for: result)
        }
    }
    
    private func drawBoundingBoxes(for result: VNRecognizedObjectObservation) {
        let boundingBox = result.boundingBox
        let convertedBoundingBox = self.previewLayer.layerRectConverted(fromMetadataOutputRect: boundingBox)
        let squareBoundingBox = self.convertToSquare(boundingBox: convertedBoundingBox)
        
        // Create the bounding box shape layer
        let shapeLayer = self.createBoundingBoxLayer(with: squareBoundingBox)
        self.view.layer.addSublayer(shapeLayer)
        
        // Get the four points around the bounding box
        let points = self.getFourPoints(from: squareBoundingBox)
        print("Bounding box points: \(points)")
        
        // Create a text layer for the label
        let textLayer = CATextLayer()
        textLayer.frame = squareBoundingBox
        textLayer.foregroundColor = UIColor.magenta.cgColor
        textLayer.alignmentMode = .center
        textLayer.fontSize = 12
        
        let labelText = "\(result.labels.first?.identifier ?? "Unknown") \(String(format: "%.2f", result.labels.first?.confidence ?? 0))"
        
        // Set the text layer content
        textLayer.string = labelText
        
        // Add the text layer to the sublayers
        self.view.layer.addSublayer(textLayer)
    }
    
    
    private func convertToSquare(boundingBox: CGRect) -> CGRect {
        let width = max(boundingBox.width, boundingBox.height)
        let height = width
        
        return CGRect(x: boundingBox.minX, y: boundingBox.minY, width: width, height: height)
    }
    
    private func createBoundingBoxLayer(with rect: CGRect) -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = rect
        shapeLayer.borderColor = UIColor.magenta.cgColor
        shapeLayer.borderWidth = 3
        shapeLayer.cornerRadius = 5
        return shapeLayer
    }
    
    private func getFourPoints(from rect: CGRect) -> [CGPoint] {
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        return [topLeft, topRight, bottomLeft, bottomRight]
    }
    
    @IBAction func pinch(_ pinch: UIPinchGestureRecognizer) {
        let device = videoDevice
        
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            let maxZoomFactor = device.activeFormat.videoMaxZoomFactor
            let pinchVelocityDividerFactor: CGFloat = 5.0
            
            let desiredZoomFactor = device.videoZoomFactor + atan2(pinch.velocity, pinchVelocityDividerFactor)
            device.videoZoomFactor = max(1.0, min(desiredZoomFactor, maxZoomFactor))
        } catch {
            print("Error locking configuration")
        }
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
