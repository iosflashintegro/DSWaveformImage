//
//  WaveformTimeRangeCollectionProvider.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 12.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit

/// Provider for waveform created from URL
public class WaveformTimeRangeCollectionProvider: RenderAsyncCollectionProvider {
    
    // MARK: Static
    
    private static var _sharedQueue: OperationQueue?
    override class var sharedQueue: OperationQueue? {
        get {
            return _sharedQueue
        }
        set {
            _sharedQueue = newValue
        }
    }
    
    private static var _sharedFullLoadDataQueue: DispatchQueue?
    override class var sharedFullLoadDataQueue: DispatchQueue? {
        get {
            return _sharedFullLoadDataQueue
        }
        set {
            _sharedFullLoadDataQueue = newValue
        }
    }
    
    // MARK: Instance

    private var url: URL?
    private var waveformConfiguration: Waveform.Configuration
    
    private var samplesTimeRanges: [RenderCollection.SamplesTimeRange]? // параметры интервалов для каждой из ячеек
    
    public override init(qos: QualityOfService = .userInitiated, queueType: QueueType) {
        waveformConfiguration = Waveform.Configuration()
        super.init(qos: qos, queueType: queueType)
    }
    
    /// Analyze audio from url & load all samples
    public func prepareSamples(url: URL,
                               collectionConfiguration: RenderCollection.CollectionConfiguration,
                               waveformConfiguration: Waveform.Configuration) {
        self.url = url
        self.waveformConfiguration = waveformConfiguration
        self.collectionConfiguration = collectionConfiguration

        let trackDuration = TrackHelper.getDuration(url: url)
        let anAnalyzerOperation = WaveformTimeRangeAnalyzerOperation(url: url,
                                                                     timeRange: 0...trackDuration,
                                                                     collectionConfiguration: collectionConfiguration) { ranges in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let ranges = ranges else { return }
                self.samplesTimeRanges = ranges
            }
        }
        prepareAnalyzerOperation(anAnalyzerOperation)
    }
    
    /// Create render operation
    override func createRenderOperation(for index: Int,
                                        renderData: Any?,
                                        size: CGSize,
                                        loadDataDispatchQueue: DispatchQueue,
                                        completion: (([UIImage]?) -> Void)?) -> Operation? {
        guard let url = url else { return nil }
        var samplesTimeRange: RenderCollection.SamplesTimeRange?
        if let aRenderData = renderData {
            if let timeRange = aRenderData as? RenderCollection.SamplesTimeRange {
                samplesTimeRange = timeRange
            } else {
                // in incorrect renderData type
                return nil
            }
        } else {
            // renderData may be nil
            samplesTimeRange = nil
        }
  
        let configuration = waveformConfiguration.with(size: size)
        let renderOperation = WaveformTimeRangeImageRenderOperation(url: url,
                                                                    samplesTimeRange: samplesTimeRange,
                                                                    waveformConfiguration: configuration,
                                                                    index: index,
                                                                    loadDataDispatchQueue: loadDataDispatchQueue,
                                                                    completionHandler: completion)
        return renderOperation
    }
    
    /// Invalidate already calculated after finish analyzerOperation data
    override func invalidateAnalyzeData() {
        samplesTimeRanges = nil
    }
    
    /// Check if analyzed data already exist
    override func isAnalyzeDataExist() -> Bool {
        return (samplesTimeRanges != nil)
    }
    
    /// Get already calculated analyzed data
    override func getExistAnalyzeData(index: Int) -> Any? {
        return samplesTimeRanges?[safeIndex: index]
    }
    
    /// Get analyzed data from finished operation
    override func getAnalyzeData(operation: Operation, index: Int) -> Any? {
        return (operation as? WaveformTimeRangeAnalyzerOperation)?.samplesTimeRanges?[safeIndex: index]
    }

}
