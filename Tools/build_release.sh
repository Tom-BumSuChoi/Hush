#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release --triple arm64-apple-macosx13.0 --scratch-path .build/release-arm64
swift build -c release --triple x86_64-apple-macosx13.0 --scratch-path .build/release-intel
arm_binary_directory=$(swift build -c release --triple arm64-apple-macosx13.0 --scratch-path .build/release-arm64 --show-bin-path)
intel_binary_directory=$(swift build -c release --triple x86_64-apple-macosx13.0 --scratch-path .build/release-intel --show-bin-path)

mkdir -p .build/distribution
lipo -create "$arm_binary_directory/Hush" "$intel_binary_directory/Hush" -output .build/distribution/Hush
codesign --force --sign - .build/distribution/Hush
codesign --verify --strict .build/distribution/Hush
lipo -archs .build/distribution/Hush
.build/distribution/Hush --version
printf '배포 실행 파일: %s/.build/distribution/Hush\n' "$PWD"
