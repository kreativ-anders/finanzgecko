#!/usr/bin/env bash
# Regenerates CORPORATE_DESIGN.pdf from CORPORATE_DESIGN.md.
#
#   tool/generate_corporate_design_pdf.sh
#
# Pipeline: pandoc turns the Markdown into a standalone, self-contained HTML file
# (--embed-resources inlines the CSS below and assets/icon/icon.png as data URIs),
# then headless Chrome prints that HTML to PDF. LaTeX (xelatex) was tried first and
# rejected: it silently drops the 🦎 emoji and → arrows used in the doc, which Chrome
# renders fine since it has access to the OS's real Unicode/color-emoji fonts.
#
# Ghostscript recompression is optional (~35-40% smaller here) and skipped silently
# if `gs` isn't installed — not worth adding as a hard dependency for one file.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/CORPORATE_DESIGN.md"
CSS="$REPO/tool/corporate_design_pdf.css"
OUT="$REPO/CORPORATE_DESIGN.pdf"

command -v pandoc >/dev/null 2>&1 || {
  echo "pandoc is required (brew install pandoc)" >&2
  exit 1
}

CHROME=""
for candidate in \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "$(command -v chromium 2>/dev/null || true)" \
  "$(command -v chromium-browser 2>/dev/null || true)" \
  "$(command -v google-chrome 2>/dev/null || true)"; do
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    CHROME="$candidate"
    break
  fi
done
[[ -n "$CHROME" ]] || {
  echo "Chrome or Chromium is required for HTML->PDF rendering" >&2
  exit 1
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
HTML="$WORKDIR/CORPORATE_DESIGN.html"

pandoc "$SRC" \
  --standalone \
  --toc \
  --resource-path="$REPO" \
  --embed-resources \
  --css="$CSS" \
  --metadata title="FinanzGecko — Corporate Design" \
  -o "$HTML"

"$CHROME" --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$OUT" \
  "file://$HTML" >/dev/null 2>&1

if command -v gs >/dev/null 2>&1; then
  COMPRESSED="$WORKDIR/compressed.pdf"
  if gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.5 -dPDFSETTINGS=/ebook \
       -dNOPAUSE -dQUIET -dBATCH -sOutputFile="$COMPRESSED" "$OUT" 2>/dev/null; then
    mv "$COMPRESSED" "$OUT"
  fi
fi

echo "Wrote $OUT ($(du -h "$OUT" | cut -f1))"
