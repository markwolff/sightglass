import Foundation
import Testing
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

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "AppStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
