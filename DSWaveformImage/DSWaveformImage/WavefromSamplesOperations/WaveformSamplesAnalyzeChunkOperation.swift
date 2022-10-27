//
//  WaveformSamplesAnalyzeChunkOperation.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 07.10.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit
import AVKit


/// Calculates samples devided to chunk from linear samples
public class WaveformSamplesAnalyzeChunkOperation: Operation {
    private var sourceSamples: [Float]
    private var newSamplesCount: Int = 0
    private var duration: CMTime = .zero
    private var collectionConfiguration: RenderCollection.CollectionConfiguration
    private var completionHandler: ((_ amplitudes: [[Float]]?, _ updatedChunkIndexes: [Int]?, _ ranges: [RenderCollection.SamplesTimeRange]?) -> Void)?
    
    private var outputTimeRanges: [RenderCollection.SamplesTimeRange]?
    private var outputChunkAmplitudes: [[Float]]?

    /// - Parameter sourceSamples: all samples
    /// - Parameter chunksCount - amount of samples on each chunks
    /// - Parameter newSamplesCount: amount updated samples in sourceSamples (compared with previous request)
    /// - Parameter completionHandler: called from a background thread. Returns (the sampled result and index of updated chunk)  or nil in edge-error cases.
    public init(sourceSamples: [Float],
                newSamplesCount: Int,
                duration: CMTime,
                collectionConfiguration: RenderCollection.CollectionConfiguration,
                completionHandler: ((_ amplitudes: [[Float]]?, _ updatedChunkIndexes: [Int]?, _ ranges: [RenderCollection.SamplesTimeRange]?) -> Void)?) {
        self.sourceSamples = sourceSamples
        self.newSamplesCount = newSamplesCount
        self.duration = duration
        self.collectionConfiguration = collectionConfiguration
        self.completionHandler = completionHandler
    }
    
    override public func main() {
        if self.isCancelled {
            return
        }
        
        let chunksCount = collectionConfiguration.itemsWidth.map { Int($0) }
        
        if sourceSamples.count == 0 || chunksCount.count == 0 {
            completionHandler?(nil, nil, nil)
            return
        }
        
        let countInChunks = chunksCount.reduce(0, +)
        if sourceSamples.count != countInChunks {
            sourceSamples = resampling(sourceSamples, to: countInChunks)
        }
        outputChunkAmplitudes = sourceSamples.chunked(elementCounts: chunksCount)
        let updatedChunkIndexes = chunkIndexesForUpdatedSamles(count: newSamplesCount)
        
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        outputTimeRanges = RenderCollection.createSamplesRanges(timeRange: timeRange,
                                                                collectionConfiguration: collectionConfiguration)
        completionHandler?(outputChunkAmplitudes, updatedChunkIndexes, outputTimeRanges)
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


// MARK: WaveformSamplesAnalyzerChunkOutputPass
extension WaveformSamplesAnalyzeChunkOperation: WaveformSamplesAnalyzerChunkOutputPass {
    public var chunkAmplitudes: [[Float]]? {
        return outputChunkAmplitudes
    }
}


// MARK: WaveformTimeRangeAnalyzerOutputPass
extension WaveformSamplesAnalyzeChunkOperation: WaveformTimeRangeAnalyzerOutputPass {
    public var samplesTimeRanges: [RenderCollection.SamplesTimeRange]? {
        return outputTimeRanges
    }
}
