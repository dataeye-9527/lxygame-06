#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p build/core
xcrun clang -O2 -fobjc-arc -fmodules -DGD_CORE_TESTS=1 -I Sources/Core -framework Foundation -framework CoreGraphics Sources/Core/GDEngine.m Tests/CoreTests.m -o build/core/core_tests
build/core/core_tests "$@"
