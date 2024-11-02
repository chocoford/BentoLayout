//
//  VBento.swift
//  BentoDemo
//
//  Created by Dove Zachary on 2024/10/27.
//

import SwiftUI

public struct VBento<Item: BentoItem, ItemContent: View>: View {
    var bentoModel: BentoModel<Item>
    var content: (Item) -> ItemContent
    
    public init(
        model: BentoModel<Item>,
        @ViewBuilder content: @escaping (Item) -> ItemContent
    ) {
        self.bentoModel = model
        self.content = content
    }
    
    var pagePadding: CGFloat { bentoModel.pagePadding }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.clear)
            
            BentoPlaceholderView<Item>()
            
            ZStack(alignment: .topLeading) {
                // anchor top
                Color.clear.frame(width: 10, height: 10)
                BentoItemsView(content: content)
            }
            .frame(
                maxWidth: bentoModel.bentoBaseSize * CGFloat(bentoModel.columnsCount) + bentoModel.bentoGap * CGFloat(bentoModel.columnsCount - 1),
                alignment: .topLeading
            )
            
            // Auxiliary line
            AuxiliaryLineView<Item>()
        }
        .background {
            GeometryReader { geometry in
                Rectangle()
                    .fill(.blue.gradient.opacity(0))
                    .onChange(of: geometry.size, initial: true) { oldValue, newValue in
                        bentoModel.containerSize = newValue
                    }
            }
        }
        .onChange(of: bentoModel.containerSize) { oldValue, newValue in
            if newValue.width > oldValue.width || newValue.height > oldValue.height  {
                bentoModel.flushGridOccupyState()
            }
        }
        .environment(bentoModel)
    }
}

#Preview {
    BentoExampleView()
}
