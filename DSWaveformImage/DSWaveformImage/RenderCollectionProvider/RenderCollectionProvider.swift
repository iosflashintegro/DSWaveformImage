//
//  RenderCollectionProvider.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 05.07.2022.
//  Copyright © 2022 FlashIntegro. All rights reserved.
//

import Foundation
import UIKit

/// Base provider class for rendering any object devided into chunks.
public class RenderCollectionProvider {

    // MARK: Protected properties
    var collectionConfiguration: RenderCollection.CollectionConfiguration
    
    // MARK: Constructor/Destructor/Init
    
    public init() {
        collectionConfiguration = RenderCollection.CollectionConfiguration(visibleAreaWidth: 0,
                                                                           totalWidth: 0,
                                                                           startTrimOffset: 0,
                                                                           visibleWidth: 0,
                                                                           collectionHeight: 0,
                                                                           itemWidth: 0)
    }
    
    // MARK: Public methods
    
    /// Get image for target index
    /// - Note: Override on subclasses
    public func getImages(for index: Int,
                          size: CGSize,
                          completionHandler: ((_ imagesDataSource: RenderCellData.ImagesSource?, _ index: Int) -> Void)?) {
    }
    
    /// Cancel image generation at index
    /// - Note: Override on subclasses
    public func cancelRendering(index: Int) {
    }
}
