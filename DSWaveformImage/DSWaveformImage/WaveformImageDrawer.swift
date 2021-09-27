import Foundation
import AVFoundation
import UIKit
import CoreGraphics

/// Renders a UIImage of the waveform data calculated by the analyzer.
public class WaveformImageDrawer {

    private var qos: QualityOfService
    
    /// only internal; determines whether to draw silence lines in live mode.
    var shouldDrawSilencePadding: Bool = false
    
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
}

extension WaveformImageDrawer {
    /// Renders the waveform from the provided samples into the provided `CGContext`.
    ///
    /// Samples need to be normalized within interval `(0...1)`.
    /// Ensure context size & scale match with the configuration's size & scale.
    func draw(waveform samples: [Float], newSampleCount: Int, on context: CGContext, with configuration: Waveform.Configuration) {
//        guard samples.count > 0 || shouldDrawSilencePadding else {
//            return
//        }
//
//        let samplesNeeded = Int(configuration.size.width * configuration.scale)
//
//        if case .striped = configuration.style, samples.count >= samplesNeeded {
//            lastOffset = (lastOffset + newSampleCount) % stripeBucket(configuration)
//        }
//
//        // move the window, so that its always at the end (moves the graph after it reached the right side)
//        let startSample = max(0, samples.count - samplesNeeded)
//        let clippedSamples = Array(samples[startSample..<samples.count])
//        let dampenedSamples = configuration.shouldDampen ? dampen(clippedSamples, with: configuration) : clippedSamples
//        let paddedSamples = shouldDrawSilencePadding ? dampenedSamples + Array(repeating: 1, count: samplesNeeded - clippedSamples.count) : dampenedSamples
//
//        draw(on: context, from: paddedSamples, with: configuration)
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
