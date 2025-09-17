#!/usr/bin/env bash
set -euo pipefail

echo "[ffmpeg] Build FFmpeg libraries only (iOS)"

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
export LDFLAGS="-arch arm64 -isysroot ${IOS_SDK_PATH} -mios-version-min=${IOS_MIN_VERSION} -Wl,-rpath,@executable_path -Wl,-rpath,@loader_path"
export PKG_CONFIG_PATH="$IOS_PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$IOS_PREFIX/lib/pkgconfig"
export PATH="$PATH:$IOS_PREFIX/bin"

echo "[ffmpeg] Pkg-config environment:"
echo "  PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
echo "  PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR"
echo "[ffmpeg] Available pkg-config packages:"
pkg-config --list-all | grep -E "(aom|x265|x264|vpx|opus)" || echo "  None found"

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

echo "[ffmpeg] Download FFmpeg 8.0"
if [ ! -d "ffmpeg" ]; then
  rm -f ffmpeg-8.0.tar.xz
  fetch "https://ffmpeg.org/releases/ffmpeg-8.0.tar.xz" "ffmpeg-8.0.tar.xz"
  tar -xf ffmpeg-8.0.tar.xz
  mv ffmpeg-8.0 ffmpeg
fi

cd ffmpeg

# Test compiler first
echo "[ffmpeg] Test compiler"
cat > test.c <<'EOF'
int main() { return 0; }
EOF

if ! "$CC" $CFLAGS $LDFLAGS test.c -o test; then
  echo "ERROR: Compiler test failed"
  exit 1
fi
rm -f test test.c
echo "Compiler test OK"

echo "[ffmpeg] Configure for static libraries only - Core codecs only"
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
  --disable-programs \
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
  --enable-libopus \
  --enable-libmp3lame \
  --enable-libvorbis \
  --enable-libwebp \
  --enable-libfreetype \
  --enable-libvpx \
  --enable-libspeex || { cat ffbuild/config.log; exit 1; }

echo "[ffmpeg] Build libraries"
make -j"$NPROC"

echo "[ffmpeg] Install libraries"
make install

echo "[ffmpeg] Build simple test program"
cat > test_ffmpeg.c <<'EOF'
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <stdio.h>

int main() {
    printf("FFmpeg version: %s\n", av_version_info());
    return 0;
}
EOF

if "$CC" $CFLAGS test_ffmpeg.c -L"$IOS_PREFIX/lib" -lavformat -lavcodec -lavutil $LDFLAGS -o test_ffmpeg; then
  echo "✅ FFmpeg test program compiled successfully"
  ls -la test_ffmpeg
  file test_ffmpeg
else
  echo "❌ FFmpeg test program failed"
fi

echo "[ffmpeg] Verify installation"
ls -la "$IOS_PREFIX/lib/libav"*.a || true
ls -la "$IOS_PREFIX/include/libav"* || true
echo "Libraries built successfully!"