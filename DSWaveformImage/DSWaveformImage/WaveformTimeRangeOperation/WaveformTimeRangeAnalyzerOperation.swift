//
//  WaveformTimeRangeAnalyzerOperation.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 12.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import AVKit


public protocol WaveformTimeRangeAnalyzerOutputPass {
    var samplesTimeRanges: [RenderCollection.SamplesTimeRange]? { get }
}

/// Calculates time ranges for RenderCollection.CollectionConfiguration
class WaveformTimeRangeAnalyzerOperation: Operation {
    
    // MARK: Private properties
    private var timeRange: CMTimeRange
    private var collectionConfiguration: RenderCollection.CollectionConfiguration
    private var completionHandler: ((_ ranges: [RenderCollection.SamplesTimeRange]?) -> Void)?
    
    private var outputTimeRanges: [RenderCollection.SamplesTimeRange]?
    
    // MARK: Constructors/Destructors/Init
    
    /// - Parameter url: video file url.
    /// - Parameter timeRange: track interval
    /// - Parameter collectionConfiguration: totalWidth & itemWidth for rendering previews.
    /// - Parameter completionHandler: called from a background thread. Returns array of timestampRange for each range.
    init(timeRange: CMTimeRange,
         collectionConfiguration: RenderCollection.CollectionConfiguration,
         completionHandler: ((_ ranges: [RenderCollection.SamplesTimeRange]?) -> Void)?) {
        self.timeRange = timeRange
        self.collectionConfiguration = collectionConfiguration
        self.completionHandler = completionHandler
    }
    
    override func main() {
        if self.isCancelled {
            return
        }
        outputTimeRanges = RenderCollection.createSamplesRanges(timeRange: timeRange,
                                                                collectionConfiguration: collectionConfiguration)
        completionHandler?(outputTimeRanges)
    }
}


// MARK: WaveformTimeRangeAnalyzerOutputPass
extension WaveformTimeRangeAnalyzerOperation: WaveformTimeRangeAnalyzerOutputPass {
    public var samplesTimeRanges: [RenderCollection.SamplesTimeRange]? {
        return outputTimeRanges
    }
}
