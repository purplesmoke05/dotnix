#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${OPENCLAW_CONTAINER:-openclaw}"
OPENCLAW_CLI_VERSION="${OPENCLAW_CLI_VERSION:-2026.2.26}"
TARGET_MODEL_ID="${OPENCLAW_GEMINI31_MODEL_ID:-gemini-3.1-pro-preview}"

usage() {
  cat <<EOF
Usage: ./scripts/patch-openclaw-gemini31-cli-model.sh

Environment overrides:
  OPENCLAW_CONTAINER         Podman container name (default: openclaw)
  OPENCLAW_CLI_VERSION       openclaw npx version (default: 2026.2.26)
  OPENCLAW_GEMINI31_MODEL_ID model id to add under google-gemini-cli (default: gemini-3.1-pro-preview)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! podman container exists "$CONTAINER"; then
  echo "Container \"$CONTAINER\" does not exist." >&2
  exit 1
fi

if [[ "$(podman inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)" != "true" ]]; then
  echo "Container \"$CONTAINER\" is not running." >&2
  exit 1
fi

# Ensure npx cache for the selected version exists before patching.
podman exec "$CONTAINER" npx -y "openclaw@${OPENCLAW_CLI_VERSION}" --version >/dev/null

podman exec \
  -e OPENCLAW_CLI_VERSION="$OPENCLAW_CLI_VERSION" \
  -e OPENCLAW_GEMINI31_MODEL_ID="$TARGET_MODEL_ID" \
  "$CONTAINER" node - <<'NODE'
const fs = require("fs");
const path = require("path");

const openclawVersion = process.env.OPENCLAW_CLI_VERSION;
const targetModelId = process.env.OPENCLAW_GEMINI31_MODEL_ID || "gemini-3.1-pro-preview";
const npxRoot = "/root/.npm/_npx";

function findOpenclawDir() {
  const dirs = fs.readdirSync(npxRoot, { withFileTypes: true }).filter((entry) => entry.isDirectory());
  const candidates = [];
  for (const entry of dirs) {
    const base = path.join(npxRoot, entry.name, "node_modules", "openclaw");
    const pkgJsonPath = path.join(base, "package.json");
    if (!fs.existsSync(pkgJsonPath)) continue;
    try {
      const pkg = JSON.parse(fs.readFileSync(pkgJsonPath, "utf8"));
      if (pkg.version !== openclawVersion) continue;
      const stat = fs.statSync(base);
      candidates.push({ base, mtimeMs: stat.mtimeMs });
    } catch {
      // ignore broken cache entries
    }
  }
  candidates.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return candidates[0]?.base;
}

function patchCatalog(filePath) {
  const src = fs.readFileSync(filePath, "utf8");
  const startMarker = '    "google-gemini-cli": {';
  const endMarker = '    "google-vertex": {';
  const start = src.indexOf(startMarker);
  const end = src.indexOf(endMarker, start);
  if (start < 0 || end < 0 || end <= start) {
    throw new Error("google-gemini-cli section not found");
  }
  const section = src.slice(start, end);
  if (section.includes(`"${targetModelId}": {`)) {
    return { changed: false };
  }

  const anchorId = '"gemini-3-pro-preview": {';
  const anchorStart = section.indexOf(anchorId);
  if (anchorStart < 0) {
    throw new Error("gemini-3-pro-preview block not found");
  }
  const anchorEndNeedle = "\n        },";
  const anchorEnd = section.indexOf(anchorEndNeedle, anchorStart);
  if (anchorEnd < 0) {
    throw new Error("gemini-3-pro-preview block end not found");
  }

  const anchorBlock = section.slice(anchorStart, anchorEnd + anchorEndNeedle.length);
  const extraBlock = anchorBlock
    .replace(/gemini-3-pro-preview/g, targetModelId)
    .replace("Gemini 3 Pro Preview", "Gemini 3.1 Pro Preview");

  const patchedSection =
    section.slice(0, anchorEnd + anchorEndNeedle.length) +
    "\n" +
    extraBlock +
    section.slice(anchorEnd + anchorEndNeedle.length);
  const patched = src.slice(0, start) + patchedSection + src.slice(end);

  const backupPath = `${filePath}.bak-${Date.now()}`;
  fs.copyFileSync(filePath, backupPath);
  fs.writeFileSync(filePath, patched, "utf8");
  return { changed: true, backupPath };
}

const openclawDir = findOpenclawDir();
if (!openclawDir) {
  throw new Error(`openclaw@${openclawVersion} cache directory not found under ${npxRoot}`);
}

const catalogPath = path.join(
  openclawDir,
  "..",
  "@mariozechner",
  "pi-ai",
  "dist",
  "models.generated.js"
);

if (!fs.existsSync(catalogPath)) {
  throw new Error(`models catalog file not found: ${catalogPath}`);
}

const result = patchCatalog(catalogPath);
if (result.changed) {
  console.log(`patched: ${catalogPath}`);
  console.log(`backup: ${result.backupPath}`);
} else {
  console.log(`already present: ${catalogPath}`);
}
NODE

echo "Verifying model visibility: google-gemini-cli/${TARGET_MODEL_ID}"
podman exec "$CONTAINER" \
  npx -y "openclaw@${OPENCLAW_CLI_VERSION}" models list --provider google-gemini-cli --json
