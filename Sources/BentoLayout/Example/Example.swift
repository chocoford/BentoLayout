//
//  SwiftUIView.swift
//  BentoLayout
//
//  Created by Dove Zachary on 2024/10/28.
//

import SwiftUI
import ChocofordUI

internal struct ExampleBentoItem: BentoItem {
    public var id: UUID { itemID }
    public var itemID = UUID()
    public var frame: CGRect
    public var borderRadius: CGFloat = 4
    
    public var restrictions: [BentoItemRestriction] = []
    public var showResizeHandler: Bool { true }
    
    public var color: Color
    public var isGradient: Bool
    public var fill: some ShapeStyle {
        if isGradient {
            return AnyShapeStyle(color.gradient)
        } else {
            return AnyShapeStyle(color)
        }
    }
    
    public init() {
        self.init(x: 0, y: 0, width: 1, height: 1)
    }
    
    public init(
        id: UUID = UUID(),
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        restrictions: [BentoItemRestriction] = [],
        color: Color = .accentColor
    ) {
        self.itemID = id
        self.frame = CGRect(x: x, y: y, width: width, height: height)
        self.restrictions = restrictions
        self.color = color
        self.isGradient = true
    }
    
    public func duplicated(withSameID: Bool = false) -> ExampleBentoItem {
        ExampleBentoItem(
            id: withSameID ? self.itemID : UUID(),
            x: self.x,
            y: self.y,
            width: self.width,
            height: self.height,
            restrictions: self.restrictions
        )
    }
}

/// Example Bento View
internal struct BentoExampleView: View {
    @State private var bentoModel: BentoModel<ExampleBentoItem> = BentoModel(
        items:  []
    )
    
    @State private var inEdit = false
    
    var body: some View {
        ScrollView {
            VBento(model: bentoModel) { item in
                ExampleBentoItemView(item: item)
            }
            .padding()
            .containerRelativeFrame(.horizontal)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 4) {
                
                Button {
                    withAnimation {
                        bentoModel.undoManager.undo()
                    }
                } label: {
                    Image(systemSymbol: .arrowUturnBackward)
                }
                .foregroundStyle(bentoModel.undoManager.canUndo ? .primary : .secondary)
                .disabled(!bentoModel.undoManager.canUndo)
                
                Button {
                    withAnimation {
                        bentoModel.undoManager.redo()
                    }
                } label: {
                    Image(systemSymbol: .arrowUturnForward)
                }
                .foregroundStyle(bentoModel.undoManager.canRedo ? .primary : .secondary)
                .disabled(!bentoModel.undoManager.canRedo)
                
                Divider()

                Button {
                    bentoModel.rearrangeBentoItems(direction: .leading)
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: "rectangle.3.group")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 10)
                        Image(systemSymbol: .arrowLeft)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 6)
                    }
                }
                
                Button {
                    bentoModel.rearrangeBentoItems(direction: .top)
                } label: {
                    HStack(spacing: -2) {
                        Image(systemName: "arrow.up")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 6)
                        Image(systemName: "rectangle.3.group")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 18)
                            .rotationEffect(.degrees(-90))
                    }
                }
                
                Divider()
                
                Button {
                    bentoModel.addBentoItem(
                        ExampleBentoItem(
                            x: 0,
                            y: 0,
                            width: 120,
                            height: 120,
                            color: [Color.blue, .gray, .teal, .orange, .pink, .mint, .red, .indigo].randomElement()!
//                            content: .text(BentomanTextItem(content: ""))
                        )
                    )
                } label: {
                    Image(systemName: "textformat")
                }
                
//                FileImporterButton(types: [.image], allowMultiple: false) { urls in
//                    guard let url = urls.first else { return }
//                    if url.startAccessingSecurityScopedResource() {
//                        let imageData = try Data(contentsOf: url)
//                        let mediaID = UUID().uuidString
//                        let imageItem = BentomanImageItem(type: .image, dataKey: mediaID)
//                        bentoModel.addBentoItem(
//                            ExampleBentoItem(
//                                x: 0,
//                                y: 0,
//                                width: 2,
//                                height: 2,
//                                content: .image(imageItem),
//                                medias: [mediaID : imageData]
//                            )
//                        )
//                        
//                        url.stopAccessingSecurityScopedResource()
//                    } else {
//                        print("startAccessingSecurityScopedResource failed.")
//                    }
//                } label: {
//                    Image(systemName: "photo")
//                }
            }
            .buttonStyle(.text(square: true))
            .frame(height: 24)
            .padding()
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20))
            .compositingGroup()
            .shadow(radius: 3, y: 2)
            .padding()
//            HStack {
//                Button {
//                    bentoModel.rearrangeBentoItems()
//                } label: {
//                    Text("Rearrange")
//                }
//                
//                Button {
//                    inEdit.toggle()
//                } label: {
//                    Text(inEdit ? "Done" : "Edit")
//                }
//                
//                if !inEdit {
//                    Button {
//                        let width = Double(Int.random(in: 1...5) * 40)
//                        let height = Double(Int.random(in: 1...5) * 40)
//                        let bentoItem = ExampleBentoItem(
//                            x: 0,
//                            y: 0,
//                            width: width,
//                            height: height
//                        )
//                        bentoModel.addBentoItem(bentoItem)
//                    } label: {
//                        Text("Add item")
//                    }
//                }
//            }
//            .padding()
//            .background {
//                Capsule().fill(.regularMaterial)
//            }
//            .padding(.bottom)
        }
    }
}

#Preview {
    BentoExampleView()
}
