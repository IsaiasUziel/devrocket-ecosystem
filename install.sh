#!/bin/sh

set -eu

OWNER="IsaiasUziel"
REPO="devrocket-ecosystem"
BINARY="dr-sys"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${VERSION:-latest}"

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

download() {
  url=$1
  output=$2

  if need_cmd curl; then
    curl -fsSL "$url" -o "$output"
  elif need_cmd wget; then
    wget -qO "$output" "$url"
  else
    fail "curl or wget is required to download releases"
  fi
}

sha256_file() {
  file=$1

  if need_cmd sha256sum; then
    sha256sum "$file" | awk '{print $1}'
  elif need_cmd shasum; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    return 1
  fi
}

OS=$(uname -s 2>/dev/null || printf unknown)
ARCH=$(uname -m 2>/dev/null || printf unknown)

if [ "$OS" != "Linux" ]; then
  fail "this installer currently supports Linux only; use Homebrew on macOS"
fi

case "$ARCH" in
  x86_64|amd64)
    GO_ARCH="amd64"
    ;;
  aarch64|arm64)
    GO_ARCH="arm64"
    ;;
  *)
    fail "unsupported architecture: $ARCH"
    ;;
esac

ARCHIVE="${REPO}_linux_${GO_ARCH}.tar.gz"
CHECKSUMS="checksums.txt"

if [ "$VERSION" = "latest" ]; then
  BASE_URL="https://github.com/${OWNER}/${REPO}/releases/latest/download"
else
  BASE_URL="https://github.com/${OWNER}/${REPO}/releases/download/${VERSION}"
fi

TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/${REPO}.XXXXXX")
trap 'rm -rf "$TMPDIR"' EXIT INT TERM HUP

ARCHIVE_PATH="$TMPDIR/$ARCHIVE"
CHECKSUMS_PATH="$TMPDIR/$CHECKSUMS"

say "==> Downloading ${ARCHIVE}"
download "$BASE_URL/$ARCHIVE" "$ARCHIVE_PATH"

CHECKSUM_VERIFIED="skipped"
say "==> Downloading ${CHECKSUMS}"
if download "$BASE_URL/$CHECKSUMS" "$CHECKSUMS_PATH"; then
  EXPECTED_SUM=$(awk -v file="$ARCHIVE" '$2 == file { print $1; exit }' "$CHECKSUMS_PATH")
  if [ -n "$EXPECTED_SUM" ]; then
    if ACTUAL_SUM=$(sha256_file "$ARCHIVE_PATH"); then
      if [ "$EXPECTED_SUM" = "$ACTUAL_SUM" ]; then
        CHECKSUM_VERIFIED="ok"
        say "==> Checksum verified"
      else
        fail "checksum mismatch for ${ARCHIVE}"
      fi
    else
      say "==> Checksum tools not found; skipping verification"
    fi
  else
    say "==> No checksum entry found for ${ARCHIVE}; skipping verification"
  fi
else
  say "==> Could not download checksums.txt; skipping verification"
fi

say "==> Extracting release archive"
tar -xzf "$ARCHIVE_PATH" -C "$TMPDIR"

[ -f "$TMPDIR/$BINARY" ] || fail "${BINARY} not found in release archive"

say "==> Installing ${BINARY} to ${INSTALL_DIR}"
mkdir -p "$INSTALL_DIR"
cp "$TMPDIR/$BINARY" "$INSTALL_DIR/$BINARY"
chmod 755 "$INSTALL_DIR/$BINARY"

case ":$PATH:" in
  *:"$INSTALL_DIR":*)
    PATH_HINT="present"
    ;;
  *)
    PATH_HINT="missing"
    ;;
esac

say
say "Installed ${BINARY} successfully."
say "- Version source: ${VERSION}"
say "- Archive: ${ARCHIVE}"
say "- Checksum: ${CHECKSUM_VERIFIED}"
say "- Binary path: ${INSTALL_DIR}/${BINARY}"
say

if [ "$PATH_HINT" = "missing" ]; then
  say "Add ${INSTALL_DIR} to your PATH if needed:"
  say "  export PATH=\"${INSTALL_DIR}:\$PATH\""
  say "Then restart your shell or source your shell profile."
  say
fi

say "Run the installer with:"
say "  ${BINARY}"
