//
//  SwiftUIView.swift
//  WizardlyCoding
//
//  Created by Sri Ganty on 2026-06-16.
//

import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("Wizardly Coding")
                    .font(.largeTitle.bold())
                
                NavigationLink(value: "play") {
                    Text("Play")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                
                NavigationLink(destination: OptionsView()) {
                    Text("Options")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                }
                
                NavigationLink(destination: CreditsView()) {
                    Text("Credits")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                }
            }
            .padding()
            .navigationDestination(for: String.self) { value in
                if value == "play" {
                    AREngineView()
                }
            }
        }
    }
}
