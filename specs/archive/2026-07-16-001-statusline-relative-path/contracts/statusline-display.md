# Contract: Statusline File Display

This contract defines the user-visible behavior of the statusline file segment.

## Inputs

| Input | Meaning |
|-------|---------|
| Starting directory | Directory where the editor session was opened |
| Active buffer path | Full path of the active file, when available |
| Buffer type | Whether the active buffer is a normal file, unnamed buffer, or special buffer |
| Modified state | Whether the active buffer has unsaved changes |
| Edit restriction state | Whether the active buffer is read-only or not modifiable |
| Window width | Available display width for the statusline |

## Outputs

| Output | Requirement |
|--------|-------------|
| Relative path text | Normal files inside the starting directory display without the absolute prefix |
| Outside-directory fallback | Files outside the starting directory remain readable and do not break rendering |
| Unnamed label | Unnamed buffers show a clear placeholder |
| Special-buffer label | Special buffers show a meaningful label instead of empty or misleading paths |
| Modified indicator | Unsaved changes are visible through a compact marker |
| Read-only indicator | Restricted editing state is visible through a compact marker |

## Scenarios

1. Given the editor starts in `/repo`, when `/repo/nvim/lua/statusline.lua` is active, then
   the file segment displays `nvim/lua/statusline.lua`.
2. Given the editor starts in `/repo`, when `/repo/README.md` is active and modified, then
   the file segment displays `README.md` plus a compact modified marker.
3. Given the editor starts in `/repo`, when an unnamed buffer is active, then the file segment
   displays a clear unnamed-buffer label.
4. Given a special buffer is active, then the file segment displays a meaningful special-buffer
   label and keeps the rest of the statusline readable.
5. Given a narrow window, then the active file name remains visible even if parent directory
   context must be shortened.

## Non-Goals

- Do not add new persistent statusline sections unrelated to file orientation or editing state.
- Do not change Git, diagnostics, filetype, encoding, or cursor-position behavior unless needed
  to keep the layout readable.
- Do not add a new plugin dependency.
