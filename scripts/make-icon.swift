#!/usr/bin/env swift
// アプリアイコン（Packaging/AppIcon.icns、および実行時表示用のPNG）を生成するスクリプト。
// デザインを変更する場合はこのファイルを編集し、以下を再実行する:
//   swift scripts/make-icon.swift
import AppKit

let iconsetDir = URL(fileURLWithPath: "Packaging/AppIcon.iconset")
let icnsPath = "Packaging/AppIcon.icns"
// swift run（.appバンドル化されない開発時実行）でも Dock/Cmd+Tab/強制終了ダイアログ等に
// 独自アイコンを出すため、SwiftPMリソースとしてもPNGを1枚置く（AppDelegateが読み込む）。
let runtimeIconPath = URL(fileURLWithPath: "Sources/Yubisaki/Resources/Icons/AppIcon.png")

try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

func drawIcon(pixelSize: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    image.lockFocus()

    // macOSの標準アプリアイコンはキャンバス全体を塗らず、周囲に約10%の余白を残す
    // （Big Sur以降のアイコンテンプレート準拠）。これが無いと他アプリと並べた時に一回り大きく見える。
    let margin = pixelSize * 0.10
    let iconSize = pixelSize - margin * 2
    let rect = NSRect(x: margin, y: margin, width: iconSize, height: iconSize)
    // 角丸は余白を除いた実サイズ基準で約21%
    let cornerRadius = iconSize * 0.2109
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.30, green: 0.50, blue: 0.98, alpha: 1.0),
        NSColor(calibratedRed: 0.52, green: 0.30, blue: 0.90, alpha: 1.0),
    ])
    gradient?.draw(in: path, angle: -60)

    // メニューバーアイコン（scripts/make-gesture-icons.swift の menuBarIcon）と同じ
    // 2本指シルエット。デザインを変える場合は両方に反映すること。
    NSColor.white.setFill()
    let f1 = NSRect(x: rect.minX + iconSize * 0.30, y: rect.minY + iconSize * 0.30,
                     width: iconSize * 0.16, height: iconSize * 0.38)
    let f2 = NSRect(x: rect.minX + iconSize * 0.54, y: rect.minY + iconSize * 0.16,
                     width: iconSize * 0.16, height: iconSize * 0.60)
    NSBezierPath(roundedRect: f1, xRadius: iconSize * 0.08, yRadius: iconSize * 0.08).fill()
    NSBezierPath(roundedRect: f2, xRadius: iconSize * 0.08, yRadius: iconSize * 0.08).fill()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "make-icon", code: 1)
    }
    try png.write(to: url)
}

let baseSizes = [16, 32, 128, 256, 512]
for base in baseSizes {
    for scale in [1, 2] {
        let pixel = CGFloat(base * scale)
        let suffix = scale == 2 ? "@2x" : ""
        let image = drawIcon(pixelSize: pixel)
        let filename = "icon_\(base)x\(base)\(suffix).png"
        try writePNG(image, to: iconsetDir.appendingPathComponent(filename))
    }
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath]
try process.run()
process.waitUntilExit()

try? FileManager.default.removeItem(at: iconsetDir)

try writePNG(drawIcon(pixelSize: 512), to: runtimeIconPath)

print(process.terminationStatus == 0 ? "Wrote \(icnsPath) and \(runtimeIconPath.path)" : "iconutil failed")
