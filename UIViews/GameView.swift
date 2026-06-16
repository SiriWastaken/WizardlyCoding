//
//  SwiftUIView.swift
//  WizardlyCoding
//
//  Created by Sri Ganty on 2026-06-16.
//

import SwiftUI

struct GameView: View {
    let userName: String
    
    var body: some View {
        AREngineView()
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                Text("Welcome, \(userName)")
                    .font(.headline)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding()
            }
    }
}
