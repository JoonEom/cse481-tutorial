//
//  SpeechTranscriber.swift
//  Tutorial
//
//  Handles live speech transcription using Apple Speech framework
//

import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechTranscriber: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String? = nil
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Check if running in simulator
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
    
    // Request speech recognition permissions
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
            }
        }
    }
    
    // Check current authorization status
    func checkAuthorization() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }
    
    // Start recording and transcribing
    func startRecording() {
        // Check if in simulator
        if isSimulator {
            errorMessage = "Simulator: Microphone not available. Use Simulator Mode to test."
            return
        }
        
        // Clear any previous errors
        errorMessage = nil
        
        // Check authorization
        guard authorizationStatus == .authorized else {
            requestAuthorization()
            errorMessage = "Please grant speech recognition permission"
            return
        }
        
        // Check if already recording
        guard !isRecording else { return }
        
        // Stop any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Reset transcript
        transcript = ""
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            let errorMsg = "Audio session setup failed: \(error.localizedDescription)"
            print(errorMsg)
            errorMessage = errorMsg
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            let errorMsg = "Unable to create recognition request"
            print(errorMsg)
            errorMessage = errorMsg
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Get audio input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on audio input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            let errorMsg = "Audio engine failed to start: \(error.localizedDescription). This often happens in simulators."
            print(errorMsg)
            errorMessage = errorMsg
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                    self.errorMessage = nil // Clear error on success
                }
                
                // Handle errors
                if let error = error {
                    let errorCode = (error as NSError).code
                    print("Speech recognition error: \(error.localizedDescription) (code: \(errorCode))")
                    
                    // Only stop on non-recoverable errors
                    if errorCode == 216 { // SFSpeechRecognizerErrorCode.audioEngineError
                        self.errorMessage = "Audio engine error. Try again or use Simulator Mode."
                        self.stopRecording()
                    } else if errorCode != 0 {
                        // Other errors (but not 0 which is "no error")
                        self.errorMessage = "Recognition error: \(error.localizedDescription)"
                    }
                }
                
                // Don't stop on final result - keep listening for continuous transcription
                // The user will manually stop recording
            }
        }
        
        isRecording = true
        errorMessage = nil
    }
    
    // Stop recording
    func stopRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        isRecording = false
    }
    
    // Toggle recording state
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}
