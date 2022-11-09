//
//  RenderCollectionProvider.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 03.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit

/// Async version of RenderCollectionProvider
public class RenderAsyncCollectionProvider: RenderCollectionProvider {
    
    // MARK: Enum
    
    /// Type of rendering & load data queues
    public enum QueueType {
        case nonShared                              // queue is created for each instanse of provider
        case sharedFull                             // queue is single for all instances in app (shared between all instanses of provider in app)
        case shared(OperationQueue, DispatchQueue)  // queue is single for any providers (shared between instanses of provider with same queue)
    }
    
    /// Source for rendering data
    enum RenderSource: CustomStringConvertible {
        
        case activeOperation            // wait active analyze operation
        case finishedOperation(Any)     // get data from already finished analyze operation
        case existData(Any)             // data for rendering alrady exist
        case notSource
        
        // simple compare (only compare state, without underlying operation
        static func == (lhs: RenderSource, rhs: RenderSource) -> Bool {
            switch (lhs, rhs) {
            case (.activeOperation, .activeOperation):
                return true
            case (.finishedOperation, .finishedOperation):
                return true
            case (.existData, .existData):
                return true
            case (.notSource, .notSource):
                return true
            default:
                return false
            }
        }
        
        func getData() -> Any? {
            switch self {
            case .activeOperation:
                return nil
            case .finishedOperation(let data):
                return data
            case .existData(let data):
                return data
            case .notSource:
                return nil
            }
        }
        
        var description: String {
            switch self {
            case .activeOperation:
                return "activeOperation"
            case .finishedOperation:
                return "finishedOperation"
            case .existData:
                return "existData"
            case .notSource:
                return "notSource"
            }
        }
    }
    
    // MARK: Static sharedQueue
    
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
    class func getSharedFullQueue(qos: QualityOfService = .userInitiated) -> OperationQueue {
        if let queue = sharedQueue {
            return queue
        } else {
            let queue = createSharedFullQueue(qos: qos)
            sharedQueue = queue
            return queue
        }
    }
    
    /// Creatae queue for rendering, shared between all instance of current class
    class func createSharedFullQueue(qos: QualityOfService = .userInitiated) -> OperationQueue {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = qos
        
        let className = String(describing: self)
        let queueName = className + "Queue_SharedFull_" + UUID().uuidString
        queue.name = queueName
        
        return queue
    }
    
    // MARK: Static sharedFullLoadDataQueue
    
    private static var _sharedFullLoadDataQueue: DispatchQueue?
    // sharedFullLoadDataQueue will be overrided on subclasses for has access to private _sharedFullLoadDataQueue, uniqued for each subclass
    class var sharedFullLoadDataQueue: DispatchQueue? {
        get {
            return _sharedFullLoadDataQueue
        }
        set {
            _sharedFullLoadDataQueue = newValue
        }
    }
    
    /// Get sharedQueue
    class func getSharedFullLoadDataQueue(qos: DispatchQoS = .userInitiated) -> DispatchQueue {
        if let queue = sharedFullLoadDataQueue {
            return queue
        } else {
            let queue = createSharedFullLoadDataQueue(qos: qos)
            sharedFullLoadDataQueue = queue
            return queue
        }
    }
    
    /// Creatae queue for loading data from resource, shared between all instance of current class
    class func createSharedFullLoadDataQueue(qos: DispatchQoS = .userInitiated) -> DispatchQueue {
        let className = String(describing: self)
        let queueName = className + "LoadDataQueue_SharedFull_" + UUID().uuidString
        let queue = DispatchQueue(label: queueName, qos: qos)
        return queue
    }
    
    // MARK: Static methods
    
    /// Creatae queue for rendering, shared between any instances of current class
    class func createSharedQueue(qos: QualityOfService = .userInitiated) -> OperationQueue {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = qos
        
        let className = String(describing: self)
        let queueName = className + "Queue_Shared_" + UUID().uuidString
        queue.name = queueName
        
        return queue
    }
    
    /// Creatae queue for loading data from resource, shared between any instances of current class
    class func createSharedLoadDataQueue(qos: DispatchQoS = .userInitiated) -> DispatchQueue {
        let className = String(describing: self)
        let queueName = className + "LoadDataQueue_Shared_" + UUID().uuidString
        let queue = DispatchQueue(label: queueName, qos: qos)
        return queue
    }
    
    
    // MARK: Private properties
    
    private var analyzerOperation: Operation?
    private var renderOperations: [Int: Operation] = [:]     // render operations. key - index

    private var queue: OperationQueue?                  // base queue for add all analyse & rendering operations
    private var loadDataDispatchQueue: DispatchQueue!   // queue for async loading data
    
    // MARK: Constructor/Destructor/Init

    public init(qos: QualityOfService = .userInitiated, queueType: QueueType) {
        super.init()

        switch queueType {
        case .nonShared:
            queue = createInstanceQueue(qos: qos)
            loadDataDispatchQueue = createInstanceLoadDataQueue(qos: WaveformSupport.convertQoS(qos))
        case .sharedFull:
            queue = type(of: self).getSharedFullQueue(qos: qos)
            loadDataDispatchQueue = type(of: self).getSharedFullLoadDataQueue(qos: WaveformSupport.convertQoS(qos))
        case .shared(let operationQueue, let loadDataQueue):
            queue = operationQueue
            loadDataDispatchQueue = loadDataQueue
        }
    }
    
    deinit {
        cancelAllRendering()
    }
    
    // MARK: Public methods

    /// Any actions on recreate analyserOperation
    func prepareAnalyzerOperation(_ anAnalyzerOperation: Operation) {
        invalidateAnalyzeData()     // invalidate previously calculated analyzed data before execute new analyze operation
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
    public override func getImages(for index: Int,
                                   size: CGSize,
                                   completionHandler: ((_ imagesDataSource: RenderCell.ImagesDataSource?, _ index: Int) -> Void)?) {
        let completion: (RenderCell.ImagesDataSource?) -> Void = { image in
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

        // let cancel exist render operation
        if let existRenderOperation = renderOperations[index] {
            existRenderOperation.cancel()
            renderOperations[index] = nil
        }

        
        var renderSource: RenderSource = .notSource
        if let existData = getExistAnalyzeData(index: index) {
            renderSource = .existData(existData)
        } else if let analyzerOperation = analyzerOperation {
            if analyzerOperation.isFinished {
                if let renderData = getAnalyzeData(operation: analyzerOperation, index: index) {
                    renderSource = .finishedOperation(renderData)
                } else {
                    renderSource = .notSource
                }
            } else {
                renderSource = .activeOperation
            }
        } else {
            renderSource = .notSource
        }
        
        if renderSource == .notSource {
            completion(nil)
            return
        }
        
        guard let renderOperation = createRenderOperation(for: index,
                                                          renderData: renderSource.getData(),
                                                          size: size,
                                                          loadDataDispatchQueue: loadDataDispatchQueue,
                                                          completion: completion) else {
            completion(nil)
            return
        }
        
        if renderSource == .activeOperation, let analyzerOperation = analyzerOperation {
            renderOperation.addDependency(analyzerOperation)
        }

        // add operation to queue
        renderOperations[index] = renderOperation
        queue?.addOperations([renderOperation], waitUntilFinished: false)
    }
    
    /// Cancel image generation at index
    public override func cancelRendering(index: Int) {
        if let operation = renderOperations[index] {
            operation.cancel()
            renderOperations[index] = nil
        }
    }
   
    /// Cancel all operations
    public func cancelAllRendering() {
        renderOperations.values.forEach { $0.cancel() }
        renderOperations.removeAll()
        analyzerOperation?.cancel()
        analyzerOperation = nil
    }
    
    public func activeOperationsCount() -> Int {
        return renderOperations.count + ((analyzerOperation != nil) ? 1: 0)
    }
    
    /// Create render operation
    /// - Note: Override on subclasses
    func createRenderOperation(for index: Int,
                               renderData: Any?,
                               size: CGSize,
                               loadDataDispatchQueue: DispatchQueue,
                               completion: ((RenderCell.ImagesDataSource?) -> Void)?) -> Operation? {
        return nil
    }

    /// Invalidate already calculated after finish analyzerOperation data
    /// - Note: Override on subclasses
    func invalidateAnalyzeData() {
    }
    
    /// Check if analyzed data already exist
    /// - Note: Override on subclasses
    func isAnalyzeDataExist() -> Bool {
        return false
    }
    
    /// Get already calculated analyzed data
    /// - Note: Override on subclasses
    func getExistAnalyzeData(index: Int) -> Any? {
        return nil
    }
    
    /// Get analyzed data from finished operation
    /// - Note: Override on subclasses
    func getAnalyzeData(operation: Operation, index: Int) -> Any? {
        return nil
    }

    
    // MARK: Private methods
    
    /// Recreate RenderOperation (if exist) and set dependency for its to newAnalyzerOperation
    private func updateDependendentRenderOperation(_ newAnalyzerOperation: Operation) -> [RenderOperation] {
        guard let existAnalyzerOperation = analyzerOperation else {
            return []
        }
        let existRenderOperations = Array(renderOperations.values).filter { $0.dependencies.contains(existAnalyzerOperation)}
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
        let queueName = className + UUID().uuidString
        queue.name = queueName
        
        return queue
    }
    
    /// Creatae queue for loading data from resource, shared between all instance of current class
    private func createInstanceLoadDataQueue(qos: DispatchQoS = .userInitiated) -> DispatchQueue {
        let className = String(describing: self)
        let queueName = className + UUID().uuidString
        let queue = DispatchQueue(label: queueName, qos: qos)
        return queue
    }
    
}
