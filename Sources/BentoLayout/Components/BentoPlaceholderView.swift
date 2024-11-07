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
        VStack(spacing: 0) {
#if DEBUG
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
#endif
        }
        .animation(.default, value: bentoModel.isDragging || bentoModel.isResizing)
        .frame(width: bentoModel.containerSize.width, height: bentoModel.containerSize.height, alignment: .topLeading)
    }
}

#Preview {
    BentoExampleView()
}
