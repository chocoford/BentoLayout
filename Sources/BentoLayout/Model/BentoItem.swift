//
//  BentoItem.swift
//  BentoDemo
//
//  Created by Dove Zachary on 2024/10/27.
//

import SwiftUI
import UniformTypeIdentifiers

public struct BentoItemSize: Hashable, Codable, Sendable, CustomStringConvertible {
    var width: CGFloat
    var height: CGFloat
    
    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
//    var width: Int
//    var height: Int
    
    static var zero: BentoItemSize { BentoItemSize(width: 0, height: 0) }
    
    public var description: String {
        "BentoItemSize: (\(width), \(height))"
    }
}

public enum BentoItemRestriction: Codable, Hashable, Sendable {
    case ratio(Set<BentoItemSize>)
    case minSize(BentoItemSize)
    case maxSize(BentoItemSize)
}

public protocol BentoItem: Identifiable, Hashable, Transferable, Sendable {
    var itemID: UUID { get set }
//    var frame: CGRect { get set }
    
    var x: CGFloat { get set }
    var y: CGFloat { get set }
    var width: CGFloat { get set }
    var height: CGFloat { get set }
    
    var borderRadius: CGFloat { get }
    
    var restrictions: [BentoItemRestriction] { get set }
    
    var showResizeHandler: Bool { get }
    
    mutating func applyChange(from item: Self)
    func duplicated(withSameID: Bool) -> Self
}

extension BentoItem {
    public     var frame: CGRect {
        get {
            CGRect(x: x, y: y, width: width, height: height)
        }
        set {
            self.x = newValue.origin.x
            self.y = newValue.origin.y
            self.width = newValue.size.width
            self.height = newValue.size.height
        }
    }
    
    
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
    
    public func checkIsOverlay<I: BentoItem>(
        with item: I,
        safeAreaPadding: CGFloat = 0
    ) -> Bool {
        if self.x >= item.x + item.width + safeAreaPadding {
            return false
        }
        if self.x + self.width + safeAreaPadding <= item.x {
            return false
        }
        if self.y >= item.y + item.height + safeAreaPadding {
            return false
        }
        if self.y + self.height + safeAreaPadding <= item.y {
            return false
        }
        return true
    }
    
    public func checkIsOverlay(frame: CGRect) -> Bool {
        var item = self.duplicated(withSameID: false)
        item.frame = frame
        return checkIsOverlay(with: item)
    }
    
    public func checkIsOverlay(position: CGPoint) -> Bool {
//    public func checkIsOverlay(position: (x: Int, y: Int)) -> Bool {
        var item = self.duplicated(withSameID: false)
        item.x = position.x
        item.y = position.y
        return checkIsOverlay(with: item)
    }
    
    public var maximumSize: CGSize? {
        for restriction in self.restrictions {
            if case .maxSize(let maxSize) = restriction {
                return CGSize(width: maxSize.width, height: maxSize.height)
            }
        }
        return nil
    }
    
    public var minimumSize: CGSize {
        for restriction in self.restrictions {
            if case .minSize(let minSize) = restriction {
                return CGSize(width: minSize.width, height: minSize.height)
            }
        }

//        for restriction in self.restrictions {
//            if case .ratio(let ratios) = restriction {
//                return ratios.reduce(.init(width: 100, height: 100)) {
//                    
//                    var minSize: BentoItemSize = $1
//                    var minEdge = min(minSize.width, minSize.height)
//                    if minEdge >= 2 {
//                        for i in stride(from: minEdge, through: 2, by: -1) {
//                            if i > minEdge { continue }
//                            if minSize.width % i == 0, minSize.height % i == 0 {
//                                minSize.width /= i
//                                minSize.height /= i
//                                minEdge = min(minSize.width, minSize.height)
//                            }
//                        }
//                    }
//                    
//                    return .init(
//                        width: min($0.width, minSize.width),
//                        height: min($0.height, minSize.height)
//                    )
//                }
//            }
//        }
        
        return CGSize(width: 30, height: 30)
    }
}

public struct DefaultBentoItem: BentoItem {
    
    public var id: UUID { itemID }
    public var itemID = UUID()
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    
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
        self.init(x: 0, y: 0, width: 100, height: 100)
    }
    
    public init(
        id: UUID = UUID(),
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        restrictions: [BentoItemRestriction] = []
    ) {
        self.itemID = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.restrictions = restrictions
        self.color = .accentColor
        self.isGradient = true
    }
    
//    public init(x: Int, y: Int, width: Int, height: Int) {
//        self.init(id: UUID(), x: x, y: y, width: width, height: height)
//    }
    
    public func duplicated(withSameID: Bool = false) -> DefaultBentoItem {
        DefaultBentoItem(
            id: withSameID ? self.itemID : UUID(),
            x: x,
            y: y,
            width: width,
            height: height,
            restrictions: self.restrictions
        )
    }
    
    mutating public func applyChange(from item: DefaultBentoItem) {
        self.itemID = item.itemID
        self.frame = item.frame
        self.restrictions = item.restrictions
        self.borderRadius = item.borderRadius
        self.color = item.color
        self.isGradient = item.isGradient
    }
}

#Preview {
    BentoExampleView()
}
