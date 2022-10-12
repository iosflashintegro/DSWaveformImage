//
//  WaveformSupport.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 04.10.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit

struct WaveformSupport {

    static func convertQoS(_ sourceQoS: QualityOfService) -> DispatchQoS {
        var targetQoS: DispatchQoS = .default
        switch sourceQoS {
        case .userInteractive:
            targetQoS = .userInteractive
        case .userInitiated:
            targetQoS = .userInitiated
        case .utility:
            targetQoS = .utility
        case .background:
            targetQoS = .background
        case .default:
            targetQoS = .default
        @unknown default:
            targetQoS = .default
        }
        return targetQoS
    }
    
    /// Devide segment into parts with part's width
    static func devideSegment(segmentWidth: CGFloat,
                              itemWidth: CGFloat) -> [CGFloat] {
        if itemWidth >= segmentWidth {
            return [segmentWidth]
        }
        
        let itemsCount = Int(segmentWidth / itemWidth)
        var itemsWidth: [CGFloat] = Array(repeating: itemWidth, count: itemsCount)

        let remaider = segmentWidth.truncatingRemainder(dividingBy: itemWidth)
        if remaider != 0 {
            itemsWidth.append(remaider)
        }
        return itemsWidth
    }
    
}
