# Feature Specification: Trailing Whitespace Cleanup

**Feature Branch**: `009-trim-trailing-whitespace`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "crea un auto command que quite los espacios de las lineas yo tenia uno en mi version anteiror de nvim pero ya no lo pase a esata configuracion, hay lineas en el markdown que se quedan con espacios y no me gusta, segun yo loacia prettier pero en estos archivos no veo que lo haga, puedes investigar esta parte si es necesario el command o solo con el fomatter"

## Investigation Summary (2026-09-25)

The request asked whether a separate auto command is needed or whether the formatter already
covers it. It was investigated empirically before writing this specification, and the answer
decides the scope:

| Question | Finding |
| --- | --- |
| Is a formatter available? | Yes. The editor resolves a working formatter install and uses it for markdown on save. |
| Does it run? | Yes. Reproduced headlessly: a markdown file with stray trailing spaces is cleaned on save. |
| Why did some lines keep their spaces? | Every markdown line in the repository that still ends in spaces ends in **exactly two** spaces inside prose. Those are intentional hard line breaks, which the formatter preserves on purpose because they are semantically meaningful in Markdown. Lines that merely *accidentally* carried extra spaces (3 spaces, or 2 spaces on a heading) were already removed. |
| Is the silent case real? | Yes, and it is the actual risk: the whitespace-only formatters are chained *after* the main one, and only the first available formatter runs. If the main formatter is ever unavailable, markdown silently gets **no** trimming at all, with no visible warning. |
| Is a second, parallel mechanism justified? | No. The user confirmed the formatter path is acceptable ("si el formateado lo hace está bien"). A competing auto command would duplicate behavior and race the formatter on the same save event. |

**Scope decision**: no auto command is added. The work is to *guarantee* the behavior that
already exists (regression coverage), close the silent-no-op hole, and document the
hard-break exception so it is not "fixed" into broken rendering later.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Save a document and it is already clean (Priority: P1)

As someone who writes Markdown, SQL and config files in this editor, I save a file and never
see stray spaces at the end of lines again — I do not have to remember to clean them, and I do
not need a separate auto command for it.

**Why this priority**: This is the whole request. Today the cleanup works, but only because a
specific chain happens to be configured; nothing protects it, and one missing tool turns the
cleanup into a silent no-op.

**Independent Test**: Type trailing spaces on a few lines of any document type, save, reopen the
file, and confirm the spaces are gone without running any command.

**Acceptance Scenarios**:

1. **Given** a Markdown file with lines ending in accidental extra spaces, **When** the user saves, **Then** the saved file has no trailing spaces on those lines.
2. **Given** a SQL, shell, Lua, or YAML file with trailing spaces, **When** the user saves, **Then** the trailing spaces are removed by the same behavior, not by a per-language special case.
3. **Given** a file the user saves repeatedly, **When** they save it again with no edits, **Then** the file is unchanged apart from the cleanup, and no duplicate or conflicting cleanup runs.

---

### User Story 2 - The cleanup never fails silently (Priority: P2)

As someone who trusts the editor to clean files, I want to know when the cleanup could not run,
instead of discovering later that spaces survived.

**Why this priority**: A silent no-op is worse than no cleanup at all, because it looks like
it works. This is the one real defect behind the original request.

**Independent Test**: Disable the main formatter and save a Markdown file; the result must be
either a clean file or a visible message, never a silent pass.

**Acceptance Scenarios**:

1. **Given** the main formatter is not installed or not runnable, **When** the user saves a document, **Then** the whitespace cleanup still runs.
2. **Given** no formatter at all can run for the file type, **When** the user saves, **Then** the editor surfaces a message identifying the file type instead of silently doing nothing.
3. **Given** the cleanup runs, **When** it changes nothing, **Then** the file's modification state and undo history are not disturbed.

---

### User Story 3 - Intentional line breaks keep working (Priority: P3)

As someone who uses two trailing spaces in prose to force a line break, I want that to keep
rendering as a line break and not be "cleaned up" into a single run-on paragraph.

**Why this priority**: A cleanup that is too aggressive is a data-loss bug in a document. This
story exists to protect the exception, and to record why it exists.

**Independent Test**: Write two prose lines that end with two spaces, save, and confirm the
rendered output still shows two lines.

**Acceptance Scenarios**:

1. **Given** a prose line ending in exactly two spaces inside a paragraph, **When** the user saves, **Then** the two spaces are preserved and the rendered document still shows a line break.
2. **Given** a heading or table line ending in two spaces, **When** the user saves, **Then** those spaces are removed, because they carry no meaning there.
3. **Given** a fenced code block containing trailing spaces in an example, **When** the user saves, **Then** the content inside the fence is left as the user wrote it.

---

### Edge Cases

- **Formatter chain ordering**: only the first available formatter runs today, so the
  whitespace-only steps never execute for Markdown. If the main formatter is removed, all three
  behaviors change at once.
- **A directory containing its own formatter configuration** (for example a JavaScript project
  with its own settings file): that directory's rules win, and the cleanup must still apply there.
- **Whitespace inside fenced code blocks and indented examples**: never touched; the user may
  be documenting trailing spaces on purpose.
- **Whitespace-only lines** between paragraphs: a line of only spaces must become an empty line,
  never be deleted (deleting it would merge paragraphs).
- **Files with CRLF line endings**: the carriage return must not be mistaken for content, and
  must not be re-introduced.
- **Very large or generated files**: the cleanup must not slow saving down noticeably; a file
  with no trailing spaces should cost almost nothing.
- **Disabled auto-format**: when the user turns formatting off for a session, the cleanup must
  respect that choice instead of running anyway.
- **First save on a new machine** where formatter tooling has not been installed yet: the user
  should get a message, not a file that quietly keeps its spaces.
- **Tabs used for indentation**: untouched; only end-of-line whitespace is in scope.
- **The user's other editors**: a file edited outside this editor may reintroduce spaces; the
  next save here must clean it again without complaint.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Saving any supported document type MUST remove trailing whitespace from the end of each line, without the user running a separate command.
- **FR-002**: The cleanup MUST apply to Markdown, plain text, source code, and configuration file types supported by the editor.
- **FR-003**: A line consisting only of whitespace MUST become an empty line; it MUST NOT be removed, and paragraph separation MUST be preserved.
- **FR-004**: Trailing whitespace that carries meaning in the document format — a two-space hard line break inside Markdown prose — MUST be preserved, and the rendered document MUST be unchanged.
- **FR-005**: Whitespace inside fenced code blocks and indented code examples MUST be left exactly as written.
- **FR-006**: Content inside the line MUST be preserved byte for byte, including leading indentation and tabs.
- **FR-007**: When the primary formatter for a file type is unavailable, the trailing-whitespace cleanup MUST still be applied.
- **FR-008**: When no formatter at all can run for a file type, the editor MUST show a message naming the file type instead of silently doing nothing.
- **FR-009**: The cleanup MUST be part of the editor's existing single formatting path. A second, parallel auto command MUST NOT be added, so that saving a file never triggers two competing cleanup mechanisms.
- **FR-010**: The behavior MUST be verifiable without a running editor session or a database, so it can be covered by automated checks that run in this repository.
- **FR-011**: Line-ending style MUST be preserved: a file saved with Windows line endings MUST NOT be silently converted, and the carriage return MUST NOT be treated as trailing content.
- **FR-012**: When auto-formatting is disabled by the user, the cleanup MUST NOT run.
- **FR-013**: The editor's module documentation MUST state that trailing whitespace is cleaned on save, list the intentional exception, and explain the fallback order, in the same change that alters this behavior.
- **FR-014**: The change MUST be developed on a feature branch and submitted through a pull request that links an approved issue, before merge.
- **FR-015**: No new runtime dependency and no new configuration file MUST be introduced.

### Key Entities

- **Trailing whitespace**: characters at the end of a line after the last non-whitespace character. Meaningful only when it is not a format-level hard line break.
- **Hard line break**: the two-space convention inside Markdown prose that forces the following text onto a new rendered line. Intentional, and therefore protected.
- **Cleanup step**: the whitespace-only part of the save-time formatting behavior, which must survive independently of the primary formatter.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After saving any file type, 100% of lines have no accidental trailing whitespace, verified by reopening the saved file.
- **SC-002**: A saved file's two-space prose line breaks render identically to before the change: 0 documents change their rendered layout as a result of this feature.
- **SC-003**: Removing the primary formatter for a file type still yields a saved file with no trailing whitespace in 100% of attempts; the silent no-op case count is 0.
- **SC-004**: The automated checks for this behavior pass with 0 failures, run without a live editor session.
- **SC-005**: Exactly one cleanup mechanism runs per save; no save triggers both a dedicated auto command and the formatting path.

## Assumptions

- The editor's formatting behavior is already correctly configured to run on save; this change
  hardens and documents it rather than introducing a new trigger.
- The user accepts that the cleanup is performed by the formatter, and does not require a
  dedicated auto command.
- The user accepts that two trailing spaces inside prose remain, because they are an intentional
  line-break convention rather than a formatting defect.
- "Trailing whitespace" means the end of a line, not the start; leading indentation is out of scope.
- Markdown hard line breaks are written as exactly two spaces; three or more spaces at the end of
  a prose line are treated as accidental and removed.
- Automatic dependency installation is out of scope: if a formatter is missing, the user is told
  how to install it rather than having it installed silently.
