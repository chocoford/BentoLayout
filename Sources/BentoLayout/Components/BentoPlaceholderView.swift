//
//  BentoPlaceholderView.swift
//  BentoDemo
//
//  Created by Dove Zachary on 2024/10/27.
//

import SwiftUI

struct BentoPlaceholderView<Item: BentoItem>: View {
    @Environment(BentoModel<Item>.self) var bentoModel

    var items: [Item] { bentoModel.items }
    
    var body: some View {
        //        LazyVGrid(columns: bentoModel.gridColumns, spacing: bentoModel.bentoGap) {
        //            ForEach(0..<bentoModel.gridOccupies.flatMap{$0}.count, id: \.self) { _ in
        //                Rectangle()
        //                    .fill(.red.opacity(0.5))
        //                    .frame(
        ////                        width: bentoModel.minItemSize.width,
        //                        height: bentoModel.minItemSize.height
        //                    )
        //            }
        //        }
        VStack(spacing: 0) {
            ForEach(Array(bentoModel.gridOccupies.enumerated()), id: \.offset) { i, e in
                HStack(spacing: 0) {
                    ForEach(Array(e.enumerated()), id: \.offset) { j, _ in
                        Rectangle()
                            .fill(.red.opacity(0.05))
                            .stroke(.red.opacity(0.1))
                            .frame(
                                width: bentoModel.minItemSize.width,
                                height: bentoModel.minItemSize.height
                            )
                    }
                }
            }
        }
        .animation(.default, value: bentoModel.isDragging || bentoModel.isResizing)
        .frame(width: bentoModel.containerSize.width, height: bentoModel.containerSize.height, alignment: .topLeading)
    }
}

#Preview {
    BentoExampleView()
}
