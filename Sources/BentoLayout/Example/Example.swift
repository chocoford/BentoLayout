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
    
    mutating public func applyChange(from item: ExampleBentoItem) {
        self.itemID = item.itemID
        self.frame = item.frame
        self.restrictions = item.restrictions
        self.borderRadius = item.borderRadius
        self.color = item.color
        self.isGradient = item.isGradient
    }
}

/// Example Bento View
internal struct BentoExampleView: View {
    @State private var bentoModel: BentoModel<ExampleBentoItem> = BentoModel(
        items:  []
    )
    
    @State private var inEdit = false
    @State private var inSwapMode = false
    @State private var swapItems: [ExampleBentoItem] = []
    
    var body: some View {
        ScrollView {
            VBento(model: bentoModel) { item in
                ExampleBentoItemView(item: item)
                    .gesture(
                        TapGesture().onEnded {
                            swapItems.append(item)
                            
                            if swapItems.count >= 2 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    inSwapMode = false
                                    withAnimation {
                                        bentoModel.swapItemFrame(
                                            aID: swapItems[0].itemID,
                                            bID: swapItems[1].itemID
                                        )
                                    }
                                    swapItems.removeAll()
                                }
                            }
                        },
                        including: inSwapMode ? .gesture : .subviews
                    )
            } overlayAccessoryView: { proxy in
                if inSwapMode {
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.7)
                            .overlay {
                                Text("Select two item to swap.")
                                    .font(.title)
                                    .foregroundStyle(.white)
                            }
                        
                        ForEach(swapItems) { item in
                            ZStack {
                                RoundedRectangle(cornerRadius: item.borderRadius)
                                    .fill(Color.accentColor.opacity(0.5))
                                RoundedRectangle(cornerRadius: item.borderRadius)
                                    .stroke(Color.accentColor, lineWidth: 4)
                            }
                            .frame(
                                width: proxy.itemsBounds[item.itemID]?.size.width,
                                height: proxy.itemsBounds[item.itemID]?.size.height
                            )
                            .offset(
                                x: proxy.itemsBounds[item.itemID]?.origin.x ?? .zero,
                                y: proxy.itemsBounds[item.itemID]?.origin.y ?? .zero
                            )
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .padding()
            .containerRelativeFrame(.horizontal)
            .animation(.default, value: inSwapMode)
        }
        .overlay(alignment: .bottom) {
            toolbar()
                .frame(height: 24)
                .padding()
                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20))
                .compositingGroup()
                .shadow(radius: 3, y: 2)
                .padding()
                .animation(.default, value: inSwapMode)
        }
    }
    
    @MainActor @ViewBuilder
    private func toolbar() -> some View {
        HStack(spacing: 4) {
            
            if !inSwapMode {
                
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
            }
            
            Button {
                inSwapMode.toggle()
            } label: {
                Label("Swap", systemImage: "rectangle.2.swap")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(inSwapMode ? Color.accentColor : .primary)
            }
            
            Divider()
            
            if !inSwapMode {
                
                Button {
                    bentoModel.addBentoItem(
                        ExampleBentoItem(
                            x: 0,
                            y: 0,
                            width: 120,
                            height: 120,
                            color: [Color.blue, .gray, .teal, .orange, .pink, .mint, .red, .indigo].randomElement()!
                        )
                    )
                } label: {
                    Image(systemName: "textformat")
                }
            } else {
                Text("Select two item to swap.")
                
                Button {
                    inSwapMode = false
                    swapItems.removeAll()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
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
    }
}

#Preview {
    BentoExampleView()
}
