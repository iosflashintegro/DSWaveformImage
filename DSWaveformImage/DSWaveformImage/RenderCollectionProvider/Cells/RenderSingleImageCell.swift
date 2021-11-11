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
        imageView?.removeFromSuperview()
        imageView = nil
    }
    
    // MARK: Public methods
    func updateImage(_ image: UIImage) {
        onRederContentReady()
        
        if imageView == nil {
            let anImageView = UIImageView()
            contentView.addSubview(anImageView)
            anImageView.translatesAutoresizingMaskIntoConstraints = false
            anImageView.widthAnchor.constraint(equalTo: contentView.widthAnchor).isActive = true
            anImageView.heightAnchor.constraint(equalTo: contentView.heightAnchor).isActive = true
            imageView = anImageView
        }
        imageView?.image = image
    }
}
