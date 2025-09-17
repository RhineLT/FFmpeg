#!/usr/bin/env bash
set -euo pipefail

echo "[tools] Build FFmpeg command-line tools for iOS"

: "${XCODE_PATH:?XCODE_PATH missing}"
: "${IOS_SDK_PATH:?IOS_SDK_PATH missing}"
: "${IOS_MIN_VERSION:?IOS_MIN_VERSION missing}"
: "${IOS_PREFIX:?IOS_PREFIX missing}"

export CC="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
export CXX="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++"
export AR="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar"
export RANLIB="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib"
export STRIP="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip"

# 添加iOS 16兼容的链接选项
export CFLAGS="-arch arm64 -isysroot ${IOS_SDK_PATH} -mios-version-min=${IOS_MIN_VERSION} -O2 -fno-common"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-arch arm64 -isysroot ${IOS_SDK_PATH} -mios-version-min=${IOS_MIN_VERSION} -Wl,-rpath,@executable_path -Wl,-rpath,@loader_path"export PKG_CONFIG_PATH="$IOS_PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$IOS_PREFIX/lib/pkgconfig"
export PATH="$PATH:$IOS_PREFIX/bin"

NPROC=$(sysctl -n hw.ncpu || echo 4)

workdir=$(pwd)
trap 'cd "$workdir"' EXIT

fetch() {
  local url=$1 out=$2
  if command -v curl >/dev/null 2>&1; then
    curl -LfsS "$url" -o "$out"
  else
    wget -q "$url" -O "$out"
  fi
}

echo "[tools] Download FFmpeg 8.0 (for tools)"
if [ ! -d "ffmpeg-tools" ]; then
  rm -f ffmpeg-8.0.tar.xz
  fetch "https://ffmpeg.org/releases/ffmpeg-8.0.tar.xz" "ffmpeg-8.0.tar.xz"
  tar -xf ffmpeg-8.0.tar.xz
  mv ffmpeg-8.0 ffmpeg-tools
fi

cd ffmpeg-tools

echo "[tools] Configure for command-line tools"
./configure \
  --prefix="$IOS_PREFIX" \
  --arch=arm64 \
  --target-os=darwin \
  --enable-cross-compile \
  --cc="$CC" \
  --cxx="$CXX" \
  --ar="$AR" \
  --ranlib="$RANLIB" \
  --strip="$STRIP" \
  --sysroot="$IOS_SDK_PATH" \
  --extra-cflags="$CFLAGS" \
  --extra-cxxflags="$CXXFLAGS" \
  --extra-ldflags="$LDFLAGS" \
  --pkg-config-flags="--static" \
  --disable-shared \
  --enable-static \
  --disable-debug \
  --disable-doc \
  --disable-network \
  --disable-bzlib \
  --disable-iconv \
  --disable-lzma \
  --disable-securetransport \
  --disable-xlib \
  --disable-zlib \
  --enable-gpl \
  --enable-version3 \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libaom \
  --enable-libopus || { cat ffbuild/config.log; exit 1; }

echo "[tools] Build command-line tools"
make -j"$NPROC"

echo "[tools] Install tools and verify"
make install

echo "[tools] Verify tools installation"
ls -la "$IOS_PREFIX/bin/ff"* || true
file "$IOS_PREFIX/bin/ff"* || true

echo "[tools] Code sign binaries for iOS 16.5+"
# 为iOS 16.5创建ad-hoc签名
for binary in "$IOS_PREFIX/bin/ff"*; do
  if [ -f "$binary" ]; then
    echo "Signing $binary"
    # 使用ad-hoc签名（- 表示使用本地identity）
    codesign --force --sign - --entitlements "../ffmpeg.entitlements" --deep --timestamp "$binary" || {
      echo "Warning: Code signing failed for $binary, trying without entitlements"
      codesign --force --sign - --deep "$binary" || {
        echo "Warning: Basic code signing also failed for $binary"
      }
    }
    # 验证签名
    codesign --verify --verbose "$binary" && echo "✓ $binary signed successfully" || echo "✗ $binary signing failed"
  fi
done

echo "Command-line tools built successfully!"