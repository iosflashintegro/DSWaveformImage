import Foundation
import AVFoundation
import UIKit
import CoreGraphics

/// Renders a UIImage of the waveform data calculated by the analyzer.
public class WaveformImageDrawer {

    private var qos: QualityOfService
    
    
    /// only internal; determines whether to draw silence lines in live mode.
    var shouldDrawSilencePadding: Bool = false
    /// Makes sure we always look at the same samples while animating
    private var lastOffset: Int = 0
    
    private var queue: OperationQueue

    public init(qos: QualityOfService = .userInitiated) {
        self.qos = qos
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = qos
        queue.name = "WaveformImageDrawerOperation_" + NSUUID().uuidString
    }
    
    deinit {
        cancelWaveformGeneration()
    }
    
    
    /// Async analyzes the provided audio and renders a UIImage of the waveform data calculated by the analyzer.
    public func waveformImage(fromAudioAt audioAssetURL: URL,
                              with configuration: Waveform.Configuration,
                              completionHandler: @escaping (_ waveformImage: UIImage?) -> ()) {
        cancelWaveformGeneration()
        
        let sampleCount = Int(configuration.size.width * configuration.scale)
        let analyzerOperation = WaveformAnalyzerOperation(audioAssetURL: audioAssetURL,
                                                          count: sampleCount,
                                                          qos: convertQoS(qos),
                                                          completionHandler: nil)

        let renderOperation = WaveformImageRenderOperation(sourceSamples: nil,
                                                           configuration: configuration,
                                                           completionHandler: completionHandler)

        let adapter = BlockOperation(block: { [unowned analyzerOperation, unowned renderOperation] in
            renderOperation.sourceSamples = analyzerOperation.amplitudes
        })

        adapter.addDependency(analyzerOperation)
        renderOperation.addDependency(adapter)

        queue.addOperations([analyzerOperation, adapter, renderOperation], waitUntilFinished: false)
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
        let renderOperation = WaveformLiveImageRenderOperation(sourceSamples: samples,
                                                               newSampleCount: newSampleCount,
                                                               configuration: configuration,
                                                               context: context,
                                                               lastOffset: lastOffset,
                                                               shouldDrawSilencePadding: shouldDrawSilencePadding)
        lastOffset = renderOperation.draw() // start on called thread
    }
}


extension WaveformImageDrawer {
    
    private func convertQoS(_ sourceQoS: QualityOfService) -> DispatchQoS.QoSClass {
        var targetQoS: DispatchQoS.QoSClass = .default
        switch sourceQoS {
        case .userInteractive:
            targetQoS = .userInteractive
        case .userInitiated:
            targetQoS = .userInitiated
        case .utility:
            targetQoS = .utility
        case .background:
            targetQoS = .background
        case .default:
            targetQoS = .default
        @unknown default:
            targetQoS = .default
        }
        return targetQoS
    }
    
}
