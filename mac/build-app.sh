#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

CONFIG="${1:-release}"
APP_NAME="CSM"
BUNDLE_ID="com.example.csm"
EXE_NAME="CSMMac"
APP_DIR="./${APP_NAME}.app"

echo "==> swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)/${EXE_NAME}"
if [[ ! -x "${BIN_PATH}" ]]; then
    echo "error: did not find executable at ${BIN_PATH}" >&2
    exit 1
fi

echo "==> bundling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${EXE_NAME}"
cp Resources/Info.plist "${APP_DIR}/Contents/Info.plist"

# Ad-hoc sign so macOS will let us launch it without "damaged" errors.
codesign --force --deep --sign - "${APP_DIR}" >/dev/null

echo "==> built ${APP_DIR}"
echo "    open ${APP_DIR}    # to launch"
