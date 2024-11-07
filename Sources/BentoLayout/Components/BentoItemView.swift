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
                    },
                isEnabled: bentoModel.canMove
            ) // Drag handler
            .overlay {
                resizeHandler()
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
    
    var canShowResizeHandler: Bool {
        item.showResizeHandler &&
        bentoModel.canResize &&
        !bentoModel.isDragging &&
        (isHovered || bentoModel.resizedItemID == item.itemID)
    }
    
    @MainActor @ViewBuilder
    private func resizeHandler() -> some View {
        let maxRadius: CGFloat = 20
        VStack {
            HStack {
                if canShowResizeHandler {
                    RoundedCorner(radius: item.borderRadius)
                        .stroke(.regularMaterial, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(180))
                        .shadow(radius: 2)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(coordinateSpace: .global)
                                .onChanged { value in
                                    resizeBentoItem(item, anchor: .topLeading, dragData: value)
                                }.onEnded { _ in
                                    onResizeEnd()
                                },
                            including: .all
                        )
                        .frame(width: maxRadius, height: maxRadius)
                        .transition(.offset(x: 6, y: 6).combined(with: .opacity))
                }
                Spacer()
                
            }
            Spacer()
            HStack {
                
            }
            Spacer()
            HStack {
                Spacer()
                if canShowResizeHandler {
                    
                    RoundedCorner(radius: item.borderRadius)
                        .stroke(.regularMaterial, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .shadow(radius: 2)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(coordinateSpace: .global)
                                .onChanged { value in
                                    resizeBentoItem(item, anchor: .bottomTrailing, dragData: value)
                                }.onEnded { _ in
                                    onResizeEnd()
                                },
                            including: .all
                        )
                        .frame(width: maxRadius, height: maxRadius)
                        .transition(.offset(x: -6, y: -6).combined(with: .opacity))
                }
                
            }
        }
        .animation(.bouncy(duration: 0.3, extraBounce: 0.3), value: canShowResizeHandler)
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
            
            // only detect the adjacent grid.
            let hinders = bentoModel.getAdjacentHinders(of: itemID, frame: item.frame)
            
            let canPlace = hinders.allSatisfy({
                $0 == item || !$0.checkIsOverlay(with: newItem, safeAreaPadding: bentoModel.bentoGap)
            }) &&
            newItem.frame.minX >= 0 &&
            newItem.frame.minY >= 0 &&
            newItem.frame.maxX <= bentoModel.containerSize.width
            
            print("try place item to \(frame), can place: \(canPlace), hinders: \(hinders.map{$0.frame})")
            
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
                print("try place item aligned: \(alignedFrame)")
                return
            }
        }
        if tryPlaceItem(to: newFrame) { return }
        
        
        // 要全部检测，因为存在重叠后仍然朝反方向移动的情况
        let minX = bentoModel.getAdjacentHinders(
            of: item.itemID,
            frame: item.frame,
            direction: [.leading]
        ).reduce(0) {
            max($0, $1.x + $1.width + bentoGap)
        }
        let maxX = bentoModel.getAdjacentHinders(
            of: item.itemID,
            frame: item.frame,
            direction: [.trailing]
        ).reduce(bentoModel.containerSize.width) {
            min($0, $1.x - bentoGap)
        }
        let minY = bentoModel.getAdjacentHinders(
            of: item.itemID,
            frame: item.frame,
            direction: [.top]
        ).reduce(0) {
            max($0, $1.y + $1.height + bentoGap)
        }
        let maxY = bentoModel.getAdjacentHinders(
            of: item.itemID,
            frame: item.frame,
            direction: [.bottom]
        ).reduce(bentoModel.containerSize.height + 100) {
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
    @State private var initialStateBeforeDrag: [UUID : Item]?
    @State private var previousTranslation: CGSize = .zero
    /// Resize需要实时检测障碍物，因为两个方向的resize会存在障碍物变化的场景
    private func resizeBentoItem(_ item: Item, anchor: UnitPoint, dragData: DragGesture.Value) {
        let item = item.duplicated(withSameID: true)
        guard let index = items.firstIndex(where: {$0.itemID == item.itemID}) else { return }
        if !isResizing {
            bentoModel.resizedItemID = item.itemID
            itemBeforeResized = item.duplicated(withSameID: true)
            initialStateBeforeDrag = items.map{[$0.itemID : $0.duplicated(withSameID: true)]}.merged()
        }
        guard let itemBeforeResized else { return }
        
        defer { previousTranslation = dragData.translation }

        // calculate the anchor
        let offsetX = dragData.translation.width
        let offsetY = dragData.translation.height
        
        let stepOffsetX = dragData.translation.width - offsetX
        let stepOffsetY = dragData.translation.height - offsetY
        
        var newOriginX: CGFloat = item.frame.origin.x
        var newOriginY: CGFloat = item.frame.origin.y
        var newWidth: CGFloat = .zero
        var newHeight: CGFloat = .zero
        
        switch anchor {
            case .topLeading:
                newOriginX = max(0, itemBeforeResized.frame.minX + offsetX)
                newOriginY = max(0, itemBeforeResized.frame.minY + offsetY)
                newWidth = itemBeforeResized.frame.maxX - newOriginX
                newHeight = itemBeforeResized.frame.maxY - newOriginY
            case .bottomTrailing:
                newWidth = min(itemBeforeResized.frame.width + offsetX, bentoModel.containerSize.width - itemBeforeResized.frame.minX)
                newHeight = itemBeforeResized.frame.height + offsetY
            default:
                break
        }

        newWidth = max(item.minimumSize.width, newWidth)
        newHeight = max(item.minimumSize.height, newHeight)
        newOriginX = min(itemBeforeResized.frame.maxX - item.minimumSize.width, newOriginX)
        newOriginY = min(itemBeforeResized.frame.maxY - item.minimumSize.height, newOriginY)
        
        guard newWidth > 0, newHeight > 0 else { return }
        
        var newFrame = CGRect(
            origin: CGPoint(x: newOriginX, y: newOriginY),
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
                print("Align new frame to: \(mostAlignedFrame)")
            }
        }
        
        var flushRegions: [CGRect] = []
        
        /// Resize the hinders of the specific item.
        func resizeHinders(of item: Item, hinders: [Item]? = nil, direction: UnitPoint, start: CGFloat) -> (offset: CGFloat, dirtyRects: [CGRect]) {
            
            let hinders = hinders ?? bentoModel.getAdjacentHinders(
                of: item.itemID,
                frame: item.frame,
                direction: [direction]
            ).map {
                $0.duplicated(withSameID: true)
            }
            
            let sign: CGFloat = direction == .leading || direction == .top ? -1 : 1
            let isHorizontal = direction == .leading || direction == .trailing
            let stepOffset = isHorizontal ? stepOffsetX : stepOffsetY
            let originKeyPath: WritableKeyPath<CGPoint, CGFloat> = isHorizontal ? \.x : \.y
            let sizeKeyPath: WritableKeyPath<CGSize, CGFloat> = isHorizontal ? \.width : \.height
            
            if hinders.isEmpty {
                let prevMax = start - bentoModel.bentoGap * sign
                // the fix offset
                return (
                    offset: sign > 0 ? min(0, bentoModel.containerSize[keyPath: sizeKeyPath] - prevMax) : max(0, -prevMax),
                    dirtyRects: []
                )
            }
            
            var offset: CGFloat = .zero
            var dirtyRects: [CGRect] = []
            
            // Maybe bug here
            let sortedHinders: [Item] = hinders.sorted(by: {
                $0.frame.point(at: direction)[keyPath: originKeyPath] < $1.frame.point(at: direction)[keyPath: originKeyPath]
            })
            print("resize hinders - item: \(item.frame) its hinders: \(hinders.map{$0.frame})")
            // 遍历
            for hinder in sortedHinders {
                let hinderHinders = bentoModel.getAdjacentHinders(of: hinder.itemID, frame: hinder.frame, direction: [direction]).map {
                    $0.duplicated(withSameID: true)
                }
                print("resize hinders - hinder: \(hinder.frame), \(hinder.frame.origin[keyPath: originKeyPath]), start - stepOffset: \(start - stepOffset), offset: \(offset) hinderHinders: \(hinderHinders.map{$0.frame})")
                // if item is block by one of its trailing hinders.
                /// 缩放前的Hinder边缘
                let hinderEdge = hinder.frame.point(at: direction.inverted)[keyPath: originKeyPath]
                // 如果现阶段的缩放边缘超过缩放前Hinder的边缘，就要对其Resize
                if sign > 0 ? hinderEdge <= start : hinderEdge >= start {
                    guard let index = self.items.firstIndex(where: {$0.itemID == hinder.itemID}) else { continue }
                    var newFrame = hinder.frame
                    // 如果是向右下方向进行缩放的，就先调整Hinder的原点位置
                    // 否则就要先调整宽高，因为此时优先考虑原点不动的情况，直到判断到缩放宽高后小于最小限制，才会考虑调整原点
                    if sign > 0 {
                        newFrame.origin[keyPath: originKeyPath] = start + offset
                    }
                    
                    print("resize hinders - new origin: \(newFrame.origin)")
                    // if this hinder are block by its hinder, then it should resize itself.
                    // Otherwise, it should be resize by the container.
                    let hinderEdge = hinderHinders.reduce(sign > 0 ? bentoModel.containerSize.width : 0) { partialResault, child in
                        sign > 0 ? // next hinder start minus gap
                        min(partialResault, child.frame.point(at: direction.inverted)[keyPath: originKeyPath] - bentoModel.bentoGap) :
                        max(partialResault, child.frame.point(at: direction.inverted)[keyPath: originKeyPath] + bentoModel.bentoGap)
                    }
                    newFrame.size[keyPath: sizeKeyPath] = sign > 0 ?
                    min(hinderEdge - newFrame.origin[keyPath: originKeyPath], hinder.frame.size[keyPath: sizeKeyPath]) :
                    min(start - hinderEdge, hinder.frame.size[keyPath: sizeKeyPath])

                    if sign < 0 {
                        newFrame.origin[keyPath: originKeyPath] = start + offset - max(
                            hinder.minimumSize[keyPath: sizeKeyPath],
                            newFrame.size[keyPath: sizeKeyPath]
                        )
                    }
                    
                    print("resize hinders - \(direction) - hinderEdge: \(hinderEdge), newFrame: \(newFrame)")
                    if !newFrame.isValid ||
                        newFrame.size[keyPath: sizeKeyPath] < hinder.minimumSize[keyPath: sizeKeyPath] ||
                        newFrame.origin[keyPath: originKeyPath] < 0 {
                        // recursive find hinders
                        newFrame.size[keyPath: sizeKeyPath] = max(newFrame.size[keyPath: sizeKeyPath], hinder.minimumSize[keyPath: sizeKeyPath])
                        let (offsetFix, rects) = resizeHinders(
                            of: hinder,
                            hinders: hinderHinders,
                            direction: direction,
                            start: newFrame.point(at: direction)[keyPath: originKeyPath] + bentoModel.bentoGap * sign
                        )
                        if sign > 0 {
                            offset = min(offset, min(0, offsetFix))
                        } else {
                            offset = max(offset, max(0, offsetFix))
                        }
                        newFrame = newFrame.offsetBy(dx: isHorizontal ? offset : .zero, dy:  isHorizontal ? 0 : offset)
                        dirtyRects.append(contentsOf: rects)
                        
                        let dirtyDirectionalRange = ([newFrame] + hinders.map{$0.frame}).reduce((0, 0)) {
                            isHorizontal ? (min($0.0, $1.minY), max($0.1, $1.maxY)) : (min($0.0, $1.minX), max($0.1, $1.maxX))
                        }
                        dirtyRects.append(
                            CGRect(
                                origin: newFrame.offsetBy(dx: sign > 0 ? 0 : -bentoModel.bentoGap, dy: sign > 0 ? 0 : -bentoModel.bentoGap).origin,
                                size: CGSize(
                                    width: isHorizontal ? (newFrame.width + sign > 0 ? bentoModel.bentoGap : 0) : dirtyDirectionalRange.1 - dirtyDirectionalRange.0,
                                    height: isHorizontal ? dirtyDirectionalRange.1 - dirtyDirectionalRange.0 : newFrame.height + sign > 0 ? bentoModel.bentoGap : 0
                                )
                            )
                        )
                    }
                    bentoModel.items[index].frame = newFrame
                    print("resize hinders done", newFrame)
                } else { // revert hinders changes
                    guard let initialHinder = self.initialStateBeforeDrag?[hinder.itemID],
                          let index = self.items.firstIndex(where: {$0.itemID == hinder.itemID}) else { continue }
                    
                    var frame = CGRect(
                        x: direction == .trailing ? max(initialHinder.x, start) : bentoModel.items[index].frame.origin.x,
                        y: direction == .bottom ? max(initialHinder.y, start) : bentoModel.items[index].frame.origin.y,
                        width: isHorizontal ? min(initialHinder.width, (hinder.frame.point(at: direction).x - start) * sign) :
                            self.items[index].frame.width,
                        height: isHorizontal ? bentoModel.items[index].frame.height :
                            min(initialHinder.height, (self.items[index].frame.point(at: direction).y - start) * sign)
                    )
                    print("resize hinders revert----------------------------")
                    print("resize hinders revert - frame: \(frame), hinder's frame: \(hinder.frame), union: \(frame.union(hinder.frame))")
                    // Revert its hinders first if any hinders has been resized.
                    // 存在一种情况，突然revert，导致一下空出很多空间，需要递归算出revert的距离
                    if hinderHinders.contains(where: { item in
                        item.frame != initialStateBeforeDrag?[item.itemID]?.frame
                    }) {
                        let maxWidth = hinderHinders.reduce(CGFloat.greatestFiniteMagnitude) {
                            guard let initialState = initialStateBeforeDrag?[$1.itemID] else { return $0 }
                            return min(
                                $0,
                                initialState.frame.point(at: direction.inverted)[keyPath: originKeyPath] - sign * (start + bentoModel.bentoGap)
                            )
                        }
                        frame.size[keyPath: sizeKeyPath] = max(hinder.minimumSize[keyPath: sizeKeyPath], maxWidth)
                        print("resize hinders revert - maxWidth: \(maxWidth)")
                        let (offset, rects) = resizeHinders(
                            of: item,
                            hinders: hinderHinders,
                            direction: direction,
                            start: start + (hinder.minimumSize[keyPath: sizeKeyPath] + bentoModel.bentoGap) * sign
                        )
                        dirtyRects.append(contentsOf: rects)
                        dirtyRects.append(
                            frame.union(hinder.frame)
                        )
                    }
                    bentoModel.items[index].frame = frame
                }
            }
            print("resize hinders done for \(item.frame), dirtyRects: \(dirtyRects)")
            return (offset: offset, dirtyRects: dirtyRects)
        }
        
        switch anchor {
            case .topLeading:
                let (offsetXFix, dirtyXRects) = resizeHinders(of: item, direction: .leading, start: newFrame.minX - bentoGap)
                newFrame.origin.x += offsetXFix
                newFrame.size.width -= offsetXFix
                flushRegions.append(contentsOf: dirtyXRects)
                
                let (offsetYFix, dirtyYRects) = resizeHinders(of: item, direction: .top, start: newFrame.minY - bentoGap)
                newFrame.origin.y += offsetYFix
                newFrame.size.height -= offsetYFix
                flushRegions.append(contentsOf: dirtyYRects)
            case .bottomTrailing:
                let (offsetXFix, dirtyXRects) = resizeHinders(of: item, direction: .trailing, start: newFrame.maxX + bentoGap)
                newFrame.size.width += offsetXFix
                flushRegions.append(contentsOf: dirtyXRects)
                
                let (offsetYFix, dirtyYRects) = resizeHinders(of: item, direction: .bottom, start: newFrame.maxY + bentoGap)
                flushRegions.append(contentsOf: dirtyYRects)
            default:
                break
        }
        
        // min size check
        newFrame.size.width = max(
            item.minimumSize.width,
            min(newFrame.width, bentoModel.containerSize.width - newFrame.origin.x)
        )
        newFrame.size.height = max(
            item.minimumSize.height,
            newFrame.height
        )
        
        print(#function, "newWidth: \(newWidth), newHeight: \(newHeight)")
        
        bentoModel.items[index].frame = newFrame
        
        /**
         由于每次resize都会可能会导致`OccupyState`发生变化，即`Hinders`是会变化的，
         因此需要刷新状态，但所有刷新一遍是一个非常消耗性能的操作，所以要针对性的刷新。
         ------
         在缩放的时候，可以知道：
         > 由于`OccupyState`同时受`minItemSize`的影响，因此缩放的时候仍然可能发生变化。
         > 目前是先限制`minItemSize`为相对静态的——当前items中最小的限制大小。
         - 缩放前后面积小的那一个状态区域内，`OccupyState`是不会发生变化的。
         - 如果没有发生障碍物因最小面积限制而移动，缩放前后面积大的区域外一个最小单元格外的`OccupyState`是不会发生变化的。
         - 主要难题就是如何解决在当发生了有障碍物因最小面积限制而移动的情况下，`OccupyState`的刷新逻辑。
         */
        
        flushRegions.append(
            contentsOf: itemBeforeResized.frame.size.areaSize > newFrame.size.areaSize ?
            itemBeforeResized.frame.substract(newFrame) :
                CGRect(
                    x: max(0, newFrame.minX - bentoModel.bentoGap),
                    y: max(0, newFrame.minY - bentoModel.bentoGap),
                    width: min(bentoModel.containerSize.width - max(0, newFrame.minX - bentoModel.bentoGap), newFrame.maxX + bentoModel.bentoGap),
                    height: min(bentoModel.containerSize.height - max(0, newFrame.minY - bentoModel.bentoGap), newFrame.maxY + bentoModel.bentoGap)
                ).substract(itemBeforeResized.frame)
        )
        
        bentoModel.flushState(regions: flushRegions)
    }

    private func onResizeEnd() {
        itemBeforeResized = nil
        bentoModel.resizedItemID = nil
        bentoModel.flushState()
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat

    nonisolated func path(in rect: CGRect) -> Path {
        return Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: 0))
            if radius < min(rect.width, rect.height), radius > 0 {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                    control:  CGPoint(x: rect.maxX, y: rect.maxY)
                )
                path.addLine(to: CGPoint(x: 0, y: rect.maxY))
            } else {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: 0, y: rect.maxY))
            }
        }
    }
}

extension CGRect {
    func point(at anchor: UnitPoint) -> CGPoint {
        switch anchor {
            case .topLeading:
                CGPoint(x: minX, y: minY)
            case .top:
                CGPoint(x: midX, y: minY)
            case .topTrailing:
                CGPoint(x: maxX, y: minY)
            case .leading:
                CGPoint(x: minX, y: midY)
            case .center:
                CGPoint(x: midX, y: midY)
            case .trailing:
                CGPoint(x: maxX, y: midY)
            case .bottomLeading:
                CGPoint(x: minX, y: maxY)
            case .bottom:
                CGPoint(x: midX, y: maxY)
            case .bottomTrailing:
                CGPoint(x: maxX, y: maxY)
            default:
                CGPoint.zero
        }
    }
}

extension UnitPoint {
    var inverted: UnitPoint {
        switch self {
            case .topLeading:
                    .bottomTrailing
            case .top:
                    .bottom
            case .topTrailing:
                    .bottomLeading
            case .leading:
                    .trailing
            case .center:
                    .center
            case .trailing:
                    .leading
            case .bottomLeading:
                    .topTrailing
            case .bottom:
                    .top
            case .bottomTrailing:
                    .topLeading
            default:
                    .center
        }
    }
}

#Preview {
    BentoExampleView()
}
