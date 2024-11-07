//
//  VBento.swift
//  BentoDemo
//
//  Created by Dove Zachary on 2024/10/27.
//

import SwiftUI

public struct BentoOverlayAccessoryProxy {
    public var frame: CGRect
    public var itemsBounds: [UUID : CGRect]
}

public struct VBento<Item: BentoItem, ItemContent: View, OverlayAccessoryView: View>: View {
    var bentoModel: BentoModel<Item>
    var content: (Item) -> ItemContent
    var overlayAccessoryView: (BentoOverlayAccessoryProxy) -> OverlayAccessoryView
    
    public init(
        model: BentoModel<Item>,
        @ViewBuilder content: @escaping (Item) -> ItemContent,
        @ViewBuilder overlayAccessoryView: @escaping (BentoOverlayAccessoryProxy) -> OverlayAccessoryView = { _ in EmptyView() }
    ) {
        self.bentoModel = model
        self.content = content
        self.overlayAccessoryView = overlayAccessoryView
    }
    
    var pagePadding: CGFloat { bentoModel.pagePadding }

    @State private var accessoryViewProxy: BentoOverlayAccessoryProxy?
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.clear)
            
//            BentoPlaceholderView<Item>()
            
            ZStack(alignment: .topLeading) {
                // anchor top
                Color.clear.frame(width: 10, height: 10)
                BentoItemsView(content: content)
                
                if let accessoryViewProxy {
                    overlayAccessoryView(accessoryViewProxy)
                }
            }
            .frame(
                maxWidth: max(0, bentoModel.bentoBaseSize * CGFloat(bentoModel.columnsCount) + bentoModel.bentoGap * CGFloat(bentoModel.columnsCount - 1)),
                alignment: .topLeading
            )
            .overlayPreferenceValue(BentoItemAnchorKey.self) { val in
                GeometryReader { geomertry in
                    Color.clear
                        .onChange(of: val) {
                            accessoryViewProxy = BentoOverlayAccessoryProxy(
                                frame: geomertry.frame(in: .global),
                                itemsBounds: val.map { [$0.key : geomertry[$0.value]] }.merged()
                            )
                        }
                }
            }
//            // Overlay Accessory View
//            self.overlayAccessoryView()
//            
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
        .onChange(of: bentoModel.items.count) {
            bentoModel.flushState()
        }
    }
}

#Preview {
    BentoExampleView()
}
