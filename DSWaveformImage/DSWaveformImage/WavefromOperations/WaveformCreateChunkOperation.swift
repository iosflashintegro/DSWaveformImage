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
    private var newSamplesCount: Int = 0
    private var chunksCount: [Int] = []
    private var completionHandler: ((_ amplitudes: [[Float]]?, _ updatedChunkIndexes: [Int]?) -> ())?
    
    private var outputChunkAmplitudes: [[Float]]?

    /// - Parameter sourceSamples: media file url.
    /// - Parameter chunksCount - amount of samples on each chunks
    /// - Parameter newSamplesCount: amount updated samples in sourceSamples (compared with previous request)
    /// - Parameter completionHandler: called from a background thread. Returns (the sampled result and index of updated chunk)  or nil in edge-error cases.
    public init(sourceSamples: [Float],
                newSamplesCount: Int,
                chunksCount: [Int],
                completionHandler: ((_ amplitudes: [[Float]]?, _ updatedChunkIndexes: [Int]?) -> ())?) {
        self.sourceSamples = sourceSamples
        self.newSamplesCount = newSamplesCount
        self.chunksCount = chunksCount
        self.completionHandler = completionHandler
    }
    
    override public func main() {
        if self.isCancelled {
            return
        }
        
        if sourceSamples.count == 0 || chunksCount.count == 0 {
            completionHandler?(nil, nil)
            return
        }
        
        let countInChunks = chunksCount.reduce(0, +)
        if sourceSamples.count != countInChunks {
            sourceSamples = resampling(sourceSamples, to: countInChunks)
        }
        outputChunkAmplitudes = sourceSamples.chunked(elementCounts: chunksCount)
        let updatedChunkIndexes = chunkIndexesForUpdatedSamles(count: newSamplesCount)
        completionHandler?(outputChunkAmplitudes, updatedChunkIndexes)
    }
    
    /// - Returns: Indexes of chunk for updated new samples
    private func chunkIndexesForUpdatedSamles(count: Int) -> [Int]? {
        guard let chunkAmplitudes = outputChunkAmplitudes, newSamplesCount > 0 else {
            return nil
        }
        
        var targetChunkIndexes: [Int] = []
        var sampleCount = newSamplesCount
        for index in stride(from: (chunkAmplitudes.count-1), through: 0, by: -1) {
            if sampleCount > 0 {
                targetChunkIndexes.append(index)
                sampleCount -= chunkAmplitudes[index].count
            } else {
                break
            }
        }
        return targetChunkIndexes
    }

    private func resampling(_ samples: [Float], to count: Int) -> [Float] {
        if samples.isEmpty || count <= 0 {
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
    public var chunkAmplitudes: [[Float]]? {
        return outputChunkAmplitudes
    }
}
