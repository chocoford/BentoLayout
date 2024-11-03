//
//  SwiftUIView.swift
//  BentoLayout
//
//  Created by Dove Zachary on 2024/10/30.
//

import SwiftUI
import Combine

struct BentoItemView<Item: BentoItem, ItemContent: View>: View {
    @Environment(BentoModel<Item>.self) var bentoModel

    @Binding var item: Item
    var itemContent: (Item) -> ItemContent
    
    public init(
        item: Binding<Item>,
        @ViewBuilder content: @escaping (Item) -> ItemContent
    ) {
        self._item = item
        self.itemContent = content
    }
    
    var items: [Item] { bentoModel.items }
    var draggedItem: Item? { bentoModel.draggedItem }
    var columnsCount: Int { bentoModel.columnsCount }
    var bentoBaseSize: CGFloat { bentoModel.bentoBaseSize }
    var bentoGap: CGFloat { bentoModel.bentoGap }
    var isDragging: Bool { bentoModel.isDragging }
    
    @State private var isHovered = false
    @State private var draggedItemInitial: Item?
    
    @State private var draggingLocation: CGPoint?
    
    var body: some View {
        let itemX = item.x
        let itemY = item.y
        itemContent(item)
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .global)
                    .onChanged { val in
                        onMove(itemID: item.itemID, value: val)
                    }
                    .onEnded { val in
                        onMoveEnd(val)
                    }
            ) // Drag handler
            .overlay(alignment: .bottomTrailing) {
                let maxRadius: CGFloat = 20

                if item.showResizeHandler,
                   !bentoModel.isDragging,
                   isHovered || bentoModel.resizedItemID == item.itemID {
                    Path { path in
                        path.move(to: CGPoint(x: maxRadius, y: 0))
                        if item.borderRadius < maxRadius, item.borderRadius > 0 {
                            path.addLine(to: CGPoint(x: maxRadius, y: maxRadius - item.borderRadius))
                            path.addQuadCurve(
                                to:  CGPoint(x: maxRadius - item.borderRadius, y: maxRadius),
                                control:  CGPoint(x: maxRadius, y: maxRadius)
                            )
                            path.addLine(to: CGPoint(x: 0, y: maxRadius))
                        } else {
                            path.addQuadCurve(
                                to:  CGPoint(x: 0, y: maxRadius),
                                control:  CGPoint(x: maxRadius, y: maxRadius)
                            )
                        }
                    }
                    .stroke(.regularMaterial, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .shadow(radius: 2)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .onChanged { value in
                                resizeBentoItem(item, dragData: value)
                            }.onEnded { _ in
                                onResizeEnd()
                            },
                        including: .all
                    )
                    .frame(width: maxRadius, height: maxRadius)
                }
            } // Resize handler
            .onHover(perform: {isHovered = $0})
            .alignmentGuide(.leading, computeValue: { d in
                let leadingDistance = d[.leading] - CGFloat(itemX)
                return leadingDistance
            })
            .alignmentGuide(.top, computeValue: { d in
                let topDistance = d[.top] - CGFloat(itemY)
                return topDistance
            })
            .frame(
                width: item.width,
                height: item.height
            )
            .transition(.scale.animation(.bouncy(duration: 0.2, extraBounce: 0.2)))
            .animation(.default, value: itemBeforeResized?.itemID == item.itemID)
            .animation(.default, value: draggedItem == item)
    }
    
    // MARK: - Drag(Move)
    private func onMove(itemID: UUID, value val: DragGesture.Value) {
        if !bentoModel.isDragging {
            bentoModel.draggedItemID = itemID
            bentoModel.flushState()
        }
        if draggedItemInitial == nil {
            draggedItemInitial = item.duplicated(withSameID: true)
        }
        guard let draggedItemInitial else { return }
        var newFrame = draggedItemInitial.frame.offsetBy(dx: val.translation.width, dy: val.translation.height)
        newFrame.origin.x = max(0, newFrame.origin.x)
        newFrame.origin.y = max(0, newFrame.origin.y)
        
        func tryPlaceItem(to frame: CGRect) -> Bool {
            var newItem = draggedItemInitial.duplicated(withSameID: true)
            newItem.frame = frame
            let canPlace = bentoModel.items.allSatisfy({
                $0 == item || !$0.checkIsOverlay(with: newItem, safeAreaPadding: bentoModel.bentoGap)
            }) &&
            newItem.frame.minX >= 0 &&
            newItem.frame.minY >= 0 &&
            newItem.frame.maxX <= bentoModel.containerSize.width
            
            guard canPlace else { return false }
            if abs(item.frame.origin.x - frame.origin.x) > 20, abs(item.frame.origin.x - frame.origin.x) > 20 {
                withAnimation(.smooth(duration: 0.15)) {
                    item.frame = frame
                }
            } else {
                item.frame = frame
            }
            return true
        }
        
        // 注意一种场景：进入了左边一点点的对齐判定区域，但无法对齐到那个位置
        let alignedFrame = bentoModel.getMostAlignedFrame(frame: newFrame)
        
        bentoModel.activeAlignments = []
        if let alignedFrame {
            if tryPlaceItem(to: alignedFrame) {
                bentoModel.activeAlignments = bentoModel.getAlignedAlignments(frame: alignedFrame)
                // send tapic feedback
                print("align item to \(alignedFrame)")
                return
            }
        }
        if tryPlaceItem(to: newFrame) { return }
        
        
        // 要全部检测，因为存在重叠后仍然朝反方向移动的情况
        let hinders = bentoModel.getPotentialHinderItems(of: item)
        let minX = getHinderItems(of: item, from: hinders, direction: .leading).reduce(0) {
            max($0, $1.x + $1.width + bentoGap)
        }
        let maxX = getHinderItems(of: item, from: hinders, direction: .trailing).reduce(bentoModel.containerSize.width) {
            min($0, $1.x - bentoGap)
        }
        let minY = getHinderItems(of: item, from: hinders, direction: .top).reduce(0) {
            max($0, $1.y + $1.height + bentoGap)
        }
        let maxY = getHinderItems(of: item, from: hinders, direction: .bottom).reduce(bentoModel.containerSize.height + 100) {
            min($0, $1.y - bentoGap)
        }
        
        let safeX = min(max(newFrame.origin.x, minX), maxX - newFrame.size.width)
        let safeY = min(max(newFrame.origin.y, minY), maxY - newFrame.size.height)
        
        
        if let alignedFrame {
            if safeX == newFrame.origin.x {
                let safeAlignedFrame = CGRect(
                    origin: CGPoint(x: alignedFrame.origin.x, y: safeY),
                    size: newFrame.size
                )
                if tryPlaceItem(to: safeAlignedFrame) {
                    bentoModel.activeAlignments = bentoModel.getAlignedAlignments(frame: safeAlignedFrame)
                    return
                }
            }
//            
            if safeY == newFrame.origin.y { // 说明y方向上没有被阻挡
                let safeAlignedFrame = CGRect(
                    origin: CGPoint(x: safeX, y: alignedFrame.origin.y),
                    size: newFrame.size
                )
                if tryPlaceItem(to: safeAlignedFrame) {
                    bentoModel.activeAlignments = bentoModel.getAlignedAlignments(frame: safeAlignedFrame)
                    return
                }
            }
        }
        newFrame.origin = CGPoint(x: safeX, y: safeY)
        item.frame = newFrame
    }
    
    private func onMoveEnd(_ val: DragGesture.Value) {
        bentoModel.draggedItemID = nil
        draggedItemInitial = nil
        draggingLocation = nil
        bentoModel.flushState()
    }
    
    // MARK: - Resize
    var isResizing: Bool { bentoModel.isResizing }
    @State private var itemBeforeResized: Item?
    @State private var initialStateBeforeDrag: [Item]?
    private func resizeBentoItem(_ item: Item, dragData: DragGesture.Value) {
        guard let index = items.firstIndex(where: {$0.itemID == item.itemID}) else { return }
        if !isResizing {
            bentoModel.resizedItemID = item.itemID
            itemBeforeResized = item.duplicated(withSameID: true)
            initialStateBeforeDrag = items.map{$0.duplicated(withSameID: true)}
        }
        guard let itemBeforeResized else { return }

        // calculate the anchor
        let offsetX = dragData.translation.width
        let offsetY = dragData.translation.height
        
        let hinders = bentoModel.getPotentialHinderItems(of: item)
        
        let trailingHinders = getHinderItems(of: item, from: hinders, direction: .trailing)
        let bottomHinders = getHinderItems(of: item, from: hinders, direction: .bottom)
        
        let maxX = trailingHinders.reduce(bentoModel.containerSize.width) { min($0, $1.x - bentoGap) }
        let maxY = bottomHinders.reduce(bentoModel.containerSize.height + 100) { min($0, $1.y - bentoGap) }
        
        let newWidth = max(
            item.minimumSize.width,
            min(itemBeforeResized.frame.width + offsetX, bentoModel.containerSize.width - item.x)
        )
        let newHeight = max(
            item.minimumSize.height,
            itemBeforeResized.frame.height + offsetY
        )

        guard newWidth > 0, newHeight > 0 else {
            print("Invalid size, return.")
            return
        }
        
        var newFrame = CGRect(
            origin: item.frame.origin,
            size: CGSize(width: newWidth, height: newHeight)
        )
        
        // align
        if let mostAlignedFrame = bentoModel.getMostAlignedFrame(
            frame: newFrame,
            direction: .bottomTrailing
        ) {
            var futureItem = item.duplicated(withSameID: true)
            futureItem.frame = mostAlignedFrame
            if bentoModel.items.allSatisfy({
                $0 == item || !$0.checkIsOverlay(with: futureItem, safeAreaPadding: bentoModel.bentoGap)
            }) {
                newFrame = mostAlignedFrame
            }
        }
        
        func resizeTrailingHinders(_ trailingHinders: [Item], accWidth: CGFloat) {
            for trailingHinder in trailingHinders {
                // Get trailing hinders of the trailing hinder.
                let trailingHindersHinders = bentoModel.getPotentialHinderItems(of: trailingHinder)
                let trailingHindersTrailingHinders = getHinderItems(of: trailingHinder, from: trailingHindersHinders, direction: .trailing)
                
                // if item is block by one of its trailing hinders.
                if trailingHinder.x <= accWidth {
                    // Get the index
                    guard let index = self.items.firstIndex(where: {$0.itemID == trailingHinder.itemID}) else { continue }
                    var newFrame = bentoModel.items[index].frame
                    newFrame.origin.x = accWidth
                    // if this trailing hinder are block by its trailing hinder, then it should resize itself.
                    // Otherwise, it should be resize by the container.
                    let tth = trailingHindersTrailingHinders.first(where: { tth in tth.x <= trailingHinder.frame.maxX + bentoModel.bentoGap })
                    let trailingMaxX: CGFloat = if let tth { tth.frame.minX - bentoModel.bentoGap } else { bentoModel.containerSize.width }
                    newFrame.size.width = min(trailingMaxX - newFrame.minX, trailingHinder.width)
                    if newFrame.width < trailingHinder.minimumSize.width {
                        // recursive find hinders
                        newFrame.size.width = trailingHinder.minimumSize.width
                        resizeTrailingHinders(
                            trailingHindersTrailingHinders,
                            accWidth: accWidth + trailingHinder.minimumSize.width + bentoModel.bentoGap
                        )
                    }
                    bentoModel.items[index].frame = newFrame
                } else { // revert hinders changes
                    guard let initialHinder = self.initialStateBeforeDrag?.first(where: {$0.itemID == trailingHinder.itemID}),
                          let index = self.items.firstIndex(where: {$0.itemID == trailingHinder.itemID}) else { continue }

                    let hinderMinX = accWidth
                    var frame = CGRect(
                        x: max(initialHinder.x, hinderMinX),
                        y: bentoModel.items[index].frame.origin.y,
                        width: min(initialHinder.width, self.items[index].frame.maxX - hinderMinX),
                        height: bentoModel.items[index].frame.height
                    )
                    
                    
                    if trailingHindersTrailingHinders.contains(where: { item in
                        item.frame != initialStateBeforeDrag?.first(where: {$0.itemID == item.itemID})?.frame
                    }) {
                        frame.size.width = trailingHinder.minimumSize.width
                        resizeTrailingHinders(
                            trailingHindersTrailingHinders,
                            accWidth: accWidth + trailingHinder.minimumSize.width + bentoModel.bentoGap
                        )
                    } else {
                    }
                    bentoModel.items[index].frame = frame
                }
            }
        }
        func resizeBottomHinders(_ bottomHinders: [Item], accHeight: CGFloat) {
            for bottomHinder in bottomHinders {
                // Get trailing hinders of the trailing hinder.
                let bottomHindersHinders = bentoModel.getPotentialHinderItems(of: bottomHinder)
                let bottomHindersBottomHinders = getHinderItems(of: bottomHinder, from: bottomHindersHinders, direction: .bottom)
                
                // if item is block by one of its trailing hinders.
                if bottomHinder.y <= accHeight {
                    // Get the index
                    guard let index = self.items.firstIndex(where: {$0.itemID == bottomHinder.itemID}) else { continue }
                    var newFrame = bentoModel.items[index].frame
                    newFrame.origin.y = accHeight
                    // if this trailing hinder are block by its bottom hinder, then it should resize itself.
                    if let bbh = bottomHindersBottomHinders.first(where: { bbh in bbh.y <= bottomHinder.frame.maxY + bentoModel.bentoGap }) {
                        let bottomMaxY: CGFloat = bbh.frame.minY - bentoModel.bentoGap
                        newFrame.size.height = min(bottomMaxY - newFrame.minY, bottomHinder.height)
                    } else {
                        newFrame.size.height = bottomHinder.height
                    }
                    
                    if newFrame.height < bottomHinder.minimumSize.height {
                        // recursive find hinders
                        newFrame.size.height = bottomHinder.minimumSize.height
                        resizeBottomHinders(
                            bottomHindersBottomHinders,
                            accHeight: accHeight + bottomHinder.minimumSize.height + bentoModel.bentoGap
                        )
                    }
                    bentoModel.items[index].frame = newFrame
                } else { // revert hinders changes
                    guard let initialHinder = self.initialStateBeforeDrag?.first(where: {$0.itemID == bottomHinder.itemID}),
                          let index = self.items.firstIndex(where: {$0.itemID == bottomHinder.itemID}) else { continue }

                    let hinderMinY = accHeight
                    var frame = CGRect(
                        x: bentoModel.items[index].frame.origin.x,
                        y: max(initialHinder.y, hinderMinY),
                        width: bentoModel.items[index].frame.width,
                        height: min(initialHinder.height, self.items[index].frame.maxY - hinderMinY)
                    )
                    
                    
                    if bottomHindersBottomHinders.contains(where: { item in
                        item.frame != initialStateBeforeDrag?.first(where: {$0.itemID == item.itemID})?.frame
                    }) {
                        frame.size.height = bottomHinder.minimumSize.height
                        resizeBottomHinders(
                            bottomHindersBottomHinders,
                            accHeight: accHeight + bottomHinder.minimumSize.height + bentoModel.bentoGap
                        )
                    }
                    bentoModel.items[index].frame = frame
                }
            }
        }
        
        resizeTrailingHinders(trailingHinders, accWidth: item.x + newFrame.width + bentoGap)
        resizeBottomHinders(bottomHinders, accHeight: item.y + newFrame.height + bentoGap)
        
        print(#function, "newWidth: \(newWidth), newHeight: \(newHeight)")
        
        bentoModel.items[index].frame = newFrame
        
        bentoModel.flushState()
    }
    
    private func onResizeEnd() {
        itemBeforeResized = nil
        bentoModel.resizedItemID = nil
        bentoModel.flushGridOccupyState()

    }
    
    private func getBentoSize(_ item: Item, withBounceOnEdge: Bool = false, transformer: (CGSize) -> CGSize = { $0 }) -> CGSize {
//        let size = transformer(
//            CGSize(
//                width: bentoBaseSize * CGFloat(item.width) + bentoGap * CGFloat(item.width - 1),
//                height: bentoBaseSize * CGFloat(item.height) + bentoGap * CGFloat(item.height - 1)
//            )
//        )
//        
//        func bounceUpperTo(_ a: Double, target: Double) -> Double {
//            if a > target {
//                return target + log(a - target + 1)
//            } else {
//                return a
//            }
//        }
//        
//        func bounceLowerTo(_ a: Double, target: Double) -> Double {
//            if a < target {
//                return target - log(target - a + 1)
//            } else {
//                return a
//            }
//        }
//        
//        let maxWidthColumns = 2 //min(item.maximumSize?.width ?? (columnsCount - item.x), columnsCount - item.x)
//        let maxHeightColumns = 2 // item.maximumSize?.height ?? 99999
//        
//        if withBounceOnEdge {
//            return CGSize(
//                width: bounceLowerTo(
//                    bounceUpperTo(
//                        size.width,
//                        target: CGFloat(maxWidthColumns) * bentoBaseSize + CGFloat(maxWidthColumns) * bentoGap
//                    ),
//                    target: CGFloat(item.minimumSize?.height ?? 1) * bentoBaseSize
//                ),
//                height: bounceLowerTo(
//                    bounceUpperTo(
//                        size.height,
//                        target: CGFloat(maxHeightColumns) * bentoBaseSize + CGFloat(maxHeightColumns) * bentoGap
//                    ),
//                    target: CGFloat(item.minimumSize?.height ?? 1) * bentoBaseSize
//                )
//            )
//        } else {
//            return CGSize(
//                width: max(
//                    CGFloat(item.minimumSize?.height ?? 1) * bentoBaseSize,
//                    min(
//                        CGFloat(maxWidthColumns) * bentoBaseSize + CGFloat(maxWidthColumns) * bentoGap,
//                        size.width
//                    )
//                ),
//                height: max(
//                    CGFloat(item.minimumSize?.height ?? 1) * bentoBaseSize,
//                    min(
//                        CGFloat(maxHeightColumns) * bentoBaseSize + CGFloat(maxHeightColumns) * bentoGap,
//                        size.height
//                    )
//                )
//            )
//        }
        return .zero
    }
}

#Preview {
    BentoExampleView()
}
