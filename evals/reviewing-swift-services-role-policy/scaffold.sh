#!/bin/bash
# Lays down a tiny "notes" service in the working directory for the reviewer to audit.
set -euo pipefail
mkdir -p Sources/NotesCore/Notes/UseCases/CreateNote Sources/NotesPostgres/Migrations/Note Sources/NotesPostgres/Scopes Sources/Notes/Serve Tests/NotesCoreTests
cat > Package.swift <<'PKG'
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "acme-notes",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "notes", targets: ["Notes"])],
    dependencies: [
        .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.1.0"),
        .package(url: "https://github.com/swift-microservices/swift-persistence-postgres.git", from: "0.1.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication-jwt.git", from: "0.1.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication-grpc.git", from: "0.1.0"),
        .package(url: "https://github.com/acme/acme-core.git", from: "0.1.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.33.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.15.0"),
    ],
    targets: [
        .target(name: "NotesCore", dependencies: [
            .product(name: "Persistence", package: "swift-persistence"),
            .product(name: "AcmeAuthentication", package: "acme-core"),
            .product(name: "Logging", package: "swift-log"),
        ]),
        .target(name: "NotesPostgres", dependencies: [
            "NotesCore",
            .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
            .product(name: "PostgresNIO", package: "postgres-nio"),
            .product(name: "Logging", package: "swift-log"),
        ]),
        .executableTarget(name: "Notes", dependencies: [
            "NotesCore", "NotesPostgres",
            .product(name: "AuthenticationGRPC", package: "swift-authentication-grpc"),
            .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
            .product(name: "AcmeAuthentication", package: "acme-core"),
            .product(name: "AcmePersistence", package: "acme-core"),
            .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
            .product(name: "Logging", package: "swift-log"),
        ]),
        .testTarget(name: "NotesCoreTests", dependencies: [
            "NotesCore",
            .product(name: "AcmeAuthentication", package: "acme-core"),
            .product(name: "AcmeTesting", package: "acme-core"),
            .product(name: "Logging", package: "swift-log"),
        ]),
    ],
    swiftLanguageModes: [.v6]
)
PKG
cat > Sources/NotesCore/Notes/Note.swift <<'SWIFT'
import Foundation

package struct Note: Equatable, Sendable {
    package let id: UUID
    package let userId: UUID
    package let body: String
    package let creationDate: Date
}
SWIFT
cat > Sources/NotesCore/Notes/NoteRepository.swift <<'SWIFT'
package struct CreateNoteCommand: Sendable {
    package let userId: UUID
    package let body: String
}

package protocol NoteRepository: Sendable {
    func create(_ command: CreateNoteCommand) async throws -> Note
}

package protocol CreateNoteUseCaseScope: Sendable {
    var noteRepository: any NoteRepository { get }
}
SWIFT
cat > Sources/NotesCore/Notes/UseCases/CreateNote/CreateNoteUseCase.swift <<'SWIFT'
import AcmeAuthentication
import Logging
import Persistence
import PostgresNIO

package struct CreateNoteUseCase: CreateNoteUseCaseProtocol {
    private let connection: PostgresConnection
    private let logger: Logger

    package init(connection: PostgresConnection, logger: Logger) {
        self.connection = connection
        self.logger = logger
    }

    package func callAsFunction(subject: UserIdentity, input: CreateNoteUseCaseInput) async throws(CreateNoteUseCaseError) -> Note {
        guard !input.body.isEmpty else { throw .emptyBody }
        do {
            let rows = try await connection.query("INSERT INTO notes (user_id, body) VALUES (\(subject.userId), \(input.body)) RETURNING id, user_id, body, creation_date", logger: logger)
            for try await (id, userId, body, creationDate) in rows.decode((UUID, UUID, String, Date).self) {
                return Note(id: id, userId: userId, body: body, creationDate: creationDate)
            }
            throw CreateNoteUseCaseError.unknown
        } catch {
            throw .unknown
        }
    }
}
SWIFT
cat > Sources/NotesPostgres/Migrations/Note/CreateNotesRLSPolicy.swift <<'SWIFT'
import Logging
import PostgresMigrations
import PostgresNIO

package struct CreateNotesRLSPolicy: DatabaseMigration {
    package init() {}

    package func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query("ALTER TABLE notes ENABLE ROW LEVEL SECURITY", logger: logger)
        try await connection.query(
            """
            CREATE POLICY notes_tenant ON notes
                USING (user_id = NULLIF(current_setting('app.caller_user_id', true), '')::uuid OR current_setting('app.caller_role', true) IN ('admin', 'service'))
                WITH CHECK (user_id = NULLIF(current_setting('app.caller_user_id', true), '')::uuid OR current_setting('app.caller_role', true) IN ('admin', 'service'))
            """,
            logger: logger
        )
        try await connection.query(
            "CREATE POLICY notes_internal ON notes TO \"notes_internal\" USING (true) WITH CHECK (true)",
            logger: logger
        )
    }

    package func revert(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query("DROP POLICY IF EXISTS notes_internal ON notes", logger: logger)
        try await connection.query("DROP POLICY IF EXISTS notes_tenant ON notes", logger: logger)
    }
}
SWIFT
cat > Sources/NotesPostgres/Scopes/PostgresNotesScope.swift <<'SWIFT'
import Logging
import NotesCore
import PersistencePostgres
import PostgresNIO

package struct PostgresNotesScope: PostgresScope, CreateNoteUseCaseScope {
    package let noteRepository: any NoteRepository

    package init(connection: PostgresConnection, logger: Logger) {
        self.noteRepository = PostgresNoteRepository(connection: connection, logger: logger)
    }
}
SWIFT
cat > Sources/Notes/Serve/Serve.swift <<'SWIFT'
// Composition root, abridged for the fixture.
// interceptorPipeline: [
//     .apply(BearerAuthenticationInterceptor(authenticator: userAuthenticator), to: .services([Acme_Notes_V1_NoteService.descriptor])),
//     .apply(UserSettingsInterceptor(), to: .services([Acme_Notes_V1_NoteService.descriptor])),
// ]
SWIFT
git init -q && git add -A && git -c user.name=eval -c user.email=eval@example.com -c commit.gpgsign=false commit -qm "fixture"
