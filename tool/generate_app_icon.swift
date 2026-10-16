import AppKit
import Foundation

let side = 1024
let output = CommandLine.arguments.dropFirst().first ?? "assets/omnireader_app_icon.png"

func path(_ points: [(CGFloat, CGFloat)], closed: Bool = true) -> NSBezierPath {
    let shape = NSBezierPath()
    guard let first = points.first else { return shape }
    shape.move(to: NSPoint(x: first.0, y: first.1))
    for point in points.dropFirst() {
        shape.line(to: NSPoint(x: point.0, y: point.1))
    }
    if closed { shape.close() }
    return shape
}

func oval(_ rect: CGRect, _ color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

func fill(_ shape: NSBezierPath, _ color: NSColor) {
    color.setFill()
    shape.fill()
}

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: side,
    pixelsHigh: side,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

let bounds = CGRect(x: 0, y: 0, width: side, height: side)
let canvas = NSBezierPath(roundedRect: bounds.insetBy(dx: 12, dy: 12), xRadius: 220, yRadius: 220)
canvas.addClip()
let cg = context.cgContext
let colors = [
    NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.28, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.28, green: 0.13, blue: 0.55, alpha: 1).cgColor,
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
cg.drawLinearGradient(gradient, start: CGPoint(x: 70, y: 950), end: CGPoint(x: 960, y: 40), options: [])

// Comic-book burst.
let burst = NSBezierPath()
let center = CGPoint(x: 512, y: 520)
for index in 0..<32 {
    let angle = CGFloat(index) * .pi / 16 - .pi / 2
    let radius: CGFloat = index.isMultiple(of: 2) ? 530 : 380
    let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    if index == 0 { burst.move(to: point) } else { burst.line(to: point) }
}
burst.close()
fill(burst, NSColor(calibratedRed: 1, green: 0.72, blue: 0.17, alpha: 1))

// Halftone dots in the upper corners.
for row in 0..<7 {
    for column in 0..<7 {
        let x = CGFloat(94 + column * 26)
        let y = CGFloat(850 - row * 26)
        oval(CGRect(x: x, y: y, width: 9, height: 9), NSColor(calibratedWhite: 1, alpha: 0.48))
    }
}

// Cape and shoulder silhouette.
fill(path([(328, 650), (198, 326), (470, 442), (554, 442), (826, 326), (696, 650)]),
     NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.39, alpha: 1))
fill(path([(390, 518), (420, 405), (512, 370), (604, 405), (634, 518), (570, 580), (454, 580)]),
     NSColor(calibratedRed: 0.9, green: 0.16, blue: 0.2, alpha: 1))

// Generic masked hero: original silhouette with no franchise marks or symbols.
oval(CGRect(x: 402, y: 552, width: 220, height: 236), NSColor(calibratedRed: 0.96, green: 0.66, blue: 0.46, alpha: 1))
fill(path([(400, 684), (417, 778), (475, 824), (546, 824), (612, 774), (628, 684), (576, 724), (512, 700), (450, 724)]),
     NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.17, alpha: 1))
fill(path([(405, 672), (438, 710), (485, 698), (512, 718), (539, 698), (586, 710), (619, 672), (605, 634), (548, 646), (512, 637), (476, 646), (419, 634)]),
     NSColor(calibratedRed: 0.1, green: 0.64, blue: 0.91, alpha: 1))
fill(path([(446, 666), (483, 659), (496, 674), (476, 681)]), NSColor.white)
fill(path([(528, 674), (541, 659), (578, 666), (548, 681)]), NSColor.white)

// Open comic book foreground.
let leftPage = NSBezierPath()
leftPage.move(to: NSPoint(x: 142, y: 294))
leftPage.curve(to: NSPoint(x: 501, y: 326), controlPoint1: NSPoint(x: 257, y: 384), controlPoint2: NSPoint(x: 411, y: 370))
leftPage.line(to: NSPoint(x: 501, y: 180))
leftPage.curve(to: NSPoint(x: 142, y: 210), controlPoint1: NSPoint(x: 382, y: 248), controlPoint2: NSPoint(x: 264, y: 196))
leftPage.close()
leftPage.lineWidth = 13
fill(leftPage, NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.88, alpha: 1))
NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.17, alpha: 1).setStroke()
leftPage.stroke()

let rightPage = NSBezierPath()
rightPage.move(to: NSPoint(x: 523, y: 326))
rightPage.curve(to: NSPoint(x: 882, y: 294), controlPoint1: NSPoint(x: 613, y: 370), controlPoint2: NSPoint(x: 767, y: 384))
rightPage.line(to: NSPoint(x: 882, y: 210))
rightPage.curve(to: NSPoint(x: 523, y: 180), controlPoint1: NSPoint(x: 760, y: 196), controlPoint2: NSPoint(x: 642, y: 248))
rightPage.close()
rightPage.lineWidth = 13
fill(rightPage, NSColor(calibratedRed: 1, green: 0.99, blue: 0.93, alpha: 1))
NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.17, alpha: 1).setStroke()
rightPage.stroke()

// Page details and center fold.
for y in stride(from: CGFloat(236), through: CGFloat(292), by: 18) {
    let leftLine = NSBezierPath()
    leftLine.move(to: NSPoint(x: 220, y: y))
    leftLine.line(to: NSPoint(x: 430, y: y + 18))
    leftLine.lineWidth = 5
    NSColor(calibratedRed: 0.36, green: 0.38, blue: 0.52, alpha: 0.52).setStroke()
    leftLine.stroke()

    let rightLine = NSBezierPath()
    rightLine.move(to: NSPoint(x: 594, y: y + 18))
    rightLine.line(to: NSPoint(x: 804, y: y))
    rightLine.lineWidth = 5
    NSColor(calibratedRed: 0.36, green: 0.38, blue: 0.52, alpha: 0.52).setStroke()
    rightLine.stroke()
}
let fold = NSBezierPath()
fold.move(to: NSPoint(x: 512, y: 180))
fold.line(to: NSPoint(x: 512, y: 326))
fold.lineWidth = 10
NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.17, alpha: 1).setStroke()
fold.stroke()

// Small four-point action star.
fill(path([(796, 730), (822, 786), (878, 812), (822, 838), (796, 894), (770, 838), (714, 812), (770, 786)]), NSColor.white)

NSGraphicsContext.restoreGraphicsState()
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode app icon PNG")
}
try FileManager.default.createDirectory(atPath: URL(fileURLWithPath: output).deletingLastPathComponent().path, withIntermediateDirectories: true)
try data.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
