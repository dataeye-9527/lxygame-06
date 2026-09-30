#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p build/core
xcrun clang -fobjc-arc -fmodules -DGD_SETTINGS_TESTS=1 -I Sources/Core -framework Foundation Sources/Core/GDSettings.m Tests/SettingsTests.m -o build/core/settings_tests
build/core/settings_tests
