//
//  RenderCollection.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 03.11.2021.
//  Copyright © 2021 FlashIntegro. All rights reserved.
//

import Foundation
import UIKit
import AVKit

public enum RenderCollection {
    
    /// Configuration for RenderCollectionProvider
    public struct CollectionConfiguration {
        public let visibleAreaWidth: CGFloat    // width of visible area of timeline
        public let totalWidth: CGFloat          // total with of full track (not only visible part - track can be trimmed)
        public let visibleWidth: CGFloat        // visible part of track (cell's width - width of track without trimmed parts)
        public let startTrimOffset: CGFloat     // offset between pseudo startPosition of track if it isn't trimmed on start and real startPoint
        public let collectionHeight: CGFloat    // height of cell
        public let itemWidth: CGFloat           // the width of the element into which the entire width will be split
        public let itemsWidth: [CGFloat]        // the width of all the elements into which we divide collectionWidth
        
        public var itemsCount: Int {
            return itemsWidth.count
        }
        
        /// square size for tile
        public var squareTileSize: CGSize {
            return CGSize(width: collectionHeight, height: collectionHeight)
        }

        
        public init(visibleAreaWidth: CGFloat,
                    totalWidth: CGFloat,
                    startTrimOffset: CGFloat,
                    visibleWidth: CGFloat,
                    collectionHeight: CGFloat,
                    itemWidth: CGFloat) {
            self.visibleAreaWidth = visibleAreaWidth
            self.totalWidth = totalWidth
            self.startTrimOffset = startTrimOffset
            self.visibleWidth = visibleWidth
            self.collectionHeight = collectionHeight
            self.itemWidth = itemWidth
            self.itemsWidth = WaveformSupport.devideSegment(segmentWidth: totalWidth,
                                                            itemWidth: itemWidth)
        }
        
        public func with(visibleAreaWidth: CGFloat? = nil,
                         totalWidth: CGFloat? = nil,
                         startTrimOffset: CGFloat? = nil,
                         visibleWidth: CGFloat? = nil,
                         collectionHeight: CGFloat? = nil,
                         itemWidth: CGFloat? = nil) -> CollectionConfiguration {
            return CollectionConfiguration(visibleAreaWidth: visibleAreaWidth ?? self.visibleAreaWidth,
                                           totalWidth: totalWidth ?? self.totalWidth,
                                           startTrimOffset: startTrimOffset ?? self.startTrimOffset,
                                           visibleWidth: visibleWidth ?? self.visibleWidth,
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
        let proportionallyParts = collectionConfiguration.itemsWidth.map { Double($0 / collectionConfiguration.totalWidth) }
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
