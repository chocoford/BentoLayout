//
//  BentoItemsView.swift
//  BentoDemo
//
//  Created by Dove Zachary on 2024/10/27.
//

import SwiftUI
import Combine


struct BentoItemAnchorKey: PreferenceKey {
    static let defaultValue: [UUID : Anchor<CGRect>] = [:]
    
    static func reduce(value: inout [UUID : Anchor<CGRect>], nextValue: () -> [UUID : Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

struct BentoItemsView<Item: BentoItem, ItemContent: View>: View {
    @Environment(BentoModel<Item>.self) var bentoModel
    
    var itemContent: (Item) -> ItemContent

    public init(
        @ViewBuilder content: @escaping (Item) -> ItemContent
    ) {
        self.itemContent = content
    }
    var body: some View {
        ForEach(Array(bentoModel.items.enumerated()), id: \.element.id) { i, item in
            BentoItemView(
                item: Binding(get: {
                    item
                }, set: {
                    bentoModel.items[i] = $0
                }),
                content: itemContent
            )
            .background {
                Color.clear
                    .anchorPreference(key: BentoItemAnchorKey.self, value: .bounds) {
                        [item.itemID : $0]
                    }
            }
        }
    }
}

#Preview {
    BentoExampleView()
}
