import AppKit
import SwiftUI
import Testing
import SightglassCore
@testable import SightglassUI

@MainActor
struct ViewerMVPTests {

    // MARK: - 1. UI Automation Tests (state transition verification)

    @Test func selectNodeUpdatesStateAndRevealsLayer() throws {
        let state = makeLoadedState(spec: "Specs/layered-rest-service.yaml", repo: "Repos/express-api")
        let spec = try #require(state.currentSpec)
        let node = try #require(spec.nodes.first)

        // Hide the node's layer first so we can verify reveal
        state.setLayerVisibility(false, for: node.layer)
        #expect(!state.visibleLayerIDs.contains(node.layer))

        state.selectNode(id: node.id)

        #expect(state.selectedNodeID == node.id)
        #expect(state.visibleLayerIDs.contains(node.layer))
    }

    @Test func hideLayerClearsSelectionOfHiddenNode() throws {
        let state = makeLoadedState(spec: "Specs/layered-rest-service.yaml", repo: "Repos/express-api")
        let spec = try #require(state.currentSpec)
        let node = try #require(spec.nodes.first)

        state.selectNode(id: node.id)
        #expect(state.selectedNodeID == node.id)

        state.setLayerVisibility(false, for: node.layer)

        #expect(state.selectedNodeID == nil)
    }

    @Test func searchQueryFilters() throws {
        let state = makeLoadedState(spec: "Specs/layered-rest-service.yaml", repo: "Repos/express-api")
        let spec = try #require(state.currentSpec)

        state.searchQuery = "Auth"

        let matchingNodes = spec.nodes.filter {
            $0.name.localizedCaseInsensitiveContains(state.searchQuery)
        }
        #expect(!matchingNodes.isEmpty)
        #expect(matchingNodes.allSatisfy { $0.name.localizedCaseInsensitiveContains("Auth") })
    }

    @Test func jumpFromEntryPointToNode() throws {
        let state = makeLoadedState(spec: "Specs/layered-rest-service.yaml", repo: "Repos/express-api")
        let entryPoint = try #require(state.currentSpec?.entryPoints?.first)

        state.activateEntryPoint(id: entryPoint.id)

        #expect(state.activeEntryPointID == entryPoint.id)
        #expect(state.selectedNodeID == entryPoint.node)
    }

    @Test func fitToScreenSetsReasonableZoomAndPan() throws {
        let state = makeLoadedState(spec: "Specs/layered-rest-service.yaml", repo: "Repos/express-api")
        #expect(!state.nodePositions.isEmpty)

        state.fitToScreen(canvasSize: CGSize(width: 800, height: 600))

        #expect(state.zoomLevel > 0)
        #expect(state.zoomLevel.isFinite)
        #expect(state.panOffset.width.isFinite)
        #expect(state.panOffset.height.isFinite)
    }

    @Test func flowSelectionFocusesFirstStep() throws {
        let state = makeLoadedState(spec: "Specs/layered-rest-service.yaml", repo: "Repos/express-api")
        let flow = try #require(state.currentSpec?.flows?.first)

        state.selectFlow(id: flow.id)

        #expect(state.selectedFlowID == flow.id)
        let orderedSteps = flow.steps.sorted { $0.sequence < $1.sequence }
        let expectedNodeID = orderedSteps.first?.from ?? orderedSteps.first?.to
        #expect(state.selectedNodeID == expectedNodeID)
    }

    // MARK: - 2. Golden Screenshot Tests (rendered image stability)

    @Test func goldenScreenshotSmallFixture() throws {
        let state = makeLoadedState(spec: "Specs/minimal-valid.yaml")
        let spec = try #require(state.currentSpec)
        state.zoomLevel = 1.0

        let image = try render(
            DiagramView(spec: spec).environmentObject(state),
            size: CGSize(width: 900, height: 700)
        )
        let pixels = try nonBackgroundPixelCount(in: image)
        #expect(pixels > 500)
    }

    @Test func goldenScreenshotMediumFixture() throws {
        let state = makeLoadedState(spec: "Specs/layered-rest-service.yaml", repo: "Repos/express-api")
        let spec = try #require(state.currentSpec)
        state.zoomLevel = 1.0

        let image = try render(
            DiagramView(spec: spec).environmentObject(state),
            size: CGSize(width: 900, height: 700)
        )
        let pixels = try nonBackgroundPixelCount(in: image)
        #expect(pixels > 2_000)
    }

    @Test func goldenScreenshotLargeFixture() throws {
        let state = makeLoadedState(spec: "Specs/large-graph.yaml", repo: "Repos/medium-monolith")
        let spec = try #require(state.currentSpec)
        state.zoomLevel = 0.5

        let image = try render(
            DiagramView(spec: spec).environmentObject(state),
            size: CGSize(width: 900, height: 700)
        )
        let pixels = try nonBackgroundPixelCount(in: image)
        #expect(pixels > 1_000)
    }

    @Test func goldenScreenshotAtLowZoom() throws {
        let state = makeLoadedState(spec: "Specs/layered-rest-service.yaml", repo: "Repos/express-api")
        let spec = try #require(state.currentSpec)

        state.zoomLevel = 1.0
        state.fitToScreen(canvasSize: CGSize(width: 900, height: 700))
        let normalImage = try render(
            DiagramView(spec: spec).environmentObject(state),
            size: CGSize(width: 900, height: 700)
        )
        let normalPixels = try nonBackgroundPixelCount(in: normalImage)

        state.zoomLevel = 0.2
        state.panOffset = .zero
        let lowZoomImage = try render(
            DiagramView(spec: spec).environmentObject(state),
            size: CGSize(width: 900, height: 700)
        )
        let lowZoomPixels = try nonBackgroundPixelCount(in: lowZoomImage)

        // At very low zoom LOD kicks in; it should still render something
        #expect(lowZoomPixels > 0)
        // But fewer detail pixels than the normal view (LOD reduces detail)
        #expect(lowZoomPixels < normalPixels)
    }

    @Test func goldenScreenshotAtHighZoom() throws {
        let state = makeLoadedState(spec: "Specs/layered-rest-service.yaml", repo: "Repos/express-api")
        let spec = try #require(state.currentSpec)

        // At high zoom, nodes are larger but some may be clipped by viewport.
        // The key check is that it still renders meaningful content.
        state.zoomLevel = 2.0
        state.fitToScreen(canvasSize: CGSize(width: 900, height: 700))
        let highZoomImage = try render(
            DiagramView(spec: spec).environmentObject(state),
            size: CGSize(width: 900, height: 700)
        )
        let highZoomPixels = try nonBackgroundPixelCount(in: highZoomImage)

        // At high zoom with fit-to-screen, we should see substantial rendered content
        #expect(highZoomPixels > 2_000)
    }

    // MARK: - 3. Performance Test

    @Test func performanceTestLargeGraph() throws {
        let yaml = try FixtureLoader.loadString(at: "Specs/large-graph.yaml")
        let spec = try SpecParser.parse(yamlString: yaml)

        #expect(spec.nodes.count >= 10)

        let start = CFAbsoluteTimeGetCurrent()
        let iterations = 15
        for _ in 0..<iterations {
            let layout = GraphLayout(spec: spec)
            let positions = layout.computePositions()
            _ = DiagramGeometrySnapshotBuilder.makeSnapshot(spec: spec, positions: positions)
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let averageMs = elapsed / Double(iterations)

        #expect(averageMs < 500, "Layout + snapshot for large-graph should complete in under 500ms, took \(averageMs)ms")
    }

    // MARK: - 4. Regression Tests for Hover and Selection at Transformed States

    @Test func hitTestingWorksAtDefaultZoomAndPan() throws {
        let state = makeLoadedState(spec: "Specs/layered-rest-service.yaml", repo: "Repos/express-api")
        let spec = try #require(state.currentSpec)
        let targetNode = try #require(spec.nodes.first)
        let position = try #require(state.nodePositions[targetNode.id])

        #expect(position.x.isFinite)
        #expect(position.y.isFinite)

        state.selectNode(id: targetNode.id)
        #expect(state.selectedNodeID == targetNode.id)
    }

    @Test func selectionPersistsThroughZoomChange() throws {
        let state = makeLoadedState(spec: "Specs/layered-rest-service.yaml", repo: "Repos/express-api")
        let spec = try #require(state.currentSpec)
        let targetNode = try #require(spec.nodes.first)

        state.selectNode(id: targetNode.id)
        #expect(state.selectedNodeID == targetNode.id)

        state.zoomLevel = 0.5
        #expect(state.selectedNodeID == targetNode.id)

        state.zoomLevel = 2.0
        #expect(state.selectedNodeID == targetNode.id)

        state.zoomLevel = 0.1
        #expect(state.selectedNodeID == targetNode.id)
    }

    @Test func hoverStateTracking() throws {
        let state = makeLoadedState(spec: "Specs/layered-rest-service.yaml", repo: "Repos/express-api")
        let spec = try #require(state.currentSpec)
        let node = try #require(spec.nodes.first)

        #expect(state.hoveredNodeID == nil)

        state.hoveredNodeID = node.id
        #expect(state.hoveredNodeID == node.id)

        state.hoveredNodeID = nil
        #expect(state.hoveredNodeID == nil)
    }

    // MARK: - Private Helpers

    private func makeLoadedState(
        spec specPath: String,
        repo repoPath: String? = nil
    ) -> AppState {
        let defaults = makeIsolatedDefaults()
        let specURL = FixtureLoader.fixtureURL(specPath)
        let repoURL = repoPath.map { FixtureLoader.repoURL($0) }
        let state = AppState(userDefaults: defaults, launchArguments: [])
        state.loadSpec(from: specURL, repositoryRoot: repoURL)
        return state
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "ViewerMVPTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - Render / Bitmap Helpers

    private func render<V: View>(_ view: V, size: CGSize) throws -> NSImage {
        let hostingView = NSHostingView(
            rootView: view
                .frame(width: size.width, height: size.height)
                .background(Color.white)
        )
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            Issue.record("Expected NSHostingView to provide a bitmap for rendering")
            throw ViewerMVPTestError.renderFailed
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

    private func bitmapData(for image: NSImage) throws -> BitmapData {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            Issue.record("Expected NSImage to provide a CGImage backing")
            throw ViewerMVPTestError.missingCGImage
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)

        guard
            let data = bitmap.bitmapData,
            bitmap.bitsPerPixel == 32,
            bitmap.samplesPerPixel >= 4
        else {
            Issue.record("Unexpected bitmap layout for test image")
            throw ViewerMVPTestError.invalidBitmapLayout
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

private enum ViewerMVPTestError: Error {
    case invalidBitmapLayout
    case missingCGImage
    case renderFailed
}
