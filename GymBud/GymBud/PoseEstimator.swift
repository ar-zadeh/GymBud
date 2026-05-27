import AVFoundation
import Vision
import Foundation
import Combine
import SwiftUI

struct PoseOverlayPoint: Identifiable {
    let id: String
    let location: CGPoint
    let confidence: Float
}

class PoseEstimator: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var repCount = 0
    @Published var isTracking = false
    @Published var overlayPoints: [PoseOverlayPoint] = []
    @Published var frameSize: CGSize = .zero
    
    @objc let captureSession = AVCaptureSession()
    private var isUp = false // Rep tracking state
    
    func startSession() {
        guard !captureSession.isRunning else { return }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoDeviceInput) else {
            return
        }
        
        captureSession.addInput(videoDeviceInput)
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    connection.videoRotationAngle = 90
                } else {
                    connection.videoOrientation = .portrait
                }
            }
        }
        
        captureSession.commitConfiguration()
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isTracking = true
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
            isTracking = false
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        DispatchQueue.main.async {
            self.frameSize = CGSize(width: width, height: height)
        }
        
        let request = VNDetectHumanBodyPoseRequest(completionHandler: handlePoseDetection)
        
        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try handler.perform([request])
        } catch {
            print("Error parsing body pose: \(error)")
        }
    }
    
    private func handlePoseDetection(request: VNRequest, error: Error?) {
        guard let bodyPoseObservations = request.results as? [VNHumanBodyPoseObservation],
              let observation = bodyPoseObservations.first else { return }
        
        do {
            // Let's count squats or arm curls as a primitive rep counter mock
            let recognizedPoints = try observation.recognizedPoints(.all)
            let jointsToCapture: [VNHumanBodyPoseObservation.JointName] = [
                .nose,
                .leftEye, .rightEye,
                .leftEar, .rightEar,
                .leftShoulder, .rightShoulder,
                .leftElbow, .rightElbow,
                .leftWrist, .rightWrist,
                .leftHip, .rightHip,
                .leftKnee, .rightKnee,
                .leftAnkle, .rightAnkle
            ]

            var overlayPoints: [PoseOverlayPoint] = []
            for joint in jointsToCapture {
                guard let point = recognizedPoints[joint], point.confidence > 0.2 else { continue }
                overlayPoints.append(PoseOverlayPoint(id: joint.rawValue.rawValue, location: point.location, confidence: point.confidence))
            }

            DispatchQueue.main.async {
                self.overlayPoints = overlayPoints
            }
            
            // Wrist vs Shoulder for curl detection logic as a simple example
            guard let rightWrist = recognizedPoints[.rightWrist],
                  let rightShoulder = recognizedPoints[.rightShoulder],
                  let rightElbow = recognizedPoints[.rightElbow],
                  rightWrist.confidence > 0.3, rightShoulder.confidence > 0.3, rightElbow.confidence > 0.3 else {
                return
            }
            
            let wristY = rightWrist.location.y
            let shoulderY = rightShoulder.location.y
            let elbowY = rightElbow.location.y
            
            DispatchQueue.main.async {
                // If wrist goes above shoulder (in normalized inverted coordinate space)
                if wristY > shoulderY - 0.1 && !self.isUp {
                    self.isUp = true
                } 
                // If wrist goes below elbow
                else if wristY < elbowY && self.isUp {
                    self.isUp = false
                    self.repCount += 1
                }
            }
        } catch {
            print("Error extracting points: \(error)")
        }
    }
}
