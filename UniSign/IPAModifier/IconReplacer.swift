import UIKit

/// Utility to find and replace app icons in an unzipped .app bundle
public class IconReplacer {
    
    public enum IconError: LocalizedError {
        case imageConversionFailed
        case noIconsFound
        
        public var errorDescription: String? {
            switch self {
            case .imageConversionFailed: return "Could not process or convert the replacement icon image."
            case .noIconsFound: return "No icon files were located in the app bundle."
            }
        }
    }
    
    /// Replaces the primary application icon with the provided image
    public static func replaceIcon(inAppURL appURL: URL, withImage newIcon: UIImage) throws {
        let fileManager = FileManager.default
        
        // Target common dimensions for iOS icons
        let iconDimensions: [(name: String, size: CGSize)] = [
            ("AppIcon60x60@2x.png", CGSize(width: 120, height: 120)),
            ("AppIcon60x60@3x.png", CGSize(width: 180, height: 180)),
            ("AppIcon76x76@2x~ipad.png", CGSize(width: 152, height: 152)),
            ("AppIcon83.5x83.5@2x~ipad.png", CGSize(width: 167, height: 167)),
            ("Icon-60@2x.png", CGSize(width: 120, height: 120)),
            ("Icon-60@3x.png", CGSize(width: 180, height: 180)),
            ("AppIcon20x20@2x.png", CGSize(width: 40, height: 40)),
            ("AppIcon20x20@3x.png", CGSize(width: 60, height: 60)),
            ("AppIcon29x29@2x.png", CGSize(width: 58, height: 58)),
            ("AppIcon29x29@3x.png", CGSize(width: 87, height: 87)),
            ("AppIcon40x40@2x.png", CGSize(width: 80, height: 80)),
            ("AppIcon40x40@3x.png", CGSize(width: 120, height: 120))
        ]
        
        // 1. Scan app directory for any existing files containing "AppIcon" or "Icon"
        let contents = try fileManager.contentsOfDirectory(atPath: appURL.path)
        var replacedCount = 0
        
        for file in contents {
            if file.lowercased().contains("appicon") || (file.lowercased().contains("icon") && file.hasSuffix(".png")) {
                let targetURL = appURL.appendingPathComponent(file)
                // Determine existing image size if readable
                if let existingImg = UIImage(contentsOfFile: targetURL.path) {
                    let targetSize = existingImg.size
                    if let resizedData = resizeImage(image: newIcon, targetSize: targetSize)?.pngData() {
                        try? resizedData.write(to: targetURL)
                        replacedCount += 1
                        continue
                    }
                }
                
                // Fallback default resize
                if let fallbackData = resizeImage(image: newIcon, targetSize: CGSize(width: 120, height: 120))?.pngData() {
                    try? fallbackData.write(to: targetURL)
                    replacedCount += 1
                }
            }
        }
        
        // 2. Also write standard icon names if none were matched
        if replacedCount == 0 {
            for item in iconDimensions {
                let destURL = appURL.appendingPathComponent(item.name)
                if let data = resizeImage(image: newIcon, targetSize: item.size)?.pngData() {
                    try? data.write(to: destURL)
                    replacedCount += 1
                }
            }
        }
    }
    
    /// Helper to render image at specified pixel dimensions
    public static func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
