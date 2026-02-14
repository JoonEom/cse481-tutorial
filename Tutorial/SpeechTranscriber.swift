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
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
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
        // Check authorization
        guard authorizationStatus == .authorized else {
            requestAuthorization()
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
            print("Audio session setup failed: \(error)")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
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
            print("Audio engine failed to start: \(error)")
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                }
                
                // Handle errors
                if let error = error {
                    print("Speech recognition error: \(error.localizedDescription)")
                    // Only stop on non-recoverable errors
                    if (error as NSError).code == 216 { // SFSpeechRecognizerErrorCode.audioEngineError
                        self.stopRecording()
                    }
                }
                
                // Don't stop on final result - keep listening for continuous transcription
                // The user will manually stop recording
            }
        }
        
        isRecording = true
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
