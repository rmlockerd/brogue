//
//  GameScene.swift
//  SKTest
//
//  Created by Anthony DeSouza on 2017-04-11.
//  Copyright © 2017 Anthony DeSouza. All rights reserved.
//

import SpriteKit
import GameplayKit

// To see Swift classes from ObjC they MUST be prefaced with @objc and be public/open
@objc public class RogueScene: SKScene {
    fileprivate let rows: Int
    fileprivate let cols: Int
    
    fileprivate var cellWidth: CGFloat
    fileprivate var cellHeight: CGFloat
    fileprivate let initialSize: NSSize
    
    fileprivate var cells = [[Cell]]()
    fileprivate var textureMap: [String : SKTexture] = [:]
    var aEvent: NSEvent?

    // We don't want small letters scaled to huge proportions, so we only allow letters to stretch 
    // within a certain range (e.g. size of M +/- 20%)
    fileprivate lazy var maxScaleFactor: CGFloat = {
        let char: NSString = "M" // Good letter to do the base calculations from
        let calcBounds: CGRect = char.boundingRect(with: NSMakeSize(0, 0),
                                                   options: [.usesDeviceMetrics, .usesFontLeading],
                                                   attributes: [NSFontAttributeName: NSFont(name: "Arial Unicode MS", size: 120)!])
        return min(self.cellWidth / calcBounds.width, self.cellHeight / calcBounds.height)
    }()
    
    public init(size: CGSize, rows: Int, cols: Int) {
        initialSize = size
        self.rows = rows
        self.cols = cols
        cellWidth = CGFloat(size.width) / CGFloat(cols)
        cellHeight = CGFloat(size.height) / CGFloat(rows)
        super.init(size: size)
        anchorPoint = NSMakePoint(0, 0)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func keyDown(with event: NSEvent) {
        aEvent = event
    }
    
    public override func mouseDown(with event: NSEvent) {
        aEvent = event
    }
    
    public override func mouseUp(with event: NSEvent) {
        aEvent = event
    }
    
    public override func mouseMoved(with event: NSEvent) {
        aEvent = event
    }
}

extension RogueScene {
    public func setCell(x: Int, y: Int, code: UInt32, bgColor: CGColor, fgColor: CGColor) {
        cells[x][y].fgcolor = SKColor(cgColor: fgColor)!
        cells[x][y].bgcolor = SKColor(cgColor: bgColor)!
        
        if let glyph = UnicodeScalar(code) {
            cells[x][y].glyph = getTexture(glyph: String(glyph))
        }
    }
    
    override public func sceneDidLoad() {
        for x in 0...cols-1 {
            var row = [Cell]()
            for y in 0...rows-1 {
                let newCell = Cell(x: CGFloat(x) * cellWidth, y: CGFloat(rows - y - 1) * cellHeight, size: NSMakeSize(CGFloat(cellWidth), CGFloat(cellHeight)))
                row.append(newCell)
            }
            cells.append(row);
        }
    }
    
    override public func didMove(to view: SKView) {
        self.anchorPoint = NSMakePoint(0, 0)
        
        for x in 0...cols-1 {
            for y in 0...rows-1 {
                cells[x][y].background.anchorPoint = NSMakePoint(0, 0)
                addChild(cells[x][y].background)
                addChild(cells[x][y].foreground)
            }
        }
    }
}

fileprivate extension RogueScene {

    // Create/find glyph textures
    func getTexture(glyph: String) -> SKTexture {
        if let texture = textureMap[glyph] {
            return texture
        } else {
            addTexture(glyph: glyph)
            return getTexture(glyph: glyph)
        }
    }
    
    func createTextureFromGlyph(glyph: String, size: CGSize) -> SKTexture {
        // Apple Symbols provides U+26AA, for rings, which Arial does not.
        
        enum GlyphType {
            case letter
            case scroll
            case charm
            case ring
            case foliage
            case amulet
            case glyph
            
            var fontName: String {
                switch self {
                case .ring:
                    return "Apple Symbols"
                case .foliage:
                    return "Arial Unicode MS"
                default:
                    return "Monaco"
                }
            }
            
            var scaleFactor: CGFloat {
                switch self {
                case .letter, .foliage, .scroll:
                    return 1
                case .glyph, .ring:
                    return 0.8
                case .charm:
                    return 0.6
                case .amulet:
                    return 1.2
                }
            }
            
            var drawingOptions: NSStringDrawingOptions {
                switch self {
                case .letter:
                    return [.usesFontLeading]
                default:
                    return [.usesDeviceMetrics, .usesFontLeading]
                }
            }
            
            //func glyphType(glyph: String) -> GlyphType {
            init(glyph: String) {
                // We want to use pretty font/centering if we can, but
                // it makes tExT LOOk liKe THiS so we're defining characters
                // that will be rendered at the same lineheight
                // Note: Items "call"ed with non-standard characters aren't covered
                // If some characters become ugly, this list can be expanded
                switch (glyph) {
                    case "a"..."z",
                         "A"..."Z",
                         "0"..."9",
                         "!"..."?",
                         " ", "[", "/", "]", "^", "{", "|", "}", "~":
                    self = .letter
                case "\(UnicodeScalar(UInt32(FOLIAGE_CHAR))!)":
                    self = .foliage
                case "\(UnicodeScalar(UInt32(SCROLL_CHAR))!)":
                    self = .scroll
                case "\(UnicodeScalar(UInt32(CHARM_CHAR))!)":
                    self = .charm
                case "\(UnicodeScalar(UInt32(RING_CHAR))!)":
                    self = .ring
                case "\(UnicodeScalar(UInt32(AMULET_CHAR))!)":
                    self = .amulet
                default:
                    self = .glyph
                }
            }
        }
        
        let glyphType = GlyphType(glyph: glyph)
        // Find ideal size for text
        let text = glyph
        let fontSize: CGFloat = 130 // Base size, we'll calculate from here
        
        //TODO: Proper font checking/fallbacks, but this should rarely fail. At the very least message the user.
        let calcFont = NSFont(name: glyphType.fontName, size: fontSize)!
        
        var surface: NSImage {
            // Calculate font scale factor
            var scaleFactor: CGFloat {
                let calcAttributes = [NSFontAttributeName: calcFont]
                // If we calculate with the descender, the line height will be centered incorrectly for letters
                let calcOptions = glyphType.drawingOptions
                let calcBounds = text.boundingRect(with: NSMakeSize(0, 0), options: calcOptions, attributes: calcAttributes)
                let rawScaleFactor = min(size.width / calcBounds.width, size.height / calcBounds.height)
                let clampedScaleFactor = max(maxScaleFactor * 0.8, min(rawScaleFactor, maxScaleFactor * 1.2)) // Within 20% of original
                
                return clampedScaleFactor * (glyphType.scaleFactor) // Shrink certain non-letters
            }
            
            // Actual font that we're going to render
            let font = NSFont(name: glyphType.fontName, size: fontSize * scaleFactor)!
            let fontAttributes = [
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: SKColor.white // White so we can blend it
            ]
            
            let realBounds: CGRect = text.boundingRect(with: NSMakeSize(0, 0), options: glyphType.drawingOptions, attributes: fontAttributes)
            let stringOrigin = NSMakePoint((size.width - realBounds.width)/2 - realBounds.origin.x,
                                           font.descender - realBounds.origin.y + (size.height - realBounds.height)/2)
            let surface = NSImage(size: size)
            surface.lockFocus()
            text.draw(at: stringOrigin, withAttributes: fontAttributes)
            surface.unlockFocus()
            return surface
        }
    
        return SKTexture(image: surface)
    }
    
    func addTexture(glyph: String) {
        textureMap[glyph] = createTextureFromGlyph(glyph: glyph, size: CGSize(width: cellWidth, height: cellHeight))
    }
}
