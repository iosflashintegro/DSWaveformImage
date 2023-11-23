//
//  RenderCollectionView.swift
//  vqVideoeditor
//
//  Created by Dmitry Nuzhin on 03.11.2021.
//  Copyright © 2021 FlashIntegro. All rights reserved.
//

import Foundation
import UIKit

/// Base class for rendering long image over collection view
open class RenderCollectionView: UIView {
    
    // MARK: Type of rendering for cell
    public enum ImageRenderType {
        case single     // single image on cell
        case multi      // multi images on cell
    }
 
    // MARK: Public Properties
    public var renderProvider: RenderCollectionProvider?
    public var flowLayout = UICollectionViewFlowLayout()
    public var collectionView: UICollectionView!
    public var collectionConfiguration = RenderCollection.CollectionConfiguration(visibleAreaWidth: 0,
                                                                                  totalWidth: 0,
                                                                                  startTrimOffset: 0,
                                                                                  visibleWidth: 0,
                                                                                  collectionHeight: 0,
                                                                                  itemWidth: 0)
    public var renderType: ImageRenderType = .single
    public var cellEmptyStyle: RenderCell.EmptyStyle = .empty
    
    public var contentOffset: CGPoint = .zero
    public var isChunkGenerationEnable: Bool = true     // флаг, генерировать ли содержимое всех ячеек сразу или по отдельности
                                                        // Если генерируем содержимое ячеек по отдельности, то "окно" из  collectionView будет занимать размер 3 ячеек
                                                        // (для того, чтобы при скроллинге запрос на отображение новых ячеек проходил заранее)
    
    private var currentFrame = CGRect.zero


    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    public override func layoutSubviews() {
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
    
    /// Calls on cell change frame
    open func boundsUpdated() {
        updateCollectionViewContentOffset()
    }
    
    // MARK: Public Methods
    
    open func configure(collectionConfiguration: RenderCollection.CollectionConfiguration,
                        renderType: ImageRenderType,
                        cellEmptyStyle: RenderCell.EmptyStyle) {
        self.collectionConfiguration = collectionConfiguration
        self.renderType = renderType
        self.cellEmptyStyle = cellEmptyStyle
        
        updateCollectionViewContentOffset()
    }
    
    open func requestSingleImageForIndexPath(_ indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? RenderSingleImageCell else { return }
        requestSingleImageForCell(cell, indexPath: indexPath)
    }
    
    open func requestMultiImagesForIndexPath(_ indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? RenderMultiImagesCell else { return }
        requestMultiImagesForCell(cell, indexPath: indexPath)
    }
    
    /// Setup current offset inside cell
    /// - Parameters: parentContentOffset - offset on parent view
    open func setContentOffset(_ parentContentOffset: CGPoint) {
        let localContentOffset = self.convert(parentContentOffset, from: superview)
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
        collectionView.clipsToBounds = true
        collectionView.allowsSelection = false
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(RenderSingleImageCell.self, forCellWithReuseIdentifier: cellIdentifier(for: RenderSingleImageCell.self))
        collectionView.register(RenderMultiImagesCell.self, forCellWithReuseIdentifier: cellIdentifier(for: RenderMultiImagesCell.self))

        addSubview(collectionView)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func getCellSize(for indexPath: IndexPath) -> CGSize {
        let cellWidth = collectionConfiguration.itemsWidth[safeIndex: indexPath.row] ?? 0
        let cellHeight = self.bounds.height
        let cellSize = CGSize(width: cellWidth, height: cellHeight)
        return cellSize
    }
    
    private func requestSingleImageForCell(_ cell: RenderSingleImageCell, indexPath: IndexPath) {
        renderProvider?.getImages(for: indexPath.row,
                                  size: getCellSize(for: indexPath)) { [weak cell] imagesDataSource, providerIndex in
            guard let cell = cell else { return }
            if providerIndex == cell.indexPath?.row {
                cell.updateImages(imagesDataSource)
            } else {
                cell.updateImages(nil)
            }
        }
    }
    
    private func requestMultiImagesForCell(_ cell: RenderMultiImagesCell, indexPath: IndexPath) {
        renderProvider?.getImages(for: indexPath.row,
                                  size: getCellSize(for: indexPath)) { [weak cell] imagesDataSource, providerIndex in
            guard let cell = cell else { return }
            if providerIndex == cell.indexPath?.row {
                cell.updateImages(imagesDataSource)
            } else {
                cell.updateImages(nil)
            }
        }
    }
    
    /// Update size and contentOffset inside collectionView for current value of view's contentOffset
    private func updateCollectionViewContentOffset() {
        let startTrimOffset = collectionConfiguration.startTrimOffset
        
        if isChunkGenerationEnable {
            // основной размер "окна" - ширина видимой области таймлайна
            let windowWidth = collectionConfiguration.visibleAreaWidth
            let leftExcess = windowWidth/2
            let rightExcess = windowWidth/2

            let collectionViewFrame = CGRect(origin: CGPoint(x: contentOffset.x - leftExcess,
                                                             y: 0),
                                             size: CGSize(width: windowWidth + leftExcess + rightExcess,
                                                          height: bounds.size.height))

            collectionView.frame = collectionViewFrame
            // важно! устанавливаем смещение через collectionView.contentOffset(_:, animated:), т.к. если установить через collectionView.contentOffset =,
            // то на ios 16.2 смещение будет анимировано
            
            let targetContentOffset = CGPoint(x: contentOffset.x - leftExcess + startTrimOffset, y: 0)
            collectionView.setContentOffset(targetContentOffset, animated: false)
        } else {
            collectionView.frame = CGRect(origin: CGPoint(x: 0, y: 0),
                                      size: bounds.size)
        }
        
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
    
    /// Return cell's identificator for cell type
    func cellIdentifier(for cellClass: AnyClass) -> String {
        return String(describing: cellClass)
    }
}


// MARK: UICollectionViewDataSource
extension RenderCollectionView: UICollectionViewDataSource {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionConfiguration.itemsCount
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
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
        cell.emptyStyle = cellEmptyStyle
        cell.indexPath = indexPath
        return cell
    }
}

    
// MARK: UICollectionViewDelegate
extension RenderCollectionView: UICollectionViewDelegate {

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
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
   
    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        renderProvider?.cancelRendering(index: indexPath.row)
    }
}


// MARK: UICollectionViewDelegateFlowLayout
extension RenderCollectionView: UICollectionViewDelegateFlowLayout {

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellSize = getCellSize(for: indexPath)
        return cellSize
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}
