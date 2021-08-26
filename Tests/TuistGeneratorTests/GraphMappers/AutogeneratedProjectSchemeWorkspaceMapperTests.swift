import Foundation
import TSCBasic
import TuistCore
import TuistGraph
import TuistGraphTesting
import XCTest

@testable import TuistGenerator
@testable import TuistSupportTesting

final class AutogeneratedProjectSchemeWorkspaceMapperTests: TuistUnitTestCase {
    func test_map() throws {
        // Given
        let subject = AutogeneratedProjectSchemeWorkspaceMapper(codeCoverageMode: nil)
        let targetA = Target.test(
            name: "A"
        )
        let targetATests = Target.test(
            name: "ATests",
            product: .unitTests,
            dependencies: [.target(name: "A")]
        )

        let projectPath = try temporaryPath()
        let project = Project.test(
            path: projectPath,
            targets: [
                targetA,
                targetATests,
            ]
        )

        let targetB = Target.test(
            name: "B"
        )
        let targetBTests = Target.test(
            name: "BTests",
            product: .unitTests,
            dependencies: [.target(name: "B")]
        )

        let projectBPath = try temporaryPath().appending(component: "ProjectB")
        let projectB = Project.test(
            path: projectBPath,
            targets: [
                targetB,
                targetBTests,
            ]
        )

        let workspace = Workspace.test(
            name: "A",
            projects: [
                project.path,
                projectB.path,
            ]
        )

        // When
        let (got, sideEffects) = try subject.map(
            workspace: WorkspaceWithProjects(workspace: workspace, projects: [project, projectB])
        )

        // Then
        XCTAssertEmpty(sideEffects)
        let schemes = got.workspace.schemes

        XCTAssertEqual(schemes.count, 1)
        let scheme = try XCTUnwrap(schemes.first)
        XCTAssertTrue(scheme.shared)
        XCTAssertEqual(scheme.name, "A-Project")
        XCTAssertEqual(
            Set(scheme.buildAction.map(\.targets) ?? []),
            Set([
                TargetReference(
                    projectPath: projectBPath,
                    name: targetB.name
                ),
                TargetReference(
                    projectPath: projectPath,
                    name: targetA.name
                ),
                TargetReference(
                    projectPath: projectPath,
                    name: targetATests.name
                ),
                TargetReference(
                    projectPath: projectBPath,
                    name: targetBTests.name
                ),
            ])
        )
        XCTAssertEqual(
            Set(scheme.testAction.map(\.targets) ?? []),
            Set([
                TestableTarget(
                    target: TargetReference(
                        projectPath: projectPath,
                        name: targetATests.name
                    )
                ),
                TestableTarget(
                    target: TargetReference(
                        projectPath: projectBPath,
                        name: targetBTests.name
                    )
                ),
            ])
        )
        XCTAssertFalse(try XCTUnwrap(scheme.testAction?.coverage))
    }

    func test_multiple_project_sorting() throws {
        // Given
        let subject = AutogeneratedProjectSchemeWorkspaceMapper(codeCoverageMode: .all)
        let targetA = Target.test(name: "A")
        let targetB = Target.test(name: "B")
        let targetC = Target.test(name: "C")

        let projectB = Project.test(
            path: try temporaryPath(),
            name: "ProjectB",
            targets: [
                targetB,
            ]
        )

        let projectA = Project.test(
            path: try temporaryPath(),
            name: "ProjectA",
            targets: [
                targetA,
                targetC,
            ]
        )

        let workspace = Workspace.test()

        // When
        let (got, _) = try subject.map(
            workspace: WorkspaceWithProjects(workspace: workspace, projects: [projectB, projectA])
        )

        // Then
        let scheme = try XCTUnwrap(got.workspace.schemes.first)
        let targetsNames = scheme.buildAction?.targets.map { $0.name }
        XCTAssertEqual(targetsNames, ["A", "B", "C"])
    }

    func test_map_when_multiple_platforms() throws {
        // Given
        let subject = AutogeneratedProjectSchemeWorkspaceMapper(codeCoverageMode: nil)
        let targetA = Target.test(
            name: "A",
            platform: .iOS
        )
        let targetATests = Target.test(
            name: "ATests",
            platform: .iOS,
            product: .unitTests,
            dependencies: [.target(name: "A")]
        )

        let projectPath = try temporaryPath()
        let project = Project.test(
            path: projectPath,
            targets: [
                targetA,
                targetATests,
            ]
        )

        let targetB = Target.test(
            name: "B",
            platform: .macOS
        )
        let targetBTests = Target.test(
            name: "BTests",
            platform: .macOS,
            product: .unitTests,
            dependencies: [.target(name: "B")]
        )

        let projectBPath = try temporaryPath().appending(component: "ProjectB")
        let projectB = Project.test(
            path: projectBPath,
            targets: [
                targetB,
                targetBTests,
            ]
        )

        let workspace = Workspace.test(
            name: "A",
            projects: [
                project.path,
                projectB.path,
            ]
        )

        // When
        let (got, sideEffects) = try subject.map(
            workspace: WorkspaceWithProjects(workspace: workspace, projects: [project, projectB])
        )

        // Then
        XCTAssertEmpty(sideEffects)
        let schemes = got.workspace.schemes

        XCTAssertEqual(schemes.count, 2)
        XCTAssertEqual(
            Set(schemes.map(\.name)),
            Set([
                "A-Project-iOS",
                "A-Project-macOS",
            ])
        )
        let iosScheme = try XCTUnwrap(schemes.first(where: { $0.name == "A-Project-iOS" }))
        let macOSScheme = try XCTUnwrap(schemes.first(where: { $0.name == "A-Project-macOS" }))
        XCTAssertEqual(
            iosScheme.buildAction.map(\.targets) ?? [],
            [
                TargetReference(
                    projectPath: projectPath,
                    name: targetA.name
                ),
                TargetReference(
                    projectPath: projectPath,
                    name: targetATests.name
                ),
            ]
        )
        XCTAssertEqual(
            macOSScheme.buildAction.map(\.targets) ?? [],
            [
                TargetReference(
                    projectPath: projectBPath,
                    name: targetB.name
                ),
                TargetReference(
                    projectPath: projectBPath,
                    name: targetBTests.name
                ),
            ]
        )

        XCTAssertEqual(
            iosScheme.testAction.map(\.targets) ?? [],
            [
                TestableTarget(
                    target: TargetReference(
                        projectPath: projectPath,
                        name: targetATests.name
                    )
                ),
            ]
        )
        XCTAssertEqual(
            macOSScheme.testAction.map(\.targets) ?? [],
            [
                TestableTarget(
                    target: TargetReference(
                        projectPath: projectBPath,
                        name: targetBTests.name
                    )
                ),
            ]
        )
    }

    func test_map_codeCoverage_nil() throws {
        // Given
        let subject = AutogeneratedProjectSchemeWorkspaceMapper(codeCoverageMode: nil)
        let targetA = Target.test(
            name: "A"
        )
        let targetATests = Target.test(
            name: "ATests",
            product: .unitTests,
            dependencies: [.target(name: "A")]
        )

        let projectPath = try temporaryPath()
        let project = Project.test(
            path: projectPath,
            targets: [
                targetA,
                targetATests,
            ]
        )

        let workspace = Workspace.test(
            name: "A",
            projects: [
                project.path,
            ]
        )

        // When
        let (got, _) = try subject.map(
            workspace: WorkspaceWithProjects(workspace: workspace, projects: [project])
        )

        // Then
        let scheme = try XCTUnwrap(got.workspace.schemes.first)
        XCTAssertFalse(try XCTUnwrap(scheme.testAction?.coverage))
    }

    func test_map_codeCoverageMode_all() throws {
        // Given
        let subject = AutogeneratedProjectSchemeWorkspaceMapper(codeCoverageMode: .all)
        let targetA = Target.test(
            name: "A"
        )
        let targetATests = Target.test(
            name: "ATests",
            product: .unitTests,
            dependencies: [.target(name: "A")]
        )

        let projectPath = try temporaryPath()
        let project = Project.test(
            path: projectPath,
            targets: [
                targetA,
                targetATests,
            ]
        )

        let workspace = Workspace.test(
            name: "A",
            projects: [
                project.path,
            ]
        )

        // When
        let (got, _) = try subject.map(
            workspace: WorkspaceWithProjects(workspace: workspace, projects: [project])
        )

        // Then
        let scheme = try XCTUnwrap(got.workspace.schemes.first)
        XCTAssertTrue(try XCTUnwrap(scheme.testAction?.coverage))
    }

    func test_map_codeCoverageMode_targets() throws {
        // Given
        let targetA = Target.test(
            name: "A"
        )
        let targetB = Target.test(
            name: "B"
        )
        let targetATests = Target.test(
            name: "ATests",
            product: .unitTests,
            dependencies: [.target(name: "A")]
        )

        let projectPath = try temporaryPath()
        let project = Project.test(
            path: projectPath,
            targets: [
                targetA,
                targetB,
                targetATests,
            ]
        )

        let workspace = Workspace.test(
            name: "A",
            projects: [
                project.path,
            ]
        )

        let targetBRef = TargetReference(projectPath: projectPath, name: "B")
        let subject = AutogeneratedProjectSchemeWorkspaceMapper(codeCoverageMode: .targets([targetBRef]))

        // When
        let (got, _) = try subject.map(
            workspace: WorkspaceWithProjects(workspace: workspace, projects: [project])
        )

        // Then
        let scheme = try XCTUnwrap(got.workspace.schemes.first)
        let testAction = try XCTUnwrap(scheme.testAction)

        XCTAssertTrue(testAction.coverage)
        XCTAssertEqual(testAction.codeCoverageTargets, [targetBRef])
    }

    func test_map_codeCoverageMode_relevant_nonEmpty() throws {
        // Given
        let targetA = Target.test(
            name: "A"
        )
        let targetB = Target.test(
            name: "B"
        )
        let targetATests = Target.test(
            name: "ATests",
            product: .unitTests,
            dependencies: [.target(name: "A")]
        )

        let projectPath = try temporaryPath()
        let targetBRef = TargetReference(projectPath: projectPath, name: "B")
        let project = Project.test(
            path: projectPath,
            targets: [
                targetA,
                targetB,
                targetATests,
            ],
            schemes: [
                Scheme.test(
                    name: "B",
                    testAction: TestAction.test(
                        coverage: true,
                        codeCoverageTargets: [targetBRef]
                    )
                ),
            ]
        )

        let workspace = Workspace.test(
            name: "A",
            projects: [
                project.path,
            ]
        )

        let subject = AutogeneratedProjectSchemeWorkspaceMapper(codeCoverageMode: .relevant)

        // When
        let (got, _) = try subject.map(
            workspace: WorkspaceWithProjects(workspace: workspace, projects: [project])
        )

        // Then
        let scheme = try XCTUnwrap(got.workspace.schemes.first)
        let testAction = try XCTUnwrap(scheme.testAction)

        XCTAssertTrue(testAction.coverage)
        XCTAssertEqual(testAction.codeCoverageTargets, [targetBRef])
    }

    func test_map_codeCoverageMode_relevant_complex() throws {
        // Given
        let targetA = Target.test(
            name: "A"
        )
        let targetB = Target.test(
            name: "B"
        )
        let targetATests = Target.test(
            name: "ATests",
            product: .unitTests,
            dependencies: [.target(name: "A")]
        )

        let projectAPath = try temporaryPath()
        let targetBRef = TargetReference(projectPath: projectAPath, name: "B")
        let projectSingleCoverage = Project.test(
            path: projectAPath,
            targets: [
                targetA,
                targetB,
                targetATests,
            ],
            schemes: [
                Scheme.test(
                    name: "B",
                    testAction: TestAction.test(
                        coverage: true,
                        codeCoverageTargets: [targetBRef]
                    )
                ),
            ]
        )

        let projectBPath = try temporaryPath()
        let targetCRef = TargetReference(projectPath: projectBPath, name: "C")
        let targetDRef = TargetReference(projectPath: projectBPath, name: "D")
        let projectAllCoverage = Project.test(
            path: projectBPath,
            targets: [
                Target.test(name: "C"),
                Target.test(name: "D"),
            ],
            schemes: [
                Scheme.test(
                    buildAction: BuildAction.test(targets: [targetCRef, targetDRef]),
                    testAction: TestAction.test(coverage: true)
                ),
            ]
        )

        let workspace = Workspace.test(
            name: "A",
            projects: [
                projectSingleCoverage.path,
                projectAllCoverage.path,
            ]
        )

        let subject = AutogeneratedProjectSchemeWorkspaceMapper(codeCoverageMode: .relevant)

        // When
        let (got, _) = try subject.map(
            workspace: WorkspaceWithProjects(workspace: workspace, projects: [projectSingleCoverage, projectAllCoverage])
        )

        // Then
        let scheme = try XCTUnwrap(got.workspace.schemes.first)
        let testAction = try XCTUnwrap(scheme.testAction)

        XCTAssertTrue(testAction.coverage)
        XCTAssertEqual(testAction.codeCoverageTargets.count, 3)
        XCTAssertEqual(Set(testAction.codeCoverageTargets), Set([targetBRef, targetCRef, targetDRef]))
    }

    func test_map_codeCoverageMode_relevant_empty() throws {
        // Given
        let targetA = Target.test(
            name: "A"
        )
        let targetB = Target.test(
            name: "B"
        )
        let targetATests = Target.test(
            name: "ATests",
            product: .unitTests,
            dependencies: [.target(name: "A")]
        )

        let projectPath = try temporaryPath()
        let project = Project.test(
            path: projectPath,
            targets: [
                targetA,
                targetB,
                targetATests,
            ],
            schemes: [
            ]
        )

        let workspace = Workspace.test(
            name: "A",
            projects: [
                project.path,
            ]
        )

        let subject = AutogeneratedProjectSchemeWorkspaceMapper(codeCoverageMode: .relevant)

        // When
        let (got, _) = try subject.map(
            workspace: WorkspaceWithProjects(workspace: workspace, projects: [project])
        )

        // Then
        let scheme = try XCTUnwrap(got.workspace.schemes.first)
        let testAction = try XCTUnwrap(scheme.testAction)

        XCTAssertFalse(testAction.coverage)
        XCTAssertEmpty(testAction.codeCoverageTargets)
    }
}
