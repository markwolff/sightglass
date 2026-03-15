// NOTE: These tests require Xcode (not just Command Line Tools) to run.
// Run with: xcodebuild test or open in Xcode.
// With Command Line Tools only, XCTest/Testing modules are not available.

import XCTest
@testable import Sightglass

final class SpecParserTests: XCTestCase {
    let sampleYAML = """
    name: test-app
    version: 1
    analyzed_at: 2024-01-15T10:30:00Z

    layers:
      - id: api
        name: API Layer
        color: "#4A90D9"
      - id: business
        name: Business Logic
        color: "#7B68EE"
      - id: data
        name: Data Access
        color: "#50C878"

    nodes:
      - id: auth-controller
        name: AuthController
        layer: api
        file: src/controllers/auth.ts
        description: "Handles login, signup, token refresh"

      - id: auth-service
        name: AuthService
        layer: business
        file: src/services/auth.ts
        description: "Authentication business logic"

      - id: user-repo
        name: UserRepository
        layer: data
        file: src/repos/user.ts
        description: "User database operations"

    edges:
      - from: auth-controller
        to: auth-service
        label: "credentials"
        data_type: "LoginRequest"

      - from: auth-service
        to: user-repo
        label: "findByEmail"
        data_type: "string -> User?"

    entry_points:
      - node: auth-controller
        type: http
        method: POST
        path: /api/auth/login
    """

    func testParseValidYAML() throws {
        let spec = try SpecParser.parse(yamlString: sampleYAML)

        XCTAssertEqual(spec.name, "test-app")
        XCTAssertEqual(spec.version, 1)
        XCTAssertEqual(spec.layers.count, 3)
        XCTAssertEqual(spec.nodes.count, 3)
        XCTAssertEqual(spec.edges.count, 2)
        XCTAssertEqual(spec.entryPoints?.count, 1)
    }

    func testParseLayers() throws {
        let spec = try SpecParser.parse(yamlString: sampleYAML)

        let apiLayer = spec.layers.first { $0.id == "api" }
        XCTAssertNotNil(apiLayer)
        XCTAssertEqual(apiLayer?.name, "API Layer")
        XCTAssertEqual(apiLayer?.color, "#4A90D9")
    }

    func testParseNodes() throws {
        let spec = try SpecParser.parse(yamlString: sampleYAML)

        let authController = spec.nodes.first { $0.id == "auth-controller" }
        XCTAssertNotNil(authController)
        XCTAssertEqual(authController?.name, "AuthController")
        XCTAssertEqual(authController?.layer, "api")
        XCTAssertEqual(authController?.file, "src/controllers/auth.ts")
    }

    func testParseEdges() throws {
        let spec = try SpecParser.parse(yamlString: sampleYAML)

        let firstEdge = spec.edges.first
        XCTAssertEqual(firstEdge?.from, "auth-controller")
        XCTAssertEqual(firstEdge?.to, "auth-service")
        XCTAssertEqual(firstEdge?.label, "credentials")
        XCTAssertEqual(firstEdge?.dataType, "LoginRequest")
    }

    func testParseEntryPoints() throws {
        let spec = try SpecParser.parse(yamlString: sampleYAML)

        let ep = spec.entryPoints?.first
        XCTAssertEqual(ep?.node, "auth-controller")
        XCTAssertEqual(ep?.type, "http")
        XCTAssertEqual(ep?.method, "POST")
        XCTAssertEqual(ep?.path, "/api/auth/login")
    }

    func testValidateValidSpec() throws {
        let spec = try SpecParser.parse(yamlString: sampleYAML)
        let warnings = SpecParser.validate(spec)
        XCTAssertTrue(warnings.isEmpty)
    }

    func testValidateInvalidLayerRef() throws {
        let yaml = """
        name: test
        version: 1
        layers:
          - id: api
            name: API
            color: "#000"
        nodes:
          - id: node1
            name: Node1
            layer: nonexistent
        edges: []
        """
        let spec = try SpecParser.parse(yamlString: yaml)
        let warnings = SpecParser.validate(spec)
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].contains("nonexistent"))
    }

    func testValidateInvalidEdgeRef() throws {
        let yaml = """
        name: test
        version: 1
        layers:
          - id: api
            name: API
            color: "#000"
        nodes:
          - id: node1
            name: Node1
            layer: api
        edges:
          - from: node1
            to: nonexistent
        """
        let spec = try SpecParser.parse(yamlString: yaml)
        let warnings = SpecParser.validate(spec)
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].contains("nonexistent"))
    }

    func testParseMinimalSpec() throws {
        let yaml = """
        name: minimal
        version: 1
        layers:
          - id: default
            name: Default
            color: "#999"
        nodes:
          - id: main
            name: Main
            layer: default
        edges: []
        """
        let spec = try SpecParser.parse(yamlString: yaml)
        XCTAssertEqual(spec.name, "minimal")
        XCTAssertNil(spec.analyzedAt)
        XCTAssertNil(spec.entryPoints)
        XCTAssertNil(spec.nodes[0].file)
        XCTAssertNil(spec.nodes[0].description)
    }
}
