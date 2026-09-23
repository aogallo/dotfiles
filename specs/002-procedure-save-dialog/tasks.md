# Tasks: Procedure Save Dialog

**Input**: Design documents from `specs/002-procedure-save-dialog/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: La constitución exige validación (syntax/static checks, smoke tests relevantes, module README, feature-branch/PR workflow, active-spec closure review). Los smokes de esta feature viven en `nvim/lua/tests/db_objects_save_smoke.lua` (puro Lua, sin UI ni servidor) y se corren headless; se crean junto a cada story, no como TDD fail-first.

**Organization**: Tasks grouped by user story for independent implementation/testing.

**⚠️ Dependency note**: esta feature consume la *row shape* (campo `database`) y la fuente byte-exacta de `source()` de la feature predecesora `001-multidb-object-search`. Si 001 no está mergeada, US1/US3 no pueden validarse end-to-end sobre datos reales; el plan (y la revisión de active-spec en PR) lo documenta.

## Format: `[ID] [P?] [Story] Description`

- **T###**: Stable task ID.
- **[P]**: Parallelizable (distinct files, no dependency on incomplete work).
- **[US#]**: User story marker — the phase's `Story Link` points to the matching `spec.md` heading.
- Exact file paths in every task.

## Path Conventions

- Neovim module only: `nvim/lua/config/db_objects.lua`, `nvim/plugin/database.lua`, `nvim/lua/tests/*.lua`, `nvim/README.md`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verificación de línea base; esta feature no instalaba dependecias ni toolchain nuevo.

- [X] T001 [P] Establecer la línea base de validación: corre `nvim --headless -u nvim/init.lua '+quitall'` y `stylua --check nvim` desde la raíz del repo; ambos deben pasar ANTES de editar.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: La captura del startup root (default del diálogo) — bloquea US1/US2 (FR-002/003).

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 Implementar `M.setup(startup_root)` en `nvim/lua/config/db_objects.lua`: guarda el root read-only en un local del módulo; fallback defensivo a `vim.fn.getcwd()` si nunca se llama.
- [X] T003 [P] Conectar la captura en `nvim/plugin/database.lua`: al momento de sourcear el plugin (antes de cualquier `:cd`), leer `vim.fn.getcwd()` y pasarlo a `require('config.db_objects').setup(root)` antes de definir `:DBObjects`. (research.md → "Default target = startup root captured at plugin source time")

**Checkpoint**: Foundation ready — el default del diálogo es el launch cwd.

---

## Phase 3: User Story 1 - Save a selected procedure to a chosen directory (Priority: P1) 🎯 MVP

**Story Link**: [US1 in spec.md](./spec.md#user-story-1---save-a-selected-procedure-to-a-chosen-directory-priority-p1)

**Goal**: Tras cargar la fuente de un procedimiento, se muestra el diálogo de guardado default al startup root; confirmar escribe un archivo `<database>.<name>.sql` con el texto byte-exacto; cancelar = no-op.

**Independent Test**: Seleccionar un procedimiento, confirmar el default → aparece `<db>.<name>.sql` con el texto exacto en el directorio de arranque; cancelar (ESC) → ningún archivo y buffer intacto.

### Validation for User Story 1 (constitution smoke coverage)

- [X] T004 [P] [US1] Escribir en `nvim/lua/tests/db_objects_save_smoke.lua`: casos de `suggest_save_name` (con database → `db.proc.sql`; sin database → `proc.sql`), roundtrip de `write_source` en un temp dir (contenido en disco == source lines), y ausencia de escritura en cancel/stub de target `nil` (FR-005/006/008).

### Implementation for User Story 1

- [X] T005 [P] [US1] Implementar `suggest_save_name(database, name)` en `nvim/lua/config/db_objects.lua` (contrato `contracts/db_objects-save.md`): `database..'.'..name..'.sql'`, fallback `name..'.sql'` (FR-006).
- [X] T006 [P] [US1] Implementar `pick_save_target(initial)` en `nvim/lua/config/db_objects.lua`: navegador de directorios con `vim.fs.dir` + `vim.ui.select` (entradas: subdirectorios, `..`, `use this directory`, `type a path…` vía `vim.ui.input`); rutas relativas resueltas contra el startup root con `vim.fs.normalize`; tipo de ruta inexistente → oferta explícita `create directory` (FR-004).
- [X] T007 [US1] Implementar `write_source(lines, dir, name)` en `nvim/lua/config/db_objects.lua` vía `vim.fn.writefile`: contenido = `lines` exactas, sin transformaciones; errores → string accionable único (FR-005/009).
- [X] T008 [US1] Conectar el flujo de guardado en la rama procedure de `open_row`/`open_procedure_source` en `nvim/lua/config/db_objects.lua`: tras abrir el buffer de fuente, correr el diálogo SIEMPRE; cancel → no-op total; error de escritura → `vim.notify` accionable sin salir de Nvim (FR-001/008/009/010).

**Checkpoint**: User Story 1 fully functional — guardar un SP es elección de ubicación + confirmar.

---

## Phase 4: User Story 2 - Is asked where to save on every save (Priority: P1)

**Story Link**: [US2 in spec.md](./spec.md#user-story-2---are-asked-where-to-save-on-every-save-priority-p1)

**Goal**: El diálogo aparece en CADA guardado y su default es siempre el startup root, nunca la carpeta elegida previamente (FR-003/SC-002).

**Independent Test**: Guardar un SP a una carpeta distinta y seleccionar otro SP: el diálogo reaparece y su default es de nuevo el startup root.

### Validation for User Story 2 (constitution smoke coverage)

- [X] T009 [P] [US2] Ampliar `nvim/lua/tests/db_objects_save_smoke.lua`: simular dos saves consecutivas y comprobar que el seed inicial del picker sigue siendo el startup root en ambos casos (el valor no se muta tras una elección previa) (FR-002/003).

### Implementation for User Story 2

- [X] T010 [US2] Asegurar ausencia de estado de "último directorio": en `nvim/lua/config/db_objects.lua`, `pick_save_target` debe arrancar siempre desde el startup root y no mutar el default tras una elección (revisar T006/T008 para que ningún path elegido quede en estado compartido; el local del módulo solo guarda el root read-only).
- [X] T011 [US2] Verificar que el diálogo no tiene ningún camino de skip en el flujo de selección de procedimiento (revisión del wiring de T008 en `nvim/lua/config/db_objects.lua`) — cada selección de procedimiento dispara el save dialog.

**Checkpoint**: User Stories 1 AND 2 — invitación a guardar en cada selección, default siempre el root.

---

## Phase 5: User Story 3 - Save without collisions or data loss (Priority: P2)

**Story Link**: [US3 in spec.md](./spec.md#user-story-3---save-without-collisions-or-data-loss-priority-p2)

**Goal**: Nunca se sobrescribe en silencio; los SP homónimos de distintas bases conviven como archivos distintos (FR-006/007, SC-003/005).

**Independent Test**: Guardar sobre un archivo existente → elección explícita overwrite/keep; dos SP homónimos de bases distintas en una misma carpeta → dos archivos `db1.proc.sql`/`db2.proc.sql`.

### Validation for User Story 3 (constitution smoke coverage)

- [X] T012 [P] [US3] Ampliar `nvim/lua/tests/db_objects_save_smoke.lua`: `filereadable(path)` → `confirm_overwrite` devuelve `overwrite`|`cancel`; `suggest_save_name('db1','proc')` ≠ `suggest_save_name('db2','proc')` (FR-006/007).

### Implementation for User Story 3

- [X] T013 [P] [US3] Implementar `confirm_overwrite(path)` en `nvim/lua/config/db_objects.lua`: si `vim.fn.filereadable(path)` → `vim.ui.select` con opciones `overwrite` / `keep existing`; `keep existing` cancela con cero efectos (FR-007/008).
- [X] T014 [US3] Integrar el check de existencia antes de escribir en el flujo de `db_objects.lua` (entre `pick_save_target` y `write_source`): `filereadable` → `confirm_overwrite`; si `cancel` → abortar sin escribir (FR-007/SC-003).

**Checkpoint**: All user stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T015 [P] Documentar en `nvim/README.md` (sección DB): flujo del diálogo de guardado, default = startup root, siempre pregunta, naming `<db>.<name>.sql`, validación (comandos del quickstart), boundary de personalización (ninguno), rollback (eliminar archivos guardados es manual del usuario) — constitution XIV.
- [X] T016 [P] Correr la validación automatizada de `specs/002-procedure-save-dialog/quickstart.md` en el branch `002-procedure-save-dialog`: headless startup, `stylua --check nvim`, smokes existentes (`sybase_adapter_smoke`, `sybase_objects_smoke`) y el nuevo `db_objects_save_smoke`; todos exit 0.
- [ ] T017 Verificar que los commits estén en el feature branch `002-procedure-save-dialog` con mensajes convencionales y que la PR enlace el issue aprobado requerido.
- [ ] T018 Antes de crear la PR, revisar la relación del active spec: confirmar si la PR es related/unrelated al active spec (`002-procedure-save-dialog`) y **preguntar si la spec predecesora `001-multidb-object-search` (related, completada por esta cadena) debe cerrarse** — constitution XIII.
- [X] T019 Confirmar que los Story Links de este `tasks.md` coinciden con los headings de `spec.md` (US1/US2/US3) y que el legend `[P]/[US#]/T###` está visible — constitution XV.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sin dependencias — arranca ya.
- **Foundational (Phase 2)**: Depende de Setup; BLOQUEA todas las user stories (root default).
- **User Stories (Phase 3+)**: Dependen de Foundational. US1 (P1) primero; US2 y US3 reutilizan el wiring de US1 (`pick_save_target`, `write_source`) aunque son independent-testable.
- **Polish (Final Phase)**: Depende de las stories completas.

### User Story Dependencies

- **US1 (P1)**: Después de Foundational; sin dependencias de otras stories.
- **US2 (P2/P1)**: Después de Foundational; refina T006/T008 (no break US1).
- **US3 (P2)**: Después de Foundational; añade `confirm_overwrite` + integración sobre el flujo de US1; no rompe US1/US2.

### Within Each User Story

- Validation junto a la implementación (smoke del artículo theory), luego helpers → wiring → checkpoint de story.

### Parallel Opportunities

- T001, T003, T004, T005, T006, T009, T012, T013, T015, T016: distintos archivos / sin dependencias (marcados [P]).
- T002 → T008 → T014 son la cadena crítica (captura → wiring → overwrite).

---

## Parallel Example: User Story 1

```bash
# Helpers puros en paralelo (mismos pasos de contrato, archivos distintos):
Task: "suggest_save_name"  →  nvim/lua/config/db_objects.lua
Task: "pick_save_target"   →  nvim/lua/config/db_objects.lua  (mismo archivo: NO en paralelo real; [P] aquí = secuencial-libre)
Task: "save smoke"         →  nvim/lua/tests/db_objects_save_smoke.lua
```

> Nota: T005/T006 comparten archivo (`db_objects.lua`) pero son ediciones disjuntas (helpers); respetar el orden T005→T006→T007→T008 para evitar conflictos de stashing.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup → 2. Phase 2: Foundational (T002/T003) → 3. Phase 3: US1 (T004–T008) → 4. **STOP y VALIDATE US1** → 5. Demo del MVP.

### Incremental Delivery

1. Foundation (root default) → MVP (US1: guardar en ubicación elegida) → US2 (siempre pregunta, default root) → US3 (sin colisiones ni pérdida). Cada story se valida por separado.

### Parallel Team Strategy

- Single developer sugerido: cadena secuencial P1→P2→P3; el paralelismo [P] aplica a validación/docs (`db_objects_save_smoke.lua`, `README.md`) mientras se implementa el wiring.

---

## Notes

- [P] tasks = different files (o ediciones disjuntas) y sin dependencias de trabajo incompleto.
- [US#] tasks mapean a la phase de la story; los `Story Link` apuntan a `spec.md`.
- Esta feature depende de `001-multidb-object-search` (row shape `database`, `source()` byte-exacto); si no está mergeada, la validación end-to-end requiere PR conjunta o secuencial y la revisión de active-spec en T018.
- Commit tras cada task o grupo lógico en `002-procedure-save-dialog`, nunca en `main`.
- Antes de crear la PR, revisar si el active spec es related y preguntar si la spec relacionada completada debe cerrarse.
- Módulo afectado: `nvim/` — su README (T015) es obligatorio (constitution XIV).
- Evitar: tasks vagos, conflictos en el mismo archivo, dependencias cross-story que rompan la independencia.