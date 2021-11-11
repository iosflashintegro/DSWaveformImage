//
//  RenderCell.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 09.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import UIKit

/// Protocol for render indicator
protocol RenderIndicator: UIView {
    func startRenderAnimating()
    func stopRenderAnimating()
}


/// Base cell class used for rendering chunk (with any images) of long image
class RenderCell: UICollectionViewCell {
    
    // MARK: EmptyStyle - style for bacground before rendered images will be loaded
    enum EmptyStyle {
        case empty
        case color(UIColor)
        case blur(UIBlurEffect, CGFloat)
        case indicator(() -> RenderIndicator)
    }
    
    // MARK: Public properties
    var indexPath: IndexPath?
    var emptyStyle: EmptyStyle = .empty {
        didSet {
            applyEmptyStyle(emptyStyle)
        }
    }
    
    // MARK: Private properties
    private var colorBackgroundView: UIView?
    private var blurBackgroundView: UIView?
    private var renderIndicator: RenderIndicator?
    
    // MARK: Setup UI
    func setupUI() {
        clipsToBounds = true
        onRederContentStart()
    }
    
    // MARK: Override methods
    
    override func prepareForReuse() {
        super.prepareForReuse()
        onRederContentStart()
    }
    
    /// Clear render content
    /// - Note: Override on subclasses
    func clearRenderContent() {
    }
    
    // MARK: Public methods

    /// Actions on start render images
    func onRederContentStart() {
        switch emptyStyle {
        case .empty, .color, .indicator:
            clearRenderContent()
        case .blur:
            // on blur effect need background with images from prev reused cell, not delete images
            break
        }
    }

    /// Action on rendered images ready
    func onRederContentReady() {
        clearRenderContent()
        removeAllBackgrounds()
    }
    
    // MARK: Private methods
    
    func applyEmptyStyle(_ style: EmptyStyle) {
        removeAllBackgrounds()
        
        switch style {
        case .empty:
            break
        case .color(let uiColor):
            addColorBackground(uiColor)
        case .blur(let effect, let alpha):
            addBlurBackground(effect: effect, alpha: alpha)
        case .indicator(let idicatorGenerator):
            addIndicatorBackground(generator: idicatorGenerator)
        }
    }

    
    private func addColorBackground(_ color: UIColor) {
        let view = UIView()
        view.backgroundColor = color

        contentView.insertSubview(view, at: 0)
        applyFillConstraints(view)
        colorBackgroundView = view
    }

    private func addBlurBackground(effect: UIBlurEffect, alpha: CGFloat) {
        let view = UIVisualEffectView()
        view.effect = effect
        view.alpha = alpha
        
//        contentView.insertSubview(view, at: 0)
        contentView.addSubview(view)
        applyFillConstraints(view)
        blurBackgroundView = view
    }
    
    private func addIndicatorBackground(generator: () -> RenderIndicator) {
        let indicator = generator()
        contentView.insertSubview(indicator, at: 0)
        applyIndicatorConstraints(indicator)
        indicator.startRenderAnimating()
        renderIndicator = indicator
    }
    
    
    private func removeColorBackground() {
        colorBackgroundView?.removeFromSuperview()
        colorBackgroundView = nil
    }
    
    private func removeBlurBackground() {
        blurBackgroundView?.removeFromSuperview()
        blurBackgroundView = nil
    }
    
    private func removeIndicatorBackground() {
        renderIndicator?.stopRenderAnimating()
        renderIndicator?.removeFromSuperview()
        renderIndicator = nil
    }
    
    private func removeAllBackgrounds() {
        removeColorBackground()
        removeIndicatorBackground()
        removeBlurBackground()
    }
    

    private func applyFillConstraints(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: contentView.widthAnchor).isActive = true
        view.heightAnchor.constraint(equalTo: contentView.heightAnchor).isActive = true
    }
    
    private func applyIndicatorConstraints(_ indicator: RenderIndicator) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.5).isActive = true
        indicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        indicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        indicator.addConstraint(NSLayoutConstraint(item: indicator,
                                                   attribute: .height,
                                                   relatedBy: .equal,
                                                   toItem: indicator,
                                                   attribute: .width,
                                                   multiplier: 1.0,
                                                   constant: 0))
    }
}
