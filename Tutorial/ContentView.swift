import SwiftUI

struct ContentView: View {
    @State private var speechManager = SpeechManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text(speechManager.transcribedText)
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                speechManager.startTranscribing()
            }) {
                Label("Start", systemImage: "mic.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .glassBackgroundEffect()
    }
}
