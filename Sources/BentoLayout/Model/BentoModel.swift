//
//  BentoModel.swift
//  BentoDemo
//
//  Created by Dove Zachary on 2024/10/27.
//

import SwiftUI
import Combine

import ChocofordUI
import ChocofordEssentials

public enum BentoEvent<Item: BentoItem> {
    case didInsert(Item)
    case didRemove(UUID)
}

@Observable
public class BentoModel<Item: BentoItem> {
    public var items: [Item] = [] {
        didSet { // not good, but worked
            undoManager.recordCheckpoint()
        }
    }
    
    public private(set) var undoManager: BentoUndoManager<Item>
    
    internal var minItemSize: CGSize {
        items.reduce(
            CGSize(
                width: containerSize.width + 1,
                height: containerSize.height + 1
            )
        ) {
            CGSize(width: min($0.width, $1.width), height: min($0.height, $1.height))
        }
    }
    
    public init() where Item == DefaultBentoItem {
        self.eventsHandler = { (_: BentoEvent<Item>) -> Void in }
        self.items = []
        self.undoManager = BentoUndoManager(parent: nil)
        self.undoManager.parent = self
    }
    
    public init(
        items: [Item] = [],
        eventsHandler: @escaping (BentoEvent<Item>) -> Void = { _ in }
    ) {
        self.eventsHandler = eventsHandler
        self.items = items
        self.undoManager = BentoUndoManager(parent: nil)
        self.undoManager.parent = self
    }
    
    public var eventsHandler: (BentoEvent<Item>) -> Void
    
    public var containerSize: CGSize = .zero
    public var gridColumns: [GridItem] {
        .init(
            repeating: GridItem(.flexible()),
            count: max(0, Int(ceil(containerSize.width / minItemSize.width)))
        )
    }
    public let pagePadding: CGFloat = 0
    public var bentoBaseSize: CGFloat {
        max(0, (containerSize.width - 2 * pagePadding - Double(columnsCount - 1) * bentoGap) / Double(columnsCount))
    }
    public let bentoGap: CGFloat = 10
    
    public var columnsCount: Int { gridColumns.count }
    public let paddingRows = 6
    
    public var canMove: Bool = true
    public var canResize: Bool = true
    
    public var draggedItemID: UUID?
    public var draggedItem: Item? {
        get { items.first(where: {$0.itemID == draggedItemID}) }
    }
    public var isDragging: Bool { draggedItemID != nil }
    public var resizedItemID: UUID?
    public var resizedItem: Item? {
        get { items.first(where: {$0.itemID == resizedItemID}) }
    }
    public var isResizing: Bool { resizedItemID != nil }
    
    private func findConflictItems(with item: Item) -> [Item] {
        self.items.filter({$0.itemID != item.itemID}).filter({$0.checkIsOverlay(with: item)})
    }
    
    /// Get the top adjacent items.
    private func getTopAdjacentItems(of item: Item) -> [Item] {
        self.items
            .filter({$0.itemID != item.itemID})
            .filter({
                $0.y < item.y &&
                $0.x < item.x + item.width &&
                $0.x + $0.width > item.x
            })
    }
    
    /// Get the bottom adjacent items.
    private func getBottomAdjacentItems(of item: Item) -> [Item] {
        self.items
            .filter({$0.itemID != item.itemID})
            .filter({
                $0.y > item.y &&
                $0.x < item.x + item.width &&
                $0.x + $0.width > item.x
            })
    }
    
    private func getTrailingAdjacentItems(of item: Item) -> [Item] {
        self.items
            .filter({$0.itemID != item.itemID})
            .filter({
                item.x > $0.x &&
                $0.y < item.y + item.height &&
                $0.y + $0.height > item.y
            })
    }
    
    /// 把所有冲突的bento item挤下去
    public func forceTransformItem(_ itemID: UUID, to newItem: Item) {
        guard let itemIndex = self.items.firstIndex(where: {$0.itemID == itemID}) else { return }
        guard newItem.x >= 0, newItem.y >= 0/*, newItem.x + newItem.width <= columnsCount*/ else { return }
        
        withAnimation(.bouncy(duration: 0.4)) {
            items[itemIndex].x = newItem.x
            items[itemIndex].y = newItem.y
            items[itemIndex].width = newItem.width
            items[itemIndex].height = newItem.height
        }
        
        var conflictItems = self.items.filter({$0.itemID != itemID}).filter({$0.checkIsOverlay(with: newItem)})
        for item in conflictItems {
            if let index = self.items.firstIndex(of: item) {
                withAnimation(.bouncy(duration: 0.4)) {
                    self.items[index].y = newItem.y + newItem.height
                }
            }
        }
        var loopCount = 0
        while !conflictItems.isEmpty {
            if loopCount > 10000 {
                break
            }
            let item = conflictItems.removeFirst()
            var adjacencies: [Item] = self.getBottomAdjacentItems(of: item)
            print("adjacencies: \(adjacencies)")
            while !adjacencies.isEmpty {
                if loopCount > 10000 {
                    break
                }
                let adjacency = adjacencies.removeFirst()
                
                if let index = conflictItems.firstIndex(of: adjacency) {
                    conflictItems.remove(at: index)
                }
                
                guard let itemLatest = self.items.first(where: {$0.itemID == item.itemID}) else { continue }
                if adjacency.checkIsOverlay(with: itemLatest) {
                    adjacencies.append(contentsOf: getBottomAdjacentItems(of: adjacency))
                    if let index = self.items.firstIndex(where: {$0.itemID == adjacency.itemID}) {
                        withAnimation(.bouncy(duration: 0.4)) {
                            self.items[index].y = itemLatest.y + itemLatest.height
                        }
                    }
                }
                loopCount += 1
            }
        }
        if loopCount > 10000 {
            print("error")
        }
    }
    
    /// Insert a new bento item.
    public func addBentoItem(_ item: Item) {
        // temp
        defer { flushState() }
        
        var item = item
        
        var isOverlap = false
        for existedItem in self.items {
            if item.checkIsOverlay(with: existedItem) {
                isOverlap = true
                break
            }
        }
        
        guard isOverlap else {
            self.items.append(item)
            self.eventsHandler(.didInsert(item))
            return
        }
        
        var y: CGFloat = 0
        
        var tryCount = 0
        while tryCount < 1_000_000 {
            defer { tryCount += 1 }
            for x in stride(from: 0, to: containerSize.width - item.width, by: minItemSize.width + bentoGap) {
                var newBentoItem = item.duplicated(withSameID: false)
                newBentoItem.x = x
                newBentoItem.y = y
                if self.items.allSatisfy({ !newBentoItem.checkIsOverlay(with: $0) }) {
                    item.x = newBentoItem.x
                    item.y = newBentoItem.y
                    self.items.append(item)
                    self.eventsHandler(.didInsert(item))
                    return
                }
            }
            y += minItemSize.height + bentoGap
        }
        
   }
   
    public func removeBentoItem(_ item: Item) {
        self.items.removeAll(where: {$0.itemID == item.itemID})
        self.eventsHandler(.didRemove(item.itemID))
        flushState()
    }
    
    public func removeBentoItem(id itemID: UUID) {
        self.items.removeAll(where: {$0.itemID == itemID})
        self.eventsHandler(.didRemove(itemID))
        flushState()
    }
    
    /// Rearrange bento items.
    public func rearrangeBentoItems(direction: UnitPoint = .top) {
        var delay: Double = 0
        switch direction {
            case .top:
                self.items = self.items.sorted(by: { $0.x < $1.x }).sorted(by: { $0.y < $1.y })
                for i in 0..<self.items.count {
                    let item = self.items[i]
                    if item.y == 0 { continue }
                    let topAdjacents = getTopAdjacentItems(of: item)
                    withAnimation(.bouncy(duration: 0.4, extraBounce: 0.05).delay(delay + Double.random(in: 0..<0.1))) {
                        self.items[i].y = topAdjacents.reduce(0, {
                            max($0, $1.y + $1.height + bentoGap)
                        })
                    }
                    delay += 0.2
                }
            case .leading:
                self.items = self.items.sorted(by: { $0.y < $1.y }).sorted(by: { $0.x < $1.x })
                for i in 0..<self.items.count {
                    let item = self.items[i]
                    if item.x == 0 { continue }
                    let trailingAdjacents = getTrailingAdjacentItems(of: item)
                    withAnimation(.bouncy(duration: 0.4, extraBounce: 0.05).delay(delay + Double.random(in: 0..<0.1))) {
                        self.items[i].x = trailingAdjacents.reduce(0, {
                            max($0, $1.x + $1.width + bentoGap)
                        })
                    }
                    delay += 0.2
                }
                
            default:
                break
        }
        flushState()
    }
    
//    public func partitionBentoItems() {
//        guard !self.items.isEmpty else { return }
//        var doneItems: [Item] = [self.items.first!]
//        
//        // get the bounds
//        let maxX = self.items.reduce(0) {
//            max($0, $1.x)
//        }
//        
//        let theTopLeadingItem = self.items.dropFirst().reduce(self.items.first!) {
//            if $1.x < $0.x, $1.y < $0.y {
//                return $1
//            } else {
//                return $0
//            }
//        }
//        
//        let items = self.items.dropFirst()
//        
//        for i in stride(from: 0, to: maxX, by: bentoBaseSize) {
//            
//        }
//    }
    
    /// n rows x m colums
    var gridOccupies: [[[UUID]]] = []
    /// true - occupied
    var gridOccupyState: [[Bool]] {
        gridOccupies.map {
            $0.map {
                !$0.isEmpty
            }
        }
    }
    
    func flushGridOccupyState() {
        let start = Date()
        gridOccupies = stride(from: 0, to: containerSize.height, by: minItemSize.height).map { y in
            stride(from: 0, to: containerSize.width, by: minItemSize.width).map { x in
                let rect = CGRect(x: x, y: y, width: minItemSize.width, height: minItemSize.height)
                return self.items.filter{ $0.frame.intersects(rect) }.map{ $0.itemID }
            }
        }
        print(
            "[flushGridOccupyState] time cost: \(-start.timeIntervalSinceNow)",
            "gridOccupies: [\(gridOccupies.count) x \(gridOccupies.first?.count ?? 0)] count: \(gridOccupies.flatMap{$0}.count)",
            "containerSize: \(containerSize), minItemSize: \(minItemSize)",
            "gridOccupies: \(gridOccupies)",
            "---------------------------------",
            separator: "\n"
        )
    }
    
    private func getGridItems(at point: CGPoint) -> [Item] {
        let wIndex = Int(point.x / minItemSize.width)
        let hIndex = Int(point.y / minItemSize.height)
        guard gridOccupyState.count > hIndex, gridOccupyState[hIndex].count > wIndex else {
            return []
        }
        
        let rect = CGRect(
            x: CGFloat(wIndex) * minItemSize.width,
            y: CGFloat(hIndex) * minItemSize.height,
            width: minItemSize.width,
            height: minItemSize.height
        )
        
        if !gridOccupyState[hIndex][wIndex] { return [] }
        
        return self.items.filter({$0.frame.intersects(rect)})
    }
    
    func getPotentialHinderItems(of item: Item) -> [Item] {
        let frame = item.frame
        let itemsMap = self.items.filter({$0.itemID != item.itemID}).map {
            [$0.itemID : $0]
        }.merged()
        
        var hinders = Set<Item>()
        // get grid items
        for y in stride(
            from: max(0, Int(frame.minY / minItemSize.height) - 1),
            through: min(Int(containerSize.height / minItemSize.height) - 1, Int(frame.maxY / minItemSize.height) + 1),
            by: 1
        ) {
            for x in stride(
                from: max(0, Int(frame.minX / minItemSize.width) - 1),
                through: min(Int(containerSize.width / minItemSize.width) - 1, Int(frame.maxX / minItemSize.width) + 1),
                by: 1
            ) {
                guard y < gridOccupies.count, let yFirst = gridOccupies.first, x < yFirst.count else {
                    continue
                }
                for itemID in gridOccupies[y][x] {
                    if let item = itemsMap[itemID] {
                        hinders.insert(item)
                    }
                }
            }
        }
//        print(#function, hinders)
        return Array(hinders)
    }
    
    public func swapItemFrame(aID: UUID, bID: UUID) {
        guard let aIndex = self.items.firstIndex(where: {$0.itemID == aID}),
              let bIndex = self.items.firstIndex(where: {$0.itemID == bID}) else {
            print("Swap failed, find no items.")
            return
        }
        let aFrame = self.items[aIndex].frame
        let bFrame = self.items[bIndex].frame
        self.items[aIndex].frame = bFrame
        self.items[bIndex].frame = aFrame
    }
    
    struct CrossHinders: CustomStringConvertible {
        var top: [Item]
        var leading: [Item]
        var bottom: [Item]
        var trailing: [Item]
        
        init(top: [Item], leading: [Item], bottom: [Item], trailing: [Item]) {
            self.top = top
            self.leading = leading
            self.bottom = bottom
            self.trailing = trailing
        }
        
        init() {
            self.top = []
            self.leading = []
            self.bottom = []
            self.trailing = []
        }
        
        var description: String {
"""
CrossHinders
------------------------------------
top: \(top)
leading: \(leading)
bottom: \(bottom)
trailing: \(trailing)
"""
        }
    }
    
    internal func getCrossHinders(of item: Item) -> CrossHinders {
        let theItem = item
        var crossHinders = CrossHinders()
        for item in self.items.filter({$0.itemID != theItem.itemID}) {
            let verticalOverlay = theItem.frame.minX < item.frame.maxX && theItem.frame.maxX > item.frame.minX
            let horizontalOverlay = theItem.frame.minY < item.frame.maxY && theItem.frame.maxY > item.frame.minY
            
            // top
            if item.y + item.height <= theItem.y, verticalOverlay {
                crossHinders.top.append(item)
            }
            
            // bottom
            if item.y >= theItem.y + theItem.height, verticalOverlay {
                crossHinders.bottom.append(item)
            }
            
            // leading
            if item.x + item.width <= theItem.x, horizontalOverlay {
                crossHinders.leading.append(item)
            }
            
            // trailing
            if item.x >= theItem.x + theItem.width, horizontalOverlay {
                crossHinders.trailing.append(item)
            }
        }
        return crossHinders
    }
    
    public func stretchItem(id itemID: UUID) {
        guard let itemIndex = self.items.firstIndex(where: {$0.itemID == itemID}) else { return }
        
        var theItem = self.items[itemIndex]
        
        var newFrame = theItem.frame
        
        let crossHinders = getCrossHinders(of: theItem)
        
        newFrame.origin.y = crossHinders.top.reduce(-self.bentoGap) {
            max($0, $1.frame.maxY)
        } + self.bentoGap
        if !crossHinders.bottom.isEmpty {
            newFrame.size.height = crossHinders.bottom.dropFirst().reduce(crossHinders.bottom.first!.y) {
                min($0, $1.frame.minY)
            } - newFrame.origin.y - self.bentoGap
        } else {
            newFrame.size.height = theItem.frame.maxY - newFrame.origin.y
        }
        
        theItem.frame = newFrame
        let crossHinders2 = getCrossHinders(of: theItem)
        
        newFrame.origin.x = crossHinders2.leading.reduce(-self.bentoGap) {
            max($0, $1.frame.maxX)
        } + self.bentoGap
        newFrame.size.width = crossHinders2.trailing.reduce(containerSize.width) {
            min($0, $1.frame.minX)
        } - newFrame.origin.x - self.bentoGap

        
        self.items[itemIndex].frame = newFrame
    }
    
    // MARK: - Auxiliary line
    /// HorizontalAlignemnt - leading <-> trailing
    var horizontalAlignments: Set<CGFloat> = []
    var verticalAlignments: Set<CGFloat> = []
    var activeAlignments: [AlignInfo] = []
    var alignmentThreshold: CGFloat = 10
    
    enum AlignInfo: Hashable, CustomStringConvertible {
        case horizontal(HorizontalAlignInfo)
        case vertical(VerticalAlignInfo)
        
        struct HorizontalAlignInfo: Hashable, CustomStringConvertible {
            var alignment: HorizontalAlignment
            var value: CGFloat
            func hash(into hasher: inout Hasher) {
                hasher.combine("HorizontalAlignInfo")
                switch alignment {
                    case .trailing:
                        hasher.combine(0)
                    case .center:
                        hasher.combine(1)
                    case .trailing:
                        hasher.combine(2)
                    default:
                        break
                }
                hasher.combine(value)
            }
            
            var description: String {
                "[\(alignment): \(value)]"
            }
        }
        
        struct VerticalAlignInfo: Hashable, CustomStringConvertible {
            var alignment: VerticalAlignment
            var value: CGFloat
            func hash(into hasher: inout Hasher) {
                hasher.combine("VerticalAlignInfo")
                switch alignment {
                    case .top:
                        hasher.combine(0)
                    case .center:
                        hasher.combine(1)
                    case .bottom:
                        hasher.combine(2)
                    default:
                        break
                }
                hasher.combine(value)
            }
            
            var description: String {
                "[\(alignment): \(value)]"
            }
        }
        
        var description: String {
            switch self {
                case .horizontal(let horizontalAlignInfo):
                    "horizontal: \(horizontalAlignInfo.description)"
                case .vertical(let verticalAlignInfo):
                    "vertical: \(verticalAlignInfo.description)"
            }
        }
    }
    
    func flushAlignments() {
        horizontalAlignments.removeAll()
        verticalAlignments.removeAll()
        let checkedItems = items.filter({$0.itemID != draggedItemID && $0.itemID != resizedItemID})
        for item in checkedItems {
            horizontalAlignments.insert(item.frame.minX)
            horizontalAlignments.insert(item.frame.midX)
            horizontalAlignments.insert(item.frame.maxX)
            verticalAlignments.insert(item.frame.minY)
            verticalAlignments.insert(item.frame.midY)
            verticalAlignments.insert(item.frame.maxY)
        }
    }
    
    /// Get all available alignments for the current frame.
    func getAvailableAlignments(frame: CGRect, threshold: CGFloat? = nil) -> [AlignInfo] {
        let threshold = threshold ?? alignmentThreshold
        var results: [AlignInfo] = []
        for horizontalAlignment in horizontalAlignments {
            if horizontalAlignment <= frame.minX + threshold, horizontalAlignment >= frame.minX - threshold {
                results.append(.horizontal(.init(alignment: .leading, value: horizontalAlignment)))
            } else if horizontalAlignment <= frame.midX + threshold, horizontalAlignment >= frame.midX - threshold {
                    results.append(.horizontal(.init(alignment: .center, value: horizontalAlignment)))
            } else if horizontalAlignment <= frame.maxX + threshold, horizontalAlignment >= frame.maxX - threshold {
                results.append(.horizontal(.init(alignment: .trailing, value: horizontalAlignment)))
            }
        }
        for verticalAlignment in verticalAlignments {
            if verticalAlignment <= frame.minY + threshold,
               verticalAlignment >= frame.minY - threshold {
                results.append(.vertical(.init(alignment: .top, value: verticalAlignment)))
            } else if verticalAlignment <= frame.midY + threshold,
                      verticalAlignment >= frame.midY - threshold {
                results.append(.vertical(.init(alignment: .center, value: verticalAlignment)))
            } else if verticalAlignment <= frame.maxY + threshold,
                      verticalAlignment >= frame.maxY - threshold {
                results.append(.vertical(.init(alignment: .bottom, value: verticalAlignment)))
            }
        }
        print(#function, results)
        return results
    }
    
    /// Get the frame of the closest alignment.
    func getMostAlignedFrame(
        frame: CGRect,
        direction: UnitPoint? = nil
    ) -> CGRect? {
        let alignInfos = getAvailableAlignments(frame: frame)
        guard !alignInfos.isEmpty else { return nil }
        var closestOffset: CGSize = alignInfos.reduce(
            CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        ) { partialResult, info in
            switch info {
                case .horizontal(let info):
                    let offset: CGFloat
                    switch info.alignment {
                        case .leading:
                            guard direction == nil || direction?.x == 0 else {
                                return partialResult
                            }
                            offset = info.value - frame.minX
                        case .center:
                            guard direction == nil else { return partialResult }
                            offset = info.value - frame.midX
                        case .trailing:
                            guard direction == nil || direction?.x == 1 else {
                                return partialResult
                            }
                            offset = info.value - frame.maxX
                        default:
                            return partialResult
                    }
                    if abs(offset) < abs(partialResult.width) {
                        return CGSize(width: offset, height: partialResult.height)
                    } else {
                        return partialResult
                    }
                    
                case .vertical(let info):
                    let offset: CGFloat
                    switch info.alignment {
                        case .top:
                            guard direction == nil || direction?.y == 0 else {
                                return partialResult
                            }
                            offset = info.value - frame.minY
                        case .center:
                            guard direction == nil else { return partialResult }
                            offset = info.value - frame.midY
                        case .bottom:
                            guard direction == nil || direction?.y == 1 else {
                                return partialResult
                            }
                            offset = info.value - frame.maxY
                        default:
                            return partialResult
                    }
                    if abs(offset) < abs(partialResult.height) {
                        return CGSize(width: partialResult.width, height: offset)
                    } else {
                        return partialResult
                    }
            }
        }
        if closestOffset.width == .greatestFiniteMagnitude {
            closestOffset.width = 0
        }
        if closestOffset.height == .greatestFiniteMagnitude {
            closestOffset.height = 0
        }
        var mostAlignedFrame: CGRect = frame
        
        if let direction {
            if direction.x == 0 {
                mostAlignedFrame.origin.x -= closestOffset.width
                mostAlignedFrame.size.width += closestOffset.width
            } else if direction.x == 1 {
                mostAlignedFrame.size.width += closestOffset.width
            }
            if direction.y == 0 {
                mostAlignedFrame.origin.y -= closestOffset.height
                mostAlignedFrame.size.height += closestOffset.height
            } else if direction.y == 1 {
                mostAlignedFrame.size.height += closestOffset.height
            }
        } else {
            mostAlignedFrame = frame.offsetBy(dx: closestOffset.width, dy: closestOffset.height)
        }
        
        print(#function, frame, closestOffset, mostAlignedFrame)
        return mostAlignedFrame
    }
    
    func getAlignedAlignments(frame: CGRect) -> [AlignInfo] {
        var results = [AlignInfo]()
        let alignments = getAvailableAlignments(frame: frame)
        for alignment in alignments {
            switch alignment {
                case .horizontal(let horizontalAlignInfo):
                    switch horizontalAlignInfo.alignment {
                        case .leading:
                            if horizontalAlignInfo.value == frame.minX {
                                results.append(alignment)
                            }
                        case .center:
                            if horizontalAlignInfo.value == frame.midX {
                                results.append(alignment)
                            }
                        case .trailing:
                            if horizontalAlignInfo.value == frame.maxX {
                                results.append(alignment)
                            }
                        default: break
                    }
                case .vertical(let verticalAlignInfo):
                    switch verticalAlignInfo.alignment {
                        case .top:
                            if verticalAlignInfo.value == frame.minY {
                                results.append(alignment)
                            }
                        case .center:
                            if verticalAlignInfo.value == frame.midY {
                                results.append(alignment)
                            }
                        case .bottom:
                            if verticalAlignInfo.value == frame.maxY {
                                results.append(alignment)
                            }
                        default: break
                    }
            }
        }
        print("active alignments: \(results)")
        return results
    }
    
    /// This should be called every time item has been dragged/resized (before)
    func flushState() {
        flushGridOccupyState()
        flushAlignments()
    }
}

func getHinderItems<Item: BentoItem>(of item: Item, from items: [Item], direction: UnitPoint) -> [Item] {
    var hinders: [Item] = []
    switch direction {
        case .top:
            hinders = items.filter {
                item.frame.minX < $0.frame.maxX &&
                item.frame.maxX > $0.frame.minX &&
                item.frame.minY >= $0.frame.midY
            }
        case .bottom:
            hinders = items.filter {
                item.frame.minX < $0.frame.maxX &&
                item.frame.maxX > $0.frame.minX &&
                item.frame.maxY <= $0.frame.midY
            }
            
        case .leading:
            hinders = items.filter {
                item.frame.minY < $0.frame.maxY &&
                item.frame.maxY > $0.frame.minY &&
                item.frame.minX >= $0.frame.midX
            }
            
        case .trailing:
            hinders = items.filter {
                item.frame.minY < $0.frame.maxY &&
                item.frame.maxY > $0.frame.minY &&
                item.frame.maxX <= $0.frame.midX
            }
            
        default:
            hinders = []
    }
    
    print(#function, "direction: \(direction), hinders: \(hinders)")
    
    return hinders
}


@Observable
public class BentoUndoManager<Item: BentoItem> {
    var checkpoints: [[Item]] = []
    @ObservationIgnored
    private var readyToMakeNewCheckpoints = true
    @ObservationIgnored
    private var newCheckpointPublisher = PassthroughSubject<Void, Never>()
    @ObservationIgnored
    private var newCheckpointCancellable: AnyCancellable?
    
    public var canUndo: Bool { currentIndex > 0 }
    public var canRedo: Bool { currentIndex < checkpoints.endIndex - 1 }
        
    @ObservationIgnored
    var parent: BentoModel<Item>?
    
    init(
        parent: BentoModel<Item>?
    ) {
        self.parent = parent
        newCheckpointCancellable = newCheckpointPublisher.debounce(for: 0.5, scheduler: RunLoop.main).sink {
            self.readyToMakeNewCheckpoints = true
        }
    }
    
    private var currentIndex = 0
//    {
//        get { checkpoints[currentIndex] }
//        set {
//            if readyToMakeNewCheckpoints {
//                if !checkpoints.isEmpty {
//                    checkpoints.removeLast(checkpoints.endIndex - 1 - currentIndex)
//                }
//                checkpoints.append(newValue)
//                currentIndex = checkpoints.endIndex - 1
//                self.readyToMakeNewCheckpoints = false
//            } else {
//                checkpoints[currentIndex] = newValue
//            }
//            newCheckpointPublisher.send()
//        }
//    }
    
    
    public func undo() {
        currentIndex = max(0, currentIndex - 1)
        applyChanges()
    }
    public func redo() {
        currentIndex = min(checkpoints.endIndex - 1, currentIndex + 1)
        applyChanges()
    }
    
    
    public func recordCheckpoint() {
        guard let parent else { return }
        if readyToMakeNewCheckpoints {
            if !checkpoints.isEmpty {
                checkpoints.removeLast(checkpoints.endIndex - 1 - currentIndex)
            }
            checkpoints.append(parent.items.map{$0.duplicated(withSameID: true)})
            currentIndex = checkpoints.endIndex - 1
            self.readyToMakeNewCheckpoints = false
        } else {
            checkpoints[currentIndex] = parent.items.map{$0.duplicated(withSameID: true)}
        }
        newCheckpointPublisher.send()
    }
    
    private func applyChanges() {
        guard let parent else { return }
        let targetItems = self.checkpoints[currentIndex]
        
        var newItems = parent.items
        
        // delete not in targetItems
        for (i, item) in parent.items.enumerated() {
            if !targetItems.contains(where: {$0.itemID == item.itemID}) {
                newItems.remove(at: i)
                parent.eventsHandler(.didRemove(item.itemID))
            }
        }
        
        // change & insert not in parent items
        for (i, item) in targetItems.enumerated() {
            if var originalItem = newItems.first(where: {$0.itemID == item.itemID}) {
                originalItem.applyChange(from: item)
            } else {
                let newItem = item.duplicated(withSameID: true)
                newItems.append(newItem)
                parent.eventsHandler(.didInsert(newItem))
            }
        }
        
        self.parent?.items = newItems
    }
}


#Preview {
    BentoExampleView()
}
