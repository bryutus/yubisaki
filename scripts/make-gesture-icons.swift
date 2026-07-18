#!/usr/bin/env swift
// ジェスチャーアイコン6種 + メニューバーアイコンを生成し、
// Sources/Yubisaki/Resources/Icons/ に書き出す。
// デザインを変更する場合はこのファイルを編集し、以下を再実行する:
//   swift scripts/make-gesture-icons.swift
//
// デザイン言語（weight 4 相当）:
//   - タップする指   … 二重丸（◎ 外周リング + 中の塗り丸）
//   - 触れている指   … 黒丸（● 塗り丸。ピンチの接触点 / holdtap の休指）
//   - ピンチの向き   … 丸キャップのシェブロン（<, >）
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

let S: CGFloat = 256

func drawIcon(_ body: () -> Void) -> NSImage {
    let image = NSImage(size: NSSize(width: S, height: S))
    image.lockFocus()
    NSColor.black.setFill()
    NSColor.black.setStroke()
    body()
    image.unlockFocus()
    return image
}

// アイコンは 256x256 の y-down（左上原点・SVG準拠）座標で定義し、
// AppKit の y-up 座標へ変換して描画する。
func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: S - y) }

func rotated(_ x: CGFloat, _ y: CGFloat, deg: CGFloat, cx: CGFloat = 128, cy: CGFloat = 128) -> (CGFloat, CGFloat) {
    let r = deg * .pi / 180
    let dx = x - cx, dy = y - cy
    return (cx + dx * cos(r) - dy * sin(r), cy + dx * sin(r) + dy * cos(r))
}

/// 黒丸（塗り）
func dot(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) {
    let c = P(x, y)
    NSBezierPath(ovalIn: NSRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)).fill()
}

/// 中空リング（線）
func ring(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, lineWidth: CGFloat) {
    let c = P(x, y)
    let path = NSBezierPath(ovalIn: NSRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
    path.lineWidth = lineWidth
    path.stroke()
}

/// 二重丸（◎）＝ 外周リング + 中の塗り丸
func doubleCircle(_ x: CGFloat, _ y: CGFloat, outer: CGFloat, inner: CGFloat, lineWidth: CGFloat) {
    ring(x, y, outer, lineWidth: lineWidth)
    dot(x, y, inner)
}

/// 丸キャップ・丸ジョインのシェブロン（3点の折れ線）
func chevron(_ pts: [(CGFloat, CGFloat)], lineWidth: CGFloat) {
    let path = NSBezierPath()
    path.move(to: P(pts[0].0, pts[0].1))
    for i in 1..<pts.count { path.line(to: P(pts[i].0, pts[i].1)) }
    path.lineWidth = lineWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

// MARK: - pinchIn（2点が内側へ寄る。-30°の対角軸上・接触点=黒丸・矢印=シェブロン）
try save(drawIcon {
    let a = rotated(58, 128, deg: -30), b = rotated(198, 128, deg: -30)
    dot(a.0, a.1, 18); dot(b.0, b.1, 18)
    let l = [(96.0, 108.0), (116.0, 128.0), (96.0, 148.0)].map { rotated($0.0, $0.1, deg: -30) }
    let r = [(160.0, 108.0), (140.0, 128.0), (160.0, 148.0)].map { rotated($0.0, $0.1, deg: -30) }
    chevron(l, lineWidth: 11); chevron(r, lineWidth: 11)
}, name: "pinchIn")

// MARK: - pinchOut（2点が外側へ離れる）
try save(drawIcon {
    let a = rotated(100, 128, deg: -30), b = rotated(156, 128, deg: -30)
    dot(a.0, a.1, 18); dot(b.0, b.1, 18)
    let l = [(72.0, 108.0), (52.0, 128.0), (72.0, 148.0)].map { rotated($0.0, $0.1, deg: -30) }
    let r = [(184.0, 108.0), (204.0, 128.0), (184.0, 148.0)].map { rotated($0.0, $0.1, deg: -30) }
    chevron(l, lineWidth: 11); chevron(r, lineWidth: 11)
}, name: "pinchOut")

// MARK: - twoHoldTapLeft（休指=右・黒丸、タップ=左・二重丸）
try save(drawIcon {
    dot(162, 128, 20)
    doubleCircle(90, 128, outer: 24, inner: 13, lineWidth: 10)
}, name: "twoHoldTapLeft")

// MARK: - twoHoldTapRight（休指=左・黒丸、タップ=右・二重丸）
try save(drawIcon {
    dot(94, 128, 20)
    doubleCircle(166, 128, outer: 24, inner: 13, lineWidth: 10)
}, name: "twoHoldTapRight")

// MARK: - threeTap（二重丸 ×3）
try save(drawIcon {
    for x: CGFloat in [62, 128, 194] {
        doubleCircle(x, 128, outer: 27, inner: 13, lineWidth: 10)
    }
}, name: "threeTap")

// MARK: - fourTap（二重丸 ×4）
try save(drawIcon {
    for x: CGFloat in [50, 102, 154, 206] {
        doubleCircle(x, 128, outer: 22, inner: 10, lineWidth: 9)
    }
}, name: "fourTap")

// MARK: - メニューバーアイコン（2本指シルエット。高低差を大きく取り、実寸18pxでも
// 一時停止ボタンに見えないようにしている。テンプレート画像として使用）
try save(drawIcon {
    let f1 = NSRect(x: S * 0.30, y: S * 0.30, width: S * 0.16, height: S * 0.38)
    let f2 = NSRect(x: S * 0.54, y: S * 0.16, width: S * 0.16, height: S * 0.60)
    NSBezierPath(roundedRect: f1, xRadius: S * 0.08, yRadius: S * 0.08).fill()
    NSBezierPath(roundedRect: f2, xRadius: S * 0.08, yRadius: S * 0.08).fill()
}, name: "menuBarIcon")

print("Wrote icons to \(outDir.path)")
