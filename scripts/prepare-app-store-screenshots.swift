#!/usr/bin/env swift
import AppKit
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

/// Compose five ordered store posters from unaltered simulator screenshots.
/// Requires portrait iPhone 1206×2622 and landscape iPad 2752×2064 inputs;
/// preserves the complete screen and writes opaque sRGB PNGs plus hash bindings.
struct Poster {
    let slug: String
    let headline: String
    let phoneLines: String
}

let posters = [
    Poster(slug: "01-share", headline: "See everyone’s share", phoneLines: "See everyone’s\nshare"),
    Poster(slug: "02-assign", headline: "Choose who shared each item", phoneLines: "Choose who shared\neach item"),
    Poster(slug: "03-tax-tip", headline: "Include tax and tip", phoneLines: "Include tax\nand tip"),
    Poster(slug: "04-receipt", headline: "Keep the receipt", phoneLines: "Keep the receipt"),
    Poster(slug: "05-library", headline: "Find past meals", phoneLines: "Find past meals")
]

struct Capture {
    let image: NSBitmapImageRep
    let data: Data
}

enum CompositionError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        switch self { case .invalid(let message): return message }
    }
}

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw CompositionError.invalid(message) }
}

func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

/// Decode without resizing. Reject orientation-dependent captures so the
/// same input always means the same visible device orientation.
func readCapture(_ url: URL, expected: NSSize) throws -> Capture {
    let data = try Data(contentsOf: url)
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let image = NSBitmapImageRep(data: data) else {
        throw CompositionError.invalid("Cannot decode PNG: \(url.lastPathComponent)")
    }
    try require(CGImageSourceGetType(source) == UTType.png.identifier as CFString,
                "Input must be PNG: \(url.lastPathComponent)")
    let orientation = (properties[kCGImagePropertyOrientation] as? Int) ?? 1
    try require(orientation == 1, "Normalize capture orientation before composition: \(url.lastPathComponent)")
    try require(image.pixelsWide == Int(expected.width) && image.pixelsHigh == Int(expected.height),
                "\(url.lastPathComponent) is \(image.pixelsWide)×\(image.pixelsHigh); expected \(Int(expected.width))×\(Int(expected.height)).")
    try require(!image.hasAlpha, "Capture must be opaque: \(url.lastPathComponent)")
    return Capture(image: image, data: data)
}

let canvasColor = NSColor(srgbRed: 1, green: 0.975, blue: 0.942, alpha: 1)
let inkColor = NSColor(srgbRed: 0, green: 92.0 / 255, blue: 76.0 / 255, alpha: 1)
let frameColor = NSColor(srgbRed: 0.10, green: 0.12, blue: 0.115, alpha: 1)

/// Draw into a pixel-sized, opaque sRGB bitmap using top-left coordinates.
func bitmap(size: NSSize, draw: () throws -> Void) throws -> NSBitmapImageRep {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let cgContext = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                    bitsPerComponent: 8, bytesPerRow: Int(size.width) * 4,
                                    space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        throw CompositionError.invalid("Cannot allocate poster bitmap.")
    }
    let context = NSGraphicsContext(cgContext: cgContext, flipped: true)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.translateBy(x: 0, y: size.height)
    context.cgContext.scaleBy(x: 1, y: -1)
    canvasColor.setFill()
    NSRect(origin: .zero, size: size).fill()
    try draw()
    guard let image = cgContext.makeImage() else {
        throw CompositionError.invalid("Cannot finish poster bitmap.")
    }
    return NSBitmapImageRep(cgImage: image)
}

func drawHeadline(_ text: String, rect: NSRect, fontSize: CGFloat) throws {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = 4
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
        .foregroundColor: inkColor,
        .paragraphStyle: paragraph
    ]
    let title = NSAttributedString(string: text, attributes: attributes)
    let measured = title.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading])
    try require(measured.height <= rect.height, "Headline exceeds its reserved area: \(text)")
    title.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

/// A simple presentation frame, without fabricated hardware or app controls.
/// The screenshot is aspect-fit at its exact ratio; only rounded screen corners
/// are masked, matching the device display boundary.
func drawDevice(_ image: NSBitmapImageRep, bounds: NSRect, border: CGFloat, corner: CGFloat) {
    let ratio = CGFloat(image.pixelsWide) / CGFloat(image.pixelsHigh)
    let innerHeight = min(bounds.height - border * 2, (bounds.width - border * 2) / ratio)
    let innerWidth = innerHeight * ratio
    let outer = NSRect(x: bounds.midX - innerWidth / 2 - border, y: bounds.minY,
                       width: innerWidth + border * 2, height: innerHeight + border * 2)
    let screen = outer.insetBy(dx: border, dy: border)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = inkColor.withAlphaComponent(0.13)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    frameColor.setFill()
    NSBezierPath(roundedRect: outer, xRadius: corner + border, yRadius: corner + border).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screen, xRadius: corner, yRadius: corner).addClip()
    let nsImage = NSImage(size: NSSize(width: image.pixelsWide, height: image.pixelsHigh))
    nsImage.addRepresentation(image)
    nsImage.draw(in: screen, from: .zero, operation: .copy, fraction: 1,
                 respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()
}

func writePNG(_ image: NSBitmapImageRep, to url: URL) throws -> String {
    guard let data = image.representation(using: .png, properties: [:]) else {
        throw CompositionError.invalid("Cannot encode poster PNG.")
    }
    try data.write(to: url, options: .atomic)
    return sha256(data)
}

func writeJSON(_ value: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    try (data + Data([10])).write(to: url, options: .atomic)
}

/// Read a frozen repository manifest without admitting absolute paths or
/// malformed hashes into the portable screenshot evidence bundle.
func readSourceManifest(_ path: String) throws -> (Data, [String: String]) {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    guard let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let sources = manifest["sha256"] as? [String: String], !sources.isEmpty else {
        throw CompositionError.invalid("Frozen source manifest must contain nonempty sha256 path bindings.")
    }
    for (path, hash) in sources {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        try require(!path.hasPrefix("/") && !components.contains("..") && !components.contains(""),
                    "Source manifest requires relative repository paths: \(path)")
        try require(hash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
                    "Invalid SHA-256 binding in source manifest: \(path)")
    }
    return (data, sources)
}

func main() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let usage = "Usage: swift scripts/prepare-app-store-screenshots.swift --iphone <capture-dir> --ipad <capture-dir> --manifest <frozen-source-manifest.json> --output <output-dir> [--receipt-manifest <iPad-receipt-source-manifest.json>]"
    try require(arguments.count == 8 || arguments.count == 10, usage)
    var options: [String: String] = [:]
    for index in stride(from: 0, to: arguments.count, by: 2) {
        let key = arguments[index]
        try require(["--iphone", "--ipad", "--manifest", "--output", "--receipt-manifest"].contains(key) && options[key] == nil, usage)
        options[key] = arguments[index + 1]
    }
    try require(["--iphone", "--ipad", "--manifest", "--output"].allSatisfy { options[$0] != nil }, usage)
    let output = URL(fileURLWithPath: options["--output"]!, isDirectory: true)
    let (sourceData, sources) = try readSourceManifest(options["--manifest"]!)
    var receiptSourceData: Data?
    if let receiptPath = options["--receipt-manifest"] {
        let (data, receiptSources) = try readSourceManifest(receiptPath)
        let changed = Set(sources.keys).union(receiptSources.keys).filter { sources[$0] != receiptSources[$0] }
        // The receipt recapture changes only the native test's zoom and pan.
        // A production change requires a fresh complete screenshot capture set.
        try require(changed.allSatisfy { $0 == "SplitMyMealUITests/MealJourneyTests.swift" },
                    "Receipt-only source override must preserve every production and other verification input.")
        receiptSourceData = data
    }
    // Validate every input before creating outputs, avoiding a half-new set when
    // one missing or incorrectly oriented capture would otherwise fail late.
    let devices: [(String, NSSize, URL)] = [
        ("iphone", NSSize(width: 1206, height: 2622), URL(fileURLWithPath: options["--iphone"]!, isDirectory: true)),
        ("ipad", NSSize(width: 2752, height: 2064), URL(fileURLWithPath: options["--ipad"]!, isDirectory: true))
    ]
    var inputs: [String: Capture] = [:]
    for (device, size, directory) in devices {
        for poster in posters {
            inputs["\(device)/\(poster.slug)"] = try readCapture(directory.appendingPathComponent(poster.slug + ".png"), expected: size)
        }
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    try sourceData.write(to: output.appendingPathComponent("source-manifest.json"), options: .atomic)
    if let receiptSourceData {
        try receiptSourceData.write(to: output.appendingPathComponent("receipt-source-manifest.json"), options: .atomic)
    }
    var entries: [[String: Any]] = []
    var rendered: [String: NSBitmapImageRep] = [:]
    for (device, size, _) in devices {
        let deviceOutput = output.appendingPathComponent(device, isDirectory: true)
        let rawOutput = output.appendingPathComponent("captures/" + device, isDirectory: true)
        try FileManager.default.createDirectory(at: deviceOutput, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rawOutput, withIntermediateDirectories: true)
        for poster in posters {
            let capture = inputs["\(device)/\(poster.slug)"]!
            let image = capture.image
            let composition = try bitmap(size: size) {
                if device == "iphone" {
                    try drawHeadline(poster.phoneLines, rect: NSRect(x: 84, y: 144, width: 1038, height: 238), fontSize: 88)
                    drawDevice(image, bounds: NSRect(x: 126, y: 536, width: 954, height: 1888), border: 10, corner: 80)
                } else {
                    try drawHeadline(poster.headline, rect: NSRect(x: 144, y: 130, width: 2464, height: 210), fontSize: 116)
                    drawDevice(image, bounds: NSRect(x: 144, y: 410, width: 2464, height: 1510), border: 10, corner: 46)
                }
            }
            let filename = poster.slug + ".png"
            let posterHash = try writePNG(composition, to: deviceOutput.appendingPathComponent(filename))
            try capture.data.write(to: rawOutput.appendingPathComponent(filename), options: .atomic)
            rendered["\(device)/\(poster.slug)"] = composition
            let receiptOverride = device == "ipad" && poster.slug == "04-receipt" && receiptSourceData != nil
            entries.append(["device": device, "order": Int(poster.slug.prefix(2))!, "headline": poster.headline,
                            "poster": "\(device)/\(filename)", "posterSHA256": posterHash,
                            "capture": "captures/\(device)/\(filename)", "captureSHA256": sha256(capture.data),
                            "sourceManifest": receiptOverride ? "receipt-source-manifest.json" : "source-manifest.json",
                            "sourceManifestSHA256": sha256(receiptOverride ? receiptSourceData! : sourceData),
                            "width": Int(size.width), "height": Int(size.height)])
        }
    }
    let sheetSize = NSSize(width: 1800, height: 1080)
    let contactSheet = try bitmap(size: sheetSize) {
        for (index, poster) in posters.enumerated() {
            for device in ["iphone", "ipad"] {
                let image = rendered["\(device)/\(poster.slug)"]!
                let frame = device == "iphone"
                    ? NSRect(x: 18 + index * 356, y: 18, width: 320, height: 696)
                    : NSRect(x: 18 + index * 356, y: 790, width: 320, height: 240)
                let nsImage = NSImage(size: NSSize(width: image.pixelsWide, height: image.pixelsHigh))
                nsImage.addRepresentation(image)
                nsImage.draw(in: frame, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
            }
        }
    }
    let sheetHash = try writePNG(contactSheet, to: output.appendingPathComponent("contact-sheet.png"))
    let scriptData = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[0]))
    try writeJSON(["schemaVersion": 2, "baseSourceManifestSHA256": sha256(sourceData),
                   "renderer": "scripts/prepare-app-store-screenshots.swift", "rendererSHA256": sha256(scriptData),
                   "rendererOS": ProcessInfo.processInfo.operatingSystemVersionString,
                   "headlineFont": NSFont.systemFont(ofSize: 88, weight: .semibold).fontName,
                   "capturePolicy": "Complete native simulator screenshot; no UI reconstruction, cropping, or stretching.",
                   "colorSpace": "sRGB", "alpha": false, "posters": entries,
                   "contactSheet": ["path": "contact-sheet.png", "sha256": sheetHash]],
                  to: output.appendingPathComponent("manifest.json"))
    print("Prepared \(entries.count) ordered posters in \(output.path)")
}

do { try main() } catch {
    fputs("Screenshot composition failed: \(error)\n", stderr)
    exit(1)
}
