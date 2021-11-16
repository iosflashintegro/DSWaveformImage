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
    
    
    /// Range of track interval & samples count on that range
    public struct SamplesTimeRange {
        let startTime: TimeInterval // url start interval
        let endTime: TimeInterval   // url end interval
        let samplesCount: Int       // samples count for generate at interval
    }
    
    
    /// Create array of SamplesTimeRange for target timeRange & CollectionConfiguration
    static func createSamplesRanges(timeRange: ClosedRange<TimeInterval>,
                                    collectionConfiguration: CollectionConfiguration) -> [SamplesTimeRange]? {
        // proportions for each collectionWidth
        let proportionallyParts = collectionConfiguration.itemsWidth.map { Double($0 / collectionConfiguration.collectionWidth) }
        let chunkTimeRanges = ClosedRange<TimeInterval>.split(sourceRange: timeRange, proportionallyParts: proportionallyParts)
        
        if chunkTimeRanges.count != collectionConfiguration.itemsWidth.count {
            return nil
        }

        var samplesRanges: [SamplesTimeRange] = []
        for (index, chunkTimeRange) in chunkTimeRanges.enumerated() {
            let samplesCount = Int(collectionConfiguration.itemsWidth[index])
            let samplesRange = SamplesTimeRange(startTime: chunkTimeRange.lowerBound,
                                                endTime: chunkTimeRange.upperBound,
                                                samplesCount: samplesCount)
            samplesRanges.append(samplesRange)
        }
        return samplesRanges

    }
}
