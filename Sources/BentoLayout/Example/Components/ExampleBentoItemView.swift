//
//  ExampleBentoItemView.swift
//  BentoLayout
//
//  Created by Dove Zachary on 2024/11/1.
//

import SwiftUI

struct ExampleBentoItemView: View {
    @Environment(BentoModel<ExampleBentoItem>.self) var bentoModel
    var item: ExampleBentoItem
    
    var body: some View {
        RoundedRectangle(cornerRadius: item.borderRadius)
            .fill(item.fill)
            .shadow(radius: 2)
            .overlay {
                VStack {
                    Text("(\(Int(item.x)), \(Int(item.y)), \(Int(item.width)), \(Int(item.height)))")
                    if !item.restrictions.isEmpty {
                        ForEach(item.restrictions, id: \.self) { restriction in
                            Text(String(describing: restriction))
                        }
                    }
                }
            }
            .transition(.scale.animation(.bouncy(duration: 0.3, extraBounce: 0.2)))
            .onTapGesture {
                print("OnTap - \(item.id)")
            }
            .contextMenu {
                Button(role: .destructive) {
                    bentoModel.removeBentoItem(item)
                } label: {
                    Label("Remove", systemSymbol: .trash)
                }
            }
    }
}

#Preview {
    BentoExampleView()
}
