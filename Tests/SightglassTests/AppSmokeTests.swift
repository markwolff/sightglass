import AppKit
import SwiftUI
import Testing
@testable import SightglassUI

@MainActor
struct AppSmokeTests {
    @Test func fixtureLoadReplacesEmptyStateAndRendersDiagramCanvas() throws {
        let fixtureURL = FixtureLoader.fixtureURL("Specs/layered-rest-service.yaml")
        let repositoryRoot = FixtureLoader.repoURL("Repos/express-api")

        let emptyStateImage = try render(
            ContentView().environmentObject(AppState()),
            size: CGSize(width: 1200, height: 800)
        )

        let loadedState = AppState()
        loadedState.loadSpec(from: fixtureURL, repositoryRoot: repositoryRoot)

        let spec = try #require(loadedState.currentSpec)
        #expect(loadedState.validationResult.isValid)
        #expect(loadedState.validationResult.warnings.isEmpty)
        #expect(loadedState.errorMessage == nil)
        #expect(loadedState.nodePositions.count == spec.nodes.count)

        let loadedStateImage = try render(
            ContentView().environmentObject(loadedState),
            size: CGSize(width: 1200, height: 800)
        )
        let differingPixels = try differingPixelCount(emptyStateImage, loadedStateImage)
        #expect(differingPixels > 5_000)

        let diagramImage = try render(
            DiagramView(spec: spec).environmentObject(loadedState),
            size: CGSize(width: 900, height: 700)
        )
        let diagramPixels = try nonBackgroundPixelCount(in: diagramImage)
        #expect(diagramPixels > 2_000)
    }

    private func render<V: View>(_ view: V, size: CGSize) throws -> NSImage {
        let hostingView = NSHostingView(
            rootView: view
                .frame(width: size.width, height: size.height)
                .background(Color.white)
        )
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            Issue.record("Expected NSHostingView to provide a bitmap for smoke rendering")
            throw SmokeTestError.renderFailed
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }

    private func nonBackgroundPixelCount(in image: NSImage, tolerance: UInt8 = 8) throws -> Int {
        let bitmap = try bitmapData(for: image)
        var count = 0

        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                let offset = y * bitmap.bytesPerRow + x * 4
                let red = bitmap.bytes[offset]
                let green = bitmap.bytes[offset + 1]
                let blue = bitmap.bytes[offset + 2]
                let alpha = bitmap.bytes[offset + 3]

                let isBackground =
                    Int(alpha) >= 255 - Int(tolerance) &&
                    Int(red) >= 255 - Int(tolerance) &&
                    Int(green) >= 255 - Int(tolerance) &&
                    Int(blue) >= 255 - Int(tolerance)

                if !isBackground {
                    count += 1
                }
            }
        }

        return count
    }

    private func differingPixelCount(_ lhs: NSImage, _ rhs: NSImage, tolerance: UInt8 = 8) throws -> Int {
        let left = try bitmapData(for: lhs)
        let right = try bitmapData(for: rhs)

        #expect(left.width == right.width)
        #expect(left.height == right.height)

        var differenceCount = 0

        for y in 0..<left.height {
            for x in 0..<left.width {
                let index = y * left.bytesPerRow + x * 4
                let redDiff = abs(Int(left.bytes[index]) - Int(right.bytes[index]))
                let greenDiff = abs(Int(left.bytes[index + 1]) - Int(right.bytes[index + 1]))
                let blueDiff = abs(Int(left.bytes[index + 2]) - Int(right.bytes[index + 2]))
                let alphaDiff = abs(Int(left.bytes[index + 3]) - Int(right.bytes[index + 3]))

                if redDiff > Int(tolerance) ||
                    greenDiff > Int(tolerance) ||
                    blueDiff > Int(tolerance) ||
                    alphaDiff > Int(tolerance) {
                    differenceCount += 1
                }
            }
        }

        return differenceCount
    }

    private func bitmapData(for image: NSImage) throws -> BitmapData {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            Issue.record("Expected NSImage to provide a CGImage backing")
            throw SmokeTestError.missingCGImage
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)

        guard
            let data = bitmap.bitmapData,
            bitmap.bitsPerPixel == 32,
            bitmap.samplesPerPixel >= 4
        else {
            Issue.record("Unexpected bitmap layout for smoke test image")
            throw SmokeTestError.invalidBitmapLayout
        }

        let byteCount = bitmap.bytesPerRow * bitmap.pixelsHigh
        let bytes = Array(UnsafeBufferPointer(start: data, count: byteCount))
        return BitmapData(
            width: bitmap.pixelsWide,
            height: bitmap.pixelsHigh,
            bytesPerRow: bitmap.bytesPerRow,
            bytes: bytes
        )
    }
}

private struct BitmapData {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let bytes: [UInt8]
}

private enum SmokeTestError: Error {
    case invalidBitmapLayout
    case missingCGImage
    case renderFailed
}
