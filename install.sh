#!/usr/bin/env bash
# Installs Firefox Classic Theme into Firefox profiles on macOS and Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/axelberardino/firefox-classic-theme/main/install.sh | bash
#
# Run with --help for options.

set -euo pipefail

REPO="${CLASSIC_THEME_REPO:-axelberardino/firefox-classic-theme}"
BRANCH="${CLASSIC_THEME_BRANCH:-main}"
ORIGINAL_SUFFIX="before-classic-theme"
USER_JS_MARKER="// Written by Firefox Classic Theme (https://github.com/${REPO})"
OVERRIDE_FILES=(userChrome-overrides.css userContent-overrides.css)

PROFILE_ROOTS=(
  "${HOME}/Library/Application Support/Firefox"
  "${HOME}/Library/Application Support/Firefox Developer Edition"
  "${HOME}/Library/Application Support/Firefox Nightly"
  "${HOME}/Library/Application Support/librewolf"
  "${HOME}/Library/Application Support/Waterfox"
  "${HOME}/.mozilla/firefox"
  "${HOME}/.mozilla/firefox-esr"
  "${XDG_CONFIG_HOME:-${HOME}/.config}/mozilla/firefox"
  "${HOME}/.var/app/org.mozilla.firefox/.mozilla/firefox"
  "${HOME}/.var/app/org.mozilla.firefox/config/mozilla/firefox"
  "${HOME}/snap/firefox/common/.mozilla/firefox"
  "${HOME}/.librewolf"
  "${HOME}/.var/app/io.gitlab.librewolf-community/.librewolf"
  "${HOME}/.waterfox"
)

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: install.sh [options]

Installs Firefox Classic Theme (Lepton Photon-Style plus a few fixes) into
your Firefox profile. With no option, it picks the profile Firefox starts with.

Options:
  -p, --profile DIR   Install into this profile folder
  -a, --all           Install into every profile found
  -l, --list          List the profiles found and exit
  -u, --uninstall     Remove the theme and bring back what was there before
  -h, --help          Show this help

Your own tweaks survive updates when you put them in these files:
  <profile>/chrome/userChrome-overrides.css
  <profile>/chrome/userContent-overrides.css
  <profile>/user-overrides.js
EOF
}

# Prints the value of KEY in the [SECTION] of an ini file.
ini_value() {
  local file="$1" section="$2" key="$3"
  awk -F= -v section="[${section}]" -v key="${key}" '
    { sub(/\r$/, "") }
    /^\[/ { in_section = ($0 == section) ; next }
    in_section && $1 == key { print substr($0, length(key) + 2) ; exit }
  ' "${file}"
}

ini_sections() {
  sed -n 's/\r$//; s/^\[\(.*\)\]$/\1/p' "$1"
}

# Turns a profile entry of profiles.ini into an absolute folder.
profile_dir() {
  local root="$1" ini="$1/profiles.ini" section="$2" path relative
  path="$(ini_value "${ini}" "${section}" Path)"
  relative="$(ini_value "${ini}" "${section}" IsRelative)"
  [ -n "${path}" ] || return 0
  if [ "${relative}" = "0" ]; then
    printf '%s\n' "${path}"
  else
    printf '%s\n' "${root}/${path}"
  fi
}

all_profiles() {
  local root section
  for root in "${PROFILE_ROOTS[@]}"; do
    [ -f "${root}/profiles.ini" ] || continue
    while IFS= read -r section; do
      case "${section}" in
        Profile*) profile_dir "${root}" "${section}" ;;
      esac
    done < <(ini_sections "${root}/profiles.ini")
  done
}

# The profile a plain launch opens: the [Install...] default first (used by
# Firefox since version 67), then the profile flagged Default=1.
default_profiles() {
  local root ini section path relative
  for root in "${PROFILE_ROOTS[@]}"; do
    ini="${root}/profiles.ini"
    [ -f "${ini}" ] || continue
    path=""
    while IFS= read -r section; do
      case "${section}" in
        Install*)
          path="$(ini_value "${ini}" "${section}" Default)"
          [ -n "${path}" ] && break
          ;;
      esac
    done < <(ini_sections "${ini}")
    if [ -n "${path}" ]; then
      case "${path}" in
        /*) printf '%s\n' "${path}" ;;
        *) printf '%s\n' "${root}/${path}" ;;
      esac
      continue
    fi
    while IFS= read -r section; do
      case "${section}" in
        Profile*)
          if [ "$(ini_value "${ini}" "${section}" Default)" = "1" ]; then
            profile_dir "${root}" "${section}"
            break
          fi
          ;;
      esac
    done < <(ini_sections "${ini}")
  done
}

# Finds the theme files: next to this script when run from a clone, otherwise
# downloaded from GitHub (the curl | bash case).
fetch_source() {
  local here=""
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  if [ -n "${here}" ] && [ -f "${here}/chrome/classic.css" ]; then
    SOURCE_DIR="${here}"
    return
  fi

  command -v curl >/dev/null || die "curl is needed to download the theme"
  command -v tar >/dev/null || die "tar is needed to unpack the theme"
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  info "Downloading ${REPO} (${BRANCH})"
  curl -fsSL "https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz" |
    tar -xz -C "${TMP_DIR}" --strip-components 1
  [ -f "${TMP_DIR}/chrome/classic.css" ] || die "the download does not look like Firefox Classic Theme"
  SOURCE_DIR="${TMP_DIR}"
}

warn_if_firefox_running() {
  if pgrep -x firefox >/dev/null 2>&1 || pgrep -x firefox-bin >/dev/null 2>&1; then
    warn "Firefox is running. Restart it to see the changes."
  fi
}

install_profile() {
  local profile="$1" old_chrome="" scratch="" file
  [ -d "${profile}" ] || die "profile folder not found: ${profile}"
  info "Installing into ${profile}"

  # The first time, keep the user's own setup aside so uninstall can bring it
  # back. Later runs are updates of this theme, so only the overrides matter.
  if [ -e "${profile}/chrome" ]; then
    if [ -f "${profile}/chrome/classic.css" ] || [ -e "${profile}/chrome.${ORIGINAL_SUFFIX}" ]; then
      scratch="$(mktemp -d)"
      old_chrome="${scratch}/chrome"
    else
      old_chrome="${profile}/chrome.${ORIGINAL_SUFFIX}"
      echo "    your previous chrome folder is saved as chrome.${ORIGINAL_SUFFIX}"
    fi
    mv "${profile}/chrome" "${old_chrome}"
  fi
  if [ -f "${profile}/user.js" ] && [ ! -e "${profile}/user.js.${ORIGINAL_SUFFIX}" ] &&
    ! grep -qF "${USER_JS_MARKER}" "${profile}/user.js"; then
    cp "${profile}/user.js" "${profile}/user.js.${ORIGINAL_SUFFIX}"
    echo "    your previous user.js is saved as user.js.${ORIGINAL_SUFFIX}"
  fi

  cp -R "${SOURCE_DIR}/chrome" "${profile}/chrome"

  if [ -n "${old_chrome}" ]; then
    for file in "${OVERRIDE_FILES[@]}"; do
      if [ -f "${old_chrome}/${file}" ]; then
        cp "${old_chrome}/${file}" "${profile}/chrome/${file}"
        echo "    kept your ${file}"
      fi
    done
  fi
  [ -z "${scratch}" ] || rm -rf "${scratch}"

  {
    printf '%s\n' "${USER_JS_MARKER}"
    cat "${SOURCE_DIR}/user.js"
  } >"${profile}/user.js"
  if [ -f "${profile}/user-overrides.js" ]; then
    printf '\n// ** user-overrides.js ********************************************************\n' >>"${profile}/user.js"
    cat "${profile}/user-overrides.js" >>"${profile}/user.js"
    echo "    applied your user-overrides.js"
  fi
}

uninstall_profile() {
  local profile="$1"
  [ -d "${profile}" ] || die "profile folder not found: ${profile}"
  if [ ! -f "${profile}/chrome/classic.css" ]; then
    warn "Firefox Classic Theme is not installed in ${profile}, skipping"
    return
  fi
  info "Uninstalling from ${profile}"
  rm -rf "${profile}/chrome"
  if [ -e "${profile}/chrome.${ORIGINAL_SUFFIX}" ]; then
    mv "${profile}/chrome.${ORIGINAL_SUFFIX}" "${profile}/chrome"
    echo "    restored your previous chrome folder"
  fi
  if [ -f "${profile}/user.js" ] && grep -qF "${USER_JS_MARKER}" "${profile}/user.js"; then
    rm -f "${profile}/user.js"
  fi
  if [ -e "${profile}/user.js.${ORIGINAL_SUFFIX}" ]; then
    mv "${profile}/user.js.${ORIGINAL_SUFFIX}" "${profile}/user.js"
    echo "    restored your previous user.js"
  fi
}

main() {
  local mode="install" target="default" profiles=() profile line

  while [ $# -gt 0 ]; do
    case "$1" in
      -p | --profile)
        [ $# -ge 2 ] || die "$1 needs a folder"
        target="$2"
        shift
        ;;
      -a | --all) target="all" ;;
      -l | --list) mode="list" ;;
      -u | --uninstall) mode="uninstall" ;;
      -h | --help)
        usage
        exit 0
        ;;
      *) die "unknown option: $1 (see --help)" ;;
    esac
    shift
  done

  if [ "${mode}" = "list" ]; then
    all_profiles
    exit 0
  fi

  case "${target}" in
    default) while IFS= read -r line; do profiles+=("${line}"); done < <(default_profiles) ;;
    all) while IFS= read -r line; do profiles+=("${line}"); done < <(all_profiles) ;;
    *) profiles=("${target}") ;;
  esac
  [ "${#profiles[@]}" -gt 0 ] || die "no Firefox profile found. Open Firefox once, or pass --profile DIR"

  if [ "${mode}" = "uninstall" ]; then
    for profile in "${profiles[@]}"; do uninstall_profile "${profile}"; done
  else
    fetch_source
    for profile in "${profiles[@]}"; do install_profile "${profile}"; done
  fi

  warn_if_firefox_running
  info "Done. Restart Firefox to apply."
}

main "$@"
