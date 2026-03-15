import Foundation

/// Orchestrates running the analysis on a codebase.
///
/// In V1 this is a stub. The actual flow is:
/// 1. User points an AI agent (Claude, Codex) at their codebase with the analysis prompt
/// 2. Agent produces a YAML spec file
/// 3. User opens the spec file in Sightglass
///
/// Future versions may integrate directly with agent APIs.
struct SpecGenerator {
    /// The root directory of the codebase to analyze.
    let codebasePath: URL

    /// Generates the analysis prompt with codebase context.
    ///
    /// Returns the prompt text that should be sent to an AI agent.
    func generatePrompt() -> String {
        // TODO: Scan the codebase directory structure and inject context
        // into the prompt template (file tree, key file contents, etc.)
        let template = AnalysisPrompt.template()
        return template
    }

    /// Stub for future direct agent integration.
    ///
    /// Would call an AI agent API with the prompt and return the parsed spec.
    func analyze() async throws -> CodeSpec {
        // TODO: Implement direct agent API integration
        // For V1, users run the agent manually and load the resulting YAML file
        fatalError("Direct agent integration not implemented in V1. Use the prompt template with your preferred AI agent and load the resulting YAML file.")
    }
}
