#!/bin/bash
# The majority of this script is a copy of `cli/gh-extension-precompile` with
# the inclusion of LD_FLAGS to inject build information into the release
# binaries.

set -e

platforms=(
  darwin-amd64
  darwin-arm64
  freebsd-386
  freebsd-amd64
  freebsd-arm64
  linux-386
  linux-amd64
  linux-arm
  linux-arm64
  windows-386
  windows-amd64
  windows-arm64
)

# Include android in targeted platforms if building on linux as this does not work on macos
if [[ "$(go env GOOS)" == "linux" ]]; then
  platforms+=("android-amd64")
  platforms+=("android-arm64")
fi

if [[ $GITHUB_REF = refs/tags/* ]]; then
  tag="${GITHUB_REF#refs/tags/}"
else
  tag="$(git describe --tags --abbrev=0)"
fi

sha=$GITHUB_SHA

# The following block is the only customization from the original
# `cli/gh-extension-precompile` outside of using `LD_FLAGS` flag below
build_version="${tag#v}"
build_date="$(date +%Y-%m-%d)"
LD_FLAGS="-s -w -X github.com/github/gh-copilot/internal/build.Version=${build_version} -X github.com/github/gh-copilot/internal/build.Date=${build_date} -X github.com/github/gh-copilot/internal/build.Sha=${sha} -X github.com/github/gh-copilot/internal/build.UpdateRepo=github/gh-copilot"

# End of customization block

IFS=$'\n' read -d '' -r -a supported_platforms < <(go tool dist list) || true

for p in "${platforms[@]}"; do
  goos="${p%-*}"
  goarch="${p#*-}"
  if [[ " ${supported_platforms[*]} " != *" ${goos}/${goarch} "* ]]; then
    echo "warning: skipping unsupported platform $p" >&2
    continue
  fi
  ext=""
  if [ "$goos" = "windows" ]; then
    ext=".exe"
  fi
  cc=""
  cgo_enabled="${CGO_ENABLED:-0}"
  if [ "$goos" = "android" ]; then
    if [ "$goarch" = "amd64" ]; then
      cc="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android${ANDROID_SDK_VERSION}-clang"
      cgo_enabled="1"
    elif [ "$goarch" = "arm64" ]; then
      cc="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android${ANDROID_SDK_VERSION}-clang"
      cgo_enabled="1"
    fi
  fi
  GOOS="$goos" GOARCH="$goarch" CGO_ENABLED="$cgo_enabled" CC="$cc" go build -trimpath -ldflags="${LD_FLAGS}" -o "dist/${p}${ext} ./cmd/main.go"
done
