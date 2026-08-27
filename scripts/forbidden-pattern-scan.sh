#!/usr/bin/env bash
#
# Supply-chain implant scanner.
#
# Detects the class of attack that has repeatedly hit JS/RN starter templates:
# a legitimate-looking config file with an obfuscated payload appended after a
# long run of whitespace padding, so the payload sits off-screen in an editor.
#
# Runs entirely from the repo. It deliberately does not download anything at
# scan time -- a scanner fetched over the network is itself a supply-chain
# dependency, and defeats the purpose.

set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

FAILED=0
fail() {
  echo "FAIL [$1] $2" >&2
  FAILED=1
}

# Config files are the payload's preferred host: they are executed by the
# toolchain on every build, but are rarely read line-by-line during review.
mapfile -t CONFIG_FILES < <(
  find . \
    \( -path ./node_modules -o -path ./.git -o -path ./android -o -path ./ios \) -prune \
    -o -type f \( \
      -name '*.config.js' -o -name '*.config.mjs' -o -name '*.config.cjs' \
      -o -name '*.config.ts' -o -name 'babel.config.*' -o -name 'metro.config.*' \
      -o -name 'postcss.config.*' -o -name '.npmrc' -o -name '.yarnrc*' \
    \) -print
)

echo "[1/5] Checking ${#CONFIG_FILES[@]} config file(s) for oversized payloads..."
# A hand-written config is small. Anything past a few KB is carrying something.
for f in "${CONFIG_FILES[@]}"; do
  size=$(wc -c < "$f")
  if [ "$size" -gt 4096 ]; then
    fail "file-size" "$f is ${size} bytes (expected < 4096)"
  fi
done

echo "[2/5] Checking for whitespace-padded / minified lines..."
# The padding trick: one very long line, usually mostly spaces, hiding the
# payload beyond the right edge of the editor viewport.
for f in "${CONFIG_FILES[@]}"; do
  awk -v f="$f" '
    length > 500 {
      printf "FAIL [long-line] %s:%d (%d chars)\n", f, NR, length > "/dev/stderr"
      bad = 1
    }
    END { exit bad ? 1 : 0 }
  ' "$f" || FAILED=1
done

echo "[3/5] Checking for obfuscator signatures..."
# javascript-obfuscator emits hex identifiers (_0x1a2b3c) and a rotated string
# array. These are near-zero false positive in hand-written source.
OBFUSCATION_PATTERNS=(
  '_0x[0-9a-f]{4,6}'
  '\\x[0-9a-f]{2}\\x[0-9a-f]{2}\\x[0-9a-f]{2}'
  "global\\[[\"'][^\"']{1,3}[\"']\\]\\s*="
  'global\.[A-Za-z_$][A-Za-z0-9_$]*\s*=\s*require'
)
for f in "${CONFIG_FILES[@]}"; do
  for pattern in "${OBFUSCATION_PATTERNS[@]}"; do
    if grep -qE "$pattern" "$f" 2>/dev/null; then
      fail "obfuscation" "$f matches: $pattern"
    fi
  done
done

echo "[4/5] Checking for runtime capabilities configs should not have..."
# A babel/metro config resolves paths. It has no business spawning processes,
# opening sockets, or decompressing buffers.
CAPABILITY_PATTERNS=(
  'child_process'
  'createRequire'
  '\beval\s*\('
  '\bFunction\s*\('
  'String\.fromCharCode'
  '\brequire\s*\(\s*["'"'"']zlib'
  '\brequire\s*\(\s*["'"'"']net'
  '\brequire\s*\(\s*["'"'"']https?["'"'"']'
)
for f in "${CONFIG_FILES[@]}"; do
  for pattern in "${CAPABILITY_PATTERNS[@]}"; do
    if grep -qE "$pattern" "$f" 2>/dev/null; then
      fail "capability" "$f matches: $pattern"
    fi
  done
done

echo "[5/5] Checking for blockchain-based C2 (EtherHiding)..."
# Payloads are fetched from on-chain contract storage so the C2 cannot be
# sinkholed. The RPC calls are the tell.
C2_PATTERNS=(
  'eth_(blockNumber|getBlockByNumber|getTransactionCount|call)'
  '(drpc\.org|blockscout|blastapi\.io|publicnode\.com|1rpc\.io)'
)
mapfile -t ALL_SOURCE < <(
  find . \
    \( -path ./node_modules -o -path ./.git \) -prune \
    -o -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' -o -name '*.tsx' -o -name '*.json' \) \
    ! -name 'pnpm-lock.yaml' -print
)
for f in "${ALL_SOURCE[@]}"; do
  for pattern in "${C2_PATTERNS[@]}"; do
    if grep -qE "$pattern" "$f" 2>/dev/null; then
      fail "blockchain-c2" "$f matches: $pattern"
    fi
  done
done

if [ "$FAILED" -ne 0 ]; then
  echo "" >&2
  echo "Scan FAILED. Do not install dependencies or build until resolved." >&2
  exit 1
fi

echo "OK: no supply-chain implant signatures found."
