//
//  RenderCellSource.swift
//  VSDCTests
//
//  Created by Dmitry Nuzhin on 17.05.2023.
//  Copyright © 2023 Stas Klem. All rights reserved.
//

import UIKit

public enum RenderCellData {

    /// Data source for fill images in RenderCell
    public class ImagesSource {
        let images: [UIImage]   // images for fill cell
        let imageSize: CGSize?  // size for each image (maybe nil, than image size calculated inside cell)

        init(images: [UIImage],
             imageSize: CGSize?) {
            self.images = images
            self.imageSize = imageSize
        }
    }
    
    /// Data source with samples for rendering Waveform
    /// - Note:
    ///     - used only for RenderSingleImageCell
    ///     - used only first image in images
    public class ImagesSamplesSource: ImagesSource {
        let samples: [Float]    // samples for rendering in cell
        
        init(images: [UIImage],
             samples: [Float],
             imageSize: CGSize?) {
            self.samples = samples
            super.init(images: images,
                       imageSize: imageSize)
        }
    }
}
