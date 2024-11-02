//
//  AuxiliaryLineView.swift
//  BentoLayout
//
//  Created by Dove Zachary on 2024/11/2.
//

import SwiftUI

struct AuxiliaryLineView<Item: BentoItem>: View {
    @Environment(BentoModel<Item>.self) var bentoModel
    
    var containerSize: CGSize { bentoModel.containerSize }
    
    var body: some View {
        if bentoModel.isDragging || bentoModel.isResizing {
            ForEach(bentoModel.activeAlignments, id: \.self) { alignment in
                if case .vertical(let info) = alignment {
                    Rectangle()
                        .fill(.green)
                        .frame(height: 1)
                        .alignmentGuide(.top) { d in
                            d[.top] - info.value
                        }
                } else if case .horizontal(let info) = alignment {
                    Rectangle()
                        .fill(.green)
                        .frame(width: 1)
                        .alignmentGuide(.leading) { d in
                            d[.leading] - info.value
                        }
                }
            }
            .transition(.opacity.animation(.default))
        }
    }
}

#Preview {
    BentoExampleView()
}
