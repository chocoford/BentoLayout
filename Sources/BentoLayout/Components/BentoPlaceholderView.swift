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
        LazyVGrid(columns: bentoModel.gridColumns, spacing: 0) {
            ForEach(bentoModel.placehoders, id: \.self) { i in
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.placeholder, style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .frame(
                        width: bentoModel.bentoBaseSize + bentoModel.bentoGap,
                        height: bentoModel.bentoBaseSize + bentoModel.bentoGap
                    )
                    .opacity(bentoModel.isDragging || bentoModel.isResizing ? 1 : 0)
            }
        }
        .animation(.default, value: bentoModel.isDragging || bentoModel.isResizing)
    }
}

#Preview {
    BentoExampleView()
}
