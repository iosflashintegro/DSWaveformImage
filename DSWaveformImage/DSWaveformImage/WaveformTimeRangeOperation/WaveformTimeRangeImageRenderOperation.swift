////
////  WaveformTimeRangeImageRenderOperation.swift
////  vqVideoeditor
////
////  Created by Dmitry Nuzhin on 12.11.2021.
////  Copyright © 2021 Stas Klem. All rights reserved.
////
import Foundation
import UIKit
import Accelerate
import AVFoundation


/// Render waveform image from url with target time range
class WaveformTimeRangeImageRenderOperation: AsyncOperation, RenderOperation {
    
    // MARK: RenderOperation
    public var index: Int?
    
    // MARK: Public properties
    
    public var samplesTimeRange: RenderCollection.SamplesTimeRange? {
        var range: RenderCollection.SamplesTimeRange?
        if let samplesTimeRange = _samplesTimeRange {
            range = samplesTimeRange
        } else if let dataProvider = dependencies
                    .filter({ $0 is WaveformTimeRangeAnalyzerOutputPass })
                    .first as? WaveformTimeRangeAnalyzerOutputPass {
            let index = index ?? 0
            range = dataProvider.samplesTimeRanges?[safeIndex: index]
        }
        return range
    }
 
    var waveformConfiguration: Waveform.Configuration
    
    // MARK: Private properties
    
    private var url: URL?
    private var _samplesTimeRange: RenderCollection.SamplesTimeRange?
    private var loadDataDispatchQueue: DispatchQueue
    private var completionHandler: ((_ imagesDataSource: RenderCellData.ImagesSource?) -> Void)?
    
    private var outputImagesDataSource: RenderCellData.ImagesSource?
    
    /// Makes sure we always look at the same samples while animating
    public var lastOffset: Int = 0
    
    /// Everything below this noise floor cutoff will be clipped and interpreted as silence. Default is `-50.0`.
    public var noiseFloorDecibelCutoff: Float = -50.0

    private var assetReader: AVAssetReader?
    private var audioAssetTrack: AVAssetTrack?
    
    private var loadDataWorkItem: DispatchWorkItem?
    private var isReadStarting = false
    
    // MARK: Constructors/Destructors/Init
    
    init(url: URL?,
         samplesTimeRange: RenderCollection.SamplesTimeRange?,
         waveformConfiguration: Waveform.Configuration,
         index: Int?,
         loadDataDispatchQueue: DispatchQueue,
         completionHandler: ((_ imagesDataSource: RenderCellData.ImagesSource?) -> Void)?) {
        self.url = url
        self._samplesTimeRange = samplesTimeRange
        self.waveformConfiguration = waveformConfiguration
        self.index = index
        self.loadDataDispatchQueue = loadDataDispatchQueue
        self.completionHandler = completionHandler
    }
    
    override public func main() {
        guard let url = url,
              let range = samplesTimeRange else {
            self.markAsFinished()
            return
        }
        
        let audioAsset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        guard let assetReader = try? AVAssetReader(asset: audioAsset),
              let assetTrack = audioAsset.tracks(withMediaType: .audio).first else {
                  print("ERROR loading asset / audio track")
                  self.outputImagesDataSource = nil
                  self.completionHandler?(nil)
                  self.markAsFinished()
                  return
              }
        self.assetReader = assetReader
        self.audioAssetTrack = assetTrack
        
        renderImages(url: url,
                     samplesRange: range) { [weak self] images in
            guard let self = self else { return }
            if let images = images {
                self.outputImagesDataSource = RenderCellData.ImagesSource(images: images,
                                                                          imageSize: nil)
            } else {
                self.outputImagesDataSource = nil
            }
            
            self.completionHandler?(self.outputImagesDataSource)
            self.markAsFinished()
        }
    }
    
    override func cancel() {
        super.cancel()
        assetReader?.asset.cancelLoading()
    }
    
    // MARK: Private methods
    
    private func renderImages(url: URL,
                              samplesRange: RenderCollection.SamplesTimeRange,
                              renderCompletion: @escaping (_ images: [UIImage]?) -> Void) {
        let samplesCount = samplesRange.samplesCount
        let timeRange = samplesRange.range
        assetReader?.timeRange = timeRange
        
        waveformSamples(count: samplesCount,
                        timeRange: timeRange,
                        fftBands: nil) { [weak self] analysis in
            guard let self = self,
                  let analysis = analysis else {
                renderCompletion(nil)
                return
            }
            let samples = analysis.amplitudes

            if let image = self.render(samples: samples, with: self.waveformConfiguration) {
                renderCompletion([image])
            } else {
                renderCompletion(nil)
            }
        }
    }
}


// MARK: Private
fileprivate extension WaveformTimeRangeImageRenderOperation {
    
    func waveformSamples(count requiredNumberOfSamples: Int,
                         timeRange: CMTimeRange,
                         fftBands: Int?,
                         completionHandler: @escaping (_ analysis: WaveformAnalysis?) -> Void) {
        guard let assetReader = assetReader, let audioAssetTrack = audioAssetTrack else {
            completionHandler(nil)
            return
        }

        let trackOutput = AVAssetReaderTrackOutput(track: audioAssetTrack, outputSettings: outputSettings())
        if !assetReader.canAdd(trackOutput) {
            print("ERROR: assetReader can't add track output")
            completionHandler(nil)
            return
        }
        assetReader.add(trackOutput)
        assetReader.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            guard let self = self else { return }
            if self.isCancelled {
                completionHandler(nil)
                return
            }
            self.loadAndExtractSamples(count: requiredNumberOfSamples,
                                       timeRange: timeRange,
                                       fftBands: fftBands,
                                       completionHandler: completionHandler)
        }
    }
    
    /// Load samples from assetReader.
    /// - Note: Detach to separate method for use 'assetReader.startReading()' on separate thread (loadDataDispatchQueue), shared between all WaveformTimeRangeImageRenderOperation.
    /// If call 'assetReader.startReading()' on any thread simultaniously, crash may happen
    private func loadAndExtractSamples(count requiredNumberOfSamples: Int,
                                       timeRange: CMTimeRange,
                                       fftBands: Int?,
                                       completionHandler: @escaping (_ analysis: WaveformAnalysis?) -> Void) {
        let workItem = DispatchWorkItem(block: { [weak self] in
            guard let self = self,
                  let assetReader = self.assetReader,
                  requiredNumberOfSamples != 0 else {
                completionHandler(nil)
                return
            }

            var error: NSError?
            let status = assetReader.asset.statusOfValue(forKey: "duration", error: &error)
            switch status {
            case .loaded:
                let existSamplesCount = self.samplesCountOfAssetReader()
                let analysis = self.extract(existSamplesCount: existSamplesCount, downsampledTo: requiredNumberOfSamples, fftBands: fftBands)

                switch assetReader.status {
                case .completed:
                    completionHandler(analysis)
                default:
                    print("ERROR: reading waveform audio data has failed \(assetReader.status)")
                    completionHandler(nil)
                }
            case .failed, .cancelled, .loading, .unknown:
                print("failed to load due to: \(error?.localizedDescription ?? "unknown error")")
                completionHandler(nil)
            @unknown default:
                print("failed to load due to: \(error?.localizedDescription ?? "unknown error")")
                completionHandler(nil)
            }
        })
        loadDataWorkItem = workItem
        loadDataDispatchQueue.sync(execute: workItem)
    }
    
    private func extract(existSamplesCount: Int,
                         downsampledTo targetSampleCount: Int,
                         fftBands: Int?) -> WaveformAnalysis {
        guard let assetReader = assetReader else { return WaveformAnalysis(amplitudes: [], fft: nil) }
        
        var outputSamples = [Float]()
        var outputFFT = fftBands == nil ? nil : [TempiFFT]()
        var sampleBuffer = Data()
        var sampleBufferFFT = Data()

        // read upfront to avoid frequent re-calculation (and memory bloat from C-bridging)
        let samplesPerPixel = max(1, existSamplesCount / targetSampleCount)
        let samplesPerFFT = 4096 // ~100ms at 44.1kHz, rounded to closest pow(2) for FFT

        isReadStarting = assetReader.startReading()
        while assetReader.status == .reading {
            let trackOutput = assetReader.outputs.first!

            guard let nextSampleBuffer = trackOutput.copyNextSampleBuffer(),
                let blockBuffer = CMSampleBufferGetDataBuffer(nextSampleBuffer) else {
                    break
            }

            var readBufferLength = 0
            var readBufferPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &readBufferLength, totalLengthOut: nil, dataPointerOut: &readBufferPointer)
            sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
            if fftBands != nil {
                // don't append data to this buffer unless we're going to use it.
                sampleBufferFFT.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
            }
            CMSampleBufferInvalidate(nextSampleBuffer)

            let processedSamples = process(sampleBuffer, from: assetReader, downsampleTo: samplesPerPixel)
            outputSamples += processedSamples

            if processedSamples.count > 0 {
                // vDSP_desamp uses strides of samplesPerPixel; remove only the processed ones
                sampleBuffer.removeFirst(processedSamples.count * samplesPerPixel * MemoryLayout<Int16>.size)

                // this takes care of a memory leak where Memory continues to increase even though it should clear after calling .removeFirst(…) above.
                sampleBuffer = Data(sampleBuffer)
            }

            if let fftBands = fftBands, sampleBufferFFT.count / MemoryLayout<Int16>.size >= samplesPerFFT {
                let processedFFTs = process(sampleBufferFFT, samplesPerFFT: samplesPerFFT, fftBands: fftBands)
                sampleBufferFFT.removeFirst(processedFFTs.count * samplesPerFFT * MemoryLayout<Int16>.size)
                outputFFT? += processedFFTs
            }
        }

        // if we don't have enough pixels yet,
        // process leftover samples with padding (to reach multiple of samplesPerPixel for vDSP_desamp)
        if outputSamples.count < targetSampleCount {
            let missingSampleCount = (targetSampleCount - outputSamples.count) * samplesPerPixel
            let backfillPaddingSampleCount = missingSampleCount - (sampleBuffer.count / MemoryLayout<Int16>.size)
            let backfillPaddingSampleCount16 = backfillPaddingSampleCount * MemoryLayout<Int16>.size
            let backfillPaddingSamples = [UInt8](repeating: 0, count: backfillPaddingSampleCount16)
            sampleBuffer.append(backfillPaddingSamples, count: backfillPaddingSampleCount16)
            let processedSamples = process(sampleBuffer, from: assetReader, downsampleTo: samplesPerPixel)
            outputSamples += processedSamples
        }

        let targetSamples = Array(outputSamples[0..<targetSampleCount])
        return WaveformAnalysis(amplitudes: normalize(targetSamples), fft: outputFFT)
    }

    private func process(_ sampleBuffer: Data,
                         from assetReader: AVAssetReader,
                         downsampleTo samplesPerPixel: Int) -> [Float] {
        var downSampledData = [Float]()
        let sampleLength = sampleBuffer.count / MemoryLayout<Int16>.size

        // guard for crash in very long audio files
        guard sampleLength / samplesPerPixel > 0 else { return downSampledData }

        sampleBuffer.withUnsafeBytes { (samplesRawPointer: UnsafeRawBufferPointer) in
            let unsafeSamplesBufferPointer = samplesRawPointer.bindMemory(to: Int16.self)
            let unsafeSamplesPointer = unsafeSamplesBufferPointer.baseAddress!
            var loudestClipValue: Float = 0.0
            var quietestClipValue = noiseFloorDecibelCutoff
            var zeroDbEquivalent: Float = Float(Int16.max) // maximum amplitude storable in Int16 = 0 Db (loudest)
            let samplesToProcess = vDSP_Length(sampleLength)

            var processingBuffer = [Float](repeating: 0.0, count: Int(samplesToProcess))
            vDSP_vflt16(unsafeSamplesPointer, 1, &processingBuffer, 1, samplesToProcess) // convert 16bit int to float (
            vDSP_vabs(processingBuffer, 1, &processingBuffer, 1, samplesToProcess) // absolute amplitude value
            vDSP_vdbcon(processingBuffer, 1, &zeroDbEquivalent, &processingBuffer, 1, samplesToProcess, 1) // convert to DB
            vDSP_vclip(processingBuffer, 1, &quietestClipValue, &loudestClipValue, &processingBuffer, 1, samplesToProcess)

            let filter = [Float](repeating: 1.0 / Float(samplesPerPixel), count: samplesPerPixel)
            let downSampledLength = sampleLength / samplesPerPixel
            downSampledData = [Float](repeating: 0.0, count: downSampledLength)

            vDSP_desamp(processingBuffer,
                        vDSP_Stride(samplesPerPixel),
                        filter,
                        &downSampledData,
                        vDSP_Length(downSampledLength),
                        vDSP_Length(samplesPerPixel))
        }

        return downSampledData
    }

    private func process(_ sampleBuffer: Data,
                         samplesPerFFT: Int,
                         fftBands: Int) -> [TempiFFT] {
        var ffts = [TempiFFT]()
        let sampleLength = sampleBuffer.count / MemoryLayout<Int16>.size
        sampleBuffer.withUnsafeBytes { (samplesRawPointer: UnsafeRawBufferPointer) in
            let unsafeSamplesBufferPointer = samplesRawPointer.bindMemory(to: Int16.self)
            let unsafeSamplesPointer = unsafeSamplesBufferPointer.baseAddress!
            let samplesToProcess = vDSP_Length(sampleLength)

            var processingBuffer = [Float](repeating: 0.0, count: Int(samplesToProcess))
            vDSP_vflt16(unsafeSamplesPointer, 1, &processingBuffer, 1, samplesToProcess) // convert 16bit int to float

            repeat {
                let fftBuffer = processingBuffer[0..<samplesPerFFT]
                let fft = TempiFFT(withSize: samplesPerFFT, sampleRate: 44100.0)
                fft.windowType = TempiFFTWindowType.hanning
                fft.fftForward(Array(fftBuffer))
                fft.calculateLinearBands(minFrequency: 0, maxFrequency: fft.nyquistFrequency, numberOfBands: fftBands)
                ffts.append(fft)

                processingBuffer.removeFirst(samplesPerFFT)
            } while processingBuffer.count >= samplesPerFFT
        }
        return ffts
    }

    private func normalize(_ samples: [Float]) -> [Float] {
        return samples.map { $0 / noiseFloorDecibelCutoff }
    }

    // swiftlint:disable force_cast
    private func samplesCountOfAssetReader() -> Int {
        guard let assetReader = assetReader,
              let audioAssetTrack = audioAssetTrack else { return 0 }
        var samplesCount = 0

        autoreleasepool {
            let descriptions = audioAssetTrack.formatDescriptions as! [CMFormatDescription]
            descriptions.forEach { formatDescription in
                guard let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else { return }
                let channelCount = Int(basicDescription.pointee.mChannelsPerFrame)
                let sampleRate = basicDescription.pointee.mSampleRate
                let duration = assetReader.timeRange.duration.seconds
                samplesCount = Int(sampleRate * duration) * channelCount
            }
        }

        return samplesCount
    }
    // swiftlint:enable force_cast
    
}


// MARK: Image generation
extension WaveformTimeRangeImageRenderOperation {
    
    /// Renders a UIImage of the provided waveform samples.
    /// Samples need to be normalized within interval `(0...1)`.
    public func waveformImage(from samples: [Float], with configuration: Waveform.Configuration) -> UIImage? {
        guard samples.count > 0, samples.count == Int(configuration.size.width * configuration.scale) else {
            print("ERROR: samples: \(samples.count) != \(configuration.size.width) * \(configuration.scale)")
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = configuration.scale
        let renderer = UIGraphicsImageRenderer(size: configuration.size, format: format)
        let dampenedSamples = configuration.shouldDampen ? dampen(samples, with: configuration) : samples

        let image = renderer.image { renderContext in
            draw(on: renderContext.cgContext, from: dampenedSamples, with: configuration)
        }
        return image
    }
    
    public func draw(on context: CGContext, from samples: [Float], with configuration: Waveform.Configuration) {
        context.setAllowsAntialiasing(configuration.shouldAntialias)
        context.setShouldAntialias(configuration.shouldAntialias)

        drawBackground(on: context, with: configuration)
        drawGraph(from: samples, on: context, with: configuration)
    }
    
    public func stripeBucket(_ configuration: Waveform.Configuration) -> Int {
        if case let .striped(stripeConfig) = configuration.style {
            if configuration.scale >= 1.0 {
                return Int(stripeConfig.width + stripeConfig.spacing) * Int(configuration.scale)
            } else {
                return Int(stripeConfig.width + stripeConfig.spacing)
            }
        } else {
            return 0
        }
    }
    
    /// Dampen the samples for a smoother animation.
    public func dampen(_ samples: [Float], with configuration: Waveform.Configuration) -> [Float] {
        guard let dampening = configuration.dampening, dampening.percentage > 0 else {
            return samples
        }

        let count = Float(samples.count)
        return samples.enumerated().map { x, value -> Float in
            1 - ((1 - value) * dampFactor(x: Float(x), count: count, with: dampening))
        }
    }
    
    
    private func render(samples: [Float],
                        with configuration: Waveform.Configuration,
                        completionHandler: @escaping (_ images: [UIImage]?) -> Void) {
        if let image = render(samples: samples, with: configuration) {
            completionHandler([image])
        } else {
            completionHandler(nil)
        }
    }
    
    private func render(samples: [Float],
                        with configuration: Waveform.Configuration) -> UIImage? {
        let dampenedSamples = configuration.shouldDampen ? self.dampen(samples, with: configuration) : samples
        let image = waveformImage(from: dampenedSamples, with: configuration)
        return image
    }

    private func drawBackground(on context: CGContext, with configuration: Waveform.Configuration) {
        context.setFillColor(configuration.backgroundColor.cgColor)
        context.fill(CGRect(origin: CGPoint.zero, size: configuration.size))
    }

    private func drawGraph(from samples: [Float],
                           on context: CGContext,
                           with configuration: Waveform.Configuration) {
        let graphRect = CGRect(origin: CGPoint.zero, size: configuration.size)
        let positionAdjustedGraphCenter = CGFloat(configuration.position.value()) * graphRect.size.height
        let drawMappingFactor = graphRect.size.height * configuration.verticalScalingFactor
        let minimumGraphAmplitude: CGFloat = 1 / configuration.scale // we want to see at least a 1px line for silence

        let path = CGMutablePath()
        var maxAmplitude: CGFloat = 0.0 // we know 1 is our max in normalized data, but we keep it 'generic'

        for (y, sample) in samples.enumerated() {
            let x = y + lastOffset
            if case .striped = configuration.style, x % Int(configuration.scale) != 0 || x % stripeBucket(configuration) != 0 {
                // skip sub-pixels - any x value not scale aligned
                // skip any point that is not a multiple of our bucket width (width + spacing)
                continue
            }

            let xPos = CGFloat(x - lastOffset) / configuration.scale
            let invertedDbSample = 1 - CGFloat(sample) // sample is in dB, linearly normalized to [0, 1] (1 -> -50 dB)
            let drawingAmplitude = max(minimumGraphAmplitude, invertedDbSample * drawMappingFactor)
            let drawingAmplitudeUp = positionAdjustedGraphCenter - drawingAmplitude
            let drawingAmplitudeDown = positionAdjustedGraphCenter + drawingAmplitude
            maxAmplitude = max(drawingAmplitude, maxAmplitude)

            path.move(to: CGPoint(x: xPos, y: drawingAmplitudeUp))
            path.addLine(to: CGPoint(x: xPos, y: drawingAmplitudeDown))
        }

        context.addPath(path)
        context.setAlpha(1.0)
        context.setShouldAntialias(configuration.shouldAntialias)

        if case let .striped(config) = configuration.style {
            // draw scale-perfect for striped waveforms
            context.setLineWidth(config.width)
        } else {
            // draw pixel-perfect for filled waveforms
            context.setLineWidth(1.0 / configuration.scale)
        }

        switch configuration.style {
        case let .filled(color):
            context.setStrokeColor(color.cgColor)
            context.strokePath()
        case let .striped(config):
            context.setLineCap(config.lineCap)
            context.setStrokeColor(config.color.cgColor)
            context.strokePath()
        case let .gradient(colors):
            context.replacePathWithStrokedPath()
            context.clip()
            let colors = NSArray(array: colors.map(\.cgColor)) as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: nil)!
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: positionAdjustedGraphCenter - maxAmplitude),
                                       end: CGPoint(x: 0, y: positionAdjustedGraphCenter + maxAmplitude),
                                       options: .drawsAfterEndLocation)
        }
    }
}


// MARK: Helpers
private extension WaveformTimeRangeImageRenderOperation {
    private func stripeCount(_ configuration: Waveform.Configuration) -> Int {
        if case .striped = configuration.style {
            return Int(configuration.size.width * configuration.scale) / stripeBucket(configuration)
        } else {
            return 0
        }
    }

    private func dampFactor(x: Float, count: Float, with dampening: Waveform.Dampening) -> Float {
        if (dampening.sides == .left || dampening.sides == .both) && x < count * dampening.percentage {
            // increasing linear dampening within the left 8th (default)
            // basically (x : 1/8) with x in (0..<1/8)
            return dampening.easing(x / (count * dampening.percentage))
        } else if (dampening.sides == .right || dampening.sides == .both) && x > ((1 / dampening.percentage) - 1) * (count * dampening.percentage) {
            // decaying linear dampening within the right 8th
            // basically also (x : 1/8), but since x in (7/8>...1) x is "inverted" as x = x - 7/8
            return dampening.easing(1 - (x - (((1 / dampening.percentage) - 1) * (count * dampening.percentage))) / (count * dampening.percentage))
        }
        return 1
    }
}


// MARK: Configuration
private extension WaveformTimeRangeImageRenderOperation {
    private func outputSettings() -> [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
    }
}


// MARK: ImageRenderOutputPass
extension WaveformTimeRangeImageRenderOperation: ImageRenderOutputPass {
    var imagesDataSource: RenderCellData.ImagesSource? {
        return outputImagesDataSource
    }
}


// MARK: NSCopying
extension WaveformTimeRangeImageRenderOperation: NSCopying {
    
    func copy(with zone: NSZone? = nil) -> Any {
        let copy = WaveformTimeRangeImageRenderOperation(url: self.url,
                                                         samplesTimeRange: self._samplesTimeRange,
                                                         waveformConfiguration: self.waveformConfiguration,
                                                         index: self.index,
                                                         loadDataDispatchQueue: self.loadDataDispatchQueue,
                                                         completionHandler: self.completionHandler)
        copy.index = self.index
        copy.outputImagesDataSource = self.outputImagesDataSource
        return copy
    }
}
