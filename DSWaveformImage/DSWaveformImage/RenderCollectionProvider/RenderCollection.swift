//
//  RenderCollection.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 03.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit
import AVKit

public enum RenderCollection {
    
    /// Configuration for RenderCollectionProvider
    public struct CollectionConfiguration {
        public let visibleAreaWidth: CGFloat    // width of visible area of timelene
        public let collectionWidth: CGFloat
        public let collectionHeight: CGFloat
        public let itemWidth: CGFloat           // the width of the element into which the entire width will be split
        public let itemsWidth: [CGFloat]        // the width of all the elements into which we divide collectionWidth
        
        public var itemsCount: Int {
            return itemsWidth.count
        }
        
        /// square size for tile
        public var squareTileSize: CGSize {
            return CGSize(width: collectionHeight, height: collectionHeight)
        }

        
        public init(visibleAreaWidth: CGFloat = 0,
                    collectionWidth: CGFloat = 0,
                    collectionHeight: CGFloat = 0,
                    itemWidth: CGFloat) {
            self.visibleAreaWidth = visibleAreaWidth
            self.collectionWidth = collectionWidth
            self.collectionHeight = collectionHeight
            self.itemWidth = itemWidth
            self.itemsWidth = WaveformSupport.devideSegment(segmentWidth: collectionWidth,
                                                            itemWidth: itemWidth)
        }
        
        public func with(visibleAreaWidth: CGFloat? = nil,
                         collectionWidth: CGFloat? = nil,
                         collectionHeight: CGFloat? = nil,
                         itemWidth: CGFloat? = nil) -> CollectionConfiguration {
            return CollectionConfiguration(visibleAreaWidth: visibleAreaWidth ?? self.visibleAreaWidth,
                                           collectionWidth: collectionWidth ?? self.collectionWidth,
                                           collectionHeight: collectionHeight ?? self.collectionHeight,
                                           itemWidth: itemWidth ?? self.itemWidth)
        }
    }
    
    
    /// Range of track interval & samples count on that range
    public struct SamplesTimeRange {
        let range: CMTimeRange      // url start...end interval
        let samplesCount: Int       // samples count for generate at interval
    }
    
    
    /// Create array of SamplesTimeRange for target timeRange & CollectionConfiguration
    static func createSamplesRanges(timeRange: CMTimeRange,
                                    collectionConfiguration: CollectionConfiguration) -> [SamplesTimeRange]? {
        // proportions for each collectionWidth
        let proportionallyParts = collectionConfiguration.itemsWidth.map { Double($0 / collectionConfiguration.collectionWidth) }
        let chunkTimeRanges = timeRange.split(proportionallyParts: proportionallyParts)
        
        if chunkTimeRanges.count != collectionConfiguration.itemsWidth.count {
            return nil
        }

        var samplesRanges: [SamplesTimeRange] = []
        for (index, chunkTimeRange) in chunkTimeRanges.enumerated() {
            let samplesCount = Int(collectionConfiguration.itemsWidth[index])
            let samplesRange = SamplesTimeRange(range: chunkTimeRange,
                                                samplesCount: samplesCount)
            samplesRanges.append(samplesRange)
        }
        return samplesRanges

    }
}
