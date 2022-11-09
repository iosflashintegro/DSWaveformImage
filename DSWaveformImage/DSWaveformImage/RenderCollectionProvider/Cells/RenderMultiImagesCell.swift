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
    
    // MARK: Const
    enum Const {
        enum Preview {
            static let imageCornerRadius: CGFloat = 0
            static let distanceBetwenImages: CGFloat = 0
            static let edgeDistance: CGFloat = 0
            static let blockMargin: CGFloat = 0
        }
    }
    
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
    
    // MARK: Setup UI
    override func setupUI() {
        super.setupUI()
    }
    
    // MARK: Layout
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    // MARK: Override methods
    
    /// Clear content images
    override func clearRenderContent() {
        super.clearRenderContent()
        removeAllImages()
    }

    /// Update render content
    override func updateImages(_ imagesDataSource: ImagesDataSource?) {
        onRederContentReady()
        super.updateImages(imagesDataSource)
        drawImages()
    }
    
    // MARK: Private methods
    
    private func drawImages() {
        guard let images = imagesDataSource?.images else { return }

        let imageWidth: CGFloat // ширина каждой картинки
        if let imageSize = imagesDataSource?.imageSize {
            // if the dimensions of the image are set externally, set this value
            imageWidth = imageSize.width
        } else {
            // if the images' dimensions are not set, all images will have equal width
            let imageCount = images.count
            imageWidth = (bounds.size.width - 2 * Const.Preview.edgeDistance - Const.Preview.distanceBetwenImages * CGFloat(imageCount - 1)) / CGFloat(imageCount)
        }
        
        for (index, image) in images.enumerated() {
            let item = UIImageView()
            item.contentMode = .scaleAspectFill
            item.image = image
            item.translatesAutoresizingMaskIntoConstraints = false
            item.layer.cornerRadius = Const.Preview.imageCornerRadius
            item.clipsToBounds = true
            imageViews.append(item)
            contentView.insertSubview(item, at: 0)

            if index == 0 && images.count == 1 {
                item.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Const.Preview.blockMargin).isActive = true
                item.widthAnchor.constraint(equalToConstant: imageWidth).isActive = true
                item.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            } else if index == 0 {
                item.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Const.Preview.blockMargin).isActive = true
                item.widthAnchor.constraint(equalToConstant: imageWidth).isActive = true
                item.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            } else if index == images.count - 1 {
                item.leadingAnchor.constraint(equalTo: imageViews[index - 1].trailingAnchor, constant: Const.Preview.distanceBetwenImages).isActive = true
                item.widthAnchor.constraint(equalToConstant: imageWidth).isActive = true
                item.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            } else {
                item.leadingAnchor.constraint(equalTo: imageViews[index - 1].trailingAnchor, constant: Const.Preview.distanceBetwenImages).isActive = true
                item.widthAnchor.constraint(equalToConstant: imageWidth).isActive = true
             }

            item.topAnchor.constraint(equalTo: topAnchor).isActive = true
            item.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        }
    }
    
    private func removeAllImages() {
        imageViews.forEach({ $0.removeFromSuperview() })
        imageViews.removeAll()
    }
    
}
