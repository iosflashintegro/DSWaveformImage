//
//  RenderCollectionView.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 03.11.2021.
//  Copyright © 2021 Stas Klem. All rights reserved.
//

import Foundation
import UIKit

/// Base class for rendering long image over collection view
class RenderCollectionView: UIView {
    
    // MARK: Type of rendering for cell
    enum ImageRenderType {
        case single     // single image on cell
        case multi      // multi images on cell
    }
 
    // MARK: Public Properties
    var renderProvider: RenderCollectionProvider?
    var flowLayout = UICollectionViewFlowLayout()
    var collectionView: UICollectionView!
    var collectionConfiguration = RenderCollection.CollectionConfiguration(collectionWidth: 0,
                                                                           collectionHeight: 0,
                                                                           itemsWidth: [])
    var totalWidth: CGFloat = 0
    var itemWidth: CGFloat = 0
    var renderType: ImageRenderType = .single
    
    var contentOffset: CGPoint = .zero
    var isChunkGenerationEnable: Bool = true    // флаг, генерировать ли содержимое всех ячеек сразу или по отдельности
                                                // Если генерируем содержимое ячеек по отдельности, то "окно" из  collectionView будет занимать размер 3 ячеек
                                                // (для того, чтобы при скроллинге запрос на отображение новых ячеек проходил заранее)
    
    private var currentFrame = CGRect.zero


    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        createRenderCollectionProvider()
        setupUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if frame.size != currentFrame.size {
            currentFrame = frame
            boundsUpdated()
        }
    }
    
    func setupUI() {
        clipsToBounds = true
        addCollectionView()
    }

    // MARK: Override methods
    
    /// Create data source for renderProvider
    ///  - Note: override on children
    func createRenderCollectionProvider() {
    }
    
    /// Calls on cell change frame
    func boundsUpdated() {
        updateCollectionViewContentOffset()
    }
    
    // MARK: Public Methods
    
    func configure(totalWidth: CGFloat,
                   itemWidth: CGFloat,
                   renderType: ImageRenderType) {
        
        let itemsWidth = WaveformSupport.devideSegment(segmentWidth: totalWidth,
                                                       itemWidth: itemWidth)
        collectionConfiguration = RenderCollection.CollectionConfiguration(collectionWidth: totalWidth,
                                                                           collectionHeight: self.bounds.size.height,
                                                                           itemsWidth: itemsWidth)
        self.totalWidth = totalWidth
        self.itemWidth = itemWidth
        self.renderType = renderType
        
        updateCollectionViewContentOffset()
    }
    
    func requestSingleImageForIndexPath(_ indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? RenderSingleImageCell else { return }
        requestSingleImageForCell(cell, indexPath: indexPath)
    }
    
    func requestMultiImagesForIndexPath(_ indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? RenderMultiImagesCell else { return }
        requestMultiImagesForCell(cell, indexPath: indexPath)
    }
    
    /// Setup current offset inside cell
    /// - Parameters: parentContentOffset - offset on parent view
    func setContentOffset(_ parentContentOffset: CGPoint) {
        var localContentOffset = self.convert(parentContentOffset, from: superview)
        if localContentOffset.x < 0 {
            localContentOffset.x = 0
        } else if localContentOffset.y > bounds.size.width {
            localContentOffset.x = bounds.size.width
        }
        contentOffset = localContentOffset
        updateCollectionViewContentOffset()
    }

    
    // MARK: Private Methods
    
    private func addCollectionView() {
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumInteritemSpacing = 0
        
        collectionView = UICollectionView(frame: self.bounds, collectionViewLayout: flowLayout)
        collectionView.collectionViewLayout = flowLayout
        collectionView.alwaysBounceHorizontal = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.clipsToBounds = false
        collectionView.allowsSelection = false
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(RenderSingleImageCell.self, forCellWithReuseIdentifier: cellIdentifier(for: RenderSingleImageCell.self))
        collectionView.register(RenderMultiImagesCell.self, forCellWithReuseIdentifier: cellIdentifier(for: RenderMultiImagesCell.self))

        addSubview(collectionView)
    }
    
    private func getCellSize(for indexPath: IndexPath) -> CGSize {
        let cellWidth = collectionConfiguration.itemsWidth[safeIndex: indexPath.row] ?? 0
        let cellHeight = self.bounds.height
        let cellSize = CGSize(width: cellWidth, height: cellHeight)
        return cellSize
    }
    
    private func requestSingleImageForCell(_ cell: RenderSingleImageCell, indexPath: IndexPath) {
        renderProvider?.getImages(for: indexPath.row,
                                     size: getCellSize(for: indexPath)) { images, providerIndex in
            guard let images = images,
                  let image = images[safeIndex: 0] else { return }
            if providerIndex == cell.indexPath?.row {
                DispatchQueue.main.async { [weak cell] in
                    guard let cell = cell else { return }
                    cell.updateImage(image)
                }
            }
        }
    }
    
    private func requestMultiImagesForCell(_ cell: RenderMultiImagesCell, indexPath: IndexPath) {
        renderProvider?.getImages(for: indexPath.row,
                                     size: getCellSize(for: indexPath)) { images, providerIndex in
            guard let images = images else { return }
            if providerIndex == cell.indexPath?.row {
                DispatchQueue.main.async { [weak cell] in
                    guard let cell = cell else { return }
                    cell.updateImages(images)
                }
            }
        }
    }
    
    /// Update size and contentOffset inside collectionView for current value of view's contentOffset
    private func updateCollectionViewContentOffset() {
        if isChunkGenerationEnable && itemWidth < totalWidth {
            var collectionViewContentOffset: CGPoint = .zero    // смещение origin отображаемого "окна" collectionView
            if contentOffset.x < 0 {
                collectionViewContentOffset = .zero
            } else if contentOffset.x > (bounds.size.width - itemWidth) {
                collectionViewContentOffset = CGPoint(x: (bounds.size.width - itemWidth) , y: 0)
            } else {
                collectionViewContentOffset = CGPoint(x: contentOffset.x , y: 0)
            }
            
            let leftEcxess = itemWidth
            let rightExcess = itemWidth
            // увеличиваем размер "окна" на leftEcxess и rightExcess, а также смещаем orgin "окна" влево на leftEcxess
            collectionViewContentOffset = CGPoint(x: collectionViewContentOffset.x - leftEcxess, y: collectionViewContentOffset.y)
            collectionView.frame = CGRect(origin: collectionViewContentOffset,
                                          size: CGSize(width: itemWidth + leftEcxess + rightExcess, height: bounds.size.height))
            collectionView.contentOffset = collectionViewContentOffset
        } else {
            collectionView.frame = CGRect(origin: CGPoint(x: 0, y: 0),
                                          size: bounds.size)
        }
        self.layoutIfNeeded()
    }
    
    /// Return cell's identificator for cell type
    func cellIdentifier(for cellClass: AnyClass) -> String {
        return String(describing: cellClass)
    }
}


// MARK: UICollectionViewDataSource
extension RenderCollectionView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionConfiguration.itemsCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: RenderCell?
        switch renderType {
        case .single:
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier(for: RenderSingleImageCell.self),
                                                      for: indexPath) as? RenderSingleImageCell
        case .multi:
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier(for: RenderMultiImagesCell.self),
                                                      for: indexPath) as? RenderMultiImagesCell
        }
        guard let cell = cell else {
            return UICollectionViewCell()
        }
        cell.indexPath = indexPath
        return cell
    }
}

    
// MARK: UICollectionViewDelegate
extension RenderCollectionView: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        switch renderType {
        case .single:
            guard let cell = cell as? RenderSingleImageCell else { return }
            cell.indexPath = indexPath
            requestSingleImageForCell(cell, indexPath: indexPath)
        case .multi:
            guard let cell = cell as? RenderMultiImagesCell else { return }
            cell.indexPath = indexPath
            requestMultiImagesForCell(cell, indexPath: indexPath)
        }
    }
   
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        renderProvider?.cancelRendering(index: indexPath.row)
    }
}


// MARK: UICollectionViewDelegateFlowLayout
extension RenderCollectionView: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellSize = getCellSize(for: indexPath)
        return cellSize
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}
