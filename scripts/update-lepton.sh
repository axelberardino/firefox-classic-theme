#!/usr/bin/env bash
# Replaces the bundled Lepton files with a Lepton Photon-Style release.
#
#   scripts/update-lepton.sh           # latest release
#   scripts/update-lepton.sh v8.7.6    # a given release
#
# The theme's own files (chrome/classic.css, chrome/userChrome.css and
# chrome/userContent.css) are kept. Review the result with git diff.

set -euo pipefail

UPSTREAM="black7375/Firefox-UI-Fix"
ASSET="Lepton-Photon-Style.zip"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

version="${1:-}"
if [ -z "${version}" ]; then
  version="$(curl -fsSL "https://api.github.com/repos/${UPSTREAM}/releases/latest" |
    sed -n 's/^ *"tag_name": *"\([^"]*\)".*/\1/p')"
  [ -n "${version}" ] || {
    echo "error: could not find the latest Lepton release" >&2
    exit 1
  }
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

echo "==> Downloading ${ASSET} ${version}"
curl -fsSL -o "${tmp}/lepton.zip" "https://github.com/${UPSTREAM}/releases/download/${version}/${ASSET}"
unzip -q "${tmp}/lepton.zip" -d "${tmp}/lepton"
[ -f "${tmp}/lepton/chrome/css/leptonChrome.css" ] || {
  echo "error: ${ASSET} ${version} does not have the expected layout" >&2
  exit 1
}

rm -rf "${ROOT}/chrome/css" "${ROOT}/chrome/icons"
cp -R "${tmp}/lepton/chrome/css" "${tmp}/lepton/chrome/icons" "${ROOT}/chrome/"
cp "${tmp}/lepton/chrome/LEPTON" "${ROOT}/chrome/LEPTON"
cp "${tmp}/lepton/user.js" "${tmp}/lepton/LICENSE" "${tmp}/lepton/CREDITS" "${ROOT}/"
printf '%s\n' "${version}" >"${ROOT}/LEPTON_VERSION"

# Lepton's own userChrome.css and userContent.css are not copied, since this
# theme ships its own. Show what changed upstream so it can be carried over.
for file in userChrome.css userContent.css; do
  if ! git -C "${ROOT}" show "HEAD:upstream/${file}" 2>/dev/null |
    diff -q - "${tmp}/lepton/chrome/${file}" >/dev/null; then
    echo "==> Lepton's ${file} changed, check whether to carry it over:"
    git -C "${ROOT}" show "HEAD:upstream/${file}" 2>/dev/null |
      diff -u - "${tmp}/lepton/chrome/${file}" || true
  fi
  mkdir -p "${ROOT}/upstream"
  cp "${tmp}/lepton/chrome/${file}" "${ROOT}/upstream/${file}"
done

echo "==> Updated to Lepton ${version}. Review with: git -C \"${ROOT}\" diff --stat"
