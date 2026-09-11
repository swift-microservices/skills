#!/usr/bin/env python3
"""Checks every skill in this plugin against the authoring rules the org agreed on.

Fails on: a missing or oversized frontmatter field, a SKILL.md body over 500 lines, a reference
link that does not resolve or that nests deeper than one level below SKILL.md, a reference over
100 lines with no `## Contents` section, a retired package or type name, or a Windows-style path.
"""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SKILLS = ROOT / "skills"
RETIRED = [
    "swift-service-kit", "emberfilm-service-kit", "<project>-service-kit", "emberfilm-identity",
    "UserPayload", "ServicePrincipal", "UserSession", "SessionVariable", "SessionBuilder",
    "JWTUserTokenSigner", "JWTUserTokenVerifier", "TokenSigner", "TokenVerifier", "PeerIdentifier",
    "ServerTokenAuthenticationInterceptor", "ServerPeerAuthenticationInterceptor",
    "ClientTokenPropagationInterceptor", "TokenAuthenticationMiddleware", "MockTokenVerifier",
    "PostgresPersistence", "GRPCAuthentication", "GRPCNIOTransportAuthentication", "HTTPAuthentication",
    "UserAuthenticationContext", "PeerAuthenticationContext", "app.caller_role",
]
LINK = re.compile(r"\]\(([^)#]+)(?:#[^)]*)?\)")
failures = []

def fail(path, message):
    failures.append(f"{path.relative_to(ROOT)}: {message}")

def frontmatter(text):
    if not text.startswith("---\n"):
        return None, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return None, text
    block = text[4:end]
    fields = {}
    for line in block.splitlines():
        if ":" in line and not line.startswith(" "):
            key, _, value = line.partition(":")
            fields[key.strip()] = value.strip()
    return fields, text[end + 5:]

for skill_dir in sorted(p for p in SKILLS.iterdir() if p.is_dir()):
    skill = skill_dir / "SKILL.md"
    if not skill.exists():
        fail(skill_dir, "no SKILL.md")
        continue
    text = skill.read_text()
    fields, body = frontmatter(text)
    if fields is None:
        fail(skill, "no YAML frontmatter")
        continue
    name = fields.get("name", "")
    if not name or len(name) > 64 or not re.fullmatch(r"[a-z0-9-]+", name):
        fail(skill, f"name {name!r} must be 1-64 lowercase letters, digits, or hyphens")
    if name != skill_dir.name:
        fail(skill, f"name {name!r} does not match directory {skill_dir.name!r}")
    if any(word in name for word in ("anthropic", "claude")):
        fail(skill, "name contains a reserved word")
    description = fields.get("description", "")
    if not description or len(description) > 1024:
        fail(skill, "description must be 1-1024 characters")
    if re.search(r"\b(I|you|we)\b", description):
        fail(skill, "description must be written in the third person")
    if "Use when" not in description:
        fail(skill, "description must say when to use the skill (\"Use when ...\")")
    body_lines = body.count("\n") + 1
    if body_lines > 500:
        fail(skill, f"body is {body_lines} lines; keep it under 500")
    for match in LINK.finditer(body):
        target = match.group(1)
        if "\\" in target:
            fail(skill, f"Windows-style path {target!r}")
        if target.startswith(("http://", "https://", "mailto:")):
            continue
        resolved = (skill_dir / target).resolve()
        if not resolved.exists():
            fail(skill, f"link to missing file {target!r}")
        elif len(pathlib.Path(target).parts) > 2:
            fail(skill, f"link {target!r} nests deeper than one level")
    for doc in sorted(skill_dir.rglob("*.md")):
        content = doc.read_text()
        for word in RETIRED:
            if word in content:
                fail(doc, f"retired name {word!r}")
        if doc != skill and content.count("\n") > 100 and "## Contents" not in content:
            fail(doc, "over 100 lines with no `## Contents` section")
        for match in LINK.finditer(content):
            target = match.group(1)
            if target.startswith(("http://", "https://", "mailto:")):
                continue
            if not (doc.parent / target).resolve().exists():
                fail(doc, f"link to missing file {target!r}")
            if doc != skill and "/" in target and not target.startswith("../"):
                fail(doc, f"reference {target!r} links another level down; link from SKILL.md instead")

if failures:
    print("\n".join(failures))
    sys.exit(1)
print(f"OK: {sum(1 for p in SKILLS.iterdir() if p.is_dir())} skills validated")
