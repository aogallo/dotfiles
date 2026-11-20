# Edit ACE 12 projects on Windows

Use Neovim for JavaCompute, IBM ESQL and XML editing; keep ACE Toolkit/runtime
for flow design, authoritative validation, BAR builds, deployment and NodeSpy tests.
No IBM paths are committed, no Eclipse metadata is rewritten, and no server is
installed automatically by this feature. The existing Go and SQL configuration is unchanged.

## Quick path

1. Use the Neovim version required by this configuration (native `vim.pack` and
   `vim.lsp.config` APIs). Put this repository's `nvim/` contents in
   `$env:LOCALAPPDATA/nvim`, or link that directory. Do not add a second Java
   ftplugin that starts another JDT LS client.
2. Install a JDK compatible with the selected JDT LS release, Python 3.9+ for its
   launcher, and Node.js 18+ for ESQL. Current JDT LS upstream requires Java 25;
   older releases may require 21. Check the installed release, not ACE's JRE.
3. In Neovim run `:MasonInstall jdtls lemminx`. These are explicit installations
   on Windows, not additions to the startup auto-install list.
4. Set the machine-local variables below **before launching Neovim**.
5. Install the ESQL server as described below. With a supported C compiler and
   Tree-sitter CLI available, run `:TSInstallConfigured` to install the configured
   parsers, including Java, XML and ESQL. Use `:checkhealth nvim-treesitter` for
   the exact toolchain requirements of your installed Treesitter version.
6. Open a Java file from its Eclipse project, then an ESQL file and a WSDL/XSD.
   Run `:checkhealth vim.lsp` in each buffer. Expect `jdtls`, `esql` and
   `lemminx`, respectively. `:lua =vim.lsp.get_clients({bufnr=0})` shows attachments.

## Local JDK and IBM libraries

Set variables in PowerShell; replace **every example path** with your installation:

```powershell
# Modern JDK for editor tooling, NOT a change to ACE's runtime.
$env:JDTLS_JAVA_HOME = 'C:/Java/jdk-25'
# Also lets Java-based XML tooling find a suitable JDK.
$env:JAVA_HOME = $env:JDTLS_JAVA_HOME

# Directories containing these exact files, not the JAR filenames themselves.
$env:JCN_HOME = 'C:/your-ace-install/server/jplugin'
$env:COMMON_CLASSES_HOME = 'C:/your-ace-install/common/classes'

# Optional target runtime: set BOTH to match your actual ACE installation/project.
# JavaSE-1.8 is an example, not a claim that all ACE 12 projects use Java 8.
$env:ACE_JAVA_HOME = 'C:/your-project-compatible-jdk'
$env:ACE_JAVA_VERSION = 'JavaSE-1.8'
nvim
```

Verify `javacompute.jar` and `jplugin2.jar` exist under `JCN_HOME`, and
`IntegrationAPI.jar` under `COMMON_CLASSES_HOME`. Do not infer these paths from
the example. Session variables above are temporary; after verification, persist
them using Windows user environment settings or your local PowerShell profile.

JDT LS receives `java.classpath.variables` entries in `NAME=path` format. This
resolves the existing Eclipse variable entries without replacing `.classpath`.
The optional target runtime becomes `java.configuration.runtimes`; without both
target variables, the config does not guess an ACE Java version. The server's
`JAVA_HOME` is overridden only when `JDTLS_JAVA_HOME` is set.

Each project uses a hash of its full root for a separate JDT LS index under
`stdpath('cache')/jdtls/`, never the Toolkit workspace's `.metadata`. Source roots
and output locations remain those declared by Eclipse. Merely loading this
configuration creates no index directories; the server owns its runtime state.

### Eclipse-specific limits

The IBM `MBProjectReference` classpath container and `Integration Test Library`
user library are not implemented by this configuration. A generic JDT LS
installation may still report unresolved containers or test imports even after
the variable-based JARs resolve. Keep the Toolkit as the source of truth; do not
delete its builders/containers or add `referencedLibraries` and assume that fixes
a managed Eclipse project's classpath.

Your reference tests require IBM `com.ibm.integration.test.v1`, Jupiter (including
parameterized tests), Hamcrest and JUnit 4 assertion classes. JUnit 4 assertions
alone do not require the Vintage engine. NodeSpy also needs the matching IBM
application/flow/node context. Existing test mappings remain Go-only: this feature
does not advertise a generic JUnit runner as an ACE test runner.

## ESQL server and parser

The community project [nils-gg/esql-lsp](https://github.com/nils-gg/esql-lsp)
targets IBM ESQL, not Elasticsearch ES|QL. Its author discloses extensive
AI-assisted development and incomplete human auditing. Review it under your
organization's policy before installing it; ACE's compiler remains authoritative.

Example explicit installation in a directory you control:

```powershell
git clone https://github.com/nils-gg/esql-lsp.git
Set-Location esql-lsp
git checkout --detach b773cbf8a090083cb9a4b9eb813836f828111b4e
npm install
npm run build
npm link
```

Ensure npm's global executable directory is on Neovim's PATH. The native Node
grammar addon needs a working native build toolchain; if it cannot load, the
server documents a heuristic fallback with reduced syntax diagnostics. Check
its startup logs instead of assuming grammar mode is active.

The editor-side ESQL parser is separately registered using Treesitter's **main**
API, pinned to that same revision, including its highlight queries. It is
re-registered on `User TSUpdate` so updates do not lose the custom definition.
The compiler/toolchain for this parser is independent of the Node addon.
ESQL gets its own filetype and LSP; it never activates SQLs or Dadbod completion.
An Eclipse `.project` is preferred as its root, then Git, then the file's directory.
It does not validate external database procedures or reconstruct message models.

## XML and formatting

`.subflow`, `.msgflow`, `.wsdl`, `.xsd` and `.descriptor` use the XML filetype,
XML parser and LemMinX. This provides XML assistance, not a graphical flow editor
or validation of IBM node wiring. Generic `.map` files are not globally reassigned.
LemMinX external-resource downloading is disabled to avoid automatic schema fetches;
this is not a network sandbox. Java formatting-on-save stays disabled as before.

## Verification and troubleshooting

Offline configuration checks (no ACE installation, plugins or downloads needed):

```sh
nvim --headless -u NONE -i NONE -l nvim/lua/tests/ace_support_smoke.lua
```

On Windows, confirm the server launchers are on PATH using `Get-Command jdtls`,
`Get-Command lemminx` and `Get-Command esql-lsp` in a terminal with the same
environment as Neovim. Windows launchers run through `cmd.exe /c` to support
Mason/npm command shims. Use `:messages` and `:lua =vim.lsp.log.get_filename()`
to find launch failures. Restart Neovim after changing environment variables.

Still required on the target machine: real server startup, IBM class/import
resolution, parser compilation and representative ESQL diagnostics. Neither the
offline check nor a connected LSP proves the project builds or NodeSpy tests run.
