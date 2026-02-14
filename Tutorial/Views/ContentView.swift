//
//  ContentView.swift
//  Tutorial
//

import SwiftUI

struct ContentView: View {
    @StateObject private var speechTranscriber = SpeechTranscriber()
    @StateObject private var emotionClassifier = EmotionClassifier()
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with status
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(speechTranscriber.isRunning ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                        Text(speechTranscriber.isRunning ? "Transcribing..." : "Ready")
                            .font(.headline)
                            .foregroundStyle(speechTranscriber.isRunning ? .primary : .secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial.opacity(0.5))
                
                // Chat Area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(speechTranscriber.chatHistory) { message in
                                ChatBubble(
                                    text: message.text,
                                    isPending: false,
                                    emotion: classifyEmotionForText(message.text)
                                )
                                .id(message.id)
                                .allowsHitTesting(false)
                            }
                            
                            if !speechTranscriber.transcript.isEmpty {
                                ChatBubble(
                                    text: speechTranscriber.transcript,
                                    isPending: true,
                                    emotion: .neutral
                                )
                                .id("pending")
                                .allowsHitTesting(false)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: speechTranscriber.chatHistory) { _ in
                        if let lastId = speechTranscriber.chatHistory.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: speechTranscriber.transcript) { _ in
                        withAnimation {
                            proxy.scrollTo("pending", anchor: .bottom)
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            // Start/Stop Button - Overlay at bottom
            VStack {
                Spacer()
                Button(action: {
                    print("🔘 Button tapped!")
                    if speechTranscriber.isRunning {
                        speechTranscriber.stopRecording()
                    } else {
                        speechTranscriber.startRecording()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: speechTranscriber.isRunning ? "stop.fill" : "mic.fill")
                            .font(.title2)
                        Text(speechTranscriber.isRunning ? "Stop Transcribing" : "Start Transcribing")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(speechTranscriber.isRunning ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .disabled(speechTranscriber.authorizationStatus != .authorized)
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: speechTranscriber.transcript) { oldValue, newValue in
            if !newValue.isEmpty {
                emotionClassifier.classifyEmotion(from: newValue)
            }
        }
        .onAppear {
            if speechTranscriber.authorizationStatus == .notDetermined {
                speechTranscriber.requestAuthorization()
            }
        }
    }
    
    private func classifyEmotionForText(_ text: String) -> Emotion {
        return emotionClassifier.predictEmotion(for: text)
    }
}

struct ChatBubble: View {
    let text: String
    let isPending: Bool
    let emotion: Emotion
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(text)
                    .padding(12)
                    .background(colorForEmotion(emotion).opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .opacity(isPending ? 0.7 : 1.0)
                
                if isPending {
                    Text("Speaking...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
                .overlay(Text("0").font(.caption).foregroundColor(.white))
        }
    }
    
    private func colorForEmotion(_ emotion: Emotion) -> Color {
        switch emotion {
        case .sadness: return .blue
        case .joy: return .yellow
        case .love: return .pink
        case .anger: return .red
        case .fear: return .purple
        case .surprise: return .orange
        case .neutral: return .gray
        }
    }
}
