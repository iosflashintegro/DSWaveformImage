//
//  RenderCollection.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 03.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit

public enum RenderCollection {
    
    /// Configuration for RenderCollectionProvider
    public struct CollectionConfiguration {
        public let collectionWidth: CGFloat
        public let collectionHeight: CGFloat
        public let itemsWidth: [CGFloat]
        
        public var itemsCount: Int {
            return itemsWidth.count
        }
        
        public init(collectionWidth: CGFloat = 0,
                    collectionHeight: CGFloat = 0,
                    itemsWidth: [CGFloat] = []) {
            self.collectionWidth = collectionWidth
            self.collectionHeight = collectionHeight
            self.itemsWidth = itemsWidth
        }
        
        public func with(collectionWidth: CGFloat? = nil,
                         collectionHeight: CGFloat? = nil,
                         itemsWidth: [CGFloat]? = nil) -> CollectionConfiguration {
            return CollectionConfiguration(collectionWidth: collectionWidth ?? self.collectionWidth,
                                           collectionHeight: collectionHeight ?? self.collectionHeight,
                                           itemsWidth: itemsWidth ?? self.itemsWidth)
        }
    }
}
