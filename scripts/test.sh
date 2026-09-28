#!/bin/sh
# Tests de WisprKit. Con Xcode instalado basta `swift test`; con solo Command Line Tools hay que
# apuntar a Swift Testing a mano y desactivar el overlay _Testing_Foundation (no viene en las CLT).
set -e
cd "$(dirname "$0")/../WisprKit"

if xcodebuild -version >/dev/null 2>&1; then
    exec swift test "$@"
fi

F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
exec swift test \
    -Xswiftc -F -Xswiftc "$F" \
    -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
    -Xlinker -F -Xlinker "$F" \
    -Xlinker -rpath -Xlinker "$F" \
    -Xlinker -rpath -Xlinker "$L" \
    "$@"
