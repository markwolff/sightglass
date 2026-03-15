import Foundation
import Testing
import SightglassCore
@testable import SightglassUI

@MainActor
struct AppStateTests {
    @Test func openFolderCapturesRepositoryContextAndRecentFolder() throws {
        let defaults = makeIsolatedDefaults()
        let repoURL = FixtureLoader.repoURL("Repos/express-api")
        let state = AppState(userDefaults: defaults, launchArguments: [])

        state.openFolder(repoURL)

        let context = try #require(state.repositoryContext)
        #expect(state.currentRepoRoot == repoURL.standardizedFileURL)
        #expect(state.currentSpec == nil)
        #expect(context.rootURL == repoURL.standardizedFileURL)
        #expect(context.sourceFileCount == 5)
        #expect(context.detectedLanguage == "TypeScript")
        #expect(context.detectedFramework == "Express-style API")
        #expect(state.freshnessState == .repoContextOnly)
        #expect(state.recentFolders.first?.url == repoURL.standardizedFileURL)
    }

    @Test func loadingValidSpecInitializesViewerStateAndRecents() throws {
        let defaults = makeIsolatedDefaults()
        let repoURL = FixtureLoader.repoURL("Repos/express-api")
        let specURL = FixtureLoader.fixtureURL("Specs/layered-rest-service.yaml")
        let state = AppState(userDefaults: defaults, launchArguments: [])

        state.loadSpec(from: specURL, repositoryRoot: repoURL)

        let spec = try #require(state.currentSpec)
        #expect(state.currentRepoRoot == repoURL.standardizedFileURL)
        #expect(state.specFileURL == specURL.standardizedFileURL)
        #expect(state.selectedNodeID == nil)
        #expect(state.hoveredNodeID == nil)
        #expect(state.selectedFlowID == nil)
        #expect(state.activeEntryPointID == nil)
        #expect(state.visibleLayerIDs == Set(spec.layers.map(\.id)))
        #expect(state.nodePositions.count == spec.nodes.count)
        #expect(state.freshnessState == .specLoaded)
        #expect(state.recentSpecFiles.first?.url == specURL.standardizedFileURL)
        #expect(state.recentFolders.first?.url == repoURL.standardizedFileURL)
    }

    @Test func invalidSpecBlocksRenderingButKeepsContext() throws {
        let defaults = makeIsolatedDefaults()
        let specURL = FixtureLoader.fixtureURL("Specs/duplicate-id-failure.yaml")
        let state = AppState(userDefaults: defaults, launchArguments: [])

        state.loadSpec(from: specURL)

        #expect(state.currentSpec == nil)
        #expect(state.specFileURL == specURL.standardizedFileURL)
        #expect(!state.validationResult.fatalErrors.isEmpty)
        #expect(state.freshnessState == .validationBlocked)
        #expect(state.currentRepoRoot == specURL.deletingLastPathComponent().standardizedFileURL)
        #expect(state.recentSpecFiles.first?.url == specURL.standardizedFileURL)
    }

    @Test func recentLocationsRestoreAcrossAppStateInstances() throws {
        let defaults = makeIsolatedDefaults()
        let repoURL = FixtureLoader.repoURL("Repos/express-api")
        let specURL = FixtureLoader.fixtureURL("Specs/layered-rest-service.yaml")

        let initialState = AppState(userDefaults: defaults, launchArguments: [])
        initialState.openFolder(repoURL)
        initialState.loadSpec(from: specURL, repositoryRoot: repoURL)

        let restoredState = AppState(userDefaults: defaults, launchArguments: [])
        #expect(restoredState.recentFolders.first?.url == repoURL.standardizedFileURL)
        #expect(restoredState.recentSpecFiles.first?.url == specURL.standardizedFileURL)
    }

    @Test func sharedIntakePathSupportsSpecFilesAndFolders() throws {
        let specDefaults = makeIsolatedDefaults()
        let specURL = FixtureLoader.fixtureURL("Specs/layered-rest-service.yaml")
        let specState = AppState(userDefaults: specDefaults, launchArguments: [])

        specState.open(url: specURL)
        #expect(specState.currentSpec != nil)
        #expect(specState.specFileURL == specURL.standardizedFileURL)

        let folderDefaults = makeIsolatedDefaults()
        let repoURL = FixtureLoader.repoURL("Repos/express-api")
        let folderState = AppState(userDefaults: folderDefaults, launchArguments: [])

        folderState.open(url: repoURL)
        #expect(folderState.currentSpec == nil)
        #expect(folderState.currentRepoRoot == repoURL.standardizedFileURL)
        #expect(folderState.repositoryContext?.rootURL == repoURL.standardizedFileURL)
    }

    @Test func launchArgumentsBootstrapFileAndFolderSessions() throws {
        let specURL = FixtureLoader.fixtureURL("Specs/layered-rest-service.yaml")
        let specState = AppState(
            userDefaults: makeIsolatedDefaults(),
            launchArguments: ["Sightglass", specURL.path]
        )
        #expect(specState.currentSpec != nil)
        #expect(specState.specFileURL == specURL.standardizedFileURL)

        let repoURL = FixtureLoader.repoURL("Repos/express-api")
        let folderState = AppState(
            userDefaults: makeIsolatedDefaults(),
            launchArguments: ["Sightglass", repoURL.path]
        )
        #expect(folderState.currentSpec == nil)
        #expect(folderState.currentRepoRoot == repoURL.standardizedFileURL)
        #expect(folderState.repositoryContext?.rootURL == repoURL.standardizedFileURL)
    }

    @Test func saveWritesValidSpecToCurrentPath() throws {
        let defaults = makeIsolatedDefaults()
        let workspaceURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspaceURL) }

        try writeFile(
            at: workspaceURL.appendingPathComponent("src/index.ts"),
            contents: "export const home = true\n"
        )

        let specURL = workspaceURL.appendingPathComponent(".sightglass.yaml")
        try writeFixture("Specs/minimal-valid.yaml", to: specURL)

        let state = AppState(userDefaults: defaults, launchArguments: [])
        state.loadSpec(from: specURL, repositoryRoot: workspaceURL)

        let loadedSpec = try #require(state.currentSpec)
        state.saveCurrentSpec()

        let savedSpec = try SpecParser.parse(fileURL: specURL)
        #expect(savedSpec == loadedSpec)
        #expect(SpecParser.validate(savedSpec, repositoryRoot: workspaceURL).isValid)
        #expect(state.specFileURL == specURL.standardizedFileURL)
        #expect(state.freshnessState == .specLoaded)
    }

    @Test func saveAsUpdatesCurrentDocumentPath() throws {
        let defaults = makeIsolatedDefaults()
        let sourceWorkspaceURL = try makeTemporaryDirectory()
        let destinationWorkspaceURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: sourceWorkspaceURL)
            try? FileManager.default.removeItem(at: destinationWorkspaceURL)
        }

        try writeFile(
            at: sourceWorkspaceURL.appendingPathComponent("src/index.ts"),
            contents: "export const source = true\n"
        )
        try writeFile(
            at: destinationWorkspaceURL.appendingPathComponent("src/index.ts"),
            contents: "export const destination = true\n"
        )

        let sourceSpecURL = sourceWorkspaceURL.appendingPathComponent(".sightglass.yaml")
        try writeFixture("Specs/minimal-valid.yaml", to: sourceSpecURL)

        let state = AppState(userDefaults: defaults, launchArguments: [])
        state.loadSpec(from: sourceSpecURL, repositoryRoot: sourceWorkspaceURL)
        state.saveCurrentSpec(in: destinationWorkspaceURL)

        let destinationSpecURL = destinationWorkspaceURL.appendingPathComponent(".sightglass.yaml")
        #expect(state.specFileURL == destinationSpecURL.standardizedFileURL)
        #expect(state.currentRepoRoot == destinationWorkspaceURL.standardizedFileURL)
        #expect(FileManager.default.fileExists(atPath: destinationSpecURL.path))
    }

    @Test func recentFilesStayConsistentAfterSaveAndSaveAs() throws {
        let defaults = makeIsolatedDefaults()
        let sourceWorkspaceURL = try makeTemporaryDirectory()
        let destinationWorkspaceURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: sourceWorkspaceURL)
            try? FileManager.default.removeItem(at: destinationWorkspaceURL)
        }

        try writeFile(
            at: sourceWorkspaceURL.appendingPathComponent("src/index.ts"),
            contents: "export const source = true\n"
        )
        try writeFile(
            at: destinationWorkspaceURL.appendingPathComponent("src/index.ts"),
            contents: "export const destination = true\n"
        )

        let sourceSpecURL = sourceWorkspaceURL.appendingPathComponent(".sightglass.yaml")
        try writeFixture("Specs/minimal-valid.yaml", to: sourceSpecURL)

        let state = AppState(userDefaults: defaults, launchArguments: [])
        state.loadSpec(from: sourceSpecURL, repositoryRoot: sourceWorkspaceURL)
        state.saveCurrentSpec()

        #expect(state.recentSpecFiles.first?.url == sourceSpecURL.standardizedFileURL)
        #expect(state.recentFolders.first?.url == sourceWorkspaceURL.standardizedFileURL)

        state.saveCurrentSpec(in: destinationWorkspaceURL)

        let destinationSpecURL = destinationWorkspaceURL.appendingPathComponent(".sightglass.yaml")
        #expect(state.recentSpecFiles.first?.url == destinationSpecURL.standardizedFileURL)
        #expect(state.recentFolders.first?.url == destinationWorkspaceURL.standardizedFileURL)
        #expect(state.recentSpecFiles.contains(where: { $0.url == sourceSpecURL.standardizedFileURL }))
        #expect(state.recentFolders.contains(where: { $0.url == sourceWorkspaceURL.standardizedFileURL }))
    }

    @Test func saveAsRefreshesValidationAndPreservesViewerState() throws {
        let defaults = makeIsolatedDefaults()
        let sourceWorkspaceURL = try makeTemporaryDirectory()
        let destinationWorkspaceURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: sourceWorkspaceURL)
            try? FileManager.default.removeItem(at: destinationWorkspaceURL)
        }

        let sourceSpecURL = sourceWorkspaceURL.appendingPathComponent(".sightglass.yaml")
        try writeFixture("Specs/nonexistent-file-warning.yaml", to: sourceSpecURL)

        let state = AppState(userDefaults: defaults, launchArguments: [])
        state.loadSpec(from: sourceSpecURL, repositoryRoot: sourceWorkspaceURL)

        let spec = try #require(state.currentSpec)
        let selectedNodeID = try #require(spec.nodes.first?.id)
        state.selectNode(id: selectedNodeID)
        state.zoomLevel = 1.8

        #expect(state.freshnessState == .specLoadedWithWarnings)
        #expect(state.validationResult.warnings.contains(where: { $0.code == "missing_node_file" }))

        try writeFile(
            at: destinationWorkspaceURL.appendingPathComponent("src/routes/missing.ts"),
            contents: "export const recovered = true\n"
        )

        state.saveCurrentSpec(in: destinationWorkspaceURL)

        #expect(state.currentSpec == spec)
        #expect(state.selectedNodeID == selectedNodeID)
        #expect(state.zoomLevel == 1.8)
        #expect(state.specFileURL == destinationWorkspaceURL.appendingPathComponent(".sightglass.yaml").standardizedFileURL)
        #expect(state.currentRepoRoot == destinationWorkspaceURL.standardizedFileURL)
        #expect(state.validationResult.warnings.isEmpty)
        #expect(state.freshnessState == .specLoaded)
    }

    @Test func selectingFlowFocusesItsFirstStep() throws {
        let defaults = makeIsolatedDefaults()
        let specURL = FixtureLoader.fixtureURL("Specs/layered-rest-service.yaml")
        let repoURL = FixtureLoader.repoURL("Repos/express-api")
        let state = AppState(userDefaults: defaults, launchArguments: [])

        state.loadSpec(from: specURL, repositoryRoot: repoURL)
        let entryPointID = try #require(state.currentSpec?.entryPoints?.first?.id)
        state.activateEntryPoint(id: entryPointID)
        state.selectFlow(id: "user-login")

        #expect(state.selectedFlowID == "user-login")
        #expect(state.selectedNodeID == "auth-routes")
        #expect(state.activeEntryPointID == nil)
    }

    @Test func hidingVisibleLayerClearsSelectionButSelectingNodeRevealsItAgain() throws {
        let defaults = makeIsolatedDefaults()
        let specURL = FixtureLoader.fixtureURL("Specs/layered-rest-service.yaml")
        let repoURL = FixtureLoader.repoURL("Repos/express-api")
        let state = AppState(userDefaults: defaults, launchArguments: [])

        state.loadSpec(from: specURL, repositoryRoot: repoURL)
        let entryPointID = try #require(state.currentSpec?.entryPoints?.first?.id)
        state.activateEntryPoint(id: entryPointID)
        state.setLayerVisibility(false, for: "api")

        #expect(!state.visibleLayerIDs.contains("api"))
        #expect(state.selectedNodeID == nil)
        #expect(state.activeEntryPointID == nil)

        state.selectNode(id: "auth-routes")

        #expect(state.visibleLayerIDs.contains("api"))
        #expect(state.selectedNodeID == "auth-routes")
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "AppStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SightglassTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return url
    }

    private func writeFixture(_ fixturePath: String, to url: URL) throws {
        let contents = try FixtureLoader.loadString(at: fixturePath)
        try writeFile(at: url, contents: contents)
    }

    private func writeFile(at url: URL, contents: String) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try Data(contents.utf8).write(to: url)
    }
}
