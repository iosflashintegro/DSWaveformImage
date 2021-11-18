//
//  RenderCollectionProvider.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 03.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit

/// Base provider class for rendering any object devided into chunks.
public class RenderCollectionProvider {
    
    // MARK: Static
    
    private static var _sharedQueue: OperationQueue?
    // sharedQueue will be overrided on subclasses for has access to private _sharedQueue, uniqued for each subclass
    class var sharedQueue: OperationQueue? {
        get {
            return _sharedQueue
        }
        set {
            _sharedQueue = newValue
        }
    }
    
    /// Get sharedQueue
    class func getSharedQueue(qos: QualityOfService = .userInitiated) -> OperationQueue {
        if let queue = sharedQueue {
            return queue
        } else {
            let queue = createSharedQueue(qos: qos)
            sharedQueue = queue
            return queue
        }
    }
    
    /// Creatae queue for rendering, shared between all instance of current class
    class func createSharedQueue(qos: QualityOfService = .userInitiated) -> OperationQueue {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = qos
        
        let className = String(describing: self)
        let queueName = className + "_Shared_" + NSUUID().uuidString
        queue.name = queueName
        
        return queue
    }
    
    
    // MARK: Instance properties
    
    var analyzerOperation: Operation?
    var renderOperations: [Int: Operation] = [:]     // render operations. key - index
    
    var collectionConfiguration: RenderCollection.CollectionConfiguration
    var queue: OperationQueue?
    
    // MARK: Constructor/Destructor/Init

    public init(qos: QualityOfService = .userInitiated, shared: Bool = false) {
        collectionConfiguration = RenderCollection.CollectionConfiguration(collectionWidth: 0,
                                                                           collectionHeight: 0,
                                                                           itemsWidth: [])
        if shared {
            queue = type(of: self).getSharedQueue(qos: qos)
        } else {
            queue = createInstanceQueue(qos: qos)
        }
    }
    
    deinit {
        cancelAllRendering()
    }
    
    // MARK: Public methods

    /// Any actions on recreate analyserOperation
    func prepareAnalyzerOperation(_ anAnalyzerOperation: Operation) {
        // recreate render operations with new dependency (if needed)
        let udpatedRenderOperations = updateDependendentRenderOperation(anAnalyzerOperation)
        // cancel all exist operations
        cancelAllRendering()
        // add analyzer oparation to queue
        queue?.addOperation(anAnalyzerOperation)
        analyzerOperation = anAnalyzerOperation
        // if exist, add prev render operation
        udpatedRenderOperations.forEach {
            if let index = $0.index {
                renderOperations[index] = $0
            }
            queue?.addOperation($0)
        }
        // Later, if new renderOperation will be created for exist index, current active operation will cancelled - it's correct
    }
    
    /// Get image for target index
    public func getImages(for index: Int,
                          size: CGSize,
                          completionHandler: ((_ image: [UIImage]?, _ index: Int) -> ())?) {
        let completion: ([UIImage]?) -> Void = { image in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    completionHandler?(nil, index)
                    return
                }
                // before call completionHandler, clear renderOperations for index
                self.renderOperations[index] = nil
                completionHandler?(image, index)
            }
        }
        
        // if loading samples not called, return nil image
        guard let analyzerOperation = analyzerOperation else {
            completion(nil)
            return
        }
        
        // let cancel exist render operation
        if let existRenderOperation = renderOperations[index] {
            existRenderOperation.cancel()
            renderOperations[index] = nil
        }
        
        guard let renderOperation = createRenderOperation(for: index,
                                                             size: size,
                                                             completion: completion) else {
            completion(nil)
            return
        }
        
        renderOperation.addDependency(analyzerOperation)
        renderOperations[index] = renderOperation
        queue?.addOperations([renderOperation], waitUntilFinished: false)
    }
   
    /// Cancel all operations
    public func cancelAllRendering() {
        analyzerOperation?.cancel()
        analyzerOperation = nil
        renderOperations.values.forEach { $0.cancel() }
        renderOperations.removeAll()
    }
    
    /// Cancel image generation at index
    public func cancelRendering(index: Int) {
        if let operation = renderOperations[index] {
            operation.cancel()
            renderOperations[index] = nil
        }
    }
    
    public func activeOperationsCount() -> Int {
        return renderOperations.count + ((analyzerOperation != nil) ? 1: 0)
    }
    
    
    /// Create render operation
    /// - Note: Override on children
    func createRenderOperation(for index: Int,
                               size: CGSize,
                               completion: (([UIImage]?) -> Void)?) -> Operation? {
        return nil
    }

    
    // MARK: Private methods
    
    /// Recreate RenderOperation (if exist) and set dependency for its to newAnalyzerOperation
    private func updateDependendentRenderOperation(_ newAnalyzerOperation: Operation) -> [RenderOperation] {
        guard let existAnalyzerOperation = analyzerOperation else {
            return []
        }
        let existRenderOperations = Array(renderOperations.values).filter( { $0.dependencies.contains(existAnalyzerOperation)} )
        var copiedOperations: [RenderOperation] = []
        existRenderOperations.forEach {
            if let copyRenderOperation = $0.copy() as? RenderOperation {
                copyRenderOperation.addDependency(newAnalyzerOperation)
                copiedOperations.append(copyRenderOperation)
            }
            $0.removeDependency(existAnalyzerOperation)
        }
        return copiedOperations
    }
    
    /// Creatae queue for rendering, only for single instance of class
    private func createInstanceQueue(qos: QualityOfService = .userInitiated) -> OperationQueue {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = qos
        
        let className = String(describing: self)
        let queueName = className + NSUUID().uuidString
        queue.name = queueName
        
        return queue
    }
}
