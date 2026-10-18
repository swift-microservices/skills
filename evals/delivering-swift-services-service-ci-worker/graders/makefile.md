---
type: regex
target: { source: file, path: Makefile }
pattern: '^(?=[\s\S]*swift test[^\n]*--disable-automatic-resolution)(?=[\s\S]*\npublish:[\s\S]*delivery\.sh publish)(?=[\s\S]*\nstage:[\s\S]*delivery\.sh stage)(?=[\s\S]*\ndeploy:[\s\S]*delivery\.sh deploy)'
---
