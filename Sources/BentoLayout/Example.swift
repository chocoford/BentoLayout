//
//  SwiftUIView.swift
//  BentoLayout
//
//  Created by Dove Zachary on 2024/10/28.
//

import SwiftUI

/// Example Bento View
internal struct BentoExampleView: View {
    @State private var bentoModel: BentoModel<DefaultBentoItem> = BentoModel(
        items:  [
//            DefaultBentoItem(x: 0, y: 0, width: 100, height: 100),
//            DefaultBentoItem(x: 100, y: 0, width: 100, height: 100),
//            DefaultBentoItem(x: 200, y: 0, width: 200, height: 100),
//            DefaultBentoItem(x: 400, y: 0, width: 300, height: 100),
//            DefaultBentoItem(x: 0, y: 100, width: 100, height: 200),
//            DefaultBentoItem(
//                x: 100,
//                y: 100,
//                width: 200,
//                height: 200,
//                restrictions: [
//                    .minSize(BentoItemSize(width: 200, height: 200)),
//                    .maxSize(BentoItemSize(width: 400, height: 400)),
//                ]
//            ),
        ]
    )
    
    @State private var inEdit = false
    
    var body: some View {
        ScrollView {
            VBento(model: bentoModel) { item in
                RoundedRectangle(cornerRadius: 20)
                    .fill(item.fill)
                    .shadow(radius: 2)
                    .overlay {
                        VStack {
                            Text("(\(item.x), \(item.y), \(item.width), \(item.height))")
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
            }
            .padding()
            .containerRelativeFrame(.horizontal)
        }
        .overlay(alignment: .bottomTrailing) {
            HStack {
                Button {
                    bentoModel.rearrangeBentoItems()
                } label: {
                    Text("Rearrange")
                }
                
                Button {
                    inEdit.toggle()
                } label: {
                    Text(inEdit ? "Done" : "Edit")
                }
                
                if !inEdit {
                    Button {
                        let width = Int.random(in: 4...10)
                        let height = Int.random(in: 4...10)
                        let bentoItem = DefaultBentoItem(
                            x: max(0, Int.random(in: 0..<bentoModel.columnsCount) - width),
                            y: max(0, Int.random(in: 0..<bentoModel.columnsCount) - height),
                            width: width,
                            height: height
                        )
                        bentoModel.addBentoItem(bentoItem)
                    } label: {
                        Text("Add item")
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    BentoExampleView()
}
