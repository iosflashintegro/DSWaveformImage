//
//  WaveformTimeRangeCollectionProvider.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 12.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit
import AVKit


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
    
    // MARK: State
    
    // состояние, откуда необходимо рендерить данные
    enum RenderState {
        case url    // загрузка данных из файла
        case cache  // загрузка данных из кешированных сэмплов
    }
    
    
    // MARK: Instance
    
    private var renderState: RenderState = .url

    private var url: URL?
    private var waveformConfiguration: Waveform.Configuration
    
    private var samplesContainer: SamplesContainer?

    private var cacheCollectionProvider: WaveformSamplesCollectionProvider
    
    
    public override init(qos: QualityOfService = .userInitiated, queueType: QueueType) {
        waveformConfiguration = Waveform.Configuration()
        cacheCollectionProvider = WaveformSamplesCollectionProvider(qos: qos, queueType: queueType, isSyncAnalyze: true)
        super.init(qos: qos, queueType: queueType)
    }
    
    /// Analyze audio from url & load all samples
    public func prepareSamples(url: URL,
                               timeRange: CMTimeRange,
                               collectionConfiguration: RenderCollection.CollectionConfiguration,
                               waveformConfiguration: Waveform.Configuration) {
        self.renderState = .url
        
        self.url = url
        self.waveformConfiguration = waveformConfiguration
        self.collectionConfiguration = collectionConfiguration

        let anAnalyzerOperation = WaveformTimeRangeAnalyzerOperation(timeRange: timeRange,
                                                                     collectionConfiguration: collectionConfiguration) { ranges in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let ranges = ranges else { return }
                self.samplesContainer = SamplesContainer(fullTimeRange: timeRange,
                                                         samplesTimeRanges: ranges)
            }
        }
        prepareAnalyzerOperation(anAnalyzerOperation)
    }
    
    /// Recreate eixst anaylized samples with new collectionConfiguration
    /// - Returns:
    ///     - true: if all samples already loading
    ///     - false: in antother cases
    public func prepareExistSamples(timeRange: CMTimeRange,
                                    collectionConfiguration: RenderCollection.CollectionConfiguration,
                                    waveformConfiguration: Waveform.Configuration) -> Bool {
        guard let samplesContainer = samplesContainer else { return false }
        if samplesContainer.fullTimeRange != timeRange { return false }
        let linearSamples = samplesContainer.linearSamples
        if linearSamples.count == 0 { return false }
        
        self.renderState = .cache
        
        self.collectionConfiguration = collectionConfiguration
        self.waveformConfiguration = waveformConfiguration
        
        // изменим (если нужно) кол-во сэмплов под заданные отображаемые размеры
        let targetSamplesCount = Int(collectionConfiguration.visibleWidth * waveformConfiguration.scale)
        let targetSamples = Resampler.resample(array: linearSamples, toSize: targetSamplesCount)

        cacheCollectionProvider.prepareSamples(amplitudes: targetSamples,
                                               newSamplesCount: targetSamples.count,
                                               duration: timeRange.duration,
                                               collectionConfiguration: collectionConfiguration,
                                               waveformConfiguration: waveformConfiguration) { _ in
        }
        
        return true
    }
    
    
    /// Get image for target index
    public override func getImages(for index: Int,
                                   size: CGSize,
                                   completionHandler: ((_ imagesDataSource: RenderCellData.ImagesSource?, _ index: Int) -> Void)?) {
        switch renderState {

        case .url:
            super.getImages(for: index,
                            size: size) { imagesDataSource, index in
                guard let imagesSamplesDataSource = imagesDataSource as? RenderCellData.ImagesSamplesSource else {
                    completionHandler?(imagesDataSource, index)
                    return
                }

                // также сохраним данные сэмплов
                self.samplesContainer?.setupSamples(imagesSamplesDataSource.samples, index: index)
                completionHandler?(imagesDataSource, index)
            }

        case .cache:
            // при получении данных при рендеринге кешированных данных дополнительно обновлять ничего не нужно
            cacheCollectionProvider.getImages(for: index,
                                              size: size,
                                              completionHandler: completionHandler)
        }
    }
        
    /// Create render operation
    override func createRenderOperation(for index: Int,
                                        renderData: Any?,
                                        size: CGSize,
                                        loadDataDispatchQueue: DispatchQueue,
                                        completion: ((RenderCellData.ImagesSource?) -> Void)?) -> Operation? {
        switch renderState {
        case .url:
            return createUrlRenderOperation(for: index,
                                            renderData: renderData,
                                            size: size,
                                            loadDataDispatchQueue: loadDataDispatchQueue,
                                            completion: completion)
        case .cache:
            return cacheCollectionProvider.createRenderOperation(for: index,
                                                                 renderData: renderData,
                                                                 size: size,
                                                                 loadDataDispatchQueue: loadDataDispatchQueue,
                                                                 completion: completion)
        }
    }
    
    /// Invalidate already calculated after finish analyzerOperation data
    override func invalidateAnalyzeData() {
        samplesContainer = nil
    }
    
    /// Check if analyzed data already exist
    override func isAnalyzeDataExist() -> Bool {
        return (samplesContainer != nil)
    }
    
    /// Get already calculated analyzed data
    override func getExistAnalyzeData(index: Int) -> Any? {
        return samplesContainer?.samplesTimeRanges[safeIndex: index]
    }
    
    /// Get analyzed data from finished operation
    override func getAnalyzeData(operation: Operation, index: Int) -> Any? {
        return (operation as? WaveformTimeRangeAnalyzerOperation)?.samplesTimeRanges?[safeIndex: index]
    }

}


// MARK: Private methods
extension WaveformTimeRangeCollectionProvider {
 
    private func createUrlRenderOperation(for index: Int,
                                          renderData: Any?,
                                          size: CGSize,
                                          loadDataDispatchQueue: DispatchQueue,
                                          completion: ((RenderCellData.ImagesSource?) -> Void)?) -> Operation? {
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
}
