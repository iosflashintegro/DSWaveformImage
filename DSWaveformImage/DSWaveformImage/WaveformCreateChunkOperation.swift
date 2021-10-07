//
//  WaveformCreateChunkOperation.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 07.10.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit

public class WaveformCreateChunkOperation: Operation {
    private var sourceSamples: [Float]
    private var chunksCount: [Int] = []
    private var completionHandler: ((_ amplitudes: [[Float]]?) -> ())?
    
    private var outputChunkAmplitudes: [[Float]]?

    public init(sourceSamples: [Float],
                chunksCount: [Int],
                completionHandler: ((_ amplitudes: [[Float]]?) -> ())?) {
        self.sourceSamples = sourceSamples
        self.chunksCount = chunksCount
        self.completionHandler = completionHandler
    }
    
    override public func main() {
        let countInChunks = chunksCount.reduce(0, +)
        if sourceSamples.count != countInChunks {
            sourceSamples = resampling(sourceSamples, to: countInChunks)
        }
        if self.isCancelled {
            return
        }
        outputChunkAmplitudes = sourceSamples.chunked(elementCounts: chunksCount)
        completionHandler?(outputChunkAmplitudes)
    }

    private func resampling(_ samples: [Float], to count: Int) -> [Float] {
        if samples.isEmpty {
            return []
        }
        if samples.count < count, let first = samples.first {
            // add repeat samples on begin of samples
            let diffCount = count - samples.count
            let insertSamples = Array(repeating: first, count: diffCount)
            var targetSamples = samples
            targetSamples.insert(contentsOf: insertSamples, at: 0)
            return targetSamples
        } else if samples.count > count {
            // TODO: Incorrect behaviour
            return Array(samples[0...(count-1)])
        } else {
            return samples
        }
    }
}

extension WaveformCreateChunkOperation: WaveformAnalyzerChunkOutputPass {
    var chunkAmplitudes: [[Float]]? {
        return outputChunkAmplitudes
    }
}
