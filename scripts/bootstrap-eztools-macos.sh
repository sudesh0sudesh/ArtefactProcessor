#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
bootstrap-eztools-macos.sh

Guides or performs a macOS native-.NET Eric Zimmerman tools bootstrap for ArtefactProcessor.

Usage:
  scripts/bootstrap-eztools-macos.sh [--dest DIR] [--download] [--net-version 9|0] [--sync]

Options:
  --dest DIR        Destination for downloaded tools. Default: ~/.artefactprocessor/eztools
  --download        Download Get-ZimmermanTools.ps1 and execute it with PowerShell.
  --net-version N   Zimmerman .NET build family to request from Get-ZimmermanTools. Default: 9.
                    Use 0 to request all advertised .NET build families.
  --sync            Pass -Sync to Get-ZimmermanTools so EvtxECmd, RECmd, and SQLECmd sync maps/batches.
  -h, --help        Show this help.

Default mode is advisory: it prints the exact commands to install/download tools without executing downloads.
USAGE
}

DEST="${HOME}/.artefactprocessor/eztools"
DOWNLOAD=0
NET_VERSION=9
SYNC=0
HELPER_URL="https://raw.githubusercontent.com/EricZimmerman/Get-ZimmermanTools/master/Get-ZimmermanTools.ps1"
EVTX_REPO="https://github.com/EricZimmerman/evtx"
TOOLS_HOME="https://ericzimmerman.github.io/"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest)
      DEST="$2"
      shift 2
      ;;
    --download)
      DOWNLOAD=1
      shift
      ;;
    --net-version)
      NET_VERSION="$2"
      shift 2
      ;;
    --sync)
      SYNC=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$NET_VERSION" != "9" && "$NET_VERSION" != "0" ]]; then
  echo "Only --net-version 9 or 0 is supported by this bootstrap wrapper." >&2
  exit 2
fi

cat <<INFO
ArtefactProcessor Eric Zimmerman tools bootstrap (macOS native .NET)

Primary tool index: ${TOOLS_HOME}
Helper script:       ${HELPER_URL}
EvtxECmd source:    ${EVTX_REPO}
Destination:        ${DEST}
.NET build request: ${NET_VERSION}

This project expects published Eric Zimmerman tool zips, normally downloaded by
Get-ZimmermanTools.ps1, or a user-managed clone/build placed under the same
destination and registered in ArtefactProcessor's tool registry.
INFO

if ! command -v dotnet >/dev/null 2>&1; then
  cat <<'WARN'

WARNING: dotnet was not found on PATH.
Install the current Microsoft .NET runtime/SDK for macOS before executing native
Eric Zimmerman .NET builds, then rerun this script.
WARN
else
  echo
  echo "dotnet detected: $(dotnet --version 2>/dev/null || true)"
fi

if [[ "$DOWNLOAD" -eq 0 ]]; then
  cat <<EOF

Advisory mode only. To download published tools, install PowerShell for macOS
if needed and run:

  scripts/bootstrap-eztools-macos.sh --download --dest "${DEST}" --net-version ${NET_VERSION}$([[ "$SYNC" -eq 1 ]] && printf ' --sync')

Manual equivalent:

  mkdir -p "${DEST}"
  curl -fsSL "${HELPER_URL}" -o "${DEST}/Get-ZimmermanTools.ps1"
  pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "${DEST}/Get-ZimmermanTools.ps1" -Dest "${DEST}" -NetVersion ${NET_VERSION}$([[ "$SYNC" -eq 1 ]] && printf ' -Sync')

First parser target for ArtefactProcessor: EvtxECmd.
After download, expected locations commonly include files below:

  ${DEST}/net9/EvtxECmd/EvtxECmd
  ${DEST}/net9/EvtxECmd/EvtxECmd.dll
  ${DEST}/net9/EvtxECmd/EvtxECmd.exe

Register whichever executable form exists in the ArtefactProcessor tool registry.
EOF
  exit 0
fi

if ! command -v pwsh >/dev/null 2>&1; then
  cat <<'ERR' >&2
PowerShell (pwsh) was not found on PATH.
Install PowerShell for macOS, or run this script without --download to print the manual commands.
ERR
  exit 1
fi

mkdir -p "$DEST"
HELPER_PATH="${DEST}/Get-ZimmermanTools.ps1"
echo
echo "Downloading Get-ZimmermanTools.ps1..."
curl -fsSL "$HELPER_URL" -o "$HELPER_PATH"

CMD=(pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$HELPER_PATH" -Dest "$DEST" -NetVersion "$NET_VERSION")
if [[ "$SYNC" -eq 1 ]]; then
  CMD+=(-Sync)
fi

echo "Executing: ${CMD[*]}"
"${CMD[@]}"

echo
echo "Bootstrap complete. Next step: run ArtefactProcessor tool discovery/doctor once implemented."
