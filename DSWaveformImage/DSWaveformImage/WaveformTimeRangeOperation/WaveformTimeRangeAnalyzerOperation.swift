//
//  WaveformTimeRangeAnalyzerOperation.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 12.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation


public protocol WaveformTimeRangeAnalyzerOutputPass {
    var samplesTimeRanges: [RenderCollection.SamplesTimeRange]? { get }
}

/// Calculates time ranges from URL.
class WaveformTimeRangeAnalyzerOperation: Operation {
    
    // MARK: Private properties
    private var url: URL
    private var timeRange: ClosedRange<TimeInterval>
    private var collectionConfiguration: RenderCollection.CollectionConfiguration
    private var completionHandler: ((_ ranges: [RenderCollection.SamplesTimeRange]?) -> ())?
    
    private var outputTimeRanges: [RenderCollection.SamplesTimeRange]?
    
    // MARK: Constructors/Destructors/Init
    
    /// - Parameter url: video file url.
    /// - Parameter timeRange: track interval
    /// - Parameter collectionConfiguration: totalWidth & itemWidth for rendering previews.
    /// - Parameter completionHandler: called from a background thread. Returns array of timestampRange for each range.
    init(url: URL,
         timeRange: ClosedRange<TimeInterval>,
         collectionConfiguration: RenderCollection.CollectionConfiguration,
         completionHandler: ((_ ranges: [RenderCollection.SamplesTimeRange]?) -> ())?) {
        self.url = url
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
