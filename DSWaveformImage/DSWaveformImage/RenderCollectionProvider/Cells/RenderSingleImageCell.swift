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
    private var imageView = UIImageView()
    
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
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: Layout
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    // MARK: CollectionView
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
    
    // MARK: Public methods
    func updateImage(_ image: UIImage) {
        imageView.image = image
    }
}
