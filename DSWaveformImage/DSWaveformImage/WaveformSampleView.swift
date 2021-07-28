import Foundation
import UIKit

public class WaveformSampleView: UIView {
    private var sampleLayer: WaveformSampleLayer! {
        return layer as? WaveformSampleLayer
    }

    public var samples: [Float] = [] {
        didSet {
            sampleLayer.samples = samples
        }
    }

    public var configuration = WaveformConfiguration(size: .zero) {
        didSet {
            sampleLayer.configuration = configuration
        }
    }

    override public class var layerClass: AnyClass {
        return WaveformSampleLayer.self
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        contentMode = .redraw
    }

    /// Clears the samples, emptying the waveform view.
    public func reset() {
        samples = []
    }
}

class WaveformSampleLayer: CALayer {
    @NSManaged var samples: [Float]

    var configuration = WaveformConfiguration(size: .zero) {
        didSet { contentsScale = configuration.scale }
    }

    private let imageDrawer = WaveformImageDrawer()

    override class func needsDisplay(forKey key: String) -> Bool {
        if key == #keyPath(samples) {
            return true
        }
        return super.needsDisplay(forKey: key)
    }

    override func draw(in context: CGContext) {
        super.draw(in: context)

        guard samples.count > 0 else {
            return
        }

        UIGraphicsPushContext(context)

        imageDrawer.waveformImage(from: samples, with: configuration.with(size: bounds.size), context: context)

        UIGraphicsPopContext()
    }
}