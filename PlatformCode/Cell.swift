//
//  Cell.swift
//  Brogue
//
//  Created by Anthony DeSouza on 2017-04-22.
//
//

import SpriteKit

class Cell {
    let foreground: SKSpriteNode
    let background: SKSpriteNode
    
    var glyph: SKTexture? {
        set(newGlyph) {
            foreground.texture = newGlyph
        }
        get {
            return foreground.texture!
        }
    }
    
    var fgcolor: SKColor {
        set(newColor) {
            foreground.color = newColor
        }
        get {
            return foreground.color
        }
    }
    var bgcolor: SKColor {
        set(newColor) {
            background.color = newColor
        }
        get {
            return background.color
        }
    }
    
    init(x: CGFloat, y: CGFloat, size: CGSize) {
        foreground = SKSpriteNode(color: .clear, size: NSMakeSize(size.width, size.height))
        background = SKSpriteNode(color: .white, size: size)
        
        // Allow colours to be changed by blending their white components
        foreground.colorBlendFactor = 1
        background.colorBlendFactor = 1
        
        // The positions should be static
        let position = CGPoint(x: x, y: y)
        foreground.position = position
        background.position = position
        
        foreground.zPosition = 1 // Foreground
        
        background.anchorPoint = NSMakePoint(0, 0)
        foreground.anchorPoint = NSMakePoint(0, 0)
    }
}
