//
//  CMTimeRange+Split.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 28.01.2022.
//  Copyright © 2022 Stas Klem. All rights reserved.
//

import Foundation
import CoreMedia

extension CMTimeRange {

    func splitIntoChunks(length: CMTime) -> [CMTimeRange]? {
        var chunks: [CMTimeRange] = []
        var from = self.start
        while from < self.end {
            let chunk = CMTimeRange(start: from, duration: length).intersection(self)
            chunks.append(chunk)
            from = from + length    // swiftlint:disable:this shorthand_operator
        }
        return chunks.count > 0 ? chunks : nil
    }
    
    func split(proportionallyParts: [Double]) -> [CMTimeRange] {
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
