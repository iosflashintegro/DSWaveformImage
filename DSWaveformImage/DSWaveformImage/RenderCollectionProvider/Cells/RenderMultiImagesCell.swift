//
//  RenderMultiImagesCell.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 08.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import UIKit

/// Cell class used for rendering multi images on cell
final class RenderMultiImagesCell: RenderCell {
    
    // MARK: Private properties
    private var imageViews = [UIImageView]()
    
    // MARK: Init
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    // MARK: Override methods
    
    /// Clear content images
    override func clearRenderContent() {
        super.clearRenderContent()
        removeAllImages()
    }

    /// Update render content
    override func updateImages(_ imagesDataSource: RenderCellData.ImagesSource?) {
        onRederContentReady()
        super.updateImages(imagesDataSource)
        drawImages()
    }
    
    // MARK: Private methods
    
    private func drawImages() {
        guard let images = imagesDataSource?.images else { return }

        let imageSize: CGSize
        if let anImageSize = imagesDataSource?.imageSize {
            // if the dimensions of the image are set externally, set this value
            imageSize = anImageSize
        } else {
            // if the images' dimensions are not set, all images will have equal width
            let imageCount = images.count
            let imageWidth = bounds.size.width / CGFloat(imageCount)
            let imageHeight = bounds.size.height
            imageSize = CGSize(width: imageWidth, height: imageHeight)
        }

        var imageOrigin: CGPoint = .zero
        for (index, image) in images.enumerated() {
            imageOrigin = CGPoint(x: (imageSize.width * CGFloat(index)),
                                  y: 0)
            let imageFrame = CGRect(origin: imageOrigin,
                                    size: imageSize)
            let item = UIImageView(frame: imageFrame)
            item.contentMode = .scaleAspectFill
            item.image = image
            item.clipsToBounds = true
            imageViews.append(item)
            contentView.insertSubview(item, at: 0)
        }
    }

    private func removeAllImages() {
        imageViews.forEach({ $0.removeFromSuperview() })
        imageViews.removeAll()
    }
    
}
