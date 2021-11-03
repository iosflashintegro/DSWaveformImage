//
//  WaveformLiveImageRenderOperation.swift
//  DSWaveformImage
//
//  Created by Dmitry Nuzhin on 27.09.2021.
//  Copyright © 2021 Dennis Schmidt. All rights reserved.
//

import Foundation
import UIKit

class WaveformLiveImageRenderOperation: WaveformImageRenderOperation {
    // MARK: Private properties
    private var sourceContext: CGContext?
    private var newSampleCount: Int = 0
    private var shouldDrawSilencePadding: Bool = false
    
    public init(sourceSamples: [Float],
                newSampleCount: Int,
                configuration: Waveform.Configuration,
                context: CGContext,
                lastOffset: Int = 0,
                shouldDrawSilencePadding: Bool = false) {
        super.init(sourceSamples: sourceSamples,
                   configuration: configuration,
                   completionHandler: nil)
        self.newSampleCount = newSampleCount
        self.sourceContext = context
        self.lastOffset = lastOffset
        self.shouldDrawSilencePadding = shouldDrawSilencePadding
    }

    override public func main() {
        _ = draw()
    }
    
    // MARK: Public methods
    
    /// - Returns:Возвращает текущую позицию lastOffset
    public func draw() -> Int {
        guard let sourceSamples = sourceSamples, let sourceContext = sourceContext else { return lastOffset }
        guard sourceSamples.count > 0 || shouldDrawSilencePadding else {
            return lastOffset
        }

        if self.isCancelled {
            return lastOffset
        }
        
        let samplesNeeded = Int(configuration.size.width * configuration.scale)

        if case .striped = configuration.style, sourceSamples.count >= samplesNeeded {
            lastOffset = (lastOffset + newSampleCount) % stripeBucket(configuration)
        }

        // move the window, so that its always at the end (moves the graph after it reached the right side)
        let startSample = max(0, sourceSamples.count - samplesNeeded)
        let clippedSamples = Array(sourceSamples[startSample..<sourceSamples.count])
        let dampenedSamples = configuration.shouldDampen ? dampen(clippedSamples, with: configuration) : clippedSamples
        let paddedSamples = shouldDrawSilencePadding ? dampenedSamples + Array(repeating: 1, count: samplesNeeded - clippedSamples.count) : dampenedSamples

        draw(on: sourceContext, from: paddedSamples, with: configuration)
        return lastOffset
    }
}
