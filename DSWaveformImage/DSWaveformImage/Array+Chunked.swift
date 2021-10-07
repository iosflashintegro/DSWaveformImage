//
//  Array+Chunked.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 04.10.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation

extension Array {
    func chunked(size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
    
    /// Proportionally split array into arrays
    func chunked(proportionallyParts: [Float]) -> [[Element]] {
        var subarrays: [[Element]] = []
        var startIndex = 0
        var endIndex = 0
        for index in 0..<proportionallyParts.count {
            if startIndex >= count {
                break
            }
            endIndex = startIndex + Int(Float(count) * proportionallyParts[index])
            let subarray: [Element] = Array(self[startIndex..<endIndex])
            subarrays.append(subarray)
            startIndex = endIndex
        }
        return subarrays
    }
    
    /// Split array into arrays with count element
    func chunked(elementCounts: [Int]) -> [[Element]] {
        let sumElements = elementCounts.reduce(0, +)
        if sumElements != count {
            print("ERROR: sumElements: \(sumElements) != \(count)")
        }
        var subarrays: [[Element]] = []
        var startIndex = 0
        var endIndex = 0
        for index in 0..<elementCounts.count {
            if startIndex >= count {
                break
            }
            endIndex = startIndex + elementCounts[index]
            if endIndex >= count {
                endIndex = count
            }
            let subarray: [Element] = Array(self[startIndex..<endIndex])
            subarrays.append(subarray)
            startIndex = endIndex
        }
        return subarrays
    }
}
