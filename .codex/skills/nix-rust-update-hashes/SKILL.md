---
name: nix-rust-update-hashes
description: Use when Codex updates or fixes Nix buildRustPackage update scripts, especially cargoHash, fetchCargoVendor, fakeHash, repeated nix build hash discovery, or avoiding full Rust package builds during package update runs.
---

# Nix Rust Update Hashes

Use this skill when a Rust package updater in this repository discovers hashes by writing fake hashes and repeatedly building the final package. Prefer prefetching the source and building only the Cargo vendor fixed-output derivation; reserve the final package build for explicit verification.

## Workflow

1. Read the package expression and updater first:

```bash
rtk read pkgs/<name>/default.nix
rtk read pkgs/<name>/update.sh
```

2. Identify these fields in `default.nix`:

- `version`
- `src = fetchFromGitHub { ... hash = "..."; }`
- `cargoHash`

3. For a GitHub tag source matching `fetchFromGitHub`, compute the source hash without building the package:

```bash
base32_hash="$(nix-prefetch-url --unpack --type sha256 \
  "https://github.com/<owner>/<repo>/archive/refs/tags/v<version>.tar.gz")"
nix hash convert --hash-algo sha256 --from nix32 --to sri "$base32_hash"
```

4. Compute `cargoHash` by building only `fetchCargoVendor(...).vendorStaging` with `hash = ""`. Use the repo flake's pinned nixpkgs; do not rely on `nix-prefetch` importing its own nixpkgs.

```bash
nix build --impure --no-link --no-write-lock-file --expr '
let
  flake = builtins.getFlake "path:/abs/repo";
  pkgs = import flake.inputs.nixpkgs {
    system = builtins.currentSystem;
  };
in
(pkgs.rustPlatform.fetchCargoVendor {
  pname = "<name>";
  version = "<version>";
  src = pkgs.fetchFromGitHub {
    owner = "<owner>";
    repo = "<repo>";
    tag = "v<version>";
    hash = "<source-sri>";
  };
  hash = "";
}).vendorStaging
'
```

Parse the `got: sha256-...` value from the fixed-output hash mismatch and write it to `cargoHash`.

5. Update the script so normal updater runs do not compile the Rust package:

- Exit early when target version equals current version and both hashes are non-fake.
- Recompute hashes only when the version changed, a hash is fake/empty, or an explicit refresh flag is set.
- Make the final package build opt-in, for example `RTK_UPDATE_VERIFY=1`.
- Keep failure paths explicit. If the vendor derivation succeeds while `hash = ""`, treat that as unexpected.

## Implementation Pattern

Use a helper like this inside `update.sh`:

```bash
extract_got_hash() {
  sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | tail -n1
}
```

Run the cargo vendor expression, tee stderr/stdout into a temporary log, require a nonzero status, and extract `got:` from the log. Remove the temp file after extraction.

## Pitfalls

- `nix-prefetch` can mix registry/default nixpkgs with the repo's pinned flake nixpkgs. Prefer a direct `nix build --expr` through `builtins.getFlake "path:/abs/repo"` for Cargo vendor hashes.
- Building `pkgs.rustPlatform.fetchCargoVendor { ... }` directly may not expose a prefetchable source derivation to `nix-prefetch`; targeting `.vendorStaging` gives the fixed-output hash mismatch needed for `cargoHash`.
- Do not mutate `default.nix` to fake hashes before source prefetching; fetch the source hash directly, then write final values once.
- Do not leave routine update scripts doing final package builds just to discover hashes. Keep full builds as validation, not as hash calculation.

## Validation

After editing an updater:

```bash
bash -n pkgs/<name>/update.sh
nix shell nixpkgs#shellcheck -c shellcheck -s bash pkgs/<name>/update.sh
<VERSION_OVERRIDE_ENV>=<current-version> pkgs/<name>/update.sh
<VERSION_OVERRIDE_ENV>=<current-version> pkgs/<name>/update.sh
nix build --dry-run path:/abs/repo#<name>
nix flake check path:/abs/repo
```

The first updater run should refresh fake or stale hashes without building the final installable. The second run should exit early when nothing changed.
