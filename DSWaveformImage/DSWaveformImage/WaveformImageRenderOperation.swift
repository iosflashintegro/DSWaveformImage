import Foundation
import UIKit


protocol WaveformImageRenderOutputPass {
    var image: UIImage? { get }
}


public class WaveformImageRenderOperation: Operation {
    // MARK: Public properties
    public var sourceSamples: [Float]?
    public var configuration: Waveform.Configuration
    
    // MARK: Private properties
    private var completionHandler: ((_ waveformImage: UIImage?) -> ())?
    private var outputImage: UIImage?
    
    /// Makes sure we always look at the same samples while animating
    public var lastOffset: Int = 0
    
    public init(sourceSamples: [Float]? = nil,
                configuration: Waveform.Configuration,
                completionHandler: ((_ waveformImage: UIImage?) -> ())?) {
        self.sourceSamples = sourceSamples
        self.configuration = configuration
        self.completionHandler = completionHandler
    }
    
    override public func main() {
        guard let samples = sourceSamples else {
            return
        }
        if self.isCancelled {
            return
        }
        outputImage = render(samples: samples, with: configuration)
        completionHandler?(outputImage)
    }
    
    
    /// Renders a UIImage of the provided waveform samples.
    ///
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
}


// MARK: Image generation

private extension WaveformImageRenderOperation {
    
    private func render(samples: [Float],
                        with configuration: Waveform.Configuration,
                        completionHandler: @escaping (_ waveformImage: UIImage?) -> ()){
        let image = render(samples: samples, with: configuration)
        completionHandler(image)

//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            let image = self?.render(samples: samples, with: configuration)
//            completionHandler(image)
//        }
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


// MARK: - Helpers

private extension WaveformImageRenderOperation {
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


extension WaveformImageRenderOperation: WaveformImageRenderOutputPass {
    var image: UIImage? {
        return outputImage
    }
}
