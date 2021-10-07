//
//  WaveformCollectionProvider.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 30.09.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit

/// Provider for waveform devided to chunks.
public class WaveformCollectionProvider {
    private var analyzerOperation: (Operation & WaveformAnalyzerChunkOutputPass)?
    private var adapterOperations: [Int: Operation] = [:]                       // adapter operations, created for link analyzerOperation with renderOperation,
                                                                                // created only if analyzerOperation not completed. key - index
    private var renderOperations: [Int: WaveformImageRenderOperation] = [:]     // render operations. key - index
    
    private var qos: QualityOfService
    private var queue: OperationQueue

    private var collectionConfiguration: Waveform.CollectionConfiguration
    private var samples: [[Float]] = []
    
    
    public init(qos: QualityOfService = .userInitiated) {
        self.qos = qos
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = qos
        queue.name = "WaveformCollectionProvider" + NSUUID().uuidString
        
        collectionConfiguration = Waveform.CollectionConfiguration(collectionWidth: 0,
                                                                   itemsWidth: [],
                                                                   configuration: Waveform.Configuration())
    }
    
    deinit {
        cancelAllWaveformGenaration()
    }
    
    /// Analyze audio from url & load all samples
    public func prepareSamples(fromAudioAt audioAssetURL: URL,
                               collectionConfiguration: Waveform.CollectionConfiguration) {
        cancelAllWaveformGenaration()
        
        self.collectionConfiguration = collectionConfiguration
        let sampleCount = Int(collectionConfiguration.collectionWidth * collectionConfiguration.configuration.scale)
        let chunksCount = collectionConfiguration.itemsWidth.map { Int($0 * collectionConfiguration.configuration.scale) }
        let anAnalyzerOperation = WaveformAnalyzerOperation(audioAssetURL: audioAssetURL,
                                                            count: sampleCount,
                                                            chunksCount: chunksCount,
                                                            completionHandler: { amplitudes in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let amplitudes = amplitudes else { return }
                self.samples = amplitudes
            }
        })
        queue.addOperation(anAnalyzerOperation)
        analyzerOperation = anAnalyzerOperation
    }
    
    /// Prepare array of samples
    public func prepareSamples(amplitudes: [Float],
                               collectionConfiguration: Waveform.CollectionConfiguration) {
        cancelAllWaveformGenaration()

        self.collectionConfiguration = collectionConfiguration
        let chunksCount = collectionConfiguration.itemsWidth.map { Int($0 * collectionConfiguration.configuration.scale) }
        let anAnalyzerOperation = WaveformCreateChunkOperation(sourceSamples: amplitudes,
                                                               chunksCount: chunksCount) { amplitudes in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let amplitudes = amplitudes else { return }
                self.samples = amplitudes
            }
        }
        queue.addOperation(anAnalyzerOperation)
        analyzerOperation = anAnalyzerOperation
    }
    
    
    /// Get image for target index
    public func getImage(for index: Int,
                         size: CGSize,
                         completionHandler: ((_ waveformImage: UIImage?, _ index: Int) -> ())?) {
        let completion: (UIImage?) -> Void = { image in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    completionHandler?(nil, index)
                    return
                }
                // before call completionHandler, clear adapterOperations & renderOperations for index
                self.adapterOperations[index] = nil
                self.renderOperations[index] = nil
                completionHandler?(image, index)
            }
        }
        
        // if loading samples not called, return nil image
        guard let analyzerOperation = analyzerOperation else {
            completion(nil)
            return
        }
        
        let configuration = collectionConfiguration.configuration.with(size: size)
        let renderOperation = WaveformImageRenderOperation(sourceSamples: nil,
                                                           configuration: configuration,
                                                           completionHandler: completion)
        let adapter = BlockOperation(block: { [weak self, weak renderOperation] in
            guard let self = self, let renderOperation = renderOperation else {
                completion(nil)
                return
            }
            renderOperation.sourceSamples = self.analyzerOperation?.chunkAmplitudes?[safeIndex: index]
        })
        adapter.addDependency(analyzerOperation)
        renderOperation.addDependency(adapter)
        
        adapterOperations[index] = adapter
        renderOperations[index] = renderOperation

        queue.addOperations([adapter, renderOperation], waitUntilFinished: false)
    }
    
    /// Cancel all operations
    public func cancelAllWaveformGenaration() {
        queue.cancelAllOperations()
        analyzerOperation = nil
        adapterOperations.removeAll()
        renderOperations.removeAll()
    }
    
    /// Cancel generationImage at index
    public func cancelWaveformGeneration(index: Int) {
        if let operation = adapterOperations[index] {
            operation.cancel()
            adapterOperations[index] = nil
        }
        if let operation = renderOperations[index] {
            operation.cancel()
            renderOperations[index] = nil
        }
    }
    
    public func activeOperationsCount() -> Int {
        return queue.operationCount
    }
}
