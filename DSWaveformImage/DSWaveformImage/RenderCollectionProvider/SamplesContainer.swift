//
//  SamplesContainer.swift
//  VSDCTests
//
//  Created by Dmitry Nuzhin on 16.05.2023.
//  Copyright © 2023 FlashIntegro. All rights reserved.
//

import Foundation
import AVKit


/// Хранилище разбиений на интервалы и всех сэмплов
open class SamplesContainer {
    
    // длительность всего интервала, который разбивается на участки
    private(set) var fullTimeRange: CMTimeRange
    // инфо о необходимом разбиении на интервалы
    private(set) var samplesTimeRanges: [RenderCollection.SamplesTimeRange]
    // непосредственно сэмплы для заданных интервалов
    private var fullSamples: [Int: [Float]] = [:]
    
    // линейная последовательность всех сэмплов
    // (валидна только если isCompleteFill())
    public var linearSamples: [Float] {
        let keys = fullSamples.keys.sorted()
        var targetSamples: [Float] = []
        for key in keys {
            if let samples = fullSamples[key] {
                targetSamples.append(contentsOf: samples)
            }
        }
        return targetSamples
    }

    
    init(fullTimeRange: CMTimeRange,
         samplesTimeRanges: [RenderCollection.SamplesTimeRange]) {
        self.fullTimeRange = fullTimeRange
        self.samplesTimeRanges = samplesTimeRanges
    }

    
    public func setupSamples(_ samples: [Float], index: Int) {
        if !isCorrectIndex(index) { return }
        if !isCorrectCount(samples: samples, index: index) { return }
        fullSamples[index] = samples
    }
    
    public func isCompleteFill() -> Bool {
        return samplesTimeRanges.count == fullSamples.count
    }
    
    
    private func isCorrectIndex(_ index: Int) -> Bool {
        return index >= 0 && index < samplesTimeRanges.count
    }
    
    private func isCorrectCount(samples: [Float], index: Int) -> Bool {
        guard let samplesTimeRange = samplesTimeRanges[safeIndex: index] else { return false }
        return samplesTimeRange.samplesCount == samples.count
    }
    
    private func clear() {
        fullSamples.removeAll()
    }
}
