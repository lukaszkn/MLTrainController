//
//  PredictionBoxesView.swift
//  MLTrainController
//
//  Created by Lukasz on 08/02/2025.
//

import UIKit
import Vision

class PredictionBoxesView: UIView {
    
    func drawBox(with predictions: [VNRecognizedObjectObservation]) {
        layer.sublayers?.forEach {
            $0.removeFromSuperlayer()
        }
        
        predictions.forEach {
            drawBox(with: $0)
        }
    }
    
    private func drawBox(with prediction: VNRecognizedObjectObservation) {
        let scale = CGAffineTransform.identity.scaledBy(x: bounds.width, y: bounds.height)
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
        
        let rectangle = prediction.boundingBox.applying(transform).applying(scale)
        
//        if !prediction.labels.isEmpty {
//            let topLabelObservation = prediction.labels[0]
//            print("\(topLabelObservation.identifier) \(topLabelObservation.confidence) \(rectangle)")
//        }
        
        let newlayer = CALayer()
        newlayer.frame = rectangle
        
        newlayer.backgroundColor = UIColor.green.withAlphaComponent(0.5).cgColor
        newlayer.cornerRadius = 4
        
        layer.addSublayer(newlayer)
    }
}
