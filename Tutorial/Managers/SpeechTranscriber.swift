//
//  SpeechTranscriber.swift
//  Tutorial
//

import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechTranscriber: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRunning: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String? = nil
    @Published var chatHistory: [ChatMessage] = []
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    init() {
        checkAuthorization()
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
            }
        }
    }
    
    func checkAuthorization() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }
    
    func startRecording() {
        if isSimulator {
            errorMessage = "Simulator: Microphone not available. Use Simulator Mode to test."
            return
        }
        
        errorMessage = nil
        
        guard authorizationStatus == .authorized else {
            requestAuthorization()
            errorMessage = "Please grant speech recognition permission"
            return
        }
        
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        if micStatus == .denied {
            errorMessage = "Microphone permission denied. Please enable in Settings."
            return
        } else if micStatus == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if !granted {
                        self?.errorMessage = "Microphone permission required"
                    } else {
                        self?.startRecording()
                    }
                }
            }
            return
        }
        
        guard !isRunning else { return }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        transcript = ""
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.mixWithOthers, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session setup failed: \(error.localizedDescription)"
            return
        }
        
        setupAudioEngine()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Audio engine failed to start: \(error.localizedDescription)"
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let result = result {
                    let newTranscript = result.bestTranscription.formattedString
                    if newTranscript != self.transcript {
                        self.transcript = newTranscript
                        self.errorMessage = nil
                    }
                    
                    // When final, add to chat history (emotion will be classified in ContentView)
                    if result.isFinal && !newTranscript.isEmpty {
                        let message = ChatMessage(
                            text: newTranscript,
                            timestamp: Date(),
                            emotion: .neutral
                        )
                        self.chatHistory.append(message)
                        self.transcript = ""
                    }
                }
                
                if let error = error {
                    print("Speech recognition error: \(error.localizedDescription)")
                }
            }
        }
        
        isRunning = true
        errorMessage = nil
    }
    
    private func setupAudioEngine() {
        let inputNode = audioEngine.inputNode
        let inputBus: AVAudioNodeBus = 0
        let nativeFormat = inputNode.inputFormat(forBus: inputBus)
        
        guard nativeFormat.channelCount > 0 else {
            return
        }
        
        inputNode.removeTap(onBus: inputBus)
        inputNode.installTap(onBus: inputBus, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
        }
    }
    
    func stopRecording() {
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
        
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        
        try? AVAudioSession.sharedInstance().setActive(false)
        isRunning = false
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date
    let emotion: Emotion
}
