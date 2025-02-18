//
//  ViewController.swift
//  MLTrainController
//
//  Created by Lukasz on 08/02/2025.
//

import UIKit
import AVKit
import Vision
import CoreBluetooth
import BoostBLEKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var powerLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    
    private var captureSession: AVCaptureSession?
    private var request: VNCoreMLRequest?
    private var predictionBoxesView: PredictionBoxesView?
    private var hubManager: HubManager!
    private var power: Int8 = 0
    private var lastMidX = CGFloat.nan
    private let locoPower: Int8 = 40
    private var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMLRequest()
        setupCaptureSession()
        
        hubManager = HubManager(delegate: self)
        setPower(power: 0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupBoxesView()
        
        powerLabel.removeFromSuperview()
        view.addSubview(powerLabel)
        button.removeFromSuperview()
        view.addSubview(button)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.startRunning()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.startConnectingTrain()
        }
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
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let request = request else {
            return
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }

    private func setupMLRequest() {
        let configuration = MLModelConfiguration()
        
        guard let model = try? SimpleTrainWide1(configuration: configuration).model, let visionModel = try? VNCoreMLModel(for: model) else {
            return
        }
        
        request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
        request?.imageCropAndScaleOption = .centerCrop
    }
    
    private func setupBoxesView() {
        let predictionBoxesView = PredictionBoxesView()
        predictionBoxesView.frame = view.frame
        
        view.addSubview(predictionBoxesView)
        self.predictionBoxesView = predictionBoxesView
    }
    
    private func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let prediction = (request.results as? [VNRecognizedObjectObservation])?.first {
            
            DispatchQueue.main.async {
                self.updateLastLocoPosition(midX: prediction.boundingBox.midX)
                self.predictionBoxesView?.drawBox(with: [prediction])
            }
        } else {
            DispatchQueue.main.async {
                self.predictionBoxesView?.layer.sublayers?.removeAll()
            }
        }
    }
    
    private func updateLastLocoPosition(midX: CGFloat) {
        lastMidX = midX
        var newPower: Int8 = power
        
        if power != 0 {
            if lastMidX > 0.7 {
                newPower = -locoPower
            } else if lastMidX < 0.3 {
                newPower = locoPower
            }
        } else if lastMidX > 0.4 && lastMidX < 0.6 {
            newPower = locoPower
        }
            
        if started && newPower != power {
            setPower(power: newPower)
        }
        
        powerLabel.text = "\(String(format: "%.2f", lastMidX))  power: \(newPower)"
    }
    
    private func setPower(power: Int8) {
        self.power = power
        print("Power set to: \(power)")
        
        guard let hub = hubManager.connectedHub else { return }
        
        let ports: [BoostBLEKit.Port] = [.A]
        for port in ports {
            if let command = hub.motorStartPowerCommand(port: port, power: power) {
                hubManager.write(data: command.data)
            }
        }
    }
    
    @IBAction func buttonTapped(_ sender: Any) {
        if started {
            started = false
            setPower(power: 0)
            button.setTitle("Start", for: .normal)
        } else {
            started = true
            button.setTitle("Stop", for: .normal)
        }
    }
    
    func startConnectingTrain() {
        if hubManager.isConnectedHub {
            hubManager.disconnect()
        } else {
            button.setTitle("Connecting...", for: .normal)
            hubManager.startScan()
        }
    }
}

extension ViewController: HubManagerDelegate {
    func didConnect(peripheral: CBPeripheral) {
        print("didConnect \(peripheral.identifier)")
        button.setTitle("Start", for: .normal)
    }
    
    func didFailToConnect(peripheral: CBPeripheral, error: (any Error)?) {
        print("didFailToConnect \(peripheral.identifier) \(String(describing: error?.localizedDescription))")
    }
    
    func didDisconnect(peripheral: CBPeripheral, error: (any Error)?) {
        print("didDisconnect \(peripheral.identifier) \(String(describing: error?.localizedDescription))")
    }
    
    func didUpdate(notification: BoostBLEKit.Notification) {
        switch notification {
        case .hubProperty(let hubProperty, let value):
            switch hubProperty {
            case .advertisingName:
                print("didUpdate \(value.description)")
            case .firmwareVersion:
                print("F/W: \(value)")
            case .batteryVoltage:
                print("Battery: \(value) %")
            default:
                break
            }
            
        case .connected, .disconnected:
            guard let connectedHub = hubManager.connectedHub else { break }
            var str = ""
            for portId in connectedHub.connectedIOs.keys.sorted() {
                let port = String(format: "%02X", portId)
                let device = connectedHub.connectedIOs[portId]?.description ?? ""
                str += "\(port):\t\(device)\n"
            }
            print("connected/disconnected \(str)")
            
        default:
            break
        }
    }
    
}
