import CoreGraphics
import Foundation

enum Colr {
    static func toHexStrFromCG(_ c: CGColor) -> String {
        guard let comp = c.components, comp.count >= 3 else { return "#000000" }
        let r = Int(comp[0] * 255)
        let g = Int(comp[1] * 255)
        let b = Int(comp[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    static func toCG(_ h: String) -> CGColor? {
        var s = h.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        var v: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&v) else { return nil }
        return CGColor(
            red: CGFloat((v & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((v & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(v & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
    
    static func rgb(_ h: String) -> (r: Int, g: Int, b: Int)? {
        var s = h.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        var v: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&v) else { return nil }
        return (
            r: Int((v & 0xFF0000) >> 16),
            g: Int((v & 0x00FF00) >> 8),
            b: Int(v & 0x0000FF)
        )
    }
    
    static func hex(r: Int, g: Int, b: Int) -> String {
        String(format: "#%02X%02X%02X", r, g, b)
    }
    
    static func isValid(_ h: String) -> Bool {
        var s = h.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        guard s.count == 6 else { return false }
        return s.allSatisfy { $0.isHexDigit }
    }
}
