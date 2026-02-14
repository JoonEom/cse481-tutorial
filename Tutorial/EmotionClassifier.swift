//
//  EmotionClassifier.swift
//  Tutorial
//
//  Handles emotion classification using Core ML with a simple tokenizer stub
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
    
    // Emotion labels in the exact order from the model
    private let emotionLabels = ["sadness", "joy", "love", "anger", "fear", "surprise"]
    
    init() {
        loadModel()
    }
    
    // Load the Core ML model
    private func loadModel() {
        // The model should be added to the Xcode project
        // This will generate a Swift class (e.g., DistilBERTEmotion)
        // For now, we'll load it by name
        guard let modelURL = Bundle.main.url(forResource: "DistilBERTEmotion", withExtension: "mlpackage") else {
            print("⚠️ Model not found. Make sure DistilBERTEmotion.mlpackage is added to the Xcode project.")
            return
        }
        
        do {
            let config = MLModelConfiguration()
            model = try MLModel(contentsOf: modelURL, configuration: config)
            print("✅ Model loaded successfully")
        } catch {
            print("❌ Failed to load model: \(error)")
        }
    }
    
    // Simple tokenizer stub for tutorial purposes
    // NOTE: This is NOT equivalent to the real DistilBERT tokenizer!
    // This is a placeholder for tutorial demonstration only.
    private func simpleTokenizer(_ text: String) -> (inputIds: [Int32], attentionMask: [Int32]) {
        // Simple word-based vocabulary mapping
        // In a real implementation, you would use the actual DistilBERT tokenizer
        var vocab: [String: Int32] = [
            "[PAD]": 0,
            "[UNK]": 1
        ]
        
        // Build a simple vocabulary from common words (tutorial stub)
        // In reality, you'd use the full BERT vocabulary
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        
        var nextTokenId: Int32 = 2
        var inputIds: [Int32] = []
        
        // Map words to token IDs (or [UNK] if not in vocab)
        for word in words.prefix(128) {
            if vocab[word] == nil {
                vocab[word] = nextTokenId
                nextTokenId += 1
            }
            inputIds.append(vocab[word] ?? 1) // Use [UNK] if not found
        }
        
        // Pad or truncate to 128 tokens
        while inputIds.count < 128 {
            inputIds.append(0) // [PAD]
        }
        inputIds = Array(inputIds.prefix(128))
        
        // Create attention mask: 1 for non-pad tokens, 0 for pad tokens
        let attentionMask = inputIds.map { $0 == 0 ? Int32(0) : Int32(1) }
        
        return (inputIds, attentionMask)
    }
    
    // Convert arrays to MLMultiArray
    private func createMLMultiArray(from array: [Int32], shape: [NSNumber]) throws -> MLMultiArray {
        guard let multiArray = try? MLMultiArray(shape: shape, dataType: .int32) else {
            throw NSError(domain: "EmotionClassifier", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create MLMultiArray"])
        }
        
        for (index, value) in array.enumerated() {
            multiArray[index] = NSNumber(value: value)
        }
        
        return multiArray
    }
    
    // Classify emotion from text (with debouncing)
    func classifyEmotion(from text: String) {
        // Cancel previous task
        inferenceTask?.cancel()
        
        // Skip if text is empty
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            currentEmotion = "unknown"
            return
        }
        
        // Create new debounced task
        inferenceTask = Task {
            // Wait for debounce interval
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            // Perform classification
            await performClassification(text: text)
        }
    }
    
    // Perform the actual classification
    private func performClassification(text: String) async {
        guard let model = model else {
            print("⚠️ Model not loaded")
            currentEmotion = "unknown"
            return
        }
        
        do {
            // Tokenize text
            let (inputIds, attentionMask) = simpleTokenizer(text)
            
            // Create MLMultiArrays
            let inputIdsArray = try createMLMultiArray(from: inputIds, shape: [1, 128])
            let attentionMaskArray = try createMLMultiArray(from: attentionMask, shape: [1, 128])
            
            // Create input dictionary
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": MLFeatureValue(multiArray: inputIdsArray),
                "attention_mask": MLFeatureValue(multiArray: attentionMaskArray)
            ])
            
            // Run prediction
            let prediction = try model.prediction(from: input)
            
            // Get logits output
            // Try common output key names (the exact key depends on your model's metadata)
            var logitsArray: MLMultiArray?
            let possibleKeys = ["logits", "output", "var_2", "output1"]
            
            for key in possibleKeys {
                if let feature = prediction.featureValue(for: key),
                   let array = feature.multiArrayValue {
                    logitsArray = array
                    break
                }
            }
            
            // If no key matched, try to get the first output
            if logitsArray == nil, let firstOutput = prediction.featureNames.first,
               let feature = prediction.featureValue(for: firstOutput),
               let array = feature.multiArrayValue {
                logitsArray = array
            }
            
            guard let logitsArray = logitsArray else {
                print("⚠️ Could not extract logits from prediction. Available keys: \(prediction.featureNames)")
                currentEmotion = "unknown"
                return
            }
            
            // Find argmax (index with highest value)
            var maxIndex = 0
            var maxValue = logitsArray[0].doubleValue
            
            for i in 1..<logitsArray.count {
                let value = logitsArray[i].doubleValue
                if value > maxValue {
                    maxValue = value
                    maxIndex = i
                }
            }
            
            // Map index to emotion label
            if maxIndex < emotionLabels.count {
                currentEmotion = emotionLabels[maxIndex]
            } else {
                currentEmotion = "unknown"
            }
            
        } catch {
            print("❌ Classification error: \(error)")
            currentEmotion = "unknown"
        }
    }
    
    // Get color for emotion
    func colorForEmotion(_ emotion: String) -> Color {
        switch emotion.lowercased() {
        case "sadness":
            return .blue
        case "joy":
            return .yellow
        case "love":
            return .pink
        case "anger":
            return .red
        case "fear":
            return .purple
        case "surprise":
            return .orange
        default:
            return .gray
        }
    }
}
