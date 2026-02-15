import SwiftUI

struct ContentView: View {
    @State private var speechManager = SpeechManager()
    @State private var emotion: String = ""
    private let classifier = EmotionClassifier()
    
    var body: some View {
        VStack(spacing: 20) {
            Text(speechManager.transcribedText)
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()
            
            Text(self.emotion)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Button(action: {
                speechManager.startTranscribing()
            }) {
                Label("Start", systemImage: "mic.fill")
            }
            .buttonStyle(.borderedProminent)
            Button(action: {
                analyzeCurrentSpeech()
            }) {
                Label("Analyze", systemImage: "face.smiling.fill")
            }
            .disabled(speechManager.transcribedText.isEmpty)
        }
        .padding(40)
        .glassBackgroundEffect()
    }
    private func analyzeCurrentSpeech() {
        self.emotion = classifier.predictEmotion(for: speechManager.transcribedText).rawValue
    }
}
