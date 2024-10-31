//
//  BentoModel.swift
//  BentoDemo
//
//  Created by Dove Zachary on 2024/10/27.
//

import SwiftUI

public enum BentoEvent<Item: BentoItem> {
    case didInsert(Item)
    case didRemove(UUID)
}

@Observable
public class BentoModel<Item: BentoItem> {
    public var items: [Item]
    
//    private var minItemSize: CGSize {
//        items.reduce(
//            CGSize(
//                width: CGFloat.greatestFiniteMagnitude,
//                height: CGFloat.greatestFiniteMagnitude
//            )
//        ) {
//            CGSize(width: min($0.width, $1.width), height: min($0.width, $1.width))
//        }
//    }
    
    public init() where Item == DefaultBentoItem {
        self.items = []
        self.eventsHandler = { (_: BentoEvent<Item>) -> Void in }
    }
    
    public init(
        items: [Item] = [],
        eventsHandler: @escaping (BentoEvent<Item>) -> Void = { _ in }
    ) {
        self._items = items
        self.eventsHandler = eventsHandler
    }
    
    public var eventsHandler: (BentoEvent<Item>) -> Void
    
    public var containerSize: CGSize = .zero
    public let gridColumns: [GridItem] = .init(repeating: GridItem(.flexible()), count: 12)
    public let pagePadding: CGFloat = 0
    public var bentoBaseSize: CGFloat {
        max(0, (containerSize.width - 2 * pagePadding - Double(columnsCount - 1) * bentoGap) / Double(columnsCount))
    }
    public let bentoGap: CGFloat = 10
    
    public var columnsCount: Int { gridColumns.count }
    public let paddingRows = 6
    public var placehoders: [Int] {
        Array(
            repeating: 0,
            count: columnsCount * (items.reduce(0, {max($0, $1.y + $1.height)}) + paddingRows)
        ).enumerated().map{$0.offset}
    }
    
    public var draggedItem: Item?
    public var isDragging = false
    public var isResizing = false
    
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
    
    /// Get the top adjacent items.
    private func getBottomAdjacentItems(of item: Item) -> [Item] {
        self.items
            .filter({$0.itemID != item.itemID})
            .filter({
                $0.y > item.y &&
                $0.x < item.x + item.width &&
                $0.x + $0.width > item.x
            })
    }
    
    /// 把所有冲突的bento item挤下去
    public func forceTransformItem(_ itemID: UUID, to newItem: Item) {
        guard let itemIndex = self.items.firstIndex(where: {$0.itemID == itemID}) else { return }
        guard newItem.x >= 0, newItem.y >= 0, newItem.x + newItem.width <= columnsCount else { return }
        
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
        
        var y = 0
        
        while true {
            for i in 0..<columnsCount {
                var newBentoItem = item.duplicated(withSameID: false)
                newBentoItem.x = i
                newBentoItem.y = y
                if self.items.allSatisfy({ !newBentoItem.checkIsOverlay(with: $0) }) {
                    item.x = newBentoItem.x
                    item.y = newBentoItem.y
                    self.items.append(item)
                    self.eventsHandler(.didInsert(item))
                    return
                }
            }
        }
        
//        var tryCount = 0
//        while tryCount < 1_000_000 {
//            defer { tryCount += 1 }
//            for x in stride(from: 0, to: containerSize.width - item.width, by: minItemSize.width) {
//                var newBentoItem = item.duplicated(withSameID: false)
//                newBentoItem.x = x
//                newBentoItem.y = y
//                if self.items.allSatisfy({ !newBentoItem.checkIsOverlay(with: $0) }) {
//                    item.x = newBentoItem.x
//                    item.y = newBentoItem.y
//                    self.items.append(item)
//                    self.eventsHandler(.didInsert(item))
//                    return
//                }
//            }
//            y += minItemSize.height
//        }
   }
   
    public func removeBentoItem(_ item: Item) {
        self.items.removeAll(where: {$0.itemID == item.itemID})
        self.eventsHandler(.didRemove(item.itemID))
    }
    
    public func removeBentoItem(id itemID: UUID) {
        self.items.removeAll(where: {$0.itemID == itemID})
        self.eventsHandler(.didRemove(itemID))
    }
    
    /// Rearrange bento items.
    public func rearrangeBentoItems() {
        self.items = self.items.sorted(by: { $0.x < $1.x }).sorted(by: { $0.y < $1.y })
        var delay: Double = 0
        for i in 0..<self.items.count {
            let item = self.items[i]
            if item.y == 0 { continue }
            let topAdjacents = getTopAdjacentItems(of: item)
            withAnimation(.bouncy(duration: 0.4, extraBounce: 0.05).delay(delay + Double.random(in: 0..<0.1))) {
                self.items[i].y = topAdjacents.reduce(0, {
                    max($0, $1.y+$1.height)
                })
            }
            delay += 0.2
        }
        
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
}


#Preview {
    BentoExampleView()
}
