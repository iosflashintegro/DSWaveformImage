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
        // recreate render operations with new dependency (if needed(
        let udpatedRenderOperations = updateDependendentRenderOperation(anAnalyzerOperation)
        // cancel all exist operations
        cancelAllWaveformGenaration()
        // add analyzer oparation to queue
        queue.addOperation(anAnalyzerOperation)
        analyzerOperation = anAnalyzerOperation
        // if exist, add prev render operation
        udpatedRenderOperations.forEach {
            if let index = $0.index {
                renderOperations[index] = $0
            }
            queue.addOperation($0)
        }
        // Later, if new renderOperation will be created for exist index, current active operation will cancelled - it's correct
    }
    
    /// Prepare array of samples
    public func prepareSamples(amplitudes: [Float],
                               newSamplesCount: Int,
                               collectionConfiguration: Waveform.CollectionConfiguration,
                               completionHandler: ((_ updatedChunkIndexes: [Int]?) -> ())?) {
        self.collectionConfiguration = collectionConfiguration
        let chunksCount = collectionConfiguration.itemsWidth.map { Int($0 * collectionConfiguration.configuration.scale) }
        let anAnalyzerOperation = WaveformCreateChunkOperation(sourceSamples: amplitudes,
                                                               newSamplesCount: newSamplesCount,
                                                               chunksCount: chunksCount) { amplitudes, updatedChunkIndexes in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let amplitudes = amplitudes else { return }
                self.samples = amplitudes
                completionHandler?(updatedChunkIndexes)
            }
        }
        // recreate render operations with new dependency (if needed)
        let udpatedRenderOperations = updateDependendentRenderOperation(anAnalyzerOperation)

        // cancel all exist operations
        cancelAllWaveformGenaration()
        // add analyzer oparation to queue
        queue.addOperation(anAnalyzerOperation)
        analyzerOperation = anAnalyzerOperation
        // if exist, add prev render operation
        udpatedRenderOperations.forEach {
            if let index = $0.index {
                renderOperations[index] = $0
            }
            queue.addOperation($0)
        }
        // Later, if new renderOperation will be created for exist index, current active operation will cancelled - it's correct
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
                // before call completionHandler, clear renderOperations for index
                self.renderOperations[index] = nil
                completionHandler?(image, index)
            }
        }
        
        // if loading samples not called, return nil image
        guard let analyzerOperation = analyzerOperation else {
            completion(nil)
            return
        }
        
        // let cancel exist render operation
        if let existRenderOperation = renderOperations[index] {
            existRenderOperation.cancel()
            renderOperations[index] = nil
        }
        
        let configuration = collectionConfiguration.configuration.with(size: size)
        let renderOperation = WaveformImageRenderOperation(sourceSamples: nil,
                                                           configuration: configuration,
                                                           index: index,
                                                           completionHandler: completion)
        renderOperation.addDependency(analyzerOperation)
        renderOperations[index] = renderOperation
        queue.addOperations([renderOperation], waitUntilFinished: false)
    }
    
    /// Cancel all operations
    public func cancelAllWaveformGenaration() {
        queue.cancelAllOperations()
        analyzerOperation = nil
        renderOperations.removeAll()
    }
    
    /// Cancel generationImage at index
    public func cancelWaveformGeneration(index: Int) {
        if let operation = renderOperations[index] {
            operation.cancel()
            renderOperations[index] = nil
        }
    }
    
    public func activeOperationsCount() -> Int {
        return queue.operationCount
    }
    
    /// Recreate WaveformImageRenderOperation (if exist) and set dependency for its to newAnalyzerOperation
    private func updateDependendentRenderOperation(_ newAnalyzerOperation: (Operation & WaveformAnalyzerChunkOutputPass)) -> [WaveformImageRenderOperation] {
        guard let existAnalyzerOperation = analyzerOperation else {
            return []
        }
        let existRenderOperations = Array(renderOperations.values).filter( { $0.dependencies.contains(existAnalyzerOperation)} )
        var copiedOperations: [WaveformImageRenderOperation] = []
        existRenderOperations.forEach {
            if let copyRenderOperation = $0.copy() as? WaveformImageRenderOperation {
                copyRenderOperation.addDependency(newAnalyzerOperation)
                copiedOperations.append(copyRenderOperation)
            }
            $0.removeDependency(existAnalyzerOperation)
        }
        return copiedOperations
    }
}
