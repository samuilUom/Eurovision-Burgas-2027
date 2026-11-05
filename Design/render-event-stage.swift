import AppKit
import ImageIO
import UniformTypeIdentifiers

// Offline, original stage artwork shared by launch and event home.
let root = CommandLine.arguments[1]
func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r,g,b,a])!
}
func image(_ path: String, width: Int, height: Int, scale: Int, draw: (CGContext) -> Void) throws {
    let context = CGContext(data: nil, width: width * scale, height: height * scale, bitsPerComponent: 8,
        bytesPerRow: width * scale * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    draw(context)
    let url = URL(fileURLWithPath: root + "/" + path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination))
}
let pink = rgba(1, 0.39, 0.69), violet = rgba(0.67, 0.55, 1)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
for scale in 1...3 {
    try image("EventLaunchBackdrop.imageset/backdrop-\(scale)x.png", width: 430, height: 932, scale: scale) { cg in
        let base = CGGradient(colorsSpace: space, colors: [rgba(0.035,0.025,0.085), rgba(0.12,0.055,0.24)] as CFArray, locations: [0,1])!
        cg.drawLinearGradient(base, start: .zero, end: CGPoint(x: 430,y: 932), options: [])
        for (center, radius, color) in [(CGPoint(x: -15,y: 650), CGFloat(420), rgba(0.48,0.19,0.90,0.37)),
                                        (CGPoint(x: 450,y: 310), CGFloat(360), rgba(1,0.22,0.61,0.22))] {
            let glow = CGGradient(colorsSpace: space, colors: [color, rgba(0.1,0.05,0.2,0)] as CFArray, locations: [0,1])!
            cg.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
        // Layered stage arches, with a quiet center so text and the heart stay readable.
        for index in 0..<7 {
            let offset = CGFloat(index) * 32
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -90 + offset * 0.3, y: -10))
            path.addCurve(to: CGPoint(x: 500, y: 850 - offset * 0.3), control1: CGPoint(x: -240 + offset, y: 530), control2: CGPoint(x: 290 + offset, y: 990))
            cg.addPath(path)
            cg.setStrokeColor(index.isMultiple(of: 2) ? rgba(0.75,0.51,1,0.14) : rgba(1,0.36,0.72,0.10))
            cg.setLineWidth(index == 3 ? 2 : 1); cg.strokePath()
        }
        // A slow visual wave, drawn once rather than rendered on every animation frame.
        for index in 0..<28 {
            let x = CGFloat(index) * 18 - 24
            let h = 22 + 58 * abs(sin(CGFloat(index) * 0.47))
            cg.setFillColor(rgba(0.76,0.57,1,0.055))
            cg.addPath(CGPath(roundedRect: CGRect(x: x,y: 176 - h / 2,width: 4,height: h), cornerWidth: 2,cornerHeight: 2,transform: nil))
            cg.fillPath()
        }
        for (x,y,size) in [(57.0,742.0,3.0),(344,800,2),(355,602,3),(73,340,2),(360,120,2),(165,856,2)] {
            cg.setFillColor(rgba(0.88,0.77,1,0.5)); cg.fillEllipse(in: CGRect(x:x,y:y,width:size,height:size))
        }
    }
    for badge in [false, true] {
        let name = badge ? "EventLaunchOrbit" : "EventLaunchRing"
        try image("\(name).imageset/ring-\(scale)x.png", width: 268, height: 268, scale: scale) { cg in
            let glow = CGGradient(colorsSpace: space, colors: [rgba(0.58,0.32,0.93,0.19), rgba(0.58,0.32,0.93,0)] as CFArray, locations: [0,1])!
            cg.drawRadialGradient(glow, startCenter: CGPoint(x:134,y:134), startRadius: 55,
                                  endCenter: CGPoint(x:134,y:134), endRadius: 130, options: [])
            cg.setLineWidth(1); cg.setStrokeColor(rgba(0.73,0.57,1,0.22)); cg.strokeEllipse(in:CGRect(x:24,y:24,width:220,height:220))
            cg.setLineWidth(3); cg.setLineCap(.round); cg.setStrokeColor(rgba(1,0.39,0.69,0.65))
            cg.addArc(center:CGPoint(x:134,y:134),radius:110,startAngle:0.15,endAngle:1.0,clockwise:false); cg.strokePath()
            if badge { cg.setFillColor(rgba(0.43,0.24,0.79)); cg.fillEllipse(in:CGRect(x:110,y:220,width:48,height:48)) }
        }
    }
    try image("EventLoadingBars.imageset/bars-\(scale)x.png", width: 70, height: 28, scale: scale) { cg in
        for (index,h) in [10.0,18,26,18,10].enumerated() {
            cg.setFillColor(index.isMultiple(of:2) ? pink : violet)
            cg.addPath(CGPath(roundedRect:CGRect(x:Double(index)*14+3,y:(28-h)/2,width:6,height:h),cornerWidth:3,cornerHeight:3,transform:nil)); cg.fillPath()
        }
    }
}
let entries: [[String:String]] = (1...3).map { ["idiom":"universal","filename":"bars-\($0)x.png","scale":"\($0)x"] }
let data = try JSONSerialization.data(withJSONObject: ["images":entries,"info":["author":"xcode","version":1]], options:[.prettyPrinted,.sortedKeys])
try data.write(to: URL(fileURLWithPath: root + "/EventLoadingBars.imageset/Contents.json"))
