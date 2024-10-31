//
//  VBento.swift
//  BentoDemo
//
//  Created by Dove Zachary on 2024/10/27.
//

import SwiftUI

internal struct VBentoLayout<Item: BentoItem>: Layout {
    @Environment(BentoModel<Item>.self) var bentoModel
    var items: [Item]
    
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 10
        
        
        
        return CGSize(
            width: width,
            height: 10 //bentoModel.columnsCount
        )
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
//        print("placeSubviews(in bounds: \(bounds), proposal: \(proposal), subviews: \(subviews), cache: inout ())")
//        subviews.first?.place(at: .zero, proposal: <#T##ProposedViewSize#>)
        
        for subview in subviews {
            
        }
    }
}


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
            
            BentoDropLayerView<Item>()
        }
//        .background {
//            BentoPlaceholderView<Item>()
//        }
//        .padding(.horizontal, pagePadding)
//        .containerRelativeFrame(.horizontal)
        .dropDestination(for: Item.self) { items, location in
            bentoModel.isDragging = false
            return true
        }
        .background {
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .onChange(of: geometry.size, initial: true) { oldValue, newValue in
                        bentoModel.containerSize = newValue
                    }
            }
        }
        .environment(bentoModel)
    }
}

#Preview {
    BentoExampleView()
}
