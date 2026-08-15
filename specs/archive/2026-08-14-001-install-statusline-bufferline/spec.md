# Feature Specification: Statusline and Bufferline Upgrade

**Feature Directory**: `specs/001-install-statusline-bufferline`  
**Created**: 2026-08-14  
**Status**: Draft  
**Input**: User request: "quiero que instales https://github.com/nvim-lualine/lualine.nvim y https://github.com/akinsho/bufferline.nvim ... quiero que borres todo lo que estos plugins van a mejorar adicional si hay keymaps que se deban de agregar quiero que se siga utilizando la manera que hemos llevado que se acorde al proceso ejemplo <leader>c para codigo"

## Clarifications

### Session 2026-08-14

- Q: ¿Qué hacemos con los keymaps existentes `<leader>bn`/`<leader>bp`? → A: Eliminar; la navegación entre buffers pasa a `<S-h>`/`<S-l>` (Shift+h / Shift+l) como único mecanismo, muteados de which-key.
- Q: ¿Qué composición de dashboard de Snacks? → A: Header + Recent Files + Keymaps (sin Projects ni git status ni startup).
- Q: ¿El dashboard es cambio separado? → A: Incluirlo dentro de la feature 001-install-statusline-bufferline (mismo spec, tasks y PR).
- Q: ¿Qué header usa el dashboard? → A: Sin header personalizado; el dashboard usa el header por defecto de Snacks. Se descartaron propuestas con llaves `{ }` y con ASCII art de texto `neovim` para no verse no profesional al compartir pantalla con clientes.
- Q: ¿La sección Keymaps del dashboard muestra título? → A: Sí, título `Keymaps` con ícono `` (misma convención que `Recent Files`).

## User Scenarios & Testing

### User Story 1 - See editor status clearly (Priority: P1)

As the dotfiles user, I want the editor to show a clear status area so I can understand the current file, mode, diagnostics, and workspace context without relying on scattered or redundant UI elements.

**Why this priority**: The status area is constantly visible and affects every editing session.

**Independent Test**: Open the editor in a project file and confirm the status area presents the active editing context clearly without duplicated legacy status UI.

**Acceptance Scenarios**:

1. **Given** the editor opens a file, **When** the UI finishes loading, **Then** a modern status area is visible and reflects the active file context.
2. **Given** the active file has diagnostics or version-control context available, **When** those indicators are present, **Then** they appear in the status area without conflicting with other UI elements.
3. **Given** older status presentation already exists, **When** the new status area is enabled, **Then** redundant status configuration is removed or disabled.

---

### User Story 2 - Understand and manage open buffers (Priority: P1)

As the dotfiles user, I want a clear buffer list so I can see, switch, and close open files without losing orientation during multi-file work.

**Why this priority**: Buffer visibility and navigation are core to day-to-day editing speed.

**Independent Test**: Open multiple files, move between them, and confirm the buffer list updates to show the active buffer and available buffers.

**Acceptance Scenarios**:

1. **Given** multiple files are open, **When** the user switches between files, **Then** the active buffer is clearly indicated.
2. **Given** a buffer is closed, **When** the close action completes, **Then** the buffer list updates and focus moves predictably to another open buffer.
3. **Given** legacy tabs, buffer indicators, or custom buffer UI already exist, **When** the new buffer list is enabled, **Then** duplicated or overlapping UI is removed.

---

### User Story 3 - Keep keymaps consistent by workflow domain (Priority: P2)

As the dotfiles user, I want buffer navigation mapped to `<S-h>`/`<S-l>` (Shift+h / Shift+l) so moving between buffers feels natural, and I want the now-redundant leader buffer keymaps removed so the configuration stays clean.

**Why this priority**: Inconsistent shortcuts create long-term friction and make the configuration harder to maintain.

**Independent Test**: Press `<S-h>` and `<S-l>` to move between open buffers and confirm the old `<leader>bn`/`<leader>bp` mappings no longer exist.

**Acceptance Scenarios**:

1. **Given** multiple buffers are open, **When** I press `<S-h>` (Shift+h), **Then** focus moves to the next buffer.
2. **Given** multiple buffers are open, **When** I press `<S-l>` (Shift+l), **Then** focus moves to the previous buffer.
3. **Given** the old buffer navigation keymaps existed, **When** the feature is complete, **Then** `<leader>bn` and `<leader>bp` are removed and do not appear in which-key.
4. **Given** a new shortcut is needed for status or buffer workflows, **When** it is added, **Then** it uses the same grouping style as the existing configuration.
5. **Given** no shortcut is necessary for a workflow, **When** the feature is complete, **Then** no extra shortcut is added only for symmetry.

---

### User Story 4 - Welcome screen dashboard (Priority: P2)

As the dotfiles user, I want a dashboard shown on startup with a header, recent files, and keymaps so I can start work quickly without typing commands.

**Why this priority**: Improves startup UX but does not affect day-to-day editing once a file is open.

**Independent Test**: Open the editor with no arguments and confirm the dashboard renders the header, recent files, and keymaps sections.

**Acceptance Scenarios**:

1. **Given** the editor starts without a file argument, **When** startup completes, **Then** a dashboard appears with a header, recent files, and keymaps sections.
2. **Given** the recent files section, **When** the user selects an entry, **Then** the file opens.
3. **Given** a keymaps entry, **When** the user activates it, **Then** the mapped action runs (e.g. find file, find text).
4. **Given** a normal file is opened, **When** editing starts, **Then** the dashboard is not shown.

## Requirements

### Functional Requirements

- **FR-001**: The editor MUST provide a clear status area showing the current editing context during normal use.
- **FR-002**: The status area MUST replace or disable redundant existing status presentation that overlaps with the new status experience.
- **FR-003**: The editor MUST provide a visible buffer list when multiple files are open.
- **FR-004**: The buffer list MUST clearly identify the active buffer.
- **FR-005**: The buffer list MUST update after opening, switching, and closing buffers.
- **FR-006**: Existing UI elements that duplicate the new buffer list MUST be removed or disabled.
- **FR-007**: Any new keymaps MUST follow the existing workflow-domain convention used by the dotfiles.
- **FR-008**: New keymaps MUST only be added when they improve a concrete workflow such as buffer navigation or buffer closing.
- **FR-009**: The resulting editor UI MUST remain usable without requiring the user to remember plugin-specific commands for common buffer/status workflows.
- **FR-010**: The configuration MUST keep the editor startup experience stable, without visible errors during launch.
- **FR-011**: `<S-h>` (Shift+h) MUST move to the next buffer and `<S-l>` (Shift+l) MUST move to the previous buffer.
- **FR-012**: The `<S-h>`/`<S-l>` buffer navigation keymaps MUST be muted so they do not appear in which-key.
- **FR-013**: The redundant `<leader>bn` and `<leader>bp` keymaps MUST be removed.
- **FR-014**: A startup dashboard MUST render with a header, recent files, and keymaps sections.
- **FR-015**: The dashboard MUST allow opening recent files and triggering the mapped keymap actions.

### Edge Cases

- Opening the editor with a single buffer should not show confusing empty buffer controls.
- Closing the active buffer when multiple buffers are open should leave the user focused on a predictable remaining buffer.
- Opening unnamed or unsaved buffers should not break the buffer list or status area.
- Projects without version-control or diagnostic information should still show a useful status area.
- Existing shortcuts should not be overwritten unless they directly conflict with the new workflow and the replacement is intentional.
- The native `H` (top of window) and `L` (bottom of window) motions are overridden by `<S-h>`/`<S-l>`; this is an accepted tradeoff chosen by the user.

## Success Criteria

### Measurable Outcomes

- **SC-001**: In a manual editing session with three open files, the user can identify the active file from the buffer list within 2 seconds.
- **SC-002**: In a manual editing session with three open files, the user can switch between visible buffers and close one buffer without UI errors.
- **SC-003**: On editor launch, the status area and buffer list appear without startup error messages in 100% of smoke-test launches.
- **SC-004**: A configuration review finds no duplicated legacy status or buffer UI that overlaps with the new experience.
- **SC-005**: A keymap review confirms 100% of newly added shortcuts follow the existing workflow-domain convention.
- **SC-006**: In a manual session with three open files, pressing `<S-h>` and `<S-l>` moves between buffers and the old `<leader>bn`/`<leader>bp` mappings are confirmed removed.

## Assumptions

- The requested statusline and bufferline improvements are intended to become the primary UI for status and buffer visibility.
- Existing configuration that becomes redundant should be removed rather than kept as disabled legacy code.
- Keymaps should be added only for actions that materially improve daily editing workflows.
- The established keymap convention groups shortcuts by workflow purpose, such as code actions under a code-related leader prefix.
