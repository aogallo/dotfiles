# Feature Specification: Trailing Whitespace Cleanup

**Feature Branch**: `009-trim-trailing-whitespace`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "crea un auto command que quite los espacios de las lineas yo tenia uno en mi version anteiror de nvim pero ya no lo pase a esata configuracion, hay lineas en el markdown que se quedan con espacios y no me gusta, segun yo loacia prettier pero en estos archivos no veo que lo haga, puedes investigar esta parte si es necesario el command o solo con el fomatter"

**Second input** (2026-09-25, same feature branch): "y agrega a esta spec un indicador en la lualine que muestre contra que base de datos se ejecuta el query del buffer actual, porque cuando estoy escribiendo un query no se que base de datos se va a seleccionar, por ejemplo si hago `use base-a` y despues consulto `base-b..tabla2` no tengo forma de saberlo mirando el editor"

## Investigation Summary (2026-09-25)

The request asked whether a separate auto command is needed or whether the formatter already
covers it. It was investigated empirically before writing this specification, and the answer
decides the scope:

| Question | Finding |
| --- | --- |
| Is a formatter available? | Yes. The editor resolves a working formatter install and uses it for markdown on save. |
| Does it run? | Yes. Reproduced headlessly: a markdown file with stray trailing spaces is cleaned on save. |
| Why did some lines keep their spaces? | Every markdown line in the repository that still ends in spaces ends in **exactly two** spaces inside prose, and every one of them is mid-paragraph — the pattern of an intentional hard line break. |
| Does the formatter remove accidental extra spaces? | **Not always.** Verified against the formatter directly: three or more trailing spaces in prose are *normalized to exactly two*, not removed, because two or more spaces is a hard break in Markdown. Only spaces on a heading or a table row are dropped. This corrects an earlier draft of this spec that claimed 3-space lines were already removed. |
| Is a two-space break always preserved? | **No.** It is preserved when more text follows in the same paragraph. On the last line of a paragraph the formatter removes it, because a break with nothing after it renders identically either way. This corrects an earlier draft that promised unconditional preservation. |
| Are fenced code blocks left exactly as written? | **No.** Trailing whitespace inside a fence is stripped, and tables get re-aligned. Only the structure survives. An earlier draft promised fences were left untouched, which is not true of this formatter. |
| If the main formatter is missing, is the trimming lost? | **No.** The formatter chain is resolved by availability: unavailable formatters are skipped, and only the *first available* one stops the chain. With the main formatter gone, the whitespace-only steps are selected and run, so the cleanup still happens. This was verified in the formatter's own resolution code, and it corrects an earlier draft of this spec that claimed the opposite. |
| So is anything actually broken? | Two narrow cases, not the wholesale silent no-op the first draft described. (1) A document that a project configuration routes to a *different* formatter is given a chain that contains no whitespace-only step at all, so it gets no trimming when that formatter is unavailable. (2) The "formatters unavailable" message is emitted once per file type per session, so a failure that persists across many saves is silent from the second save onward. |
| Is a second, parallel mechanism justified? | No. The user confirmed the formatter path is acceptable ("si el formateado lo hace está bien"). A competing auto command would duplicate behavior and race the formatter on the same save event. |

**Scope decision**: no auto command is added. The work is to *guarantee* the behavior that
already exists (regression coverage), close the two narrow gaps listed above, and document the
formatter's real rules for prose, headings, tables and fences so they are not "fixed" into broken
rendering later.

**Correction note (2026-09-25)**: this summary originally claimed that a missing main formatter left
markdown completely untrimmed and silent, that 3-space lines were already removed, that a two-space
hard break was always preserved, and that fenced blocks were left untouched. All four claims were
wrong, and each was corrected above after verifying the formatter's actual output. Any later session
that revisits this spec must read this table rather than the original wording.

## Clarifications

### Session 2026-09-25

- Q: ¿En qué spec vive el indicador de base de datos? → A: se agrega a **esta** spec (009), aunque
  sea un tema distinto al de limpieza de whitespace. Decisión consciente del usuario: el PR queda
  cubriendo dos features, y el nombre de la spec no describe todo su contenido.
- Q: ¿Qué muestra el indicador? → A: la base declarada en la URL de la conexión del buffer, más una
  marca de conflicto cuando el texto del buffer cambia de contexto (una sentencia `use <db>` o
  referencias `<db>..<objeto>`). La marca **nunca** oculta la base de la conexión.
- Q: ¿El aviso es solo visual o también al ejecutar? → A: ambos. Además del indicador, en el
  instante en que se ejecuta un query se emite un aviso único si el texto cambia de contexto.
- Q: ¿En qué buffers aparece? → A: en todo buffer SQL. Con conexión muestra la base; sin conexión
  muestra un marcador visible de ausencia, para que se distinga de un indicador roto.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Save a document and it is already clean (Priority: P1)

As someone who writes Markdown, SQL and config files in this editor, I save a file and never
see stray spaces at the end of lines again — I do not have to remember to clean them, and I do
not need a separate auto command for it.

**Why this priority**: This is the whole request. Today the cleanup works, but only because a
specific chain happens to be configured, and nothing protects it: no automated check would notice
if a future change to that chain quietly removed the cleanup.

**Independent Test**: Type trailing spaces on a few lines of any document type, save, reopen the
file, and confirm the spaces are gone without running any command.

**Acceptance Scenarios**:

1. **Given** a Markdown file with lines ending in accidental extra spaces, **When** the user saves, **Then** the saved file has no trailing spaces on those lines.
2. **Given** a SQL, shell, Lua, or YAML file with trailing spaces, **When** the user saves, **Then** the trailing spaces are removed by the same behavior, not by a per-language special case.
3. **Given** a file the user saves repeatedly, **When** they save it again with no edits, **Then** the file is unchanged apart from the cleanup, and no duplicate or conflicting cleanup runs.

---

### User Story 2 - The cleanup survives a missing formatter and never stays quiet for long (Priority: P2)

As someone who trusts the editor to clean files, I want the cleanup to keep working when the
main formatter is not available, and I want a failure that keeps repeating to keep reminding me
instead of going quiet after the first time.

**Why this priority**: Two real gaps sit behind this story, both narrow: a document that a project
configuration routes to a different formatter has no whitespace-only step in its chain, and the
"no formatters" message is emitted only once per file type per session. Neither loses data on its
own, but both make a persistent failure look like a working setup.

**Independent Test**: Make the main formatter unavailable and save a Markdown file, both inside
and outside a directory that carries its own formatter configuration; then remove every formatter
for a file type and save that file type repeatedly.

**Acceptance Scenarios**:

1. **Given** the main formatter is not installed or not runnable, **When** the user saves a document, **Then** the whitespace cleanup still runs.
2. **Given** a document inside a directory that carries its own formatter configuration, **When** that formatter is unavailable and the user saves, **Then** the whitespace cleanup still runs for that document too.
3. **Given** no formatter at all can run for the file type, **When** the user saves that file type more than once in the same session, **Then** the editor surfaces a message identifying the file type again on the later saves, not only on the first.
4. **Given** the cleanup runs, **When** it changes nothing, **Then** the file's modification state and undo history are not disturbed.

---

### User Story 3 - Intentional line breaks keep working (Priority: P3)

As someone who uses two trailing spaces in prose to force a line break, I want that to keep
rendering as a line break and not be "cleaned up" into a single run-on paragraph.

**Why this priority**: A cleanup that is too aggressive is a data-loss bug in a document. This
story exists to protect the exception, and to record why it exists. It also records the cases where
the exception does not apply, so nobody "fixes" them later in the wrong direction.

**Independent Test**: Write two prose lines that end in two spaces, save, and confirm the rendered
output still shows two lines.

**Acceptance Scenarios**:

1. **Given** a prose line ending in exactly two spaces with more text following in the same paragraph, **When** the user saves, **Then** the two spaces are preserved and the rendered document still shows a line break.
2. **Given** the last line of a paragraph ending in two spaces, **When** the user saves, **Then** the spaces are removed, because a break with nothing after it renders identically and the trailing space is not a line break the author can observe.
3. **Given** a prose line ending in three or more spaces, **When** the user saves, **Then** the spaces are reduced to exactly two rather than removed, because two or more spaces is a hard break and the reduction changes nothing about the rendering.
4. **Given** a heading or table row ending in two spaces, **When** the user saves, **Then** the spaces are removed, because they carry no meaning there.
5. **Given** a fenced code block containing trailing spaces in an example, **When** the user saves, **Then** the trailing spaces inside the fence are stripped like anywhere else, because the formatter normalizes block content and the spaces are not significant to the example.


---

### User Story 4 - Know which database a query will run against (Priority: P2)

As someone who writes queries against several databases on the same server, I want to see, at a
glance, which database the current buffer will execute against, and whether the text I am typing
sends it somewhere else — because a query can start on the connection's database and end up
writing to a different one without any visible cue.

**Why this priority**: The connection supplies a starting database, but the buffer's own text can
change it mid-batch (`use <db>`) or target another one outright (`<db>..<objeto>`). Without a cue,
the only way to find out is to read the text carefully before every execution. It is second
priority because it does not block work; it prevents a wrong-database write.

**Independent Test**: Open a query buffer whose connection points at one database, type a `use` of
another, and confirm the indicator shows the connection's database plus a conflict mark naming the
other one — with no database server involved.

**Acceptance Scenarios**:

1. **Given** a query buffer whose connection declares a database, **When** the user looks at the status line, **Then** that database is shown.
2. **Given** a query buffer whose text switches context, **When** the user looks at the status line, **Then** the indicator shows the connection's database *and* a conflict mark that identifies the database or `db..object` reference found in the text.
3. **Given** a query buffer with no database connection, **When** the user looks at the status line, **Then** a visible "no database" marker is shown instead of nothing.
4. **Given** a query whose text switches context, **When** the user executes it, **Then** a single message identifies the conflict before the query runs, and the execution is not blocked.
5. **Given** a query whose text does not switch context, **When** the user executes it, **Then** no message appears.

---

### Edge Cases

- **Formatter chain ordering**: the chain stops after the first *available* formatter, so while the
  main formatter is present the whitespace-only steps never execute for Markdown. When it is
  absent, they become the first available ones and run instead — the cleanup degrades to the
  whitespace steps, not to nothing.
- **A directory containing its own formatter configuration** (for example a JavaScript project
  with its own settings file): that directory's rules win, and the cleanup must still apply there.
- **Whitespace inside fenced code blocks and indented examples**: cleaned like any other trailing
  whitespace, because the formatter normalizes block content. The structure and the code itself are
  preserved; only the trailing spaces go.
- **Three or more trailing spaces in prose**: reduced to exactly two, not removed, because two or
  more spaces is a hard break. This is the case that made the original request look unfixed: the
  spaces are gone, but the line still ends in two.
- **A two-space break on the last line of a paragraph**: removed, because nothing follows it and
  the rendering is identical either way.
- **A table in the document**: the formatter may re-align the columns, which changes bytes far from
  any trailing space. That is the formatter's own behavior and is not a whitespace change.
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
- **`use` inside a comment or a string literal**: text that only looks like a context switch MUST
  NOT be reported as one.
- **Several `use` statements in the same buffer**: statements run in order, so the last one is the
  one that determines the effective database, and that is the one to report.
- **A `use` appearing after a `db..object` reference**: both kinds of signal are reported, since
  the text targets a database explicitly and then changes it.
- **A result buffer produced by a query**: it is not SQL the user is editing, so it MUST NOT show a
  database indicator.
- **A procedure source opened from the object browser**: the buffer's connection already names the
  owning database, so the indicator shows it and no conflict mark is needed.
- **A database name containing `$` or `#`**: valid in this database engine, and it MUST be matched
  and displayed intact.
- **A `master` or other system database written explicitly**: reported like any other name.
- **The connection's database changed while the buffer is open**: the indicator MUST reflect the
  new value without needing the buffer to be reloaded.
- **No status line available** (the component is not loaded, or the status line is disabled): the
  absence of the indicator MUST NOT break the editor, and the execution-time message MUST still
  work.
- **A very long query**: inspecting the buffer for context switches MUST NOT delay the status line
  noticeably.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Saving any supported document type MUST remove trailing whitespace from the end of each line, without the user running a separate command.
- **FR-002**: The cleanup MUST apply to Markdown, plain text, source code, and configuration file types supported by the editor.
- **FR-003**: A line consisting only of whitespace MUST become an empty line; it MUST NOT be removed, and paragraph separation MUST be preserved.
- **FR-004**: Trailing whitespace that carries meaning in the document format MUST be preserved, and the rendered document MUST be unchanged. Concretely: a two-space hard line break followed by more text in the same paragraph is preserved; three or more trailing spaces in prose are reduced to exactly two; a two-space break on the last line of a paragraph is removed, because it renders identically; two spaces on a heading or table row are removed.
- **FR-005**: Whitespace inside fenced code blocks and indented code examples MUST be cleaned like any other trailing whitespace, because it is not significant to the example. The block's structure and content MUST be preserved; the formatter is allowed to normalize whitespace and table alignment inside a document.
- **FR-006**: Content inside the line MUST be preserved byte for byte, including leading indentation and tabs.
- **FR-007**: When the primary formatter for a document is unavailable, the trailing-whitespace cleanup MUST still be applied — both for documents the editor formats with its own chain, and for documents a project configuration routes to a different formatter.
- **FR-008**: When no formatter at all can run for a file type, the editor MUST show a message naming the file type, and it MUST NOT go silent on subsequent saves of that file type in the same session while the failure persists.
- **FR-009**: The cleanup MUST be part of the editor's existing single formatting path. A second, parallel auto command MUST NOT be added, so that saving a file never triggers two competing cleanup mechanisms.
- **FR-010**: The behavior MUST be verifiable without a running editor session or a database, so it can be covered by automated checks that run in this repository.
- **FR-011**: Line-ending style MUST be preserved: a file saved with Windows line endings MUST NOT be silently converted, and the carriage return MUST NOT be treated as trailing content.
- **FR-012**: When auto-formatting is disabled by the user, the cleanup MUST NOT run.
- **FR-013**: The editor's module documentation MUST state that trailing whitespace is cleaned on save, list the intentional exception, and explain the fallback order, in the same change that alters this behavior.
- **FR-014**: The change MUST be developed on a feature branch and submitted through a pull request that links an approved issue, before merge.
- **FR-015**: No new runtime dependency and no new configuration file MUST be introduced.
- **FR-016**: The status line MUST show, for the current buffer, the database the query would run against as declared by the buffer's database connection, whenever the buffer has such a connection.
- **FR-017**: When the buffer's text changes the database context, the status line MUST mark that as a conflict and identify what was found, and the connection's database MUST remain visible next to the mark.
- **FR-018**: A buffer without a database connection MUST still show a visible "no database known" marker, so an absent indicator is never confused with a broken one.
- **FR-019**: At the moment a query is executed, the editor MUST emit a message identifying the context switch when the buffer's text contains one, and MUST NOT emit any message when it does not.
- **FR-020**: The execution-time message MUST NOT block, delay, or alter the query in any way.
- **FR-021**: The conflict detection MUST be derived locally from the connection and the buffer's text; it MUST NOT require a round trip to the database server, and MUST recognise both `use <db>` and `<db>..<object>` forms, with the last `use` taking precedence.
- **FR-022**: The database indicator MUST reuse the editor's existing pre-execution hook rather than registering an additional one, and the detection logic MUST be testable without a running database.
- **FR-023**: Text that only resembles a context switch — a `use` or `db..object` inside a comment or a string literal — MUST NOT be reported as one.
- **FR-024**: The database indicator MUST NOT appear on buffers that are not user-editable query text, such as a rendered result buffer.
- **FR-025**: The status line and the query path MUST derive the database name from the same single source of truth, so that what the status line shows and what a query actually uses can never disagree.

### Key Entities

- **Trailing whitespace**: characters at the end of a line after the last non-whitespace character. Meaningful only when it is not a format-level hard line break.
- **Hard line break**: the two-space convention inside Markdown prose that forces the following text onto a new rendered line. Intentional, and therefore protected.
- **Cleanup step**: the whitespace-only part of the save-time formatting behavior, which must survive independently of the primary formatter.
- **Connection database**: the database carried by the buffer's database connection, derived from the connection's URL. It is what a query uses unless the text says otherwise.
- **Context switch**: anything in the buffer's text that makes the effective database differ from the connection database — a `use <db>` statement or a `<db>..<object>` reference.
- **Conflict mark**: the status-line marker shown when a context switch is detected, naming what was found.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After saving any file type, 100% of lines have no accidental trailing whitespace, verified by reopening the saved file.
- **SC-002**: A saved file's rendered layout is identical to before the change: 0 documents change their rendered output as a result of this feature, even where the bytes do change (three spaces reduced to two, a meaningless end-of-paragraph break removed, table columns re-aligned).
- **SC-003**: With the primary formatter made unavailable, 100% of saved documents still have no accidental trailing whitespace, including documents inside a directory that carries its own formatter configuration; and 0 saves of a file type with no available formatter pass without a message naming that file type.
- **SC-004**: The automated checks for this behavior pass with 0 failures, run without a live editor session.
- **SC-005**: Exactly one cleanup mechanism runs per save; no save triggers both a dedicated auto command and the formatting path.
- **SC-006**: The user identifies the database a query will run against in under one second of looking at the status line, in 100% of query buffers that have a connection.
- **SC-007**: 0 false negatives: every query buffer whose text switches context shows a conflict mark, verified with canned buffers containing no server involved.
- **SC-008**: 0 false positives: buffers whose text does not switch context show no conflict mark, in 100% of the canned cases, including comments and string literals.
- **SC-009**: 0 database round trips are performed to render the status line, and the status line renders in the same time as before the change.
- **SC-010**: The execution-time message appears exactly once per execution of a conflicting query, 0 times for a non-conflicting query, and 0 times change the query's result.

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
- The indicator is deliberately **not** confirmed against the server. Asking the server would cost a
  round trip on every status-line redraw, and the answer would always be the connection's database
  anyway, so it would add cost without adding truth.
- Blocking or rewriting a query because of a detected conflict is out of scope. The conflict is
  reported, not prevented; deciding whether a switch is intentional is the author's call.
- Showing the server host, the schema, or the session id in the status line is out of scope; only
  the database and any conflict are shown.
- How the connection's database is chosen in the first place is unchanged by this feature; that
  behavior belongs to the object-source work and is not touched here.
