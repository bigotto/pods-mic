// Gera Resources/AppIcon.icns: microfone cortado (branco + vermelho) sobre fundo escuro.
// Uso: make icon
import AppKit

let size: CGFloat = 1024
let resources = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()

func renderIcon() -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Grade de ícones do macOS: placa de 824 pt centrada, cantos de ~185 pt.
    let plate = NSRect(x: 100, y: 100, width: 824, height: 824)
    let path = NSBezierPath(roundedRect: plate, xRadius: 185, yRadius: 185)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(calibratedRed: 0.20, green: 0.21, blue: 0.25, alpha: 1),
        NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.09, alpha: 1),
    ])!.draw(in: path, angle: -90)

    // Brilho sutil na borda superior.
    NSColor.white.withAlphaComponent(0.08).setStroke()
    path.lineWidth = 3
    path.stroke()

    // Microfone branco com o traço vermelho (cores por camada do símbolo).
    let config = NSImage.SymbolConfiguration(pointSize: 470, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [
            NSColor(calibratedRed: 1.0, green: 0.27, blue: 0.23, alpha: 1), .white,
        ]))
    let symbol = NSImage(systemSymbolName: "mic.slash.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
    let rect = NSRect(
        x: (size - symbol.size.width) / 2, y: (size - symbol.size.height) / 2,
        width: symbol.size.width, height: symbol.size.height)
    symbol.draw(in: rect)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let master = resources.appendingPathComponent("AppIcon.png")
try renderIcon().representation(using: .png, properties: [:])!.write(to: master)

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func run(_ tool: String, _ args: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool)
    process.arguments = args
    process.standardOutput = FileHandle.nullDevice
    try! process.run()
    process.waitUntilExit()
    precondition(process.terminationStatus == 0, "\(tool) falhou")
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let pixels = String(points * scale)
        run("/usr/bin/sips", ["-z", pixels, pixels, master.path, "--out", iconset.appendingPathComponent(name).path])
    }
}
run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path])
try FileManager.default.removeItem(at: master)
print("Pronto: Resources/AppIcon.icns")
