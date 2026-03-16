import SwiftUI
import Combine
import Foundation
import SightglassCore

@MainActor
public final class AppState: ObservableObject {
    public enum LayoutAlgorithm: String, CaseIterable, Codable {
        case hybridLayered
        case forceDirected

        var displayName: String {
            switch self {
            case .hybridLayered:
                return "Hybrid Layered"
            case .forceDirected:
                return "Force Directed"
            }
        }
    }

    public enum FreshnessState: String, Codable {
        case noRepository
        case repoContextOnly
        case specLoaded
        case specLoadedWithWarnings
        case validationBlocked
        case loadFailed

        var title: String {
            switch self {
            case .noRepository:
                return "No Repository"
            case .repoContextOnly:
                return "Repo Context"
            case .specLoaded:
                return "Spec Loaded"
            case .specLoadedWithWarnings:
                return "Warnings Present"
            case .validationBlocked:
                return "Validation Blocked"
            case .loadFailed:
                return "Load Failed"
            }
        }

        var systemImage: String {
            switch self {
            case .noRepository:
                return "tray"
            case .repoContextOnly:
                return "folder"
            case .specLoaded:
                return "checkmark.circle"
            case .specLoadedWithWarnings:
                return "exclamationmark.triangle"
            case .validationBlocked, .loadFailed:
                return "xmark.octagon"
            }
        }

        var isProblem: Bool {
            switch self {
            case .specLoaded, .repoContextOnly, .noRepository:
                return false
            case .specLoadedWithWarnings, .validationBlocked, .loadFailed:
                return true
            }
        }
    }

    public struct RecentLocation: Identifiable, Hashable {
        public enum Kind: String, Codable {
            case specFile
            case folder
        }

        public let url: URL
        public let kind: Kind

        public var id: String {
            url.standardizedFileURL.path
        }

        public var displayName: String {
            let lastComponent = url.lastPathComponent
            if lastComponent.isEmpty {
                return url.path
            }
            return lastComponent
        }

        public var subtitle: String {
            url.path
        }
    }

    public struct RepositoryContext: Equatable {
        public let rootURL: URL
        public let sourceFileCount: Int
        public let detectedLanguage: String?
        public let detectedFramework: String?
        public let discoveredSpecURL: URL?

        public var displayName: String {
            let name = rootURL.lastPathComponent
            return name.isEmpty ? rootURL.path : name
        }
    }

    private enum RecentStorageKey {
        static let specFiles = "recentSpecFiles"
        static let folders = "recentFolders"
    }

    private enum SaveError: LocalizedError {
        case noSpecLoaded
        case invalidSpec(ValidationResult)

        var errorDescription: String? {
            switch self {
            case .noSpecLoaded:
                return "Load or generate a spec before saving."
            case .invalidSpec:
                return "The current spec has blocking validation errors and cannot be saved."
            }
        }
    }

    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let maxRecentLocations = 8

    // MARK: - Published State

    /// The currently loaded code spec.
    @Published var currentSpec: CodeSpec?

    /// The selected node identifier.
    @Published var selectedNodeID: String?

    /// The hovered node identifier.
    @Published var hoveredNodeID: String?

    /// Whether the file picker is shown.
    @Published var showFilePicker = false

    /// Whether the folder picker is shown.
    @Published var showFolderPicker = false

    /// Whether the save destination picker is shown.
    @Published var showSaveLocationPicker = false

    /// Whether the export panel should be shown.
    @Published var showExportPanel = false

    /// Error message to display, if any.
    @Published var errorMessage: String?

    /// Structured validation output for the loaded spec.
    @Published var validationResult = ValidationResult()

    /// Current zoom level for the diagram.
    @Published var zoomLevel: CGFloat = 1.0

    /// Current pan offset for the diagram.
    @Published var panOffset: CGSize = .zero

    /// Layout positions computed by GraphLayout.
    @Published var nodePositions: [String: CGPoint] = [:]

    /// The URL of the currently loaded spec file.
    @Published var specFileURL: URL?

    /// The currently selected repo root.
    @Published var currentRepoRoot: URL?

    /// Which layers are currently visible.
    @Published var visibleLayerIDs: Set<String> = []

    /// Free-text search query for the sidebar and viewer chrome.
    @Published var searchQuery = ""

    /// The selected flow identifier.
    @Published var selectedFlowID: String?

    /// The active entry point identifier.
    @Published var activeEntryPointID: String?

    /// The currently selected layout algorithm.
    @Published var layoutAlgorithm: LayoutAlgorithm = .hybridLayered

    /// The current freshness state for the workspace.
    @Published var freshnessState: FreshnessState = .noRepository

    /// Lightweight repository context shown before a spec exists.
    @Published private(set) var repositoryContext: RepositoryContext?

    /// Recently opened spec files.
    @Published private(set) var recentSpecFiles: [RecentLocation]

    /// Recently opened folders.
    @Published private(set) var recentFolders: [RecentLocation]

    public var canSave: Bool {
        currentSpec != nil
    }

    public var selectedNode: SpecNode? {
        guard let selectedNodeID else { return nil }
        return currentSpec?.nodes.first(where: { $0.id == selectedNodeID })
    }

    public var selectedFlow: SpecFlow? {
        guard let selectedFlowID else { return nil }
        return currentSpec?.flows?.first(where: { $0.id == selectedFlowID })
    }

    public var activeEntryPoint: EntryPoint? {
        guard let activeEntryPointID else { return nil }
        return currentSpec?.entryPoints?.first(where: { $0.id == activeEntryPointID })
    }

    public init(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        launchArguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        self.recentSpecFiles = Self.restoreRecentLocations(
            forKey: RecentStorageKey.specFiles,
            kind: .specFile,
            userDefaults: userDefaults,
            fileManager: fileManager
        )
        self.recentFolders = Self.restoreRecentLocations(
            forKey: RecentStorageKey.folders,
            kind: .folder,
            userDefaults: userDefaults,
            fileManager: fileManager
        )
        handleLaunchArguments(launchArguments)
    }

    // MARK: - Loading

    public func presentFilePicker() {
        showFilePicker = true
    }

    public func presentFolderPicker() {
        showFolderPicker = true
    }

    public func presentSaveAsPicker() {
        guard canSave else {
            errorMessage = SaveError.noSpecLoaded.localizedDescription
            return
        }

        showSaveLocationPicker = true
    }

    public func saveCurrentSpec() {
        guard let currentSpec else {
            errorMessage = SaveError.noSpecLoaded.localizedDescription
            return
        }

        guard let specFileURL else {
            presentSaveAsPicker()
            return
        }

        let repositoryRoot = (currentRepoRoot ?? specFileURL.deletingLastPathComponent()).standardizedFileURL

        do {
            try persist(
                spec: currentSpec,
                to: specFileURL,
                repositoryRoot: repositoryRoot,
                accessScopeURLs: [specFileURL, repositoryRoot]
            )
        } catch {
            errorMessage = "Failed to save spec: \(error.localizedDescription)"
        }
    }

    public func saveCurrentSpec(in directoryURL: URL) {
        guard let currentSpec else {
            errorMessage = SaveError.noSpecLoaded.localizedDescription
            return
        }

        let standardizedDirectoryURL = directoryURL.standardizedFileURL
        let destinationURL = standardizedDirectoryURL.appendingPathComponent(".sightglass.yaml", isDirectory: false)

        do {
            try persist(
                spec: currentSpec,
                to: destinationURL,
                repositoryRoot: standardizedDirectoryURL,
                accessScopeURLs: [standardizedDirectoryURL]
            )
        } catch {
            errorMessage = "Failed to save spec: \(error.localizedDescription)"
        }
    }

    func canOpen(url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL
        return isDirectory(standardizedURL) || isSupportedSpecFile(standardizedURL)
    }

    func open(url: URL) {
        let standardizedURL = url.standardizedFileURL

        if isDirectory(standardizedURL) {
            openFolder(standardizedURL)
            return
        }

        guard isSupportedSpecFile(standardizedURL) else {
            errorMessage = "Sightglass can only open folders or YAML spec files."
            freshnessState = .loadFailed
            return
        }

        loadSpec(from: standardizedURL)
    }

    /// Loads a spec from the given file URL.
    func loadSpec(from url: URL, repositoryRoot: URL? = nil) {
        let standardizedURL = url.standardizedFileURL
        let resolvedRepoRoot = (repositoryRoot ?? currentRepoRoot ?? standardizedURL.deletingLastPathComponent())
            .standardizedFileURL

        currentRepoRoot = resolvedRepoRoot
        specFileURL = standardizedURL
        repositoryContext = inspectRepository(at: resolvedRepoRoot)
        registerRecentLocation(standardizedURL, kind: .specFile)
        registerRecentLocation(resolvedRepoRoot, kind: .folder)

        do {
            let spec = try SpecParser.parse(fileURL: standardizedURL)
            let validation = SpecParser.validate(spec, repositoryRoot: resolvedRepoRoot)

            validationResult = validation
            errorMessage = nil

            resetViewerSelectionState()

            guard validation.isValid else {
                currentSpec = nil
                nodePositions = [:]
                visibleLayerIDs = []
                freshnessState = .validationBlocked
                return
            }

            currentSpec = spec
            visibleLayerIDs = Set(spec.layers.map(\.id))
            freshnessState = validation.warnings.isEmpty ? .specLoaded : .specLoadedWithWarnings
            computeLayout(for: spec)
        } catch {
            currentSpec = nil
            validationResult = ValidationResult()
            nodePositions = [:]
            errorMessage = "Failed to load spec: \(error.localizedDescription)"
            freshnessState = .loadFailed
        }
    }

    func openFolder(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        currentRepoRoot = standardizedURL
        repositoryContext = inspectRepository(at: standardizedURL)
        specFileURL = repositoryContext?.discoveredSpecURL
        errorMessage = nil
        validationResult = ValidationResult()
        registerRecentLocation(standardizedURL, kind: .folder)
        resetViewerSelectionState()

        if let discoveredSpecURL = repositoryContext?.discoveredSpecURL {
            loadSpec(from: discoveredSpecURL, repositoryRoot: standardizedURL)
            return
        }

        currentSpec = nil
        nodePositions = [:]
        visibleLayerIDs = []
        freshnessState = .repoContextOnly
    }

    func openRecent(_ location: RecentLocation) {
        open(url: location.url)
    }

    func showAllLayers() {
        guard let currentSpec else {
            visibleLayerIDs = []
            return
        }

        visibleLayerIDs = Set(currentSpec.layers.map(\.id))
    }

    func hideAllLayers() {
        visibleLayerIDs.removeAll()
        reconcileSelectionWithVisibleLayers()
    }

    func setLayerVisibility(_ isVisible: Bool, for layerID: String) {
        if isVisible {
            visibleLayerIDs.insert(layerID)
        } else {
            visibleLayerIDs.remove(layerID)
        }

        reconcileSelectionWithVisibleLayers()
    }

    // MARK: - Layout

    /// Computes node positions using the active graph layout algorithm.
    func computeLayout(for spec: CodeSpec) {
        var layout = GraphLayout(spec: spec)
        switch layoutAlgorithm {
        case .hybridLayered:
            layout.algorithm = .hybridLayered
        case .forceDirected:
            layout.algorithm = .forceDirected
        }
        nodePositions = layout.computePositions()
    }

    // MARK: - Selection

    /// Selects a node by ID.
    func selectNode(id: String) {
        revealLayerIfNeeded(forNodeID: id)
        selectedNodeID = id
    }

    func selectFlow(id: String?) {
        selectedFlowID = id

        guard let id, let flow = currentSpec?.flows?.first(where: { $0.id == id }) else {
            return
        }

        activeEntryPointID = nil

        let orderedSteps = flow.steps.sorted { $0.sequence < $1.sequence }
        if let firstNodeID = orderedSteps.first?.from ?? orderedSteps.first?.to {
            selectNode(id: firstNodeID)
        }
    }

    /// Marks an entry point as the active navigation focus.
    func activateEntryPoint(id: String) {
        activeEntryPointID = id
        selectedFlowID = nil
        if let nodeID = currentSpec?.entryPoints?.first(where: { $0.id == id })?.node {
            selectNode(id: nodeID)
        }
    }

    /// Clears the current selection.
    func clearSelection() {
        selectedNodeID = nil
    }

    // MARK: - Zoom & Pan

    /// Resets zoom and pan to default values.
    func resetView() {
        zoomLevel = 1.0
        panOffset = .zero
    }

    /// Fits the diagram so all visible nodes fill the given canvas size.
    func fitToScreen(canvasSize: CGSize = CGSize(width: 800, height: 600)) {
        guard !nodePositions.isEmpty else { return }

        let allX = nodePositions.values.map(\.x)
        let allY = nodePositions.values.map(\.y)

        let minX = allX.min()! - 100
        let maxX = allX.max()! + 100
        let minY = allY.min()! - 50
        let maxY = allY.max()! + 50

        let contentWidth = maxX - minX
        let contentHeight = maxY - minY

        guard contentWidth > 0, contentHeight > 0 else { return }

        let scaleX = canvasSize.width / contentWidth
        let scaleY = canvasSize.height / contentHeight
        let newZoom = min(scaleX, scaleY, 5.0)

        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        zoomLevel = max(0.1, newZoom)
        panOffset = CGSize(
            width: canvasSize.width / 2 - centerX * zoomLevel,
            height: canvasSize.height / 2 - centerY * zoomLevel
        )
    }

    /// Requests an export action.
    func requestExport() {
        guard currentSpec != nil else { return }
        showExportPanel = true
    }

    // MARK: - Internal Helpers

    private func handleLaunchArguments(_ arguments: [String]) {
        let candidateArguments: ArraySlice<String>
        if arguments.count > 1 {
            candidateArguments = arguments.dropFirst()
        } else {
            candidateArguments = arguments[...]
        }

        for argument in candidateArguments where !argument.hasPrefix("-") {
            let candidateURL = URL(fileURLWithPath: argument)
            guard fileManager.fileExists(atPath: candidateURL.path) else {
                continue
            }

            open(url: candidateURL)
            break
        }
    }

    private func resetViewerSelectionState() {
        selectedNodeID = nil
        hoveredNodeID = nil
        searchQuery = ""
        selectedFlowID = nil
        activeEntryPointID = nil
        resetView()
    }

    private func revealLayerIfNeeded(forNodeID nodeID: String) {
        guard let layerID = currentSpec?.nodes.first(where: { $0.id == nodeID })?.layer else {
            return
        }

        visibleLayerIDs.insert(layerID)
    }

    private func reconcileSelectionWithVisibleLayers() {
        if let selectedNode, !visibleLayerIDs.contains(selectedNode.layer) {
            selectedNodeID = nil
        }

        if
            let activeEntryPointID,
            let nodeID = currentSpec?.entryPoints?.first(where: { $0.id == activeEntryPointID })?.node,
            let layerID = currentSpec?.nodes.first(where: { $0.id == nodeID })?.layer,
            !visibleLayerIDs.contains(layerID)
        {
            self.activeEntryPointID = nil
        }
    }

    private func inspectRepository(at rootURL: URL) -> RepositoryContext {
        let standardizedURL = rootURL.standardizedFileURL
        let sourceFileCount = countSourceFiles(in: standardizedURL)
        let detectedLanguage = detectLanguage(in: standardizedURL)
        let detectedFramework = detectFramework(in: standardizedURL, detectedLanguage: detectedLanguage)
        let discoveredSpecURL = discoverSpecFile(in: standardizedURL)

        return RepositoryContext(
            rootURL: standardizedURL,
            sourceFileCount: sourceFileCount,
            detectedLanguage: detectedLanguage,
            detectedFramework: detectedFramework,
            discoveredSpecURL: discoveredSpecURL
        )
    }

    private func countSourceFiles(in rootURL: URL) -> Int {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        let ignoredDirectories = Set([".build", ".git", "DerivedData", "node_modules"])
        var count = 0

        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            if ignoredDirectories.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            guard
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                values.isRegularFile == true
            else {
                continue
            }

            count += 1
        }

        return count
    }

    private func detectLanguage(in rootURL: URL) -> String? {
        if fileManager.fileExists(atPath: rootURL.appendingPathComponent("Package.swift").path) {
            return "Swift"
        }

        if fileManager.fileExists(atPath: rootURL.appendingPathComponent("package.json").path) {
            return containsFileExtension("ts", under: rootURL) ? "TypeScript" : "JavaScript"
        }

        if fileManager.fileExists(atPath: rootURL.appendingPathComponent("pyproject.toml").path)
            || containsFileExtension("py", under: rootURL) {
            return "Python"
        }

        if fileManager.fileExists(atPath: rootURL.appendingPathComponent("Gemfile").path)
            || containsFileExtension("rb", under: rootURL) {
            return "Ruby"
        }

        return nil
    }

    private func detectFramework(in rootURL: URL, detectedLanguage: String?) -> String? {
        if fileManager.fileExists(atPath: rootURL.appendingPathComponent("Package.swift").path) {
            return "Swift Package"
        }

        if fileManager.fileExists(atPath: rootURL.appendingPathComponent("package.json").path) {
            if fileManager.fileExists(atPath: rootURL.appendingPathComponent("src/routes").path) {
                return "Express-style API"
            }
            return detectedLanguage == "TypeScript" ? "Node Service" : "Node App"
        }

        if fileManager.fileExists(atPath: rootURL.appendingPathComponent("manage.py").path) {
            return "Django"
        }

        if containsFileExtension("py", under: rootURL) {
            return "Python Service"
        }

        return nil
    }

    private func containsFileExtension(_ fileExtension: String, under rootURL: URL) -> Bool {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        let ignoredDirectories = Set([".build", ".git", "DerivedData", "node_modules"])

        for case let fileURL as URL in enumerator {
            if ignoredDirectories.contains(fileURL.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }

            if fileURL.pathExtension.lowercased() == fileExtension.lowercased() {
                return true
            }
        }

        return false
    }

    private func discoverSpecFile(in rootURL: URL) -> URL? {
        let candidates = [
            ".sightglass.yaml",
            ".sightglass.yml",
            "sightglass.yaml",
            "sightglass.yml",
        ]

        for candidate in candidates {
            let candidateURL = rootURL.appendingPathComponent(candidate)
            if fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        return nil
    }

    private func isDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) else {
            return false
        }
        return values.isDirectory == true
    }

    private func isSupportedSpecFile(_ url: URL) -> Bool {
        let filename = url.lastPathComponent.lowercased()
        let fileExtension = url.pathExtension.lowercased()
        return filename == ".sightglass.yaml"
            || filename == ".sightglass.yml"
            || fileExtension == "yaml"
            || fileExtension == "yml"
    }

    private func persist(
        spec: CodeSpec,
        to destinationURL: URL,
        repositoryRoot: URL,
        accessScopeURLs: [URL]
    ) throws {
        let standardizedDestinationURL = destinationURL.standardizedFileURL
        let standardizedRepositoryRoot = repositoryRoot.standardizedFileURL
        let validation = SpecParser.validate(spec, repositoryRoot: standardizedRepositoryRoot)

        validationResult = validation

        guard validation.isValid else {
            freshnessState = .validationBlocked
            throw SaveError.invalidSpec(validation)
        }

        let yaml = try SpecParser.encode(spec)
        let data = Data(yaml.utf8)

        try withSecurityScopedAccess(to: accessScopeURLs.map(\.standardizedFileURL)) {
            try fileManager.createDirectory(
                at: standardizedDestinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: standardizedDestinationURL, options: [.atomic])
        }

        specFileURL = standardizedDestinationURL
        currentRepoRoot = standardizedRepositoryRoot
        repositoryContext = inspectRepository(at: standardizedRepositoryRoot)
        errorMessage = nil
        registerRecentLocation(standardizedDestinationURL, kind: .specFile)
        registerRecentLocation(standardizedRepositoryRoot, kind: .folder)
        freshnessState = validation.warnings.isEmpty ? .specLoaded : .specLoadedWithWarnings
    }

    private func withSecurityScopedAccess<T>(to urls: [URL], operation: () throws -> T) throws -> T {
        let accessResults = urls.reduce(into: [(url: URL, accessed: Bool)]()) { result, url in
            guard !result.contains(where: { $0.url == url }) else {
                return
            }
            result.append((url: url, accessed: url.startAccessingSecurityScopedResource()))
        }

        defer {
            for result in accessResults.reversed() where result.accessed {
                result.url.stopAccessingSecurityScopedResource()
            }
        }

        return try operation()
    }

    private func registerRecentLocation(_ url: URL, kind: RecentLocation.Kind) {
        let location = RecentLocation(url: url.standardizedFileURL, kind: kind)

        switch kind {
        case .specFile:
            recentSpecFiles = deduplicatedRecents(byPrepending: location, to: recentSpecFiles)
            persistRecentLocations(recentSpecFiles, forKey: RecentStorageKey.specFiles)
        case .folder:
            recentFolders = deduplicatedRecents(byPrepending: location, to: recentFolders)
            persistRecentLocations(recentFolders, forKey: RecentStorageKey.folders)
        }
    }

    private func deduplicatedRecents(
        byPrepending location: RecentLocation,
        to existing: [RecentLocation]
    ) -> [RecentLocation] {
        let filtered = existing.filter { $0.id != location.id }
        return Array(([location] + filtered).prefix(maxRecentLocations))
    }

    private func persistRecentLocations(_ locations: [RecentLocation], forKey key: String) {
        let paths = locations.map { $0.url.standardizedFileURL.path }
        userDefaults.set(paths, forKey: key)
    }

    private static func restoreRecentLocations(
        forKey key: String,
        kind: RecentLocation.Kind,
        userDefaults: UserDefaults,
        fileManager: FileManager
    ) -> [RecentLocation] {
        let storedPaths = userDefaults.stringArray(forKey: key) ?? []

        return storedPaths.compactMap { path in
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard fileManager.fileExists(atPath: url.path) else {
                return nil
            }
            return RecentLocation(url: url, kind: kind)
        }
    }
}
