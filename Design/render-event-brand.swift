import AppKit
import ImageIO
import UniformTypeIdentifiers
let root = CommandLine.arguments[1]
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed:r,green:g,blue:b,alpha:a) }
let purple = color(0.43,0.24,0.79), pink = color(1,0.39,0.69), navy = color(0.045,0.035,0.11)
func png(_ name: String, _ width: Int, _ height: Int, _ scale: Int, opaque: Bool = false, drawing: (CGContext)->Void) throws {
    let cg = CGContext(data:nil,width:width*scale,height:height*scale,bitsPerComponent:8,bytesPerRow:width*scale*4,
        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(cgContext:cg,flipped:false)
    cg.scaleBy(x:CGFloat(scale),y:CGFloat(scale)); drawing(cg)
    NSGraphicsContext.restoreGraphicsState()
    let dest=CGImageDestinationCreateWithURL(URL(fileURLWithPath:root+"/"+name) as CFURL,UTType.png.identifier as CFString,1,nil)!
    CGImageDestinationAddImage(dest,cg.makeImage()!,nil)
    precondition(CGImageDestinationFinalize(dest))
}
func folder(_ name: String) throws { try FileManager.default.createDirectory(atPath:root+"/"+name,withIntermediateDirectories:true) }
func icon(_ cg: CGContext, size: CGFloat, rounded: Bool) {
    cg.saveGState();cg.scaleBy(x:size/100,y:size/100)
    let shape=NSBezierPath(roundedRect:NSRect(x:0,y:0,width:100,height:100),xRadius:rounded ? 23 : 0,yRadius:rounded ? 23 : 0)
    shape.addClip()
    NSGradient(starting:color(0.25,0.1,0.56),ending:color(0.8,0.2,0.59))!.draw(in:NSRect(x:0,y:0,width:100,height:100),angle:45)
    color(1,1,1,0.10).setStroke()
    for i in 0..<3 {
        let ring=NSBezierPath(ovalIn:NSRect(x:CGFloat(12-i*12),y:CGFloat(12-i*12),width:CGFloat(76+i*24),height:CGFloat(76+i*24)))
        ring.lineWidth=0.8;ring.stroke()
    }
    let heart=NSBezierPath()
    heart.move(to:NSPoint(x:50,y:20))
    heart.curve(to:NSPoint(x:18,y:59),controlPoint1:NSPoint(x:40,y:31),controlPoint2:NSPoint(x:18,y:43))
    heart.curve(to:NSPoint(x:50,y:73),controlPoint1:NSPoint(x:18,y:83),controlPoint2:NSPoint(x:40,y:85))
    heart.curve(to:NSPoint(x:82,y:59),controlPoint1:NSPoint(x:60,y:85),controlPoint2:NSPoint(x:82,y:83))
    heart.curve(to:NSPoint(x:50,y:20),controlPoint1:NSPoint(x:82,y:43),controlPoint2:NSPoint(x:60,y:31))
    NSColor.white.setFill();heart.fill()
    purple.setFill()
    for (i,h) in [12.0,25.0,35.0,21.0,12.0].enumerated() {
        NSBezierPath(roundedRect:NSRect(x:32+Double(i)*7,y:52-h/2,width:4.5,height:h),xRadius:2.2,yRadius:2.2).fill()
    }
    cg.restoreGState()
}
try folder("EventLaunchLogo.imageset")
try folder("EventLaunchRing.imageset")
try folder("EventLaunchOrbit.imageset")
try folder("EventLaunchBackdrop.imageset")
for scale in 1...3 {
    try png("EventLaunchLogo.imageset/logo-\(scale)x.png",112,112,scale) { icon($0,size:112,rounded:true) }
    for badge in [false,true] {
        let path=(badge ? "EventLaunchOrbit" : "EventLaunchRing")+".imageset/ring-\(scale)x.png"
        try png(path,268,268,scale) { cg in
            color(0.67,0.55,1,0.08).setFill(); NSBezierPath(ovalIn:NSRect(x:44,y:44,width:180,height:180)).fill()
            color(0.67,0.55,1,0.3).setStroke()
            let ring=NSBezierPath(ovalIn:NSRect(x:24,y:24,width:220,height:220));ring.lineWidth=1.5;ring.stroke()
            if badge { purple.setFill();NSBezierPath(ovalIn:NSRect(x:110,y:220,width:48,height:48)).fill() }
        }
    }
    try png("EventLaunchBackdrop.imageset/backdrop-\(scale)x.png",430,932,scale) { cg in
        NSGradient(starting:navy,ending:color(0.13,0.075,0.25))!.draw(in:NSRect(x:0,y:0,width:430,height:932),angle:70)
        // Decorative street-like lines; not a map of actual streets.
        let roads:[[NSPoint]] = [
            [.init(x:-20,y:120),.init(x:80,y:120),.init(x:80,y:310),.init(x:215,y:466)],
            [.init(x:200,y:-10),.init(x:200,y:230),.init(x:300,y:320),.init(x:215,y:466)],
            [.init(x:450,y:160),.init(x:350,y:160),.init(x:350,y:330),.init(x:215,y:466)],
            [.init(x:450,y:800),.init(x:340,y:800),.init(x:340,y:600),.init(x:215,y:466)],
            [.init(x:-20,y:820),.init(x:85,y:820),.init(x:85,y:620),.init(x:215,y:466)],
            [.init(x:190,y:950),.init(x:190,y:740),.init(x:215,y:466)]]
        for (i,points) in roads.enumerated() {
            (i.isMultiple(of:2) ? color(0.67,0.55,1,0.12) : color(1,0.39,0.69,0.10)).setStroke()
            let line=NSBezierPath();line.move(to:points[0]);points.dropFirst().forEach{line.line(to:$0)}
            line.lineWidth=3;line.lineJoinStyle = .round;line.stroke()
        }
        for (x,y) in [(80,120),(350,160),(340,800),(85,620)] {
            color(0.67,0.55,1,0.22).setFill();NSBezierPath(ovalIn:NSRect(x:x-4,y:y-4,width:8,height:8)).fill()
        }
    }
}
try png("AppIcon.appiconset/EurovisionIcon.png",1024,1024,1,opaque:true) { icon($0,size:1024,rounded:false) }
