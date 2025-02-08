//
//  ViewController.swift
//  MLTrainController
//
//  Created by Lukasz on 08/02/2025.
//

import UIKit
import AVKit
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private var captureSession: AVCaptureSession?
    private var request: VNCoreMLRequest?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCaptureSession()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        captureSession?.startRunning()
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        
        guard let device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: device) else {
            print("Couldn't create video input")
            return
        }
        
        session.addInput(input)
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.frame
        preview.connection!.videoOrientation = .landscapeRight
        
        view.layer.addSublayer(preview)
        
        let queue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        
        if session.canAddOutput(output) {
            session.addOutput(output)
            
            //output.connection(with: .video)?.videoOrientation = .portrait
            session.commitConfiguration()
            
            captureSession = session
        } else {
            print("Couldn't add video output")
        }
    }

}

