//
//  ContentView.swift
//  Tutorial
//
//  Created by Joon Eom on 2/13/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var speechTranscriber = SpeechTranscriber()
    @StateObject private var emotionClassifier = EmotionClassifier()
    @State private var simulatorInputText: String = ""
    @State private var isSimulatorMode: Bool = false
    
    // Detect if running in simulator
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Speech Bubble
                RoundedRectangle(cornerRadius: 20)
                    .fill(emotionClassifier.colorForEmotion(emotionClassifier.currentEmotion))
                    .frame(width: 400, height: 200)
                    .overlay(
                        VStack {
                            Text(displayText.isEmpty ? "Start speaking..." : displayText)
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                                .padding()
                                .multilineTextAlignment(.center)
                        }
                        .allowsHitTesting(false) // Text doesn't need to be tappable
                    )
                    .shadow(radius: 10)
                    .allowsHitTesting(false) // Bubble is display only
            
            // Emotion Label
            Text("Emotion: \(emotionClassifier.currentEmotion.capitalized)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            // Simulator Mode Toggle (only show in simulator)
            if isSimulator {
                Toggle("Simulator Mode (Type Text)", isOn: $isSimulatorMode)
                    .padding(.horizontal)
                    .onChange(of: isSimulatorMode) { oldValue, newValue in
                        if newValue {
                            speechTranscriber.stopRecording()
                        }
                    }
                
                if isSimulatorMode {
                    // Simulator Input Section
                    VStack(spacing: 15) {
                        Text("Simulator: Microphone not available")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        TextEditor(text: $simulatorInputText)
                            .frame(height: 100)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        
                        Button(action: {
                            print("🔘 Run Emotion button tapped - text: '\(simulatorInputText)'")
                            emotionClassifier.classifyEmotion(from: simulatorInputText)
                        }) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 20))
                                Text("Run Emotion Classification")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 25)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(20)
                        }
                        .buttonStyle(.plain) // Ensure button is clickable
                        .contentShape(Rectangle())
                    }
                }
            }
            
            // Start/Stop Recording Button (disabled in simulator mode)
            Button(action: {
                print("🔘 Recording button tapped - isRecording: \(speechTranscriber.isRecording)")
                speechTranscriber.toggleRecording()
            }) {
                HStack {
                    Image(systemName: speechTranscriber.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 24))
                    Text(speechTranscriber.isRecording ? "Stop Recording" : "Start Recording")
                        .font(.system(size: 18, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(speechTranscriber.isRecording ? Color.red : Color.blue)
                .cornerRadius(25)
            }
            .buttonStyle(.plain) // Ensure button is clickable
            .contentShape(Rectangle())
            .disabled(speechTranscriber.authorizationStatus != .authorized || isSimulatorMode)
            
            // Status messages
            VStack(spacing: 5) {
                if isSimulator && !isSimulatorMode {
                    Text("⚠️ Simulator: Microphone may not work")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if speechTranscriber.authorizationStatus != .authorized && !isSimulatorMode {
                    Text("Speech recognition permission required")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let errorMessage = speechTranscriber.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear) // Ensure background doesn't block touches
        .onChange(of: speechTranscriber.transcript) { oldValue, newValue in
            // Trigger emotion classification when transcript changes (only if not in simulator mode)
            if !isSimulatorMode {
                emotionClassifier.classifyEmotion(from: newValue)
            }
        }
        .onAppear {
            // Request permissions on appear (only if not in simulator)
            if !isSimulator && speechTranscriber.authorizationStatus == .notDetermined {
                speechTranscriber.requestAuthorization()
            }
        }
    }
    
    // Display text: use simulator input or transcript
    private var displayText: String {
        if isSimulatorMode {
            return simulatorInputText.isEmpty ? "Type text above and tap 'Run Emotion'" : simulatorInputText
        } else {
            return speechTranscriber.transcript
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
