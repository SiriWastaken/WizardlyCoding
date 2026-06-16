#if canImport(UIKit) && canImport(ARKit) && canImport(RealityKit) && canImport(AVFoundation)
import SwiftUI
import RealityKit
import ARKit
import AVFoundation
import UIKit

struct AREngineView: View {
    @State private var cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var errorMessage: String?
    @State private var sessionInterrupted = false
    
    private var hasCameraUsageDescription: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String != nil
    }
    
    var body: some View {
        ZStack {
            if !ARWorldTrackingConfiguration.isSupported {
                messageView(
                    title: "AR Not Supported",
                    message: "This device does not support AR world tracking."
                )
            } else if cameraAuthorization == .authorized && hasCameraUsageDescription {
                ARSessionViewRepresentable(
                    errorMessage: $errorMessage,
                    sessionInterrupted: $sessionInterrupted
                )
                .ignoresSafeArea()
            } else if !hasCameraUsageDescription {
                messageView(
                    title: "Configuration Error",
                    message: "Missing NSCameraUsageDescription in Info.plist. Add it to run AR safely."
                )
            } else {
                permissionView
            }
            
            if sessionInterrupted {
                statusBanner(text: "AR session interrupted. Move device to resume.")
            }
            
            if let errorMessage {
                statusBanner(text: errorMessage)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await requestCameraPermissionIfNeeded()
        }
    }
    
    private var permissionView: some View {
        VStack(spacing: 16) {
            Text("Camera Access Needed")
                .font(.title2.bold())
            Text("Allow camera access to start the AR experience.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button("Grant Access") {
                Task { await requestCameraPermissionIfNeeded(forceRequest: true) }
            }
            .buttonStyle(.borderedProminent)
            
            if cameraAuthorization == .denied || cameraAuthorization == .restricted {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func messageView(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title2.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    @ViewBuilder
    private func statusBanner(text: String) -> some View {
        VStack {
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            Spacer()
        }
    }
    
    @MainActor
    private func requestCameraPermissionIfNeeded(forceRequest: Bool = false) async {
        guard hasCameraUsageDescription else {
            errorMessage = "Camera permission cannot be requested because NSCameraUsageDescription is missing."
            return
        }
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraAuthorization = status
        
        guard status == .notDetermined || forceRequest else { return }
        
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraAuthorization = granted ? .authorized : .denied
        if !granted {
            errorMessage = "Camera permission denied. Enable it in Settings to continue."
        }
    }
}

private struct ARSessionViewRepresentable: UIViewRepresentable {
    @Binding var errorMessage: String?
    @Binding var sessionInterrupted: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session.delegate = context.coordinator
        arView.automaticallyConfigureSession = false
        arView.debugOptions = [.showFeaturePoints, .showAnchorGeometry]
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        let anchor = AnchorEntity(plane: .horizontal)
        let mazeBoard = createMazeEntity()
        anchor.addChild(mazeBoard)
        arView.scene.anchors.append(anchor)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }
    
    private func createMazeEntity() -> ModelEntity {
        let mesh = MeshResource.generatePlane(width: 0.5, depth: 0.5)
        let material = SimpleMaterial(color: .blue.withAlphaComponent(0.6), isMetallic: false)
        let model = ModelEntity(mesh: mesh, materials: [material])
        model.position.y = 0.001
        model.name = "MazeBoard"
        return model
    }
    
    final class Coordinator: NSObject, ARSessionDelegate {
        private var parent: ARSessionViewRepresentable
        
        init(_ parent: ARSessionViewRepresentable) {
            self.parent = parent
        }
        
        func session(_ session: ARSession, didFailWithError error: any Error) {
            let errorMessageBinding = parent.$errorMessage
            let message = "AR session failed: \(error.localizedDescription)"
            DispatchQueue.main.async {
                errorMessageBinding.wrappedValue = message
            }
        }
        
        func sessionWasInterrupted(_ session: ARSession) {
            let interruptedBinding = parent.$sessionInterrupted
            DispatchQueue.main.async {
                interruptedBinding.wrappedValue = true
            }
        }
        
        func sessionInterruptionEnded(_ session: ARSession) {
            let interruptedBinding = parent.$sessionInterrupted
            let errorMessageBinding = parent.$errorMessage
            DispatchQueue.main.async {
                interruptedBinding.wrappedValue = false
                errorMessageBinding.wrappedValue = nil
            }
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
    }
}

#else

import SwiftUI

@available(macOS 10.15, iOS 13.0, *)
struct AREngineView: View {
    var body: some View {
        Text("AR is available on iOS devices.")
            .padding()
    }
}

#endif
