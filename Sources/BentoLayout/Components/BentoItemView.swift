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
    
    @State private var draggedItemInitial: Item?
    
    @State private var draggingLocation: CGPoint?
    
    var body: some View {
        itemContent(item)
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .global)
                    .onChanged { val in
                        if draggedItemInitial == nil {
                            draggedItemInitial = item.duplicated(withSameID: true)
                        }
                        guard let draggedItemInitial else { return }
                        var newFrame = draggedItemInitial.frame.offsetBy(dx: val.translation.width, dy: val.translation.height)
                        newFrame.origin.x = max(0, newFrame.origin.x)
                        newFrame.origin.y = max(0, newFrame.origin.y)
                        
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
                        newFrame.origin = CGPoint(
                            x: min(max(newFrame.origin.x, minX), maxX - newFrame.size.width),
                            y: min(max(newFrame.origin.y, minY), maxY - newFrame.size.height)
                        )
                        
                        
                        item.frame = newFrame
                    }
                    .onEnded { _ in
                        bentoModel.isDragging = false
                        draggedItemInitial = nil
                        draggingLocation = nil
                        bentoModel.flushGridOccupyState()
                    }
            ) // Drag handler
            .overlay(alignment: .bottomTrailing) {
                let maxRadius: CGFloat = 20

                if item.showResizeHandler,
                   draggedItem?.itemID == item.itemID || itemBeforeResized?.itemID == item.itemID {
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
                                itemBeforeResized = nil
                            },
                        including: .all
                    )
                    .frame(width: maxRadius, height: maxRadius)
                }
            } // Resize handler
            .onHover {
                if !isDragging && !isResizing {
                    if $0 {
                        bentoModel.draggedItem = item
                    } else {
                        bentoModel.draggedItem = nil
                    }
                }
            }
            .alignmentGuide(.leading, computeValue: { d in
                let leadingDistance = d[.leading] - CGFloat(item.x)
                return leadingDistance
            })
            .alignmentGuide(.top, computeValue: { d in
                let topDistance = d[.top] - CGFloat(item.y)
                return topDistance
            })
            .frame(
                width: item.width,
                height: item.height
            )
            .transition(.scale.animation(.bouncy(duration: 0.2, extraBounce: 0.2)))
            .animation(.default, value: itemBeforeResized?.itemID == item.itemID)
            .animation(.default, value: draggedItem == item)
            .onReceive(resizePublisher.throttle(for: 0.42, scheduler: RunLoop.current, latest: true)) {
                performResize(width: $0.width, height: $0.height)
            }
            .onChange(of: isResizing) { oldValue, newValue in
                bentoModel.isResizing = newValue
            }
    }
    
    // MARK: - Resize
    var isResizing: Bool { itemBeforeResized != nil }
    @State private var itemBeforeResized: Item?
    @State private var resizePublisher = PassthroughSubject<(width: Int, height: Int), Never>()
    private func resizeBentoItem(_ item: Item, dragData: DragGesture.Value) {
//        guard let index = items.firstIndex(where: {$0.itemID == item.itemID}) else { return }
//        if itemBeforeResized == nil {
//            itemBeforeResized = item.duplicated(withSameID: true)
//        }
//        guard let itemBeforeResized else { return }
//        
//        let resizedItem = items[index]
//        // calculate the anchor
//        let offsetX = dragData.location.x - dragData.startLocation.x
//        let offsetY = dragData.location.y - dragData.startLocation.y
//        let numX = Int(offsetX / bentoBaseSize)
//        let numY = Int(offsetY / bentoBaseSize)
//        let xFactor = offsetX / bentoBaseSize - Double(numX)
//        let yFactor = offsetY / bentoBaseSize - Double(numY)
//        let newWidth = min(
//            min(columnsCount - itemBeforeResized.x, item.maximumSize?.width ?? (columnsCount - itemBeforeResized.x)),
//            max(
//                item.minimumSize?.width ?? 1,
//                itemBeforeResized.width + numX + (abs(xFactor) < 0.5 ? 0 : xFactor > 0 ? 1 : -1)
//            )
//        )
//        let newHeight = min(
//            item.maximumSize?.height ?? 999999,
//            max(
//                item.minimumSize?.height ?? 1,
//                itemBeforeResized.height + numY + (abs(yFactor) < 0.5 ? 0 : yFactor > 0 ? 1 : -1)
//            )
//        )
//        print(offsetX, numX, newWidth, newHeight)
//        
//        let intermediateSize = getBentoSize(itemBeforeResized, withBounceOnEdge: true) { size in
//            CGSize(width: size.width + offsetX, height: size.height + offsetY)
//        }
//        
////        bentoModel.items[index].intermediateWidth = intermediateSize.width
////        bentoModel.items[index].intermediateHeight = intermediateSize.height
//
//        guard resizedItem.width != newWidth || resizedItem.height != newHeight else { return }
//        resizePublisher.send((width: newWidth, height: newHeight))
    }
    private func performResize(width: Int, height: Int) {
//        guard let itemBeforeResized, let index = items.firstIndex(where: {$0.itemID == itemBeforeResized.itemID}) else { return }
//        var newItem = items[index]
//        newItem.width = width
//        newItem.height = height
//        bentoModel.forceTransformItem(newItem.itemID, to: newItem)
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
