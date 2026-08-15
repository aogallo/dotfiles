# Contract: Windows Tooling Audit Document

The final user-facing artifact must be a Spanish Markdown document at `docs/windows-tooling-audit.md`. It is a decision-support document, not an installer.

## Required Structure

```markdown
# Auditoria de herramientas para Windows

## Resumen rapido

| Herramienta / modulo | Ubicacion en el repo | Estado en Windows | Camino recomendado | Referencia |
|----------------------|----------------------|-------------------|--------------------|------------|

## Como leer los estados

## Hallazgos por herramienta

### <Tool name>

- Estado en Windows:
- Ubicacion en el repo:
- Uso recomendado:
- Enlaces:
- Forma de instalar en Windows:
- Ventajas:
- Desventajas:
- Caveats del repo:

## Fuera de alcance

## Recomendaciones finales
```

## Required Coverage

The document must cover or explicitly exclude these repository areas:

- `README.md`
- `nvim/`
- `Tmux/`
- `ghostty/`
- `zsh/`
- `keyboard/`
- `installer/`
- `setup/`
- `.github/workflows/`
- `dist/` when relevant as generated output

## Required Rules

- Must be written in Spanish.
- Must not claim any tool was installed or validated on Windows unless that actually happened outside this feature and is cited as prior evidence.
- Must distinguish native Windows from WSL, Git Bash, MSYS2, or manual-only workflows.
- Must include at least one advantage and one disadvantage for each compatible or partially compatible item.
- Must prefer official or maintainer links over third-party guides.
- Must call out macOS-only assumptions found in repository evidence, including Homebrew-only guidance, darwin-only release assets, macOS app paths, `pbcopy`, Xcode Command Line Tools, and Apple Silicon/Intel language where relevant.
- Must keep generated output, local state, private overrides, and secrets out of the document except as safe high-level caveats.

## Acceptance Checks

- Every row in the summary table has a matching detail section or a clear out-of-scope note.
- Every compatible or partially compatible detail section includes installation guidance and tradeoffs.
- Every official/reputable link is formatted as a Markdown link.
- The document contains no commands that are presented as executed by this feature.
