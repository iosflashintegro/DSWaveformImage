//
//  ClosedRange+Split.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 08.11.2021.
//  Copyright © 2021 FlashIntegro. All rights reserved.
//

import Foundation

public extension ClosedRange {

    // MARK: Static methods

    /// Поделить исходный ClosedRange на несколько частей в соответствии с пропорциями proportionallyParts
    static func split(sourceRange: ClosedRange<Double>, proportionallyParts: [Double]) -> [ClosedRange<Double>] {
        var targetRanges: [ClosedRange<Double>] = []
        let distance: Double = sourceRange.upperBound - sourceRange.lowerBound
        
        var rangeStart = sourceRange.lowerBound
        for index in 0..<proportionallyParts.count {
            let rangeEnd = rangeStart + distance * proportionallyParts[index]
            let range = rangeStart...rangeEnd
            targetRanges.append(range)
            rangeStart = rangeEnd
        }
        return targetRanges
    }
}
