//
//  BentoDropLayerView.swift
//  BentoDemo
//
//  Created by Dove Zachary on 2024/10/27.
//

import SwiftUI

struct BentoDropLayerView<Item: BentoItem>: View {
    @Environment(BentoModel<Item>.self) var bentoModel
    
    var columnsCount: Int { bentoModel.columnsCount }
    var bentoBaseSize: CGFloat { bentoModel.bentoBaseSize }
    var bentoGap: CGFloat { bentoModel.bentoGap }
    var gridColumns: [GridItem] { bentoModel.gridColumns }
    
    var items: [Item] { bentoModel.items }
    
    @State private var isDraggingCooldown = false
    
    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 0) {
//            ForEach(bentoModel.placehoders, id: \.self) { i in
//                Rectangle()
//                    .fill(.clear)
//                    .frame(
//                        width: bentoBaseSize + bentoModel.bentoGap,
//                        height: bentoBaseSize + bentoModel.bentoGap
//                    )
//                    .dropDestination(for: Item.self) { items, location in
//                        //                        print("drop ")
//                        bentoModel.isDragging = false
//                        isDraggingCooldown = true
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                            isDraggingCooldown = false
//                        }
//                        return true
//                    } isTargeted: { isTargeted in
//                        if !isDraggingCooldown {
//                            bentoModel.isDragging = true
//                        }
//                        if isTargeted, let draggedItem = bentoModel.draggedItem {
//                            let newPos: (x: Int, y: Int) = (
//                                x: i % columnsCount,
//                                y: i / columnsCount
//                            )
//                            dropBentoItem(draggedItem, pos: newPos)
//                        }
//                    }
//            }
        }
    }
    
    func dropBentoItem(_ item: Item, pos: (x: Int, y: Int)) {
//        var newItem = item.duplicated(withSameID: true)
//        newItem.x = pos.x
//        newItem.y = pos.y
//        
//        // find the bento item
//        guard let index = bentoModel.items.firstIndex(of: item) else { return }
//        
//        func checkCanPerformDrag(draggedItems: [Item]) -> Bool {
//            let remainsItems = bentoModel.items.filter({ item in
//                !draggedItems.contains(where: {$0.itemID == item.itemID})
//            })
//            
//            let result = remainsItems.allSatisfy({ remainsItem in
//                draggedItems.allSatisfy({!$0.checkIsOverlay(with: remainsItem)})
//            }) &&
//            (remainsItems + draggedItems).allSatisfy({
//                $0.x >= 0 && $0.x + $0.width <= columnsCount &&
//                $0.y >= 0
//            })
//            
//            print("checkCanPerformDrag - draggedItems: \(draggedItems), items: \(bentoModel.items)")
//            
//            return result
//        }
//        
//        
//        let canDragDirectly = bentoModel.items.allSatisfy({
//            $0 == item || !$0.checkIsOverlay(with: newItem)
//        }) && newItem.x + newItem.width <= columnsCount
//        
//        if canDragDirectly {
//            withAnimation(.bouncy(duration: 0.4, extraBounce: 0.05)) {
//                bentoModel.items[index].x = pos.x
//                bentoModel.items[index].y = pos.y
//            }
//            bentoModel.draggedItem = bentoModel.items[index]
//            return
//        }
//        
//        if let targetItemIndex = bentoModel.items.firstIndex(where: {$0.checkIsOverlay(with: newItem)}) {
//            var targetItem = bentoModel.items[targetItemIndex]
//            targetItem.x = min(columnsCount, max(0, item.x + item.width - targetItem.width))
//            targetItem.y = max(0, item.y + item.height - targetItem.height)
//            let canSwap = !newItem.checkIsOverlay(with: targetItem) && checkCanPerformDrag(draggedItems: [newItem, targetItem])
//            if canSwap {
//                withAnimation(.bouncy(duration: 0.4, extraBounce: 0.05)) {
//                    bentoModel.items[targetItemIndex].x = targetItem.x
//                    bentoModel.items[targetItemIndex].y = targetItem.y
//                    bentoModel.items[index].x = pos.x
//                    bentoModel.items[index].y = pos.y
//                }
//                bentoModel.draggedItem = bentoModel.items[index]
//                return
//            } else {
//                bentoModel.forceTransformItem(item.itemID, to: newItem)
//                bentoModel.draggedItem = bentoModel.items[index]
//            }
//        }
//        
    }
}

#Preview {
    BentoExampleView()
}
