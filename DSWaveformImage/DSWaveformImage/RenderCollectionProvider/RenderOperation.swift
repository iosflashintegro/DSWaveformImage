//
//  RenderOperation.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 03.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit

/// Output protocol for RenderOperation
protocol ImageRenderOutputPass {
    var images: [UIImage]? { get }
}

/// Base class for image render operation
public protocol RenderOperation: Operation {
    var index: Int? { get set }  // index if operation created on RenderCollection
}
