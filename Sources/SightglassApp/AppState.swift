import SwiftUI
import Combine
import SightglassCore

class AppState: ObservableObject {
    // MARK: - Published State

    /// The currently loaded code spec
    @Published var currentSpec: CodeSpec?

    /// The currently selected node in the diagram
    @Published var selectedNode: SpecNode?

    /// Whether the file picker is shown
    @Published var showFilePicker: Bool = false

    /// Error message to display, if any
    @Published var errorMessage: String?

    /// Structured validation output for the loaded spec.
    @Published var validationResult = ValidationResult()

    /// Current zoom level for the diagram
    @Published var zoomLevel: CGFloat = 1.0

    /// Current pan offset for the diagram
    @Published var panOffset: CGSize = .zero

    /// Layout positions computed by GraphLayout
    @Published var nodePositions: [String: CGPoint] = [:]

    /// The URL of the currently loaded spec file
    @Published var specFileURL: URL?

    // MARK: - Loading

    /// Loads a spec from the given file URL.
    func loadSpec(from url: URL) {
        do {
            let spec = try SpecParser.parse(fileURL: url)
            let validation = SpecParser.validate(spec, repositoryRoot: url.deletingLastPathComponent())

            guard validation.isValid else {
                self.currentSpec = nil
                self.specFileURL = url
                self.selectedNode = nil
                self.nodePositions = [:]
                self.validationResult = validation
                self.errorMessage = validation.summary
                return
            }

            self.currentSpec = spec
            self.specFileURL = url
            self.selectedNode = nil
            self.validationResult = validation
            self.errorMessage = validation.warnings.isEmpty ? nil : validation.summary
            computeLayout(for: spec)
        } catch {
            self.errorMessage = "Failed to load spec: \(error.localizedDescription)"
        }
    }

    // MARK: - Layout

    /// Computes node positions using the graph layout algorithm.
    func computeLayout(for spec: CodeSpec) {
        let layout = GraphLayout(spec: spec)
        self.nodePositions = layout.computePositions()
    }

    // MARK: - Selection

    /// Selects a node by ID.
    func selectNode(id: String) {
        selectedNode = currentSpec?.nodes.first(where: { $0.id == id })
    }

    /// Clears the current selection.
    func clearSelection() {
        selectedNode = nil
    }

    // MARK: - Zoom & Pan

    /// Resets zoom and pan to default values.
    func resetView() {
        zoomLevel = 1.0
        panOffset = .zero
    }
}
