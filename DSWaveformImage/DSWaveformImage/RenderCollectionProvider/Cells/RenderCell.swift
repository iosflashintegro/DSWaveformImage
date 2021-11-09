//
//  RenderCell.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 09.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import UIKit

/// Base cell class used for rendering chunk (with any images) of long image
class RenderCell: UICollectionViewCell {
    // MARK: Public properties
    var indexPath: IndexPath?
    
    // MARK: Setup UI
    func setupUI() {
        clipsToBounds = true
    }
}
