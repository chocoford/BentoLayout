//
//  BentoItem.swift
//  BentoDemo
//
//  Created by Dove Zachary on 2024/10/27.
//

import SwiftUI
import UniformTypeIdentifiers

public struct BentoItemSize: Hashable, Codable, CustomStringConvertible {
//    var width: CGFloat
//    var height: CGFloat
    var width: Int
    var height: Int
    
    static var zero: BentoItemSize { BentoItemSize(width: 0, height: 0) }
    
    public var description: String {
        "BentoItemSize: (\(width), \(height))"
    }
}

public enum BentoItemRestriction: Codable, Hashable {
    case ratio(Set<BentoItemSize>)
    case minSize(BentoItemSize)
    case maxSize(BentoItemSize)
}

public protocol BentoItem: Identifiable, Hashable, Transferable {
    var itemID: UUID { get set }
//    var frame: CGRect { get set }
    var x: Int { get set }
    var y: Int { get set }
    var intermediateWidth: CGFloat { get set }
    var intermediateHeight: CGFloat { get set }
    
    var width: Int { get set }
    var height: Int { get set }
    
    var borderRadius: CGFloat { get }
    
    var restrictions: [BentoItemRestriction] { get set }
    
    var showResizeHandler: Bool { get }
    
    func duplicated(withSameID: Bool) -> Self
}

extension BentoItem {
    
//    public var x: CGFloat {
//        get { frame.origin.x }
//        set { frame.origin.x = newValue }
//    }
//    public var y: CGFloat {
//        get { frame.origin.y }
//        set { frame.origin.y = newValue }
//    }
//    public var width: CGFloat {
//        get { frame.size.width }
//        set { frame.size.width = newValue }
//    }
//    public var height: CGFloat {
//        get { frame.size.height }
//        set { frame.size.height = newValue }
//    }
    
    public static var transferRepresentation: ProxyRepresentation<Self, String>  {
        ProxyRepresentation(exporting: { item in
            item.itemID.uuidString
        })
    }
    
    public func checkIsOverlay<I: BentoItem>(with item: I) -> Bool {
        if self.x >= item.x + item.width {
            return false
        }
        if self.x + self.width <= item.x {
            return false
        }
        if self.y >= item.y + item.height {
            return false
        }
        if self.y + self.height <= item.y {
            return false
        }
        return true
    }
    
//    public func checkIsOverlay(position: CGPoint) -> Bool {
    public func checkIsOverlay(position: (x: Int, y: Int)) -> Bool {
        var item = self.duplicated(withSameID: false)
        item.x = position.x
        item.y = position.y
        return checkIsOverlay(with: item)
    }
    
//    @available(*, unavailable, message: "Not ready yet")
    public var maximumSize: BentoItemSize? {
        for restriction in self.restrictions {
            if case .maxSize(let maxSize) = restriction {
                return maxSize
            }
        }
        return nil
    }
    
//    @available(*, unavailable, message: "Not ready yet")
    public var minimumSize: BentoItemSize? {
        for restriction in self.restrictions {
            if case .minSize(let minSize) = restriction {
                return minSize
            }
        }

        for restriction in self.restrictions {
            if case .ratio(let ratios) = restriction {
                return ratios.reduce(.init(width: 100, height: 100)) {
                    
                    var minSize: BentoItemSize = $1
                    var minEdge = min(minSize.width, minSize.height)
                    if minEdge >= 2 {
                        for i in stride(from: minEdge, through: 2, by: -1) {
                            if i > minEdge { continue }
                            if minSize.width % i == 0, minSize.height % i == 0 {
                                minSize.width /= i
                                minSize.height /= i
                                minEdge = min(minSize.width, minSize.height)
                            }
                        }
                    }
                    
                    return .init(
                        width: min($0.width, minSize.width),
                        height: min($0.height, minSize.height)
                    )
                }
            }
        }
        
        return nil
    }
}

public struct DefaultBentoItem: BentoItem {
    
    public var id: UUID { itemID }
    public var itemID = UUID()
//    public var frame: CGRect
    public var x: Int
    public var y: Int
    
    public var intermediateWidth: CGFloat
    public var intermediateHeight: CGFloat
    
    public var width: Int
    public var height: Int
    public var borderRadius: CGFloat = 20
    
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
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        restrictions: [BentoItemRestriction] = []
    ) {
        self.itemID = id
//        self.frame = CGRect(x: x, y: y, width: width, height: height)
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.restrictions = restrictions
        self.intermediateWidth = CGFloat(width)
        self.intermediateHeight = CGFloat(height)
        self.color = .accentColor
        self.isGradient = true
    }
    
//    public init(x: Int, y: Int, width: Int, height: Int) {
//        self.init(id: UUID(), x: x, y: y, width: width, height: height)
//    }
    
    public func duplicated(withSameID: Bool = false) -> DefaultBentoItem {
        DefaultBentoItem(
            id: withSameID ? self.itemID : UUID(),
            x: self.x,
            y: self.y,
            width: self.width,
            height: self.height,
            restrictions: self.restrictions
        )
    }
}

#Preview {
    BentoExampleView()
}
