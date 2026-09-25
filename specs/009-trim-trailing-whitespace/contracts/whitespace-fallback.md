# Contract: Whitespace Cleanup Fallback and Failure Reporting

**Branch**: `009-trim-trailing-whitespace` | **Date**: 2026-09-25
**Spec**: [spec.md](../spec.md) (US1, US2) | **Data model**: [data-model.md](../data-model.md)

The user-visible contract of the save-time whitespace behavior: what is guaranteed, and what the
editor reports when it cannot be guaranteed.

## 1. Save-time guarantees

For every file type, on a normal save:

| Situation | Guarantee |
| --- | --- |
| Main formatter available | the main formatter's result is the file's content; the whitespace-only steps do not run |
| Main formatter unavailable, file type has a whitespace fallback | trailing whitespace is removed; nothing else is touched |
| Main formatter unavailable, file type has no whitespace fallback | nothing is reformatted, and a message names the file type |
| Auto-formatting disabled by the user | no cleanup runs at all |

## 2. Guarantees that hold for Markdown

1. A Markdown file is trimmed whether or not a project configuration routes it to a different
   formatter. This is the change this feature makes.
2. Two trailing spaces inside Markdown prose survive as long as the main formatter is available.
3. When the main formatter is unavailable, the fallback trims trailing whitespace bluntly, and
   two-space prose hard breaks in that document are flattened. This is a known, accepted degradation,
   and it applies only on machines where the formatter is missing.
4. Fenced code blocks and indented examples are never touched.

## 3. Failure reporting contract

| Situation | Message | Frequency |
| --- | --- | --- |
| No formatter and no fallback available for the file type | one warning naming the file type | on **every** failing save, not only the first |
| Main formatter missing but fallback available | none | the cleanup ran; there is nothing to report |
| A formatter is present but errors while running | the existing formatter error reporting | unchanged |

Rules:

1. The message is produced by this configuration, and exactly one message appears per failing save.
   The formatting toolchain's own first-failure notification is turned off to avoid a duplicate.
2. The message names the file type and nothing about the file's content.
3. The message never appears for a save that the user explicitly excluded from formatting.

## 4. Interaction contract

1. Exactly one mechanism cleans whitespace per save. No auto command performs cleanup.
2. The reporting check never modifies the buffer, so it cannot race the formatting path.
3. The reporting check observes the same conditions that decide whether formatting runs, so it cannot
   report a failure for a save that was never going to be formatted.
