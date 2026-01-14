import AVFoundation
import UIKit

class NativeCameraHandler {
    static let shared = NativeCameraHandler()
    
    func captureSelfieDirect(completion: @escaping (Bool) -> Void) {
        print("🎬 [CAMERA] captureSelfieDirect called")
        
        // Check camera permission first
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("🎬 [CAMERA] Authorization status: \(authorizationStatus.rawValue)")
        
        switch authorizationStatus {
        case .authorized:
            print("✅ [CAMERA] Camera permission GRANTED")
            DispatchQueue.main.async {
                self.takeSelfie(completion: completion)
            }
            
        case .notDetermined:
            print("⚠️  [CAMERA] Permission not determined - requesting...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("🎬 [CAMERA] Permission response: \(granted)")
                if granted {
                    print("✅ [CAMERA] Camera permission GRANTED after request")
                    DispatchQueue.main.async {
                        self.takeSelfie(completion: completion)
                    }
                } else {
                    print("❌ [CAMERA] Camera permission DENIED")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
            
        case .denied:
            print("❌ [CAMERA] Camera permission DENIED by user")
            completion(false)
            
        case .restricted:
            print("❌ [CAMERA] Camera permission RESTRICTED")
            completion(false)
            
        @unknown default:
            print("❌ [CAMERA] Unknown permission status")
            completion(false)
        }
    }
    
    private func takeSelfie(completion: @escaping (Bool) -> Void) {
        print("📷 [CAMERA] takeSelfie started")
        
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        // Get front camera
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("❌ [CAMERA] Front camera NOT FOUND")
            completion(false)
            return
        }
        print("✅ [CAMERA] Front camera found")
        
        do {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            session.addInput(input)
            print("✅ [CAMERA] Camera input added")
            
            let output = AVCapturePhotoOutput()
            session.addOutput(output)
            print("✅ [CAMERA] Photo output added")
            
            session.startRunning()
            print("✅ [CAMERA] Session started - waiting 1.5 seconds before capture")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                print("📸 [CAMERA] Taking photo NOW...")
                let settings = AVCapturePhotoSettings()
                let delegate = PhotoDelegate { success in
                    print("📸 [CAMERA] PhotoDelegate completion called with: \(success)")
                    session.stopRunning()
                    print("✅ [CAMERA] Session stopped")
                    completion(success)
                }
                output.capturePhoto(with: settings, delegate: delegate)
                print("📸 [CAMERA] capturePhoto method called")
            }
        } catch {
            print("❌ [CAMERA] Error setting up session: \(error.localizedDescription)")
            completion(false)
        }
    }
}

class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (Bool) -> Void
    
    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                    didFinishProcessingPhoto photo: AVCapturePhoto,
                    error: Error?) {
        print("📸 [PHOTO_DELEGATE] photoOutput called")
        print("📸 [PHOTO_DELEGATE] Error: \(error?.localizedDescription ?? "nil")")
        
        if let error = error {
            print("❌ [PHOTO_DELEGATE] Photo error: \(error.localizedDescription)")
            completion(false)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("❌ [PHOTO_DELEGATE] No image data available")
            completion(false)
            return
        }
        print("✅ [PHOTO_DELEGATE] Image data obtained - size: \(imageData.count) bytes")
        
        let fileManager = FileManager.default
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let docPath = paths[0]
        let dirPath = docPath + "/unauthorized_attempts"
        
        print("📁 [PHOTO_DELEGATE] Doc path: \(docPath)")
        print("📁 [PHOTO_DELEGATE] Dir path: \(dirPath)")
        
        do {
            try fileManager.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
            print("✅ [PHOTO_DELEGATE] Directory created/exists")
        } catch {
            print("❌ [PHOTO_DELEGATE] Directory creation error: \(error.localizedDescription)")
            completion(false)
            return
        }
        
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "unauthorized_\(timestamp).jpg"
        let filePath = dirPath + "/" + filename
        let fileURL = URL(fileURLWithPath: filePath)
        
        print("💾 [PHOTO_DELEGATE] Saving to: \(filePath)")
        
        do {
            try imageData.write(to: fileURL, options: .atomic)
            print("✅ [PHOTO_DELEGATE] SELFIE SAVED SUCCESSFULLY!")
            print("✅ [PHOTO_DELEGATE] File exists: \(fileManager.fileExists(atPath: filePath))")
            completion(true)
        } catch {
            print("❌ [PHOTO_DELEGATE] File write error: \(error.localizedDescription)")
            completion(false)
        }
    }
}
