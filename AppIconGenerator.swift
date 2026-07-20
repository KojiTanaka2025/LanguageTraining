import SwiftUI
import AppKit

/// アプリアイコンを生成するためのビュー
/// このビューをプレビューで表示し、スクリーンショットを撮ることでアイコンを作成できます
struct AppIconView: View {
    var size: CGFloat = 1024
    
    var body: some View {
        ZStack {
            // グラデーション背景（青から紫へ）
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.5, blue: 1.0),
                    Color(red: 0.5, green: 0.3, blue: 0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // メインのカードアイコン
            VStack(spacing: size * 0.05) {
                // 重なったカードのイメージ
                ZStack {
                    // 背面のカード
                    RoundedRectangle(cornerRadius: size * 0.08)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: size * 0.45, height: size * 0.55)
                        .offset(x: -size * 0.06, y: size * 0.04)
                        .shadow(color: .black.opacity(0.2), radius: size * 0.02, x: 0, y: size * 0.01)
                    
                    // 中間のカード
                    RoundedRectangle(cornerRadius: size * 0.08)
                        .fill(Color.white.opacity(0.5))
                        .frame(width: size * 0.45, height: size * 0.55)
                        .offset(x: -size * 0.03, y: size * 0.02)
                        .shadow(color: .black.opacity(0.2), radius: size * 0.02, x: 0, y: size * 0.01)
                    
                    // 前面のカード（メイン）
                    ZStack {
                        RoundedRectangle(cornerRadius: size * 0.08)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.3), radius: size * 0.03, x: 0, y: size * 0.015)
                        
                        // カード上の「A」の文字
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
                            
                            // 下線（カードのイメージ）
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
                
                // 音声アイコン（スピーカー波形）
                HStack(spacing: size * 0.015) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: size * 0.12, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: size * 0.01, x: 0, y: size * 0.005)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

/// アイコン画像を実際に生成するユーティリティ
struct AppIconGenerator {
    /// 指定されたサイズでアイコン画像を生成
    static func generateIcon(size: CGFloat) -> NSImage? {
        let view = AppIconView(size: size)
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: size, height: size)
        
        guard let bitmapRep = hostingController.view.bitmapImageRepForCachingDisplay(in: hostingController.view.bounds) else {
            return nil
        }
        
        hostingController.view.cacheDisplay(in: hostingController.view.bounds, to: bitmapRep)
        
        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(bitmapRep)
        
        return image
    }
    
    /// すべての必要なサイズのアイコンを生成してデスクトップに保存
    static func generateAllIconSizes() {
        let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let iconFolder = desktopURL.appendingPathComponent("LanguageTrainingIcons")
        
        do {
            try FileManager.default.createDirectory(at: iconFolder, withIntermediateDirectories: true)
            
            for size in sizes {
                if let image = generateIcon(size: size),
                   let tiffData = image.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    
                    let filename = "icon_\(Int(size))x\(Int(size)).png"
                    let fileURL = iconFolder.appendingPathComponent(filename)
                    try pngData.write(to: fileURL)
                    print("Generated: \(filename)")
                }
                
                // @2x サイズも生成
                let size2x = size * 2
                if let image = generateIcon(size: size2x),
                   let tiffData = image.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    
                    let filename = "icon_\(Int(size))x\(Int(size))@2x.png"
                    let fileURL = iconFolder.appendingPathComponent(filename)
                    try pngData.write(to: fileURL)
                    print("Generated: \(filename)")
                }
            }
            
            print("All icons generated successfully at: \(iconFolder.path)")
        } catch {
            print("Error generating icons: \(error)")
        }
    }
}

// MARK: - プレビュー
#Preview("App Icon 1024x1024") {
    AppIconView(size: 1024)
}

#Preview("App Icon 512x512") {
    AppIconView(size: 512)
}

#Preview("App Icon 256x256") {
    AppIconView(size: 256)
}

#Preview("App Icon 128x128") {
    AppIconView(size: 128)
}

// デバッグ用：このビューを表示してボタンをクリックするとアイコンを生成できます
struct IconGeneratorDebugView: View {
    var body: some View {
        VStack(spacing: 20) {
            AppIconView(size: 256)
            
            Button("Generate Icons on Desktop") {
                AppIconGenerator.generateAllIconSizes()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

#Preview("Icon Generator") {
    IconGeneratorDebugView()
}
