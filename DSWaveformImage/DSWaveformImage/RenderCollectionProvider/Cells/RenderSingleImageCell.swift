//
//  RenderSingleImageCell.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 05.10.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import UIKit

/// Cell class used for rendering single image on cell
final class RenderSingleImageCell: RenderCell {
    
    // MARK: Private properties
    private var imageView: UIImageView?
    
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
        imageView?.removeFromSuperview()
        imageView = nil
    }
    
    /// Update render content
    override func updateImages(_ imagesDataSource: RenderCellData.ImagesSource?) {
        onRederContentReady()
        super.updateImages(imagesDataSource)
        drawImage()
    }

    
    // MARK: Private methods
    
    private func drawImage() {
        createImageViewIfNeeded()
        let image = imagesDataSource?.images[safeIndex: 0]
        imageView?.image = image
    }
    
    private func createImageViewIfNeeded() {
        if imageView == nil {
            let anImageView = UIImageView()
            contentView.addSubview(anImageView)
            anImageView.translatesAutoresizingMaskIntoConstraints = false
            anImageView.widthAnchor.constraint(equalTo: contentView.widthAnchor).isActive = true
            anImageView.heightAnchor.constraint(equalTo: contentView.heightAnchor).isActive = true
            imageView = anImageView
        }
    }
}
