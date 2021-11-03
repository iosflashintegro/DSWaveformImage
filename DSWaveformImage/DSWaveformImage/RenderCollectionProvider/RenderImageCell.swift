//
//  RenderImageCell.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 05.10.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import UIKit

/// Base cell class used for rendering chunk of long image
final class RenderImageCell: UICollectionViewCell {
    // MARK: Public properties
    var indexPath: IndexPath?
    
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
    private func setupUI() {
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        clipsToBounds = true
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
