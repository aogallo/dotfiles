# Feature Specification: Tokyonight Contrast Colors

**Feature Branch**: `feat/tokyonight-contrast-colors`  
**Created**: 2026-07-15  
**Status**: Draft  
**Input**: User description: "Quiero que explores la configuracion del colorschem que es tokyonight porque quiero que mejores los colores ya que los colores muy palidos me cuesta verlos ya sea que este en codigo o nombre de archvios. Especificamente y el que me interesa mucho es el color en el picker de explorer para los archivos que se revelan al presionar H los dotfiles, tambien me gustraia que los comentarios puedan ser legigles de mejor manera. Adicionalmente quiero agregar que cuando estoy en el explorer y estoy en el archivo con el color de la linea que hace referencia al archivo en el que estoy tambien me cuesta verlo. Uso Ghostty y no se si habra una configuracion que deba hacer desde ahi."

## User Scenarios & Testing

### Primary User Story

As the dotfiles owner, I want the current Tokyonight-based Neovim appearance to use stronger contrast for low-visibility text and active explorer states so hidden dotfiles, current-file rows, and code comments are readable without eye strain.

### Acceptance Scenarios

1. **Given** the Neovim explorer is open, **When** hidden files are revealed with `H`, **Then** dotfile names are visually distinct and readable against the current background.
2. **Given** a source file contains comments, **When** the file is opened with the configured colorscheme, **Then** comments remain clearly readable and are not washed out or overly pale.
3. **Given** the explorer highlights the row for the current file, **When** the user navigates the explorer, **Then** the current-file row is easy to identify without hiding the filename or confusing it with selection, git status, or diagnostics.
4. **Given** normal file names, directories, and code tokens are visible, **When** contrast improvements are applied, **Then** the overall Tokyonight visual identity remains recognizable and no major UI area becomes harder to read.
5. **Given** the user runs Neovim inside Ghostty, **When** contrast issues are evaluated, **Then** the implementation determines whether Neovim theme changes are sufficient or whether Ghostty configuration should be documented as a separate follow-up.
6. **Given** a future reviewer validates the change, **When** they inspect representative files and explorer states, **Then** they can confirm the intended readability improvement without relying on private machine-specific settings.

### Edge Cases

- Hidden dotfiles may inherit a muted or dimmed style that is readable for normal files but too pale when revealed.
- Comments may intentionally be lower contrast than code, but they must not become so faint that reading code context is difficult.
- Git status, diagnostics, selected rows, and directory names in the explorer must remain distinguishable after color adjustments.
- The current-file row and the selected row may use different highlight groups and must not collapse into the same visual state.
- Ghostty theme, background, opacity, font rendering, or terminal palette can affect perceived contrast even when Neovim highlight groups are correct.
- Terminal background, font rendering, and display calibration can affect perceived contrast, so validation should use the configured Neovim environment rather than screenshots alone.
- Improvements should avoid making every muted element bright; the goal is targeted readability, not flattening the whole theme.

## Requirements

### Functional Requirements

- **FR-001**: The feature MUST identify which current Neovim theme and explorer configuration controls the low-contrast text reported by the user.
- **FR-002**: The feature MUST improve readability for hidden dotfile names revealed with `H` in the Neovim explorer/picker.
- **FR-003**: The feature MUST improve readability for code comments across normal source buffers.
- **FR-004**: The feature MUST improve readability for the explorer row that represents the current file.
- **FR-005**: The feature MUST preserve the current Tokyonight-based theme as the visual foundation unless a later user decision explicitly changes themes.
- **FR-006**: The feature MUST keep file names, directory names, git indicators, diagnostics, selected rows, current-file rows, and normal code tokens visually distinguishable.
- **FR-007**: The feature MUST determine whether Ghostty settings contribute to the contrast problem and document whether Ghostty changes are necessary or out of scope.
- **FR-008**: The feature MUST avoid machine-specific or private configuration and remain portable as part of the shared Neovim dotfiles.
- **FR-009**: The feature MUST include validation steps that prove hidden dotfiles, current-file rows, and comments are easier to read in the configured Neovim environment.
- **FR-010**: The feature MUST document any remaining readability tradeoffs if a color cannot be made more visible without harming another important UI state.

## Key Entities

- **Theme Palette**: The active Tokyonight color choices that define the base Neovim appearance.
- **Hidden Dotfile Entry**: A file or directory name beginning with `.` that appears in the explorer only after hidden files are revealed.
- **Comment Text**: Source-code comments rendered with syntax highlighting.
- **Explorer/Picker Item**: A visible row in the file explorer or picker, including file name, directory, selection, git status, and diagnostic context.
- **Current File Row**: The explorer row that refers to the file currently open or focused in Neovim.
- **Terminal Rendering Context**: The Ghostty theme, palette, background, opacity, and font rendering choices that can influence perceived contrast.
- **Readability Check**: A manual or automated validation step that confirms contrast improvements in representative UI states.

## Assumptions

- The current theme is Tokyonight with the `moon` style configured in the Neovim dotfiles.
- The explorer/picker behavior is provided by the current Neovim explorer integration, where `H` toggles hidden file visibility.
- The user wants targeted contrast improvements, not a full colorscheme replacement.
- The highest-priority readability targets are hidden dotfile names in the explorer/picker and code comments.
- The current-file row in the explorer is also a priority readability target.
- Ghostty is the user's terminal emulator, but the repository does not currently contain a versioned Ghostty configuration.
- Ghostty changes should be recommended only if Neovim highlight adjustments are insufficient or if a terminal setting is clearly contributing to contrast issues.
- Exact color values will be chosen during planning/implementation after inspecting the current theme integration and representative UI states.

## Success Criteria

- **SC-001**: The user can identify hidden dotfile entries in the explorer within 2 seconds after pressing `H` during manual validation.
- **SC-002**: The user can read comments in representative Lua, shell, Markdown, and config files without needing to move the cursor, select text, or switch themes.
- **SC-003**: A reviewer can identify the current-file row in the explorer within 2 seconds without confusing it with the selected row.
- **SC-004**: A reviewer can verify at least 4 representative UI states: hidden dotfiles revealed, current-file row, normal source comments, and selected explorer row.
- **SC-005**: The implementation documents whether Ghostty needs any follow-up configuration and why.
- **SC-006**: The implementation introduces no machine-specific paths, secrets, or local-only overrides.
- **SC-007**: Neovim starts successfully with the updated configuration, and the colorscheme loads without errors.
