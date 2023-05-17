//
//  WaveformSamplesCollectionProvider.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 15.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit
import AVKit

/// Provider for waveform created from samples
public class WaveformSamplesCollectionProvider: RenderAsyncCollectionProvider {
    
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
    private var isSyncAnalyze: Bool // call analyze operation sync or async
    
    private var samples: [[Float]]?
    
    public init(qos: QualityOfService = .userInitiated,
                queueType: QueueType,
                isSyncAnalyze: Bool) {
        waveformConfiguration = Waveform.Configuration()
        self.isSyncAnalyze = isSyncAnalyze
        super.init(qos: qos, queueType: queueType)
    }
    
    /// Prepare array of samples
    public func prepareSamples(amplitudes: [Float],
                               newSamplesCount: Int,
                               duration: CMTime,
                               collectionConfiguration: RenderCollection.CollectionConfiguration,
                               waveformConfiguration: Waveform.Configuration,
                               completionHandler: ((_ updatedChunkIndexes: [Int]?) -> Void)?) {
        self.collectionConfiguration = collectionConfiguration
        self.waveformConfiguration = waveformConfiguration
        
        if isSyncAnalyze {
            // в случае синхронного вызова операцию анализа запускаем синхронно (она довольно быстрая)
            // для того, чтобы сэкономить время на переход между потоками

            clearAllOperations()
            let anAnalyzerOperation = WaveformSamplesAnalyzeChunkOperation(sourceSamples: amplitudes,
                                                                           newSamplesCount: newSamplesCount,
                                                                           duration: duration,
                                                                           collectionConfiguration: collectionConfiguration) { amplitudes, updatedChunkIndexes, _ in
                guard let amplitudes = amplitudes else { return }
                self.samples = amplitudes
                completionHandler?(updatedChunkIndexes)
            }
            setupAnalyzerOperation(anAnalyzerOperation)
            anAnalyzerOperation.start()
        } else {
            let anAnalyzerOperation = WaveformSamplesAnalyzeChunkOperation(sourceSamples: amplitudes,
                                                                           newSamplesCount: newSamplesCount,
                                                                           duration: duration,
                                                                           collectionConfiguration: collectionConfiguration) { amplitudes, updatedChunkIndexes, _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let amplitudes = amplitudes else { return }
                    self.samples = amplitudes
                    completionHandler?(updatedChunkIndexes)
                }
            }
            prepareAnalyzerOperation(anAnalyzerOperation)
        }
    }
    
    /// Create render operation
    override func createRenderOperation(for index: Int,
                                        renderData: Any?,
                                        size: CGSize,
                                        loadDataDispatchQueue: DispatchQueue,
                                        completion: ((RenderCellData.ImagesSource?) -> Void)?) -> Operation? {
        var samplesAtIndex: [Float]?
        if let aRenderData = renderData {
            if let aSamplesAtIndex = aRenderData as? [Float] {
                samplesAtIndex = aSamplesAtIndex
            } else {
                // in incorrect renderData type
                return nil
            }
        } else {
            // renderData may be nil
            samplesAtIndex = nil
        }
        
        let configuration = waveformConfiguration.with(size: size)
        let renderOperation = WaveformSamplesImageRenderOperation(sourceSamples: samplesAtIndex,
                                                                  configuration: configuration,
                                                                  index: index,
                                                                  loadDataDispatchQueue: loadDataDispatchQueue,
                                                                  completionHandler: completion)
        return renderOperation
    }
    
    /// Invalidate already calculated after finish analyzerOperation data
    override func invalidateAnalyzeData() {
        samples = nil
    }
    
    /// Check if analyzed data already exist
    override func isAnalyzeDataExist() -> Bool {
        return (samples != nil)
    }
    
    /// Get already calculated analyzed data
    override func getExistAnalyzeData(index: Int) -> Any? {
        return samples?[safeIndex: index]
    }
    
    /// Get analyzed data from finished operation
    override func getAnalyzeData(operation: Operation, index: Int) -> Any? {
        return (operation as? WaveformSamplesAnalyzerChunkOutputPass)?.chunkAmplitudes?[safeIndex: index]
    }
}
