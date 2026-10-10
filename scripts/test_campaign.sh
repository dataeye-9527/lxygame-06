#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p build/core
xcrun clang -O2 -fobjc-arc -fmodules -DGD_CORE_TESTS=1 -I Sources/Core -framework Foundation -framework CoreGraphics Sources/Core/GDEngine.m Sources/Core/GDBuffCatalog.m Sources/Core/GDLevelCatalog.m Sources/Core/GDProgressStore.m Sources/Core/GDRunRecords.m Tests/TestDefaults.m Tests/CampaignTests.m -o build/core/campaign_tests
build/core/campaign_tests "$@"
