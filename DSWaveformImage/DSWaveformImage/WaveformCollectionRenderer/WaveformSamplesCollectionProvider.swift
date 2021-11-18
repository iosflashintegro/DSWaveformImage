//
//  WaveformSamplesCollectionProvider.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 15.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit

/// Provider for waveform created from samples
public class WaveformSamplesCollectionProvider: RenderCollectionProvider {
    
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
    private var samples: [[Float]] = []
    
    public override init(qos: QualityOfService = .userInitiated, shared: Bool = false) {
        waveformConfiguration = Waveform.Configuration()
        super.init(qos: qos, shared: shared)
    }
    
    /// Prepare array of samples
    public func prepareSamples(amplitudes: [Float],
                               newSamplesCount: Int,
                               duration: TimeInterval,
                               collectionConfiguration: RenderCollection.CollectionConfiguration,
                               waveformConfiguration: Waveform.Configuration,
                               completionHandler: ((_ updatedChunkIndexes: [Int]?) -> ())?) {
        self.collectionConfiguration = collectionConfiguration
        self.waveformConfiguration = waveformConfiguration
        let anAnalyzerOperation = WaveformSamplesAnalyzeChunkOperation(sourceSamples: amplitudes,
                                                                       newSamplesCount: newSamplesCount,
                                                                       duration: duration,
                                                                       collectionConfiguration: collectionConfiguration) { amplitudes, updatedChunkIndexes, ranges in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let amplitudes = amplitudes, let ranges = ranges else { return }
                self.samples = amplitudes
                self.samplesTimeRanges = ranges
                completionHandler?(updatedChunkIndexes)
            }
        }
        prepareAnalyzerOperation(anAnalyzerOperation)
    }
    
    /// Create render operation
    override func createRenderOperation(for index: Int,
                                        size: CGSize,
                                        completion: (([UIImage]?) -> Void)?) -> Operation? {
        let configuration = waveformConfiguration.with(size: size)
        let renderOperation = WaveformSamplesImageRenderOperation(sourceSamples: nil,
                                                                  configuration: configuration,
                                                                  index: index,
                                                                  completionHandler: completion)
        return renderOperation
    }
}
