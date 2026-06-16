#if canImport(UIKit) && canImport(ARKit) && canImport(SceneKit) && canImport(AVFoundation)
import SwiftUI
import ARKit
import SceneKit
import AVFoundation
import UIKit

@available(iOS 16.0, macOS 13.0, *)
struct AREngineView: View {
    @State private var cameraAuthorization: AVAuthorizationStatus = .notDetermined
    @State private var errorMessage: String?
    
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
                ARSessionViewRepresentable()
                .ignoresSafeArea()
            } else if !hasCameraUsageDescription {
                messageView(
                    title: "Configuration Error",
                    message: "Missing NSCameraUsageDescription in Info.plist. Add it to run AR safely."
                )
            } else {
                permissionView
            }
            
            if let errorMessage {
                statusBanner(text: errorMessage)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
        }
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
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.automaticallyUpdatesLighting = true
        sceneView.debugOptions = [.showFeaturePoints, .showWorldOrigin]
        sceneView.scene = SCNScene()
        sceneView.autoenablesDefaultLighting = true
        
        guard ARWorldTrackingConfiguration.isSupported else { return sceneView }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]

        // Ensure session run happens on main thread to avoid subtle threading crashes.
        DispatchQueue.main.async {
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }

        // Attach tap recognizer to allow placing the maze board.
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        sceneView.addGestureRecognizer(tap)
        context.coordinator.sceneView = sceneView

        // Add coaching overlay safely on main thread and only if the class exists.
        if NSClassFromString("ARCoachingOverlayView") != nil {
            DispatchQueue.main.async {
                let coachingOverlay = ARCoachingOverlayView()
                coachingOverlay.session = sceneView.session
                coachingOverlay.goal = .horizontalPlane
                coachingOverlay.activatesAutomatically = true
                coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
                sceneView.addSubview(coachingOverlay)
                NSLayoutConstraint.activate([
                    coachingOverlay.topAnchor.constraint(equalTo: sceneView.topAnchor),
                    coachingOverlay.bottomAnchor.constraint(equalTo: sceneView.bottomAnchor),
                    coachingOverlay.leadingAnchor.constraint(equalTo: sceneView.leadingAnchor),
                    coachingOverlay.trailingAnchor.constraint(equalTo: sceneView.trailingAnchor)
                ])
            }
        }

        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    
    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var sceneView: ARSCNView?
        var hasPlaced = false

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let sceneView = sceneView, !hasPlaced else { return }
            let location = sender.location(in: sceneView)
            
            guard let query = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .horizontal) else { return }
            let results = sceneView.session.raycast(query)
            
            guard let first = results.first else { return }
            let transform = first.worldTransform
            let position = SCNVector3(transform.columns.3.x, transform.columns.3.y + 0.001, transform.columns.3.z)

            // Create a simple maze board (semi-transparent blue plane)
            let plane = SCNPlane(width: 0.5, height: 0.5)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.6)
            material.isDoubleSided = true
            plane.materials = [material]

            let planeNode = SCNNode(geometry: plane)
            planeNode.eulerAngles.x = -.pi / 2
            planeNode.position = position
            planeNode.name = "MazeBoard"

            sceneView.scene.rootNode.addChildNode(planeNode)
            hasPlaced = true
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
