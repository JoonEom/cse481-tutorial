//
//  ContentView.swift
//  Tutorial
//
//  Created by Joon Eom on 2/13/26.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @StateObject private var speechTranscriber = SpeechTranscriber()
    @StateObject private var emotionClassifier = EmotionClassifier()
    
    var body: some View {
        VStack(spacing: 30) {
            // Speech Bubble
            RoundedRectangle(cornerRadius: 20)
                .fill(emotionClassifier.colorForEmotion(emotionClassifier.currentEmotion))
                .frame(width: 400, height: 200)
                .overlay(
                    VStack {
                        Text(speechTranscriber.transcript.isEmpty ? "Start speaking..." : speechTranscriber.transcript)
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .padding()
                            .multilineTextAlignment(.center)
                    }
                )
                .shadow(radius: 10)
            
            // Emotion Label
            Text("Emotion: \(emotionClassifier.currentEmotion.capitalized)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            // Start/Stop Button
            Button(action: {
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
            .disabled(speechTranscriber.authorizationStatus != .authorized)
            
            // Authorization status message
            if speechTranscriber.authorizationStatus != .authorized {
                Text("Speech recognition permission required")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
            }
        }
        .padding()
        .onChange(of: speechTranscriber.transcript) { oldValue, newValue in
            // Trigger emotion classification when transcript changes
            emotionClassifier.classifyEmotion(from: newValue)
        }
        .onAppear {
            // Request permissions on appear
            if speechTranscriber.authorizationStatus == .notDetermined {
                speechTranscriber.requestAuthorization()
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
