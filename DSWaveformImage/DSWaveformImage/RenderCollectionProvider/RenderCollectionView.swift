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
 
    // MARK: Public Properties
//    var renderProvider: RenderCollectionProvider = WaveformCollectionProvider(qos: .userInitiated)
    var renderProvider: RenderCollectionProvider?
    var flowLayout = UICollectionViewFlowLayout()
    var collectionView: UICollectionView!
    var collectionConfiguration = RenderCollection.CollectionConfiguration(collectionWidth: 0,
                                                                           itemsWidth: [])
    var totalWidth: CGFloat = 0
    var itemWidth: CGFloat = 0
    
    var contentOffset: CGPoint = .zero
    var isChunkGenerationEnable: Bool = true    // флаг, генерировать ли содержимое всех ячеек сразу или по отдельности
                                                // Если генерируем содержимое ячеек по отдельности, то "окно" из  collectionView будет занимать размер 3 ячеек
                                                // (для того, чтобы при скроллинге запрос на отображение новых ячеек проходил заранее)
    
    var cellReuseIdentifier = "cellReuseIdentifier"
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
                   itemWidth: CGFloat) {
        
        let itemsWidth = WaveformSupport.devideSegment(segmentWidth: totalWidth,
                                                       itemWidth: itemWidth)
        collectionConfiguration = RenderCollection.CollectionConfiguration(collectionWidth: totalWidth,
                                                                           itemsWidth: itemsWidth)
        self.totalWidth = totalWidth
        self.itemWidth = itemWidth
        
        updateCollectionViewContentOffset()
    }
    
    func requestImageForIndexPath(_ indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? RenderImageCell else { return }
        requestImageForCell(cell, indexPath: indexPath)
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
        collectionView.register(RenderImageCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)

        addSubview(collectionView)
    }
    
    private func getCellSize(for indexPath: IndexPath) -> CGSize {
        let cellWidth = collectionConfiguration.itemsWidth[safeIndex: indexPath.row] ?? 0
        let cellHeight = self.bounds.height
        let cellSize = CGSize(width: cellWidth, height: cellHeight)
        return cellSize
    }
    
    private func requestImageForCell(_ cell: RenderImageCell, indexPath: IndexPath) {
        renderProvider?.getImage(for: indexPath.row,
                                    size: getCellSize(for: indexPath)) { image, providerIndex in
            guard let image = image else { return }
            if providerIndex == cell.indexPath?.row {
                DispatchQueue.main.async { [weak cell] in
                    guard let cell = cell else { return }
                    cell.updateImage(image)
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
}


// MARK: UICollectionViewDataSource
extension RenderCollectionView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionConfiguration.itemsCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as? RenderImageCell else {
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
        guard let cell = cell as? RenderImageCell else { return }
        cell.indexPath = indexPath
        requestImageForCell(cell, indexPath: indexPath)
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
