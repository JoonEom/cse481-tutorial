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
    @Published var chatHistory: [ChatMessage] = []
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let emotionClassifier = EmotionClassifier()
    
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
        guard authorizationStatus == .authorized else {
            requestAuthorization()
            return
        }
        
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        if micStatus == .denied {
            return
        } else if micStatus == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if granted {
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
            return
        }
        
        setupAudioEngine()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let result = result {
                    let newTranscript = result.bestTranscription.formattedString
                    if newTranscript != self.transcript {
                        self.transcript = newTranscript
                    }
                    
                    if result.isFinal && !newTranscript.isEmpty {
                        let emotion = self.emotionClassifier.predictEmotion(for: newTranscript)
                        let message = ChatMessage(
                            text: newTranscript,
                            timestamp: Date(),
                            emotion: emotion
                        )
                        self.chatHistory.append(message)
                        self.transcript = ""
                    }
                }
            }
        }
        
        isRunning = true
    }
    
    private func setupAudioEngine() {
        let inputNode = audioEngine.inputNode
        let inputBus: AVAudioNodeBus = 0
        let nativeFormat = inputNode.inputFormat(forBus: inputBus)
        
        guard nativeFormat.channelCount > 0 else { return }
        
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
