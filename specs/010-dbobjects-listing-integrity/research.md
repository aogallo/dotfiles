# Phase 0 Research: Trusted `:DBObjects` Listing

**Feature**: [010-dbobjects-listing-integrity](spec.md) | **Issue**: [#92](https://github.com/aogallo/dotfiles/issues/92)
**Date**: 2026-09-25

Every NEEDS CLARIFICATION is resolved below. Findings marked **[VERIFIED]** were confirmed
against vendor documentation; findings marked **[REPO]** were confirmed by reading the code in
this repository; findings marked **[ASSUMED]** still need a live ASE instance to confirm and are
listed again in [quickstart.md](quickstart.md).

---

## R-0001 — The actual root cause of issue #92: `sysobjects.type` is `char(2)`, not one letter

**Decision**: The listing's kind filter and its row parser both assume a single-letter type. ASE
stores the type as **`char(2)`** with **two-character** values for several kinds. This is why the
reporter's object is invisible.

**[VERIFIED]** SAP ASE `sysobjects.type` is declared `char(2)` and its valid values are:

| Value | Kind | Value | Kind |
|-------|------|-------|------|
| `C` | computed column | `PR` | prepared object |
| `D` | default | `R` | rule |
| `DD` | decrypt default | `RI` | referential constraint |
| `EK` | encryption key | `RS` | precomputed result set |
| `F` | **SQLJ** function | `S` | system table |
| `N` | partition condition | `SF` | **scalar / user-defined function** |
| `IT` | instead-of trigger | `SQ` | sequence object |
| `P` | Transact-SQL / SQLJ procedure | `TR` | **trigger** |
| `PP` | predicate of a privilege | `U` | user table |
| | | `V` | view |
| | | `XP` | **extended** stored procedure |

The code in the repository disagrees with this table in three ways **[REPO]**:

- `nvim/autoload/db/adapter/sybase.vim:375` — `where type in ('U','V','P','F','X')`
  - `'X'` **never matches**. The extended-procedure value is `XP`, not `X`. Extended stored
    procedures have never been listable.
  - `'F'` matches only **SQLJ** functions. Ordinary user-defined functions are `SF`, so **the
    "function" kind has effectively only ever listed SQLJ functions** — a rare kind.
  - `'TR'` and `'IT'` are absent, so **no trigger is listable**, even though the developer named
    triggers as a kind they work with.
- `nvim/autoload/db/adapter/sybase.vim:378` — `letter =~# '^[UVPFX]$'`
  A single-character regex. Even if the query returned `TR` or `SF`, the parser would discard
  them. Two independent layers both drop them.
- `nvim/autoload/db/adapter/sybase.vim:286-295` — `s:object_kind()` compares against `'P'`,
  `'F'`, `'X'`, `'V'` — again single letters, so `SF` maps to nothing and `TR` maps to nothing.

**Rationale**: This is the highest-confidence explanation of the report. The reporter proved the
object is readable by the object-help procedure, so the object exists and its text is in the
catalog. The listing is the only thing that could hide it, and the listing had three
independently-wrong kind values and a single-character parser. A trigger or a user-defined function
in a non-default database is invisible for exactly this reason.

**Alternatives considered**:

- *Treat the type as a free 2-char string and stop filtering.* Rejected: it would pull in system
  tables, rules, defaults, partitions and encryption keys — precisely the load FR-010 forbids.
- *Keep single letters and pad the query.* Rejected: the values genuinely are 2 characters;
  padding cannot invent `TR` from nothing.

---

## R-0002 — Corrected covered-kind set

**Decision**: The listing enumerates exactly `U`, `V`, `P`, `SF`, `TR`, `XP`.

| Kind | Type value | Maps to picker kind |
|------|-----------|---------------------|
| user table | `U` | `table` |
| view | `V` | `view` |
| procedure | `P` | `procedure` |
| scalar / user-defined function | `SF` | `function` |
| trigger | `TR` | `trigger` |
| extended stored procedure | `XP` | `function` (existing behaviour for `X`) |

**[VERIFIED]** All six values appear in the SAP ASE `sysobjects` reference. `IT` (instead-of
trigger) is included in `TR` for listing purposes because an instead-of trigger is a trigger and
the developer's ask was "triggers"; **[ASSUMED]** confirm on a live server that `IT` rows are
readable in the same query.

**Rationale**: This is the developer's list (procedures, views, functions, triggers) plus tables,
which are the basis of the existing list-rows flow. It also repairs `X`→`XP` and `F`→`SF`, so the
listing gains kinds that were *supposed* to work all along.

**Unmapped kinds**: any other value (`S`, `D`, `R`, `RS`, `N`, `SQ`, `EK`, …) is not queried, so
it cannot appear. FR-011's "unmapped kind still appears" applies to a value that *is* queried but
whose picker label is unknown — with a closed set of six, that is now unreachable, and the
defence is kept as a mapping-table fallback rather than dead code (see R-0004).

---

## R-0003 — Confirming the selected database: detect by state, not by message text

**Decision**: After a database is selected, confirm it with `select db_name()` and compare against
the requested name. Do **not** parse server error text to decide whether the switch worked.

**Rationale**: The current failure is precisely that diagnostics are discarded
(`s:run_query()` returns raw lines, and `db#adapter#sybase#objects()` keeps only lines matching a
two-token pattern, so every `Msg …` line vanishes). An inverted design — *trust the absence of
errors* — is what produced a wrong listing with no warning. Inverting it to *verify the resulting
state* removes the dependency on error text entirely.

This also survives the reasons a text-based approach would be fragile **[VERIFIED]**:

- ASE reports the same condition with different wording across versions and languages.
- `sqsh` prints `Changed database context to 'X'.` on success; **`isql` does not**. Both clients
  are supported **[REPO]**, so a success message cannot be the signal.
- The actual permission failure reads `User XXX not allowed in database 'db' - only the owner of
  this database can access it.` **[VERIFIED, community]** — one of several phrasings, and it is
  not prefixed by a stable `Msg <n>` in every path.
- `valid_user()` would answer the permission question directly, but requires `manage any login`
  or `manage server` **[VERIFIED]** — a privilege this feature must not assume.

`db_name()` needs no privilege beyond what the listing already needs, and it is the state the
subsequent catalog read will actually use. Comparing it to the request is exact: match means the
read is trustworthy, mismatch means it is not.

**Alternatives considered**:

- *Parse `Msg 1501` / `Msg 10301` to detect failure.* Rejected: version- and locale-dependent, and
  `Msg 10301` ("Can't find database id for …") is raised for *some* not-found paths but not a
  reliable discriminator on its own **[VERIFIED]**.
- *Use the client's `-D` flag instead of a `use` line.* Rejected: already rejected in this codebase
  **[REPO]** — some `isql` builds do not implement it.
- *Connect a fresh session per scope.* Rejected: a new connection is far more expensive than one
  extra `select`, and it contradicts FR-042's bounded-cost requirement.

---

## R-0004 — Distinguishing "no such database" from "not permitted" (FR-007)

**Decision**: When `db_name()` mismatches, run one existence probe against the server-wide
database list. Zero rows → the database does not exist. One row → it exists but the login could
not enter it.

SQL: `select count(*) from master..sysdatabases where name = '<name>'`, issued in the **same
batch** as the confirmation so it costs no extra round trip.

**Rationale**: `master..sysdatabases` is the one catalog the chooser already reads
(`db#adapter#sybase#complete_database()` **[REPO]**) and it is readable by `public` in ASE, so the
probe needs no new privilege. FR-007 requires the two cases be distinguishable, and the two
messages lead the developer to different actions — a typo versus a permission request.

**Alternatives considered**:

- *Infer from the diagnostic text.* Rejected, same reason as R-0003.
- *Probe `db_id()`.* **[ASSUMED]** `db_id()` may return NULL for a database the login cannot
  access, which would conflate the two cases. The explicit `master..sysdatabases` count does not
  have that ambiguity; the confirm-on-server step in [quickstart.md](quickstart.md) must check it.

---

## R-0005 — Making the row format self-identifying, so silent drops are impossible

**Decision**: Every listing row is emitted with a fixed marker prefix and a single `~` delimiter,
and the client only accepts lines carrying that marker. Everything else is classified as a
diagnostic or a dropped row and counted.

Shape: `select 'DOBJ~' + convert(varchar(255), name) + '~' + type from sysobjects
where type in ('U','V','P','SF','TR','XP') order by name`

Plus a count row in the same batch: `select 'DCNT~' + convert(varchar(20), count(*)) …`

**Rationale**: Every silent-drop mechanism in the current code comes from parsing *unmarked*
free-form output **[REPO]**:

- `matchstr(line, '^\s*\zs\S\+\ze\s')` requires the name to be followed by whitespace, so a
  truncated final column loses the row.
- The name and type are read positionally as "first token" and "second token", so a heading, a
  separator, a `Changed database context` line, a `(N rows affected)` trailer, or a wrapped
  long name all shift or destroy the parse. The current code throws all of these away silently.

With a marker, a heading cannot be mistaken for a row, a wrapped name cannot produce a
half-object, and every non-marker line is *counted and surfaced* rather than dropped (FR-012,
FR-022, FR-030). The `DCNT~` row satisfies FR-029's "objects reported" without a second round
trip, keeping SC-010's budget intact.

`~` is chosen because object names may legally contain spaces, punctuation and most printable
characters; `~` is not valid unquoted in an ASE identifier, and `name` is the *first* field so a
name containing `~` can only ever be the prefix before the first delimiter.

**Alternatives considered**:

- *Pad every column to a fixed width and slice by offset.* Rejected: brittle against a different
  `isql` width or a `sqsh` default; the codebase already fights this with `-w 32000` **[REPO]**.
- *Return each field on its own result line.* Rejected: doubles the output volume and the round
  trips for a listing the developer explicitly does not want to be heavy.

---

## R-0006 — The direct-open entry reuses the existing source reader

**Decision**: The picker's direct-open entry supplies a name and calls the **existing** source
path with the existing configured source mode. No new SQL, no new mode, no new dependency.

**Rationale**: `db#adapter#sybase#source(url, name)` already handles catalog mode, the
`showsql` opt-in, hidden/encrypted text detection, single-quote escaping, and chunk
reassembly **[REPO]**. The reporter's manual query is `exec sp_helptext 'objeto', null, null,
'showsql'` — which is *exactly* what `g:db_sybase_source_mode = 'showsql'` already produces
**[REPO]**. So the "execute the function with the params you provide" capability the developer
asked for **already exists in the codebase** and is simply not reachable from a name that is not
in the listing. The work is to expose it, not to build it.

This is why the direct-open entry is cheap enough to keep inside the server-load budget (FR-036):
it issues nothing until the developer confirms a name, and then reuses the one query the
object-opening path already makes.

**Guard — FR-035**: the entry requires a confirmed scope. Without that guard it would read from
an unknown database, which is the exact defect being fixed. This is the single most important
constraint on the new entry.

**Scope guard — FR-039**: the entry operates on the confirmed database only and rejects a
qualified two-part name, so the capability closed in
`specs/archive/2026-09-25-001-multidb-object-search/` stays closed. To reach another database the
developer changes scope first.

**Assumption confirmed by the developer** (2026-09-25): "execute the function with the params you
provide" means **reuse the path that already exists** — read the object's source with the tool's
current source mode. It is explicitly *not* executing the object. R-0006 stands as written; no
redesign needed and no new SQL, mode, or dependency is introduced.

---

## R-0007 — Where the change lands

**Decision**: Three files, no new module, no new dependency.

| File | Change |
|------|--------|
| `nvim/autoload/db/adapter/sybase.vim` | corrected kind filter, marker-based query + count row, `db_name()` confirmation, existence probe, diagnostic surfacing, per-row kind mapping for two-letter types |
| `nvim/lua/config/db_objects.lua` | confirmed-scope state, scope label from the confirmed value, direct-open entry, failure messages, reconciliation display |
| `nvim/README.md` | corrected documented kind set, new entry, updated validation commands |

New smoke coverage in `nvim/lua/tests/`, following the existing stub pattern
(`sybase_objects_smoke.lua`, `db_objects_scope_smoke.lua`, `db_objects_save_smoke.lua` **[REPO]**).

**Rationale**: Constitution IV (modularity) and XI (simplicity). The adapter already owns all
Sybase SQL; the Lua module already owns the picker flow. Splitting either would add an
abstraction with no concrete requirement.

**Documentation correction (FR-038)**: `db_objects.lua:137-139` documents the listing query as
`type in ('P','FN','IF','TF','V','U')` **[REPO]** — a *third* kind set, matching neither the code
nor the vendor table. All three must converge on the R-0002 set.

---

## R-0008 — Request budget per invocation

**Decision**: At most 2 client invocations per `:DBObjects` invocation — one confirmation batch,
one listing batch — and 1 more only if the developer uses the direct-open entry.

| Step | Client invocations |
|------|--------------------|
| Open listing, no scope change | 1 (confirmation + existence probe + listing + count, one batch) |
| Change scope | 1 (same batch shape) |
| Open a listed object | 1 (the existing source read) |
| Direct-open by name | 1 (the existing source read) |
| Direct-open not used | **0** extra (FR-036) |

**Rationale**: This satisfies FR-041 to FR-044 and SC-010 — the count is identical for a database
with 50 objects and one with 50,000, because nothing iterates databases or objects. Folding the
confirmation, existence probe, listing and count into a *single batch* is what holds the budget at
1 rather than 3. The developer's performance condition is met structurally, not by measurement.

**Rejected**: verifying each database in the chooser list up front (one request per database —
explicitly forbidden by the Assumptions), and pre-computing the whole listing (no benefit, blocks
the UI).

---

## Resolved clarifications

| Marker | Resolution |
|--------|-----------|
| Q1 — object-kind coverage | Answered by the developer: curated kinds, no system sweep, avoid server load. Reframed as R-0002 + R-0006 (reachability instead of enumeration). |
| Spec assumption — "params you provide" | **Confirmed 2026-09-25**: reuse the existing source path (`g:db_sybase_source_mode`), not object execution. R-0006. |
| Technical Context unknowns | Resolved in [plan.md](plan.md) Technical Context; no `NEEDS CLARIFICATION` remains. |
