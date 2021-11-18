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
public class WaveformTimeRangeCollectionProvider: RenderCollectionProvider {
    
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
    
    // MARK: Instance

    private var url: URL?
    private var waveformConfiguration: Waveform.Configuration
    
    private var samplesTimeRanges: [RenderCollection.SamplesTimeRange] = []  // параметры интервалов для каждой из ячеек
    
    public override init(qos: QualityOfService = .userInitiated, shared: Bool = false) {
        waveformConfiguration = Waveform.Configuration()
        super.init(qos: qos, shared: shared)
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
                                        size: CGSize,
                                        completion: (([UIImage]?) -> Void)?) -> Operation? {
        guard let url = url else { return nil }
        let configuration = waveformConfiguration.with(size: size)
        let renderOperation = WaveformTimeRangeImageRenderOperation(url: url,
                                                                    samplesTimeRange: nil,
                                                                    waveformConfiguration: configuration,
                                                                    index: index,
                                                                    completionHandler: completion)
        return renderOperation
    }
}
