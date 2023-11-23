//
//  CMTimeRange+Split.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 28.01.2022.
//  Copyright © 2022 FlashIntegro. All rights reserved.
//

import Foundation
import CoreMedia

extension CMTimeRange {

    /// Splitting CMTimeRange for a given number of segments of equal length
    public func splitIntoChunks(count: UInt) -> [CMTimeRange]? {
        if count == 0 { return nil }
        if count == 1 { return [self] }
        
        // interval - длительность подинтервалов
        // duration = duration.value/duration.timescale
        // interval = duration.value/(duration.timescale * count)
        let interval = CMTimeMultiplyByRatio(duration, multiplier: 1, divisor: Int32(count))
        
        var chunks: [CMTimeRange] = []
        var from = self.start
        for _ in 0..<count {
            let chunk = CMTimeRange(start: from, duration: interval)
            chunks.append(chunk)
            from = from + interval  // swiftlint:disable:this shorthand_operator
        }
        return chunks.count > 0 ? chunks : nil
    }
    
    /// Splitting CMTimeRange into segments of a given length
    /// - Note: At the same time, if length is not a multiple of duration for a given CMTimeRange (which usually happens),
    /// then the last interval will be shorter than the specified length
    public func splitIntoChunks(length: CMTime) -> [CMTimeRange]? {
        var chunks: [CMTimeRange] = []
        var from = self.start
        while from < self.end {
            let chunk = CMTimeRange(start: from, duration: length).intersection(self)
            chunks.append(chunk)
            from = from + length    // swiftlint:disable:this shorthand_operator
        }
        return chunks.count > 0 ? chunks : nil
    }
    
    public func split(proportionallyParts: [Double]) -> [CMTimeRange] {
        var chunks: [CMTimeRange] = []
        var from = self.start
        for index in 0..<proportionallyParts.count {
            let length = CMTimeMultiplyByFloat64(self.duration, multiplier: proportionallyParts[index])
            let chunk = CMTimeRange(start: from, duration: length).intersection(self)
            chunks.append(chunk)
            from = from + length    // swiftlint:disable:this shorthand_operator
        }
        
        return chunks
    }
}
