//
//  ContentView.swift
//  dualingo-ios
//
//  Created by Kyle Naranjo on 12/26/23.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @ObservedObject var audioManager = AudioManager()
    @ObservedObject var networkManager = NetworkManager()
    @State private var languageMode = "Any" // Default value
    
    let languageModes = ["English", "Taiwanese", "Any"]
    
    var body: some View {
        VStack {
            Picker("Language Mode", selection: $languageMode) {
                ForEach(languageModes, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button(action: {
                            if audioManager.isRecording {
                                audioManager.stopRecording()
                            } else {
                                networkManager.reset()
                                audioManager.reset()
                                audioManager.startRecording()
                            }
                        }, label: {
                            Text(buttonLabel)
                                .foregroundColor(.white)
                                .padding()
                                .background(buttonBackgroundColor)
                                .cornerRadius(10)
                        })
                        .disabled(networkManager.isLoading || audioManager.isPlaying)
                        .opacity((networkManager.isLoading || audioManager.isPlaying) ? 0.5 : 1)
            
            Text("Detected Language: \(networkManager.detectedLanguage)")
            Text("Processed Text: \(networkManager.processedText)")
            Text("Translated Text: \(networkManager.translatedText)")
        }
        .padding()
        .onChange(of: audioManager.recordedAudioURL) { newValue in
                    guard let audioURL = newValue else { return }
                    networkManager.processAndTranslate(audioURL: audioURL, languageMode: languageMode)
                }
    }
    private var buttonLabel: String {
            if audioManager.isRecording {
                return "Stop Recording"
            } else if networkManager.isLoading || audioManager.isPlaying {
                return "Processing..."
            } else {
                return "Start Recording"
            }
        }

    
    private var buttonBackgroundColor: Color {
            if audioManager.isRecording {
                return .red // Color for the "Stop Recording" state
            } else if networkManager.isLoading {
                return .orange // Color when button is disabled
            } else if audioManager.isPlaying {
                return .gray // Color when button is disabled
            } else {
                return .blue // Color for the "Start Recording" state
            }
        }
    
}

