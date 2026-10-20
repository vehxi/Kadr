import AppKit
import SwiftUI
import Testing

#if canImport(MyMovies)
@testable import MyMovies
#else
@testable import Kadr
#endif

@MainActor
struct EducaDesignTests {
    @Test func appearanceSettingsHandleOlderOrInvalidPreferences() {
        #expect(AppAppearance(storedValue: "system").colorScheme == nil)
        #expect(AppAppearance(storedValue: "light").colorScheme == .light)
        #expect(AppAppearance(storedValue: "dark").colorScheme == .dark)
        #expect(AppAppearance(storedValue: "unknown") == .system)
        #expect(AppAppearance.allCases.map(\.rawValue) == ["system", "light", "dark"])
    }

    @Test func semanticColorsResolveInBothAppearances() throws {
        let light = try #require(NSAppearance(named: .aqua))
        let dark = try #require(NSAppearance(named: .darkAqua))
        let pairs: [(Color, UInt32, UInt32)] = [
            (EducaColor.canvas, 0xEDEFF1, 0x0C0D0F),
            (EducaColor.panel, 0xFBFCFD, 0x161719),
            (EducaColor.raised, 0xDFE1E5, 0x202224),
            (EducaColor.text, 0x1D1F23, 0xEAEBED),
            (EducaColor.secondaryText, 0x505357, 0x96989B),
            (EducaColor.mutedText, 0x5D6165, 0x5E6164),
            (EducaColor.primaryButtonText, 0xFBFCFD, 0x0C0D0F)
        ]
        for (color, lightHex, darkHex) in pairs {
            #expect(try hex(color, appearance: light) == lightHex)
            #expect(try hex(color, appearance: dark) == darkHex)
        }
    }

    @Test func essentialTextHasReadableContrast() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try #require(NSAppearance(named: name))
            for background in [EducaColor.canvas, EducaColor.panel, EducaColor.raised] {
                let foreground = try luminance(EducaColor.secondaryText, appearance: appearance)
                let surface = try luminance(background, appearance: appearance)
                let ratio = (max(foreground, surface) + 0.05) / (min(foreground, surface) + 0.05)
                #expect(ratio >= 4.5)
            }
        }
    }

    private func resolved(_ color: Color, appearance: NSAppearance) throws -> NSColor {
        var result: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            result = NSColor(color).usingColorSpace(.sRGB)
        }
        return try #require(result)
    }

    private func hex(_ color: Color, appearance: NSAppearance) throws -> UInt32 {
        let rgb = try resolved(color, appearance: appearance)
        return UInt32((rgb.redComponent * 255).rounded()) << 16
            | UInt32((rgb.greenComponent * 255).rounded()) << 8
            | UInt32((rgb.blueComponent * 255).rounded())
    }

    private func luminance(_ color: Color, appearance: NSAppearance) throws -> Double {
        let rgb = try resolved(color, appearance: appearance)
        let linear = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { value in
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}
