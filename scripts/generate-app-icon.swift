#!/usr/bin/env swift
import AppKit
import SwiftUI

struct AppIconView: View {
    var size: CGFloat = 1024

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.5, blue: 1.0),
                    Color(red: 0.5, green: 0.3, blue: 0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: size * 0.05) {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.08)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: size * 0.45, height: size * 0.55)
                        .offset(x: -size * 0.06, y: size * 0.04)

                    RoundedRectangle(cornerRadius: size * 0.08)
                        .fill(Color.white.opacity(0.5))
                        .frame(width: size * 0.45, height: size * 0.55)
                        .offset(x: -size * 0.03, y: size * 0.02)

                    ZStack {
                        RoundedRectangle(cornerRadius: size * 0.08)
                            .fill(Color.white)

                        VStack(spacing: size * 0.02) {
                            Text("A")
                                .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.2, green: 0.5, blue: 1.0),
                                            Color(red: 0.5, green: 0.3, blue: 0.9)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            HStack(spacing: size * 0.015) {
                                ForEach(0..<3, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: size * 0.005)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: size * 0.1, height: size * 0.012)
                                }
                            }
                        }
                    }
                    .frame(width: size * 0.45, height: size * 0.55)
                }

                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: size * 0.12, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

func renderIcon(size: CGFloat) -> Data {
    let pixelSize = Int(size)
    let view = AppIconView(size: size)
    let hosting = NSHostingController(rootView: view)
    hosting.view.appearance = NSAppearance(named: .aqua)
    hosting.view.frame = CGRect(x: 0, y: 0, width: size, height: size)

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap for size \(pixelSize)")
    }
    rep.size = NSSize(width: size, height: size)
    hosting.view.cacheDisplay(in: hosting.view.bounds, to: rep)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG for size \(pixelSize)")
    }
    return png
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath)
    .appendingPathComponent("LanguageTraining/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let sizes: [(name: String, points: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for item in sizes {
    let data = renderIcon(size: item.points)
    try data.write(to: outputDir.appendingPathComponent(item.name))
    print("Wrote \(item.name)")
}
