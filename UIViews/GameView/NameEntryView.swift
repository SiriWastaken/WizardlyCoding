//
//  SwiftUIView.swift
//  WizardlyCoding
//
//  Created by Sri Ganty on 2026-06-16.
//

import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct NameEntryView: View {
    @State private var userName = ""
    @State private var navigateToGame = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Enter your name")
                .font(.largeTitle)
            
            TextField("Your name...", text: $userName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            Button("Begin Journey") {
                if !userName.isEmpty {
                    navigateToGame = true
                }
            }
            .disabled(userName.isEmpty)
            .padding()
            .background(userName.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(16)
            
        }
        .padding()
        .navigationDestination(isPresented: $navigateToGame) {
            GameView(userName: userName)
        }
        .navigationTitle("")
#if os(iOS)
        .navigationBarHidden(true)
#endif
    }
}
