import SwiftUI

struct ContentView: View {
    @State private var speechManager = SpeechManager()
    @State private var emotion: String = ""
    private let classifier = EmotionClassifier()
    
    var body: some View {
        VStack(spacing: 20) {
            if !classifier.isReady {
                ProgressView("Loading Emotion Model...")
                    .padding()
            }
            
            Text(speechManager.transcribedText.isEmpty ? (speechManager.isRecording ? "Listening..." : "Transcription will appear here...") : speechManager.transcribedText)
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()
            
            if !self.emotion.isEmpty && !speechManager.isRecording {
                Text("Detected Emotion: \(self.emotion)")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            Button(action: {
                if speechManager.isRecording {
                    speechManager.stopTranscribing()
                } else {
                    self.emotion = ""
                    speechManager.startTranscribing()
                }
            }) {
                Label(speechManager.isRecording ? "Stop Recording" : "Start Recording", 
                      systemImage: speechManager.isRecording ? "stop.circle.fill" : "mic.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(speechManager.isRecording ? .red : .blue)
            
            Button(action: {
                analyzeCurrentSpeech()
            }) {
                Label("Analyze Emotion", systemImage: "face.smiling.fill")
            }
            .disabled(!classifier.isReady || speechManager.transcribedText.isEmpty || speechManager.isRecording)
        }
        .padding(40)
        .glassBackgroundEffect()
    }
    private func analyzeCurrentSpeech() {
        self.emotion = classifier.predictEmotion(for: speechManager.transcribedText).rawValue
    }
}
