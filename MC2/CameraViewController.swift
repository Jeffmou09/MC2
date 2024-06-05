import Foundation
import SwiftUI
import AVFoundation
import CoreML
import Vision


extension ViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CMSampleBuffer) {
        predict(sampleBuffer: didCaptureVideoFrame)
    }
}

let mlModel = try! best_v4(configuration: .init()).model


class ViewController: UIViewController {
    private var permissionGranted = false
//    private var captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var videoPreview: UIView = UIView()
    var videoCapture: VideoCapture!
    var currentBuffer: CVPixelBuffer?

    var screenRect: CGRect! = nil
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInitiated,
                                                     attributes: [], autoreleaseFrequency: .workItem)
    
    var detector = try! VNCoreMLModel(for: mlModel)

    lazy var visionRequest: VNCoreMLRequest = {
        let request = VNCoreMLRequest(model: detector, completionHandler: {
            [weak self] request, error in
            self?.processObservations(for: request, error: error)
        })
        // NOTE: BoundingBoxView object scaling depends on request.imageCropAndScaleOption https://developer.apple.com/documentation/vision/vnimagecropandscaleoption
        request.imageCropAndScaleOption = .scaleFill  // .scaleFit, .scaleFill, .centerCrop
        return request
    }()


    
    var boundingBoxViews = [BoundingBoxView]()
    var colors: [String: UIColor] = [:]
    var classLabels: [String] = []
    
    var ballDetectRequest: VNCoreMLRequest?
    var boundingBoxLayers = [CAShapeLayer]()
    
    let minimumZoom: CGFloat = 1.0
    let maximumZoom: CGFloat = 10.0
    var lastZoomFactor: CGFloat = 1.0
    
    func startVideo() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        
        videoCapture.setUp(sessionPreset: .photo) { success in
            // .hd4K3840x2160 or .photo (4032x3024)  Warning: 4k may not work on all devices i.e. 2019 iPod
            if success {
                // Add the video preview into the UI.
                if let previewLayer = self.videoCapture.previewLayer {
//                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.view.layer.addSublayer(previewLayer)
                    previewLayer.frame = self.videoPreview.bounds  // resize preview layer
                    previewLayer.connection?.videoRotationAngle = 0

                    for box in self.boundingBoxViews {
                        box.addToLayer(previewLayer)
                    }

                }

                // Add the bounding box layers to the UI, on top of the video preview.

                // Once everything is set up, we can start capturing live video.
                self.videoCapture.start()
            }
        }
    }
    
    func processObservations(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            if let results = request.results as? [VNRecognizedObjectObservation] {
                self.show(predictions: results)
            } else {
                self.show(predictions: [])
            }
        }
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("view did load")
        checkPermission()
        
        // video preview
        videoPreview = UIView(frame: UIScreen.main.bounds)
        videoPreview.translatesAutoresizingMaskIntoConstraints = false
        videoPreview.frame = UIApplication.shared.keyWindow!.bounds
                
//        NSLayoutConstraint.activate([
//            videoPreview.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
//            videoPreview.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
//            videoPreview.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
//            videoPreview.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
//        ])
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
        view.addGestureRecognizer(pinchGesture)
        
        
//        sessionQueue.async { [unowned self] in
//            guard permissionGranted else { return }
//            setupCaptureSession()
//            print("Session running")
//        }
        
        setUpBoundingBoxViews()
        startVideo()
        print("Session running")
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
    
    func switchCamera() {
        sessionQueue.async { [unowned self] in
            self.currentCameraPosition = (self.currentCameraPosition == .back) ? .front : .back
//            self.setupCaptureSession()
        }
    }
    
    func predict(sampleBuffer: CMSampleBuffer) {
        if currentBuffer == nil, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            currentBuffer = pixelBuffer

            /// - Tag: MappingOrientation
            // The frame is always oriented based on the camera sensor,
            // so in most cases Vision needs to rotate it for the model to work as expected.
            let imageOrientation: CGImagePropertyOrientation
            switch UIDevice.current.orientation {
            case .portrait:
                imageOrientation = .up
            case .portraitUpsideDown:
                imageOrientation = .down
            case .landscapeLeft:
                imageOrientation = .left
            case .landscapeRight:
                imageOrientation = .right
            case .unknown:
                print("The device orientation is unknown, the predictions may be affected")
                fallthrough
            default:
                imageOrientation = .up
            }
            

            // Invoke a VNRequestHandler with that image
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: imageOrientation, options: [:])
            if UIDevice.current.orientation != .faceUp {  // stop if placed down on a table
                do {
                    try handler.perform([visionRequest])
                } catch {
                    print(error)
                }
            }

            currentBuffer = nil
        }
    }

    func show(predictions: [VNRecognizedObjectObservation]) {
        let width = videoPreview.bounds.width  // 375 pix
        let height = videoPreview.bounds.height  // 812 pix

        // ratio = videoPreview AR divided by sessionPreset AR
        var ratio: CGFloat = 1.0
        if videoCapture.captureSession.sessionPreset == .photo {
            ratio = (height / width) / (4.0 / 3.0)  // .photo
        } else {
            ratio = (height / width) / (16.0 / 9.0)  // .hd4K3840x2160, .hd1920x1080, .hd1280x720 etc.
        }

        for i in 0..<boundingBoxViews.count {
            // TODO: make threshold of total detected items
            if i < predictions.count && i < 100 {
                let prediction = predictions[i]

                var rect = prediction.boundingBox  // normalized xywh, origin lower left
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
                    rect.size.height /= ratio * 1.75
                }

                // Scale normalized to pixels [375, 812] [width, height]
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
        let device = videoCapture.captureDevice
        
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
