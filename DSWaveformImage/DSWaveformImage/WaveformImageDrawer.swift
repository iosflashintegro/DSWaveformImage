import Foundation
import AVFoundation
import UIKit
import CoreGraphics
import vsdcCommonServices

/// Renders a UIImage of the waveform data calculated by the analyzer.
public class WaveformImageDrawer {
    /// only internal; determines whether to draw silence lines in live mode.
    var shouldDrawSilencePadding: Bool = false
    /// Makes sure we always look at the same samples while animating
    private var lastOffset: Int = 0

    private var qos: QualityOfService
    private var queue: OperationQueue
    
    public init(qos: QualityOfService = .userInitiated) {
        self.qos = qos
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = qos
        queue.name = "WaveformImageDrawerOperation_" + UUID().uuidString
    }
    
    deinit {
        cancelWaveformGeneration()
    }
    
    
    /// Async analyzes the provided audio and renders a UIImage of the waveform data calculated by the analyzer.
    public func waveformImage(fromAudioAt audioAssetURL: URL,
                              with configuration: Waveform.Configuration,
                              completionHandler: @escaping (_ waveformImage: UIImage?) -> Void) {
        cancelWaveformGeneration()
        
        let sampleCount = Int(configuration.size.width * configuration.scale)
        let analyzerOperation = WaveformSamplesAnalyzeUrlOperation(audioAssetURL: audioAssetURL,
                                                                   count: sampleCount,
                                                                   completionHandler: nil)

        let renderOperation = WaveformSamplesImageRenderOperation(sourceSamples: nil,
                                                                  configuration: configuration,
                                                                  loadDataDispatchQueue: DispatchQueue(label: "WaveformImageDrawer" + UUID().uuidString),
                                                                  completionHandler: { imagesDataSouece in
            if let imagesDataSouece = imagesDataSouece {
                completionHandler(imagesDataSouece.images[safeIndex: 0])
            } else {
                completionHandler(nil)
            }
        })
        renderOperation.addDependency(analyzerOperation)

        queue.addOperations([analyzerOperation, renderOperation], waitUntilFinished: false)
    }
    
    /// Cancel async rendering
    public func cancelWaveformGeneration() {
        queue.cancelAllOperations()
    }
    
    public func activeOperationsCount() -> Int {
        return queue.operationCount
    }
}

extension WaveformImageDrawer {
    /// Renders the waveform from the provided samples into the provided `CGContext`.
    ///
    /// Samples need to be normalized within interval `(0...1)`.
    /// Ensure context size & scale match with the configuration's size & scale.
    func draw(waveform samples: [Float], newSampleCount: Int, on context: CGContext, with configuration: Waveform.Configuration) {
        let renderOperation = WaveformSamplesImageContextRenderOperation(sourceSamples: samples,
                                                                         newSampleCount: newSampleCount,
                                                                         configuration: configuration,
                                                                         context: context,
                                                                         lastOffset: lastOffset,
                                                                         loadDataDispatchQueue: DispatchQueue(label: "WaveformImageDrawer" + UUID().uuidString),
                                                                         shouldDrawSilencePadding: shouldDrawSilencePadding)
        lastOffset = renderOperation.draw() // start on called thread
    }
}
