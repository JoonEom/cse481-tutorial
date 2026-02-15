import SwiftUI

struct ContentView: View {
    @State private var speechManager = SpeechManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Last Spoken Sentence:")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(speechManager.transcribedText)
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                speechManager.startTranscribing()
            }) {
                Label("Start Listening", systemImage: "mic.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .glassBackgroundEffect() // The "Magic" visionOS look
    }
}
