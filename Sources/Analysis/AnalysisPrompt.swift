import Foundation

/// Provides the built-in analysis prompt template that instructs an AI agent
/// to analyze a codebase and produce a structured YAML spec.
struct AnalysisPrompt {
    /// Returns the analysis prompt template.
    ///
    /// The prompt instructs an AI agent to analyze a codebase and output
    /// YAML conforming to the Sightglass spec format.
    static func template() -> String {
        if let url = Bundle.module.url(forResource: "analyze-codebase", withExtension: "md", subdirectory: "prompts"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }

        if let url = Bundle.main.url(forResource: "analyze-codebase", withExtension: "md", subdirectory: "prompts"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }

        // Fallback inline prompt
        return Self.inlinePrompt
    }

    /// The inline fallback prompt template.
    static let inlinePrompt: String = """
    Analyze the codebase and produce a YAML architecture spec for Sightglass visualization.
    See the bundled analyze-codebase.md for the full prompt template.
    """
}
