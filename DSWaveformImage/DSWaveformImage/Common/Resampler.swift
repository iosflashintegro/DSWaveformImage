//
//  Resampler.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 17.05.2023.
//  Copyright © 2023 FlashIntegro. All rights reserved.
//

import Foundation

class Resampler {
    
    static func resample<T>(array: [T], toSize newSize: Int) -> [T] {
        let size = array.count
        return (0 ..< newSize).map { array[$0 * size / newSize] }
    }
}
