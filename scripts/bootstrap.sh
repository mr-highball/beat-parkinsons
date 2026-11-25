#!/usr/bin/env bash
# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
#
# Bootstraps the cross-platform Beat Parkinson's toolchain on Linux and macOS:
# - Initializes Git submodules (wfc, nyx)
# - Verifies Free Pascal (fpc)
# - Builds the pinned SHA-256-verified pas2js 3.3.1 browser compiler under build/
# - Builds the Nyx web bundle (app.js, oracle.css, recipes.json, graph.json, thumbnails)
# - Optionally compiles and runs all 7 strict portability unit tests
#
# Note: The local SQLite FTS5 / MCP stdio server binary (parkinsons-oracle.exe)
# currently targets Windows winsqlite3.dll; see README.md for details.

set -euo pipefail

PAS2JS_REVISION="fa10c59214cd226c60af465c831d66a7321f0214"
PAS2JS_SOURCE_SHA256="5a2ad292c8606b899ba384d81b97e789171a335759b67e338d4a37903dbe18f1"
FPC_SOURCE_REVISION="d7f522a5611b13f37164c5eac87ade49b2f5b324"
FPC_SOURCE_SHA256="84c70c67fd6b7da2be53bfc2613da2710a302432505489abdc732f89485fdc18"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_ROOT="${REPO_ROOT}/build/parkinsons-oracle"
FPC_BIN="${FPC:-}"
SKIP_SUBMODULES=0
SKIP_PAS2JS=0
SKIP_WEB=0
RUN_TESTS=0

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap.sh [options]

Options:
  --fpc PATH          Path to the Free Pascal compiler (default: $FPC or fpc on PATH)
  --build-root DIR    Ignored build output directory (default: build/parkinsons-oracle)
  --skip-submodules   Skip git submodule initialization
  --skip-pas2js       Skip building the pinned pas2js 3.3.1 compiler
  --skip-web          Skip building the Nyx web bundle and embed assets
  --run-tests         Compile and run all 7 strict portability unit tests
  -h, --help          Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fpc)
      FPC_BIN="$2"
      shift 2
      ;;
    --build-root)
      BUILD_ROOT="$2"
      shift 2
      ;;
    --skip-submodules)
      SKIP_SUBMODULES=1
      shift
      ;;
    --skip-pas2js)
      SKIP_PAS2JS=1
      shift
      ;;
    --skip-web)
      SKIP_WEB=1
      shift
      ;;
    --run-tests)
      RUN_TESTS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' was not found on PATH." >&2
    exit 1
  fi
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print tolower($1)}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print tolower($1)}'
  else
    echo "Error: neither sha256sum nor shasum is available." >&2
    exit 1
  fi
}

download_verified() {
  local url="$1"
  local dest="$2"
  local expected="$3"
  local label="$4"
  echo "Downloading ${label}..."
  curl --fail --location --retry 3 --output "$dest" "$url"
  local actual
  actual="$(sha256_file "$dest")"
  if [[ "$actual" != "$expected" ]]; then
    rm -f "$dest"
    echo "Error: ${label} SHA-256 mismatch (expected ${expected}, got ${actual})." >&2
    exit 1
  fi
}

require_cmd git
mkdir -p "${BUILD_ROOT}"
BUILD_ROOT="$(cd "${BUILD_ROOT}" && pwd)"

echo "==> Repository root: ${REPO_ROOT}"
echo "==> Build directory: ${BUILD_ROOT}"

# 1. Initialize required submodules
if [[ "${SKIP_SUBMODULES}" -eq 0 ]]; then
  echo "==> Initializing submodules (wfc, nyx)..."
  git -C "${REPO_ROOT}" submodule update --init --recursive -- \
    experiments/tools/vendor/wfc experiments/tools/vendor/nyx
fi

# 2. Verify Free Pascal compiler
if [[ -z "${FPC_BIN}" ]]; then
  FPC_BIN="$(command -v fpc || true)"
fi
if [[ -z "${FPC_BIN}" ]]; then
  cat >&2 <<'EOF'
Error: Free Pascal (fpc) was not found on PATH.
Install Free Pascal 3.2.2+ and re-run:
  Debian/Ubuntu: sudo apt-get update && sudo apt-get install -y fpc
  macOS:         brew install fpc
  Fedora:        sudo dnf install -y fpc
  Arch:          sudo pacman -S fpc
EOF
  exit 1
fi
FPC_VER="$("${FPC_BIN}" -iV | tr -d '\r\n')"
echo "==> Using Free Pascal: ${FPC_BIN} (version ${FPC_VER})"

# 3. Build or reuse pinned pas2js 3.3.1
DEFAULT_TOOLCHAIN_ROOT="${REPO_ROOT}/build/parkinsons-oracle"
PAS2JS_DIR="${BUILD_ROOT}/pas2js-aug"
PAS2JS_BIN="${PAS2JS_DIR}/pas2js"
PAS2JS_RTL="${BUILD_ROOT}/pas2js-aug-source/utils/pas2js/dist/rtl.js"
PAS2JS_PACKAGES="${BUILD_ROOT}/pas2js-source/packages"

if [[ "${SKIP_PAS2JS}" -eq 0 ]]; then
  if [[ ! ( -x "${PAS2JS_BIN}" && -f "${PAS2JS_RTL}" && -d "${PAS2JS_PACKAGES}" ) ]] && \
     [[ -x "${DEFAULT_TOOLCHAIN_ROOT}/pas2js-aug/pas2js" && \
        -f "${DEFAULT_TOOLCHAIN_ROOT}/pas2js-aug-source/utils/pas2js/dist/rtl.js" && \
        -d "${DEFAULT_TOOLCHAIN_ROOT}/pas2js-source/packages" ]]; then
    PAS2JS_BIN="${DEFAULT_TOOLCHAIN_ROOT}/pas2js-aug/pas2js"
    PAS2JS_RTL="${DEFAULT_TOOLCHAIN_ROOT}/pas2js-aug-source/utils/pas2js/dist/rtl.js"
    PAS2JS_PACKAGES="${DEFAULT_TOOLCHAIN_ROOT}/pas2js-source/packages"
  fi
  if [[ -x "${PAS2JS_BIN}" && -f "${PAS2JS_RTL}" && -d "${PAS2JS_PACKAGES}" ]]; then
    PAS2JS_VER="$("${PAS2JS_BIN}" -iV | tr -d '\r\n')"
    echo "==> Reusing pinned pas2js toolchain: ${PAS2JS_BIN} (version ${PAS2JS_VER})"
  else
    require_cmd curl
    require_cmd tar
    WORK_DIR="$(mktemp -d "${BUILD_ROOT}/pas2js-work.XXXXXX")"
    trap 'rm -rf "${WORK_DIR}"' EXIT

    PAS2JS_TAR="${WORK_DIR}/pas2js.tar.gz"
    FPC_TAR="${WORK_DIR}/fpc-source.tar.gz"
    PAS2JS_SRC="${BUILD_ROOT}/pas2js-source"
    FPC_SRC="${BUILD_ROOT}/pas2js-aug-source"
    UNITS_DIR="${WORK_DIR}/units"
    mkdir -p "${PAS2JS_SRC}" "${FPC_SRC}" "${PAS2JS_DIR}" "${UNITS_DIR}"

    download_verified \
      "https://gitlab.com/freepascal.org/fpc/pas2js/-/archive/${PAS2JS_REVISION}/pas2js-${PAS2JS_REVISION}.tar.gz" \
      "${PAS2JS_TAR}" "${PAS2JS_SOURCE_SHA256}" "pas2js packages archive"
    download_verified \
      "https://gitlab.com/freepascal.org/fpc/source/-/archive/${FPC_SOURCE_REVISION}/source-${FPC_SOURCE_REVISION}.tar.gz" \
      "${FPC_TAR}" "${FPC_SOURCE_SHA256}" "FPC pas2js compiler archive"

    echo "==> Extracting pinned pas2js sources..."
    tar -xzf "${PAS2JS_TAR}" --strip-components=1 -C "${PAS2JS_SRC}" \
      "pas2js-${PAS2JS_REVISION}/packages" \
      "pas2js-${PAS2JS_REVISION}/COPYING.txt" \
      "pas2js-${PAS2JS_REVISION}/LICENSE"
    tar -xzf "${FPC_TAR}" --strip-components=1 -C "${FPC_SRC}" \
      "source-${FPC_SOURCE_REVISION}/packages/pastojs" \
      "source-${FPC_SOURCE_REVISION}/packages/fcl-passrc" \
      "source-${FPC_SOURCE_REVISION}/packages/fcl-js" \
      "source-${FPC_SOURCE_REVISION}/packages/fcl-json" \
      "source-${FPC_SOURCE_REVISION}/utils/pas2js"

    echo "==> Compiling pinned pas2js 3.3.1..."
    "${FPC_BIN}" -Mobjfpc -O2 \
      "-Fu${FPC_SRC}/packages/pastojs/src" "-Fi${FPC_SRC}/packages/pastojs/src" \
      "-Fu${FPC_SRC}/packages/fcl-passrc/src" "-Fi${FPC_SRC}/packages/fcl-passrc/src" \
      "-Fu${FPC_SRC}/packages/fcl-js/src" "-Fi${FPC_SRC}/packages/fcl-js/src" \
      "-Fu${FPC_SRC}/packages/fcl-json/src" "-Fi${FPC_SRC}/packages/fcl-json/src" \
      "-FU${UNITS_DIR}" "-FE${PAS2JS_DIR}" \
      "${FPC_SRC}/utils/pas2js/pas2js.pp"

    PAS2JS_VER="$("${PAS2JS_BIN}" -iV | tr -d '\r\n')"
    echo "==> Built pinned pas2js: ${PAS2JS_BIN} (version ${PAS2JS_VER})"
    rm -rf "${WORK_DIR}"
    trap - EXIT
  fi
fi

# 4. Run strict portability unit tests when requested
if [[ "${RUN_TESTS}" -eq 1 ]]; then
  echo "==> Running strict portability unit tests (-Mdelphi -Sa -Cr -Co -Ci -gl)..."
  TEST_OUT="${BUILD_ROOT}/ci-tests"
  mkdir -p "${TEST_OUT}/units" "${TEST_OUT}/bin"
  (
    cd "${REPO_ROOT}"
    for test_src in \
      compat.tests.lpr \
      graph.tests.lpr \
      presentation.tests.lpr \
      selection.tests.lpr \
      rubric.tests.lpr \
      ingredients.tests.lpr \
      recipes.tests.lpr; do
      echo "  -> ${test_src}"
      "${FPC_BIN}" -Mdelphi -Sa -Cr -Co -Ci -gl \
        -Fuexperiments/tools/parkinsons-oracle \
        -Fuexperiments/tools/vendor/wfc/src \
        -Fuexperiments/1000_see_what_sticks_food/tools \
        "-FU${TEST_OUT}/units" "-FE${TEST_OUT}/bin" \
        "experiments/tools/parkinsons-oracle/${test_src}"
      "${TEST_OUT}/bin/${test_src%.lpr}"
    done
  )
fi

# 5. Build Nyx web bundle and embedded assets
if [[ "${SKIP_WEB}" -eq 0 && "${SKIP_PAS2JS}" -eq 0 ]]; then
  echo "==> Building Nyx web bundle and embedded assets..."
  WEB_OUT="${BUILD_ROOT}/web"
  TOOLS_OUT="${BUILD_ROOT}/embed-tools"
  ORACLE_DIR="${REPO_ROOT}/experiments/tools/parkinsons-oracle"
  WEB_DIR="${ORACLE_DIR}/web"
  NYX_SRC="${REPO_ROOT}/experiments/tools/vendor/nyx/src"
  WFC_SRC="${REPO_ROOT}/experiments/tools/vendor/wfc/src"
  mkdir -p "${WEB_OUT}" "${TOOLS_OUT}/units" "${TOOLS_OUT}/bin"

  (
    cd "${REPO_ROOT}"
    "${FPC_BIN}" -Mdelphi -Sa -Cr -Co -Ci -gl \
      "-Fu${ORACLE_DIR}" "-Fu${WFC_SRC}" "-Fu${REPO_ROOT}/experiments/1000_see_what_sticks_food/tools" \
      "-FU${TOOLS_OUT}/units" "-FE${TOOLS_OUT}/bin" "${ORACLE_DIR}/graph.embed.lpr"
    "${TOOLS_OUT}/bin/graph.embed" "${REPO_ROOT}" "${WEB_OUT}/graph.json"

    "${FPC_BIN}" -Mdelphi -Sa -Cr -Co -Ci -gl \
      "-Fu${ORACLE_DIR}" "-Fu${WFC_SRC}" \
      "-FU${TOOLS_OUT}/units" "-FE${TOOLS_OUT}/bin" "${ORACLE_DIR}/recipes.embed.lpr"
    "${TOOLS_OUT}/bin/recipes.embed" "${REPO_ROOT}" "${WEB_OUT}/recipes.json"

    "${PAS2JS_BIN}" -Mdelphi -Tbrowser -Jc \
      "-Fu${NYX_SRC}" "-Fi${NYX_SRC}" "-Fu${WFC_SRC}" "-Fu${ORACLE_DIR}" \
      "-Fu${PAS2JS_PACKAGES}/*/src" "-FE${WEB_OUT}" "${WEB_DIR}/oracleweb.lpr"
    mv -f "${WEB_OUT}/oracleweb.js" "${WEB_OUT}/app.js"
    cp -f "${PAS2JS_RTL}" "${WEB_OUT}/rtl.js"
    cp -f "${WEB_DIR}/index.html" "${WEB_DIR}/oracle.css" "${WEB_OUT}/"

    "${FPC_BIN}" -Mdelphi -Sa -Cr -Co -Ci -gl \
      "-FU${TOOLS_OUT}/units" "-FE${TOOLS_OUT}/bin" "${ORACLE_DIR}/glyphs.embed.lpr"
    "${TOOLS_OUT}/bin/glyphs.embed" "${WEB_DIR}/assets/glyphs" "${TOOLS_OUT}/glyphs.css"
    cat "${TOOLS_OUT}/glyphs.css" >> "${WEB_OUT}/oracle.css"

    "${FPC_BIN}" -Mdelphi -Sa -Cr -Co -Ci -gl \
      "-Fu${ORACLE_DIR}" "-Fu${REPO_ROOT}/experiments/1000_see_what_sticks_food/tools" \
      "-FU${TOOLS_OUT}/units" "-FE${TOOLS_OUT}/bin" "${ORACLE_DIR}/ingredients.gallery.check.lpr"
    mkdir -p "${WEB_OUT}/ingredients"
    "${TOOLS_OUT}/bin/ingredients.gallery.check" \
      "${REPO_ROOT}/experiments/1000_see_what_sticks_food_round_2/ingredients.tsv" \
      "${WEB_DIR}/assets/ingredients" "${WEB_OUT}/ingredients"
    cp -f "${WEB_DIR}/assets/ingredients/"*.jpg "${WEB_OUT}/ingredients/"
  )
fi

if command -v python3 >/dev/null 2>&1; then
  echo "==> Python available for research collectors: $(python3 --version)"
else
  echo "Note: python3 not found (optional; only needed for research/collect_*.py scripts)."
fi

cat <<EOF

Bootstrap complete.
  pas2js binary: ${PAS2JS_BIN}
  Web bundle:    ${BUILD_ROOT}/web

Notes:
  - All 7 portability unit tests, WFC/recipe/graph generators, Nyx web builds,
    and Python archive collectors run natively on Linux and macOS.
  - The local SQLite FTS5 / MCP stdio server binary (parkinsons-oracle.exe)
    currently links Windows winsqlite3.dll; run scripts/bootstrap.ps1 on Windows
    to host the local MCP server or local HTTP workbench.
EOF
