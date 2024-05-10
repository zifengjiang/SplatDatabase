//
//  File.swift
//  
//
//  Created by 姜锋 on 5/10/24.
//

import Foundation

func rgbaToUInt(r: Double, g: Double, b: Double, a: Double) -> UInt32 {
    let red = UInt32(r * 255.0) & 0xFF
    let green = UInt32(g * 255.0) & 0xFF
    let blue = UInt32(b * 255.0) & 0xFF
    let alpha = UInt32(a * 255.0) & 0xFF

    let colorInt = (alpha << 24) | (red << 16) | (green << 8) | blue
    return colorInt
}

func uintToRGBA(colorInt: UInt32) -> (r: Double, g: Double, b: Double, a: Double) {
    let alpha = Double((colorInt >> 24) & 0xFF) / 255.0
    let red = Double((colorInt >> 16) & 0xFF) / 255.0
    let green = Double((colorInt >> 8) & 0xFF) / 255.0
    let blue = Double(colorInt & 0xFF) / 255.0
    return (r: red, g: green, b: blue, a: alpha)
}
