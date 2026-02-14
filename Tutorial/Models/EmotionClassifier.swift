//
//  EmotionClassifier.swift
//  Tutorial
//

import Foundation
import CoreML

class EmotionClassifier {
    let model: DistilBERTEmotion
    
    init() {
        do {
            let config = MLModelConfiguration()
            self.model = try DistilBERTEmotion(configuration: config)
        } catch {
            fatalError("Failed to load model: \(error)")
        }
    }
    
    func predictEmotion(for text: String) -> Emotion {
        guard let inputs = tokenize(text) else { return .neutral }
        if let emotion = classify(inputIds: inputs.inputIds, attentionMask: inputs.attentionMask) {
            return emotion
        }
        return .neutral
    }
    
    private func tokenize(_ text: String) -> (inputIds: [Int32], attentionMask: [Int32])? {
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
    
    private func classify(inputIds: [Int32], attentionMask: [Int32]) -> Emotion? {
        do {
            let size = 128
            let shape = [1, NSNumber(value: size)]
            let inputIdsArr = try MLMultiArray(shape: shape, dataType: .int32)
            let attentionMaskArr = try MLMultiArray(shape: shape, dataType: .int32)
            
            for i in 0..<size {
                inputIdsArr[i] = 0
                attentionMaskArr[i] = 0
            }
            
            for i in 0..<min(inputIds.count, size) {
                inputIdsArr[i] = NSNumber(value: inputIds[i])
                attentionMaskArr[i] = NSNumber(value: attentionMask[i])
            }
            
            let output = try model.prediction(input_ids: inputIdsArr, attention_mask: attentionMaskArr)
            let probabilities = output.linear_37
            return interpretResults(probabilities)
        } catch {
            return nil
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
        
        if let maxProb = probabilities.max(), let bestIndex = probabilities.firstIndex(of: maxProb) {
            if maxProb < threshold {
                return .neutral
            }
            return labels[bestIndex]
        }
        return nil
    }
}
