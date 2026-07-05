#!/usr/bin/env swift
// ジェスチャーアイコン6種 + メニューバーアイコンを生成し、
// Sources/Yubisaki/Resources/Icons/ に書き出す。
// デザインを変更する場合はこのファイルを編集し、以下を再実行する:
//   swift scripts/make-gesture-icons.swift
import AppKit

let outDir = URL(fileURLWithPath: "Sources/Yubisaki/Resources/Icons")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func save(_ image: NSImage, name: String) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "make-gesture-icons", code: 1)
    }
    try png.write(to: outDir.appendingPathComponent("\(name).png"))
}

func drawIcon(size: CGFloat, _ body: (CGFloat) -> Void) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSColor.black.setFill()
    NSColor.black.setStroke()
    body(size)
    image.unlockFocus()
    return image
}

func dot(at p: NSPoint, radius: CGFloat) {
    NSBezierPath(ovalIn: NSRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)).fill()
}

/// 放射ストローク（タップの弾け）。円弧の上半分を中心に扇状に配置する。
func burst(at p: NSPoint, innerRadius: CGFloat, length: CGFloat, strokeWidth: CGFloat, alpha: CGFloat,
           count: Int, totalSpan: CGFloat) {
    NSColor.black.withAlphaComponent(alpha).setStroke()
    let path = NSBezierPath()
    let start = 90 - totalSpan / 2
    let step = totalSpan / CGFloat(count - 1)
    for i in 0..<count {
        let rad = (start + step * CGFloat(i)) * .pi / 180
        path.move(to: NSPoint(x: p.x + innerRadius * cos(rad), y: p.y + innerRadius * sin(rad)))
        path.line(to: NSPoint(x: p.x + (innerRadius + length) * cos(rad), y: p.y + (innerRadius + length) * sin(rad)))
    }
    path.lineWidth = strokeWidth
    path.lineCapStyle = .round
    path.stroke()
    NSColor.black.setStroke()
}

/// タップ表現: ドット + 放射ストローク。
/// - span: 160° で単指、100° で多指（上半分に狭めて隣との干渉を避ける）
/// - strokes: 単指は5本、多指は3本
/// 実際のUIでは24〜28px程度で表示されるため、線幅・ドットは大きめに（256px原寸換算で）確保する。
func tap(at p: NSPoint, s: CGFloat, scale: CGFloat, span: CGFloat, strokes: Int) {
    let dotR = s * 0.065 * scale
    dot(at: p, radius: dotR)
    burst(at: p, innerRadius: dotR * 1.7, length: dotR * 1.3,
          strokeWidth: s * 0.042 * scale, alpha: 0.65, count: strokes, totalSpan: span)
}

/// 丸キャップの線矢印（ピンチの移動方向）
func lineArrow(from: NSPoint, to: NSPoint, headLength: CGFloat, strokeWidth: CGFloat) {
    let shaft = NSBezierPath()
    shaft.move(to: from)
    shaft.line(to: to)
    shaft.lineWidth = strokeWidth
    shaft.lineCapStyle = .round
    shaft.stroke()
    let angle = atan2(to.y - from.y, to.x - from.x)
    let head = NSBezierPath()
    for da: CGFloat in [.pi * 0.78, -.pi * 0.78] {
        head.move(to: to)
        head.line(to: NSPoint(x: to.x + headLength * cos(angle + da),
                              y: to.y + headLength * sin(angle + da)))
    }
    head.lineWidth = strokeWidth
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()
}

let S: CGFloat = 256

// MARK: - pinchIn（2点が内側へ寄る）
try save(drawIcon(size: S) { s in
    let p1 = NSPoint(x: s * 0.26, y: s * 0.66)
    let p2 = NSPoint(x: s * 0.74, y: s * 0.34)
    dot(at: p1, radius: s * 0.07)
    dot(at: p2, radius: s * 0.07)
    lineArrow(from: NSPoint(x: s * 0.345, y: s * 0.605),
              to: NSPoint(x: s * 0.445, y: s * 0.537),
              headLength: s * 0.06, strokeWidth: s * 0.045)
    lineArrow(from: NSPoint(x: s * 0.655, y: s * 0.395),
              to: NSPoint(x: s * 0.555, y: s * 0.463),
              headLength: s * 0.06, strokeWidth: s * 0.045)
}, name: "pinchIn")

// MARK: - pinchOut（2点が外側へ離れる）
try save(drawIcon(size: S) { s in
    let p1 = NSPoint(x: s * 0.40, y: s * 0.565)
    let p2 = NSPoint(x: s * 0.60, y: s * 0.435)
    dot(at: p1, radius: s * 0.07)
    dot(at: p2, radius: s * 0.07)
    lineArrow(from: NSPoint(x: s * 0.325, y: s * 0.615),
              to: NSPoint(x: s * 0.225, y: s * 0.682),
              headLength: s * 0.06, strokeWidth: s * 0.045)
    lineArrow(from: NSPoint(x: s * 0.675, y: s * 0.385),
              to: NSPoint(x: s * 0.775, y: s * 0.318),
              headLength: s * 0.06, strokeWidth: s * 0.045)
}, name: "pinchOut")

// MARK: - twoTipTapLeft（置き指=右、タップ=左・160°・5本）
try save(drawIcon(size: S) { s in
    dot(at: NSPoint(x: s * 0.64, y: s * 0.48), radius: s * 0.095)
    tap(at: NSPoint(x: s * 0.36, y: s * 0.48), s: s, scale: 1.15, span: 160, strokes: 5)
}, name: "twoTipTapLeft")

// MARK: - twoTipTapRight（置き指=左、タップ=右・160°・5本）
try save(drawIcon(size: S) { s in
    dot(at: NSPoint(x: s * 0.36, y: s * 0.48), radius: s * 0.095)
    tap(at: NSPoint(x: s * 0.64, y: s * 0.48), s: s, scale: 1.15, span: 160, strokes: 5)
}, name: "twoTipTapRight")

// MARK: - threeTap（3点・扇100°・3本）
try save(drawIcon(size: S) { s in
    for x: CGFloat in [0.24, 0.50, 0.76] {
        tap(at: NSPoint(x: s * x, y: s * 0.48), s: s, scale: 0.95, span: 100, strokes: 3)
    }
}, name: "threeTap")

// MARK: - fourTap（4点・扇100°・3本）
try save(drawIcon(size: S) { s in
    for x: CGFloat in [0.155, 0.385, 0.615, 0.845] {
        tap(at: NSPoint(x: s * x, y: s * 0.48), s: s, scale: 0.80, span: 100, strokes: 3)
    }
}, name: "fourTap")

// MARK: - メニューバーアイコン（2本指シルエット。高低差を大きく取り、実寸18pxでも
// 一時停止ボタンに見えないようにしている。テンプレート画像として使用）
try save(drawIcon(size: S) { s in
    let f1 = NSRect(x: s * 0.30, y: s * 0.30, width: s * 0.16, height: s * 0.38)
    let f2 = NSRect(x: s * 0.54, y: s * 0.16, width: s * 0.16, height: s * 0.60)
    NSBezierPath(roundedRect: f1, xRadius: s * 0.08, yRadius: s * 0.08).fill()
    NSBezierPath(roundedRect: f2, xRadius: s * 0.08, yRadius: s * 0.08).fill()
}, name: "menuBarIcon")

print("Wrote icons to \(outDir.path)")
