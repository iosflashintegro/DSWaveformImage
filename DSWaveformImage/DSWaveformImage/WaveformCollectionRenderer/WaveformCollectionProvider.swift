//
//  WaveformCollectionProvider.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 30.09.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit

/// Provider for waveform devided into chunks.
public class WaveformCollectionProvider: RenderCollectionProvider {

    private var waveformConfiguration: Waveform.Configuration
    private var samples: [[Float]] = []
    
    public override init(qos: QualityOfService = .userInitiated) {
        waveformConfiguration = Waveform.Configuration()
        super.init(qos: qos)
    }
    
    /// Analyze audio from url & load all samples
    public func prepareSamples(fromAudioAt audioAssetURL: URL,
                               collectionConfiguration: RenderCollection.CollectionConfiguration,
                               waveformConfiguration: Waveform.Configuration) {
        self.collectionConfiguration = collectionConfiguration
        self.waveformConfiguration = waveformConfiguration
        let sampleCount = Int(collectionConfiguration.collectionWidth * waveformConfiguration.scale)
        let chunksCount = collectionConfiguration.itemsWidth.map { Int($0 * waveformConfiguration.scale) }
        let anAnalyzerOperation = WaveformAnalyzerOperation(audioAssetURL: audioAssetURL,
                                                            count: sampleCount,
                                                            chunksCount: chunksCount,
                                                            completionHandler: { amplitudes in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let amplitudes = amplitudes else { return }
                self.samples = amplitudes
            }
        })
        prepareAnalyzerOperation(anAnalyzerOperation)
    }
    
    /// Prepare array of samples
    public func prepareSamples(amplitudes: [Float],
                               newSamplesCount: Int,
                               collectionConfiguration: RenderCollection.CollectionConfiguration,
                               waveformConfiguration: Waveform.Configuration,
                               completionHandler: ((_ updatedChunkIndexes: [Int]?) -> ())?) {
        self.collectionConfiguration = collectionConfiguration
        self.waveformConfiguration = waveformConfiguration
        let chunksCount = collectionConfiguration.itemsWidth.map { Int($0 * waveformConfiguration.scale) }
        let anAnalyzerOperation = WaveformCreateChunkOperation(sourceSamples: amplitudes,
                                                               newSamplesCount: newSamplesCount,
                                                               chunksCount: chunksCount) { amplitudes, updatedChunkIndexes in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let amplitudes = amplitudes else { return }
                self.samples = amplitudes
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
        let renderOperation = WaveformImageRenderOperation(sourceSamples: nil,
                                                           configuration: configuration,
                                                           index: index,
                                                           completionHandler: completion)
        return renderOperation
    }
}
