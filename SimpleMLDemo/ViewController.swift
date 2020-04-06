//
//  ViewController.swift
//  SimpleMLDemo
//
//  Created by Gabriele Fioretti on 01/04/2020.
//  Copyright © 2020 Gabriele Fioretti. All rights reserved.
//

import UIKit
import CoreML
import Vision
import AVFoundation

class ViewController: UIViewController {
    
    //Outlets
    @IBOutlet weak var predictionLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    
    //Variables
    let mModel = GymAI_ActivityClassifier_1().model             //Referring to image classifier model
    var videoURL: URL? = nil
    var frames: [UIImage] = []                                  //Image array to pass to the model
    var predictions: [VNClassificationObservation] = []
    var generator: AVAssetImageGenerator!
    var video: AVAsset? = nil
    var bestPrediction: VNClassificationObservation? = nil
    /// - Tag: MLModelSetup
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: GymAI_ActivityClassifier_1().model)
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    /**
     *This is just a test functions that uses a local memorized video 
     */
    func processLocalVideo(){
        let path = Bundle.main.path(forResource: "big_buck_bunny_720p_5mb", ofType: "mp4")
        videoURL = URL(fileURLWithPath: path!)
        print(videoURL)
        if videoURL != nil {
            print("Url works")
            getFramesFromVideo(videoUrl: videoURL! as URL)
            for frame in frames {
                print("Elaborating frame")
                updateClassifications(for: frame)
            }
        } else {
            predictionLabel.text = "Invalid video selected"
        }
    }
    
    /// - Tag: PerformRequests
    func updateClassifications(for image: UIImage) {
        predictionLabel.text = "Classifying..."
        
        let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue))
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation!)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                /*
                 This handler catches general image processing errors. The `classificationRequest`'s
                 completion handler `processClassifications(_:error:)` catches errors specific
                 to processing that request.
                 */
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    /// Updates the UI with the results of the classification.
    /// - Tag: ProcessClassifications
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                self.predictionLabel.text = "Unable to classify image.\n\(error!.localizedDescription)"
                return
            }
            // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
            let classifications = results as! [VNClassificationObservation]
            if classifications.isEmpty {
                self.predictionLabel.text = "Nothing recognized."
            } else {
                // Display top classifications ranked by confidence in the UI.
                if classifications[0].confidence > 0.7 {
                    self.predictions.append(classifications[0])
                    self.bestPrediction = self.evaluateLastPredictions()
                }
                if self.bestPrediction != nil {
                    self.predictionLabel.text = self.bestPrediction?.identifier
                } else {
                    self.predictionLabel.text = "Not sure"
                }
            }
        }
    }
    
    func evaluateLastPredictions() -> VNClassificationObservation? {
        var result: [VNClassificationObservation : Int] = [:]
        //This functions computes an average on last classifications
        if predictions.count > 5 {
            predictions.remove(at: 0) //Delete old classifications
        }
        for prediction in predictions {
            if result[prediction] == nil {
                result[prediction] = 0
            } else {
                result[prediction]! += 1
            }
        }
        print(predictions)
        var bestResult: Int = result[predictions[0]] ?? 0
        for value in result.keys {
            if result[value]! >= bestResult {
                bestResult = result[value]!
            }
        }
        var bestValue: VNClassificationObservation = predictions[0]
        for value in result.keys {
            if result[value] == bestResult {
                bestValue = value
            }
        }
        return bestValue
    }

    @IBAction func pickPressed(_ sender: UIButton) {
        
        presentVideoPicker(sourceType: .savedPhotosAlbum)
        
    }
    
    func presentVideoPicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.mediaTypes = ["public.movie"]
        picker.allowsEditing = false
        present(picker, animated: true, completion: nil)
    }
    
    //MARK: - functions for videoToFrame
    func getFramesFromVideo(videoUrl: URL, step: Int = 1) {
        let asset: AVAsset = AVAsset(url: videoUrl)
        let duration: Float64 = CMTimeGetSeconds(asset.duration)
        generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        frames = []
        for index: Int in 0 ..< Int(duration) {
            self.getFrame(fromTime:Float64(index))
        }
        generator = nil
    }

    private func getFrame(fromTime: Float64) {
        let time:CMTime = CMTimeMakeWithSeconds(fromTime, preferredTimescale:600)
        let image:CGImage
        do {
           try image = generator.copyCGImage(at: time, actualTime:nil)
            print("Added frame")
        } catch {
            print("Error")
           return
        }
        print("Added frame")
        frames.append(UIImage(cgImage:image))
    }
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        videoURL = info[.mediaURL] as? URL
        print(videoURL!)
        if videoURL != nil {
            getFramesFromVideo(videoUrl: videoURL! as URL)
            for frame in frames {
                updateClassifications(for: frame)
            }
        } else {
            predictionLabel.text = "Invalid video selected"
        }
        self.dismiss(animated: true, completion: nil)
    }
 
}
