# Quickstart: Organize Keyboard and Optional Dependencies

## Prerequisites

- Run from the repository root.
- Do not edit the real keyboard layout while validating this feature.

## Static Validation

1. Validate Neovim dependency status:

   ```sh
   setup/validate-nvim-deps.sh
   ```

   **Expected**: Required missing count is zero. Missing `shfmt` or `shellcheck` remain clearly marked optional with install hints.

2. Preview optional dependency resolution:

   ```sh
   setup/bootstrap-nvim-deps.sh --dry-run --include-optional
   ```

   **Expected**: The command previews optional dependency handling without installing by default.

3. Validate repository whitespace:

   ```sh
   git diff --check
   ```

## Keyboard Organization Validation

1. Confirm the Iris keyboard config is no longer active at the repository root:

   ```sh
   test ! -e iris_rev__5.json
   ```

2. Confirm the moved file exists:

   ```sh
   test -f keyboard/iris_rev__5.json
   ```

3. Confirm the JSON parses:

   ```sh
   ruby -rjson -e 'JSON.parse(File.read("keyboard/iris_rev__5.json"))'
   ```

4. Confirm discoverability:

   ```sh
   test -f keyboard/README.md
   grep -n "iris_rev__5.json" keyboard/README.md
   grep -n "keyboard/" README.md
   ```

## Content Preservation

Before moving the file, capture a checksum if needed:

```sh
shasum -a 256 iris_rev__5.json
```

After moving the file, compare against the pre-move checksum:

```sh
shasum -a 256 keyboard/iris_rev__5.json
```

**Expected**: The checksum is unchanged when the move preserves content exactly.

## Rollback

Rollback is moving `keyboard/iris_rev__5.json` back to `iris_rev__5.json` and reverting the documentation changes, or reverting the feature commit. Optional dependency policy rollback is reverting any documentation or script output changes made for this feature.
