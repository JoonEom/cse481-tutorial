//
//  EmotionClassifier.swift
//  Tutorial
//

import Foundation
import CoreML
import SwiftUI

@MainActor
class EmotionClassifier: ObservableObject {
    @Published var currentEmotion: String = "unknown"
    
    private var model: MLModel?
    private var inferenceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.5
    
    init() {
        loadModel()
    }
    
    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            var modelURL: URL?
            
            if let url = Bundle.main.url(forResource: "MLAssets/DistilBERTEmotion", withExtension: "mlpackage") {
                modelURL = url
            } else if let url = Bundle.main.url(forResource: "DistilBERTEmotion", withExtension: "mlpackage") {
                modelURL = url
            }
            
            guard let modelURL = modelURL else {
                return
            }
            
            model = try MLModel(contentsOf: modelURL, configuration: config)
        } catch {
            print("Failed to load model: \(error)")
        }
    }
    
    private func simpleTokenizer(_ text: String) -> (inputIds: [Int32], attentionMask: [Int32]) {
        var vocab: [String: Int32] = ["[PAD]": 0, "[UNK]": 1]
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        
        var nextTokenId: Int32 = 2
        var inputIds: [Int32] = []
        
        for word in words.prefix(128) {
            if vocab[word] == nil {
                vocab[word] = nextTokenId
                nextTokenId += 1
            }
            inputIds.append(vocab[word] ?? 1)
        }
        
        while inputIds.count < 128 {
            inputIds.append(0)
        }
        inputIds = Array(inputIds.prefix(128))
        
        let attentionMask = inputIds.map { $0 == 0 ? Int32(0) : Int32(1) }
        return (inputIds, attentionMask)
    }
    
    private func createMLMultiArray(from array: [Int32], shape: [NSNumber]) throws -> MLMultiArray {
        guard let multiArray = try? MLMultiArray(shape: shape, dataType: .int32) else {
            throw NSError(domain: "EmotionClassifier", code: 1, userInfo: nil)
        }
        
        for (index, value) in array.enumerated() {
            multiArray[index] = NSNumber(value: value)
        }
        
        return multiArray
    }
    
    func classifyEmotion(from text: String) {
        inferenceTask?.cancel()
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            currentEmotion = "unknown"
            return
        }
        
        inferenceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await performClassification(text: text)
        }
    }
    
    private func performClassification(text: String) async {
        guard let model = model else {
            currentEmotion = "unknown"
            return
        }
        
        do {
            let (inputIds, attentionMask) = simpleTokenizer(text)
            let inputIdsArray = try createMLMultiArray(from: inputIds, shape: [1, 128])
            let attentionMaskArray = try createMLMultiArray(from: attentionMask, shape: [1, 128])
            
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": MLFeatureValue(multiArray: inputIdsArray),
                "attention_mask": MLFeatureValue(multiArray: attentionMaskArray)
            ])
            
            let prediction = try await model.prediction(from: input)
            
            let logitsArray: MLMultiArray
            if let feature = prediction.featureValue(for: "linear_37"),
               let array = feature.multiArrayValue {
                logitsArray = array
            } else if let firstOutput = prediction.featureNames.first,
                      let feature = prediction.featureValue(for: firstOutput),
                      let array = feature.multiArrayValue {
                logitsArray = array
            } else {
                currentEmotion = "unknown"
                return
            }
            
            let emotion = interpretResults(logitsArray)
            if let emotion = emotion {
                currentEmotion = emotion.rawValue
            } else {
                currentEmotion = "unknown"
            }
            
        } catch {
            currentEmotion = "unknown"
        }
    }
    
    private func interpretResults(_ logits: MLMultiArray) -> Emotion? {
        let labels: [Emotion] = [.sadness, .joy, .love, .anger, .fear, .surprise]
        let threshold = 0.6
        let T: Double = 2.0
        
        let temp = (0..<logits.count).map { logits[$0].doubleValue / T }
        let scores = temp.map { exp($0) }
        let sum = scores.reduce(0, +)
        let probabilities = scores.map { $0 / sum }
        
        if let maxProb = probabilities.max(),
           let bestIndex = probabilities.firstIndex(of: maxProb) {
            if maxProb < threshold {
                return .neutral
            }
            return labels[bestIndex]
        }
        return nil
    }
    
    func colorForEmotion(_ emotion: String) -> Color {
        switch emotion.lowercased() {
        case "sadness": return .blue
        case "joy": return .yellow
        case "love": return .pink
        case "anger": return .red
        case "fear": return .purple
        case "surprise": return .orange
        default: return .gray
        }
    }
}

enum Emotion: String {
    case sadness = "sadness"
    case joy = "joy"
    case love = "love"
    case anger = "anger"
    case fear = "fear"
    case surprise = "surprise"
    case neutral = "neutral"
}
