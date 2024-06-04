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
    private var videoPreviewLayer = AVCaptureVideoPreviewLayer()
    var screenRect: CGRect! = nil
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInitiated,
                                                     attributes: [], autoreleaseFrequency: .workItem)
    private lazy var videoDevice = bestCaptureDevice(position: currentCameraPosition)
    
    var boundingBoxViews = [BoundingBoxView]()
    var colors: [String: UIColor] = [:]
    var classLabels: [String] = []
    
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
        let mlModel = try! best_v4(configuration: .init()).model
        
        guard let model = try? VNCoreMLModel(for: mlModel) else {
            print("Failed to load CoreML model")
            return
        }
        model.featureProvider = ThresholdProvider()
        
        guard let classLabels = mlModel.modelDescription.classLabels as? [String] else {
            fatalError("Class labels are missing from the model description")
        }
        
        self.classLabels = classLabels
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
        
        setUpBoundingBoxViews()
        
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
    
    func setUpBoundingBoxViews() {
        // Ensure all bounding box views are initialized up to the maximum allowed.
        while boundingBoxViews.count < 100 {
            boundingBoxViews.append(BoundingBoxView())
        }
        // Assign random colors to the classes.
        for label in classLabels {
            if colors[label] == nil {  // if key not in dict
                colors[label] = UIColor(red: CGFloat.random(in: 0...1),
                                        green: CGFloat.random(in: 0...1),
                                        blue: CGFloat.random(in: 0...1),
                                        alpha: 0.6)
            }
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
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        
        if currentCameraPosition == .front {
            videoPreviewLayer.connection?.videoRotationAngle = 180
        } else {
            videoPreviewLayer.connection?.videoRotationAngle = 0
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
            self?.view.layer.addSublayer(self!.videoPreviewLayer)

            self?.printBoundingBox()
        }
    }
    
    func printBoundingBox() {
        for box in self.boundingBoxViews {
            box.addToLayer(self.videoPreviewLayer)
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
        
        var imageOrientation: CGImagePropertyOrientation
        switch UIDevice.current.orientation {
        case .portrait:
            imageOrientation = .up
            print("up")
        case .portraitUpsideDown:
            imageOrientation = .down
            print("down")
        case .landscapeLeft:
            imageOrientation = .left
            print("left")
        case .landscapeRight:
            imageOrientation = .right
            print("right")
        case .unknown:
            print("The device orientation is unknown, the predictions may be affected")
            fallthrough
        default:
            imageOrientation = .up
            print("orientation fallback")
        }
        
        do {
            guard let pixelBufer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return  }
            
            let visionHandler = VNImageRequestHandler(cvPixelBuffer: pixelBufer, orientation: imageOrientation, options: [:])
            try visionHandler.perform([ballDetectRequest])
            if let results = ballDetectRequest.results as? [VNRecognizedObjectObservation] {
                // Filter out classification results with low confidence
                DispatchQueue.main.async {
                    self.handleResult(for: results)
                }
            }
        } catch {
            print("Error performing Vision request: \(error)")
        }
    }
    
    private func handleResult(for results: [VNRecognizedObjectObservation]) {
        //TODO: handle score
        drawBoundingBoxes(predictions: results)
    }
    
    private func drawBoundingBoxes(predictions: [VNRecognizedObjectObservation]) {
        
        if predictions.count <= 0 {
            return
        }

        print("FOUND RESULT")

        let width = videoPreviewLayer.bounds.width
        let height = videoPreviewLayer.bounds.height
        
        var ratio: CGFloat = 1.0
        
        if captureSession.sessionPreset == .photo {
            ratio = (height / width) / (4.0 / 3.0) // photo
        } else {
            ratio = (height / width) / (16.0 / 9.0) // video
        }
        
        for i in 0..<boundingBoxViews.count {
            if i < predictions.count && i < Int(100) {
                let prediction = predictions[i]
                
                var rect = prediction.boundingBox
                switch UIDevice.current.orientation {
                case .portraitUpsideDown:
                    rect = CGRect(x: 1.0 - rect.origin.x - rect.width,
                                  y: 1.0 - rect.origin.y - rect.height,
                                  width: rect.width,
                                  height: rect.height)
                case .landscapeLeft:
                    rect = CGRect(x: rect.origin.y,
                                  y: 1.0 - rect.origin.x - rect.width,
                                  width: rect.height,
                                  height: rect.width)
                case .landscapeRight:
                    rect = CGRect(x: 1.0 - rect.origin.y - rect.height,
                                  y: rect.origin.x,
                                  width: rect.height,
                                  height: rect.width)
                case .unknown:
                    print("The device orientation is unknown, the predictions may be affected")
                    fallthrough
                default: break
                }
                
                if ratio >= 1 { // iPhone ratio = 1.218
                    let offset = (1 - ratio) * (0.5 - rect.minX)
                    let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: offset, y: -1)
                    rect = rect.applying(transform)
                    rect.size.width *= ratio
                } else { // iPad ratio = 0.75
                    let offset = (ratio - 1) * (0.5 - rect.maxY)
                    let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: offset - 1)
                    rect = rect.applying(transform)
                    rect.size.height /= ratio
                }
                
                rect = VNImageRectForNormalizedRect(rect, Int(width), Int(height))
                
                
                // The labels array is a list of VNClassificationObservation objects,
                // with the highest scoring class first in the list.
                let bestClass = prediction.labels[0].identifier
                let confidence = prediction.labels[0].confidence
                // print(confidence, rect)  // debug (confidence, xywh) with xywh origin top left (pixels)
                
                // Show the bounding box.
                boundingBoxViews[i].show(frame: rect,
                                         label: String(format: "%@ %.1f", bestClass, confidence * 100),
                                         color: colors[bestClass] ?? UIColor.white,
                                         alpha: CGFloat((confidence - 0.2) / (1.0 - 0.2) * 0.9))  // alpha 0 (transparent) to 1 (opaque) for conf threshold 0.2 to 1.0)
            } else {
                boundingBoxViews[i].hide()
            }
        }
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
