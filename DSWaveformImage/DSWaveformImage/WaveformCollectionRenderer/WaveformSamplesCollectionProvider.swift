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
    
    private static var _sharedLoadDataQueue: DispatchQueue?
    override class var sharedLoadDataQueue: DispatchQueue? {
        get {
            return _sharedLoadDataQueue
        }
        set {
            _sharedLoadDataQueue = newValue
        }
    }
    
    // MARK: Instance
    
    private var url: URL?
    private var waveformConfiguration: Waveform.Configuration
    
    private var samples: [[Float]]?
    
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
                               completionHandler: ((_ updatedChunkIndexes: [Int]?) -> Void)?) {
        self.collectionConfiguration = collectionConfiguration
        self.waveformConfiguration = waveformConfiguration
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
    
    /// Create render operation
    override func createRenderOperation(for index: Int,
                                        renderData: Any?,
                                        size: CGSize,
                                        loadDataDispatchQueue: DispatchQueue,
                                        completion: (([UIImage]?) -> Void)?) -> Operation? {
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
