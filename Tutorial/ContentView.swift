//
//  ContentView.swift
//  Tutorial
//

import SwiftUI

struct ContentView: View {
    @StateObject private var speechTranscriber = SpeechTranscriber()
    @StateObject private var emotionClassifier = EmotionClassifier()
    @State private var simulatorInputText: String = ""
    @State private var isSimulatorMode: Bool = false
    
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Speech Bubble
            RoundedRectangle(cornerRadius: 20)
                .fill(emotionClassifier.colorForEmotion(emotionClassifier.currentEmotion))
                .frame(width: 400, height: 200)
                .overlay(
                    Text(displayText.isEmpty ? "Start speaking..." : displayText)
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                        .padding()
                        .multilineTextAlignment(.center)
                )
                .shadow(radius: 10)
            
            // Emotion Label
            Text("Emotion: \(emotionClassifier.currentEmotion.capitalized)")
                .font(.system(size: 20, weight: .semibold))
            
            // Simulator Mode
            if isSimulator {
                Toggle("Simulator Mode", isOn: $isSimulatorMode)
                    .padding(.horizontal)
                
                if isSimulatorMode {
                    TextEditor(text: $simulatorInputText)
                        .frame(height: 100)
                        .padding(.horizontal)
                    
                    Button("Run Emotion Classification") {
                        emotionClassifier.classifyEmotion(from: simulatorInputText)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            
            // Recording Button
            Button(action: {
                print("🔘 Recording button tapped")
                speechTranscriber.toggleRecording()
            }) {
                HStack {
                    Image(systemName: speechTranscriber.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    Text(speechTranscriber.isRecording ? "Stop Recording" : "Start Recording")
                }
                .foregroundColor(.white)
                .padding()
                .background(speechTranscriber.isRecording ? Color.red : Color.blue)
                .cornerRadius(25)
            }
            .disabled(speechTranscriber.authorizationStatus != .authorized || isSimulatorMode)
            
            // Status indicator
            if speechTranscriber.isRecording {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Recording... Speak now")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Error message display
            if let errorMessage = speechTranscriber.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .onChange(of: speechTranscriber.transcript) { oldValue, newValue in
            if !isSimulatorMode && !newValue.isEmpty {
                print("🔄 Transcript changed, classifying emotion for: '\(newValue)'")
                emotionClassifier.classifyEmotion(from: newValue)
            }
        }
        .onChange(of: emotionClassifier.currentEmotion) { oldValue, newValue in
            print("😊 Emotion changed: \(oldValue) -> \(newValue)")
        }
        .onAppear {
            if !isSimulator && speechTranscriber.authorizationStatus == .notDetermined {
                speechTranscriber.requestAuthorization()
            }
        }
    }
    
    private var displayText: String {
        if isSimulatorMode {
            return simulatorInputText
        } else {
            return speechTranscriber.transcript
        }
    }
}
