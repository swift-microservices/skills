---
type: regex
target: { source: file, path: acme-backend/Sources/NotesHTTP/Problem/CreateNoteUseCaseError+Problem.swift }
pattern: '^(?=[\s\S]*invalidBody[^\n]*\n?[^\n]*(?:badRequest|400))(?=[\s\S]*forbidden[^\n]*\n?[^\n]*(?:\.forbidden|403))[\s\S]*unknown[^\n]*\n?[^\n]*(?:internalServerError|500)'
---
