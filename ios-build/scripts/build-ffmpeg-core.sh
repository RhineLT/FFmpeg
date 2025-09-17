#!/usr/bin/env bash
set -euo pipefail

echo "[ffmpeg] Configure and build FFmpeg 8.0"

: "${XCODE_PATH:?XCODE_PATH missing}"
: "${IOS_SDK_PATH:?IOS_SDK_PATH missing}"
: "${IOS_MIN_VERSION:?IOS_MIN_VERSION missing}"
: "${IOS_PREFIX:?IOS_PREFIX missing}"

export CC="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
export CXX="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++"
export AR="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar"
export RANLIB="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib"
export STRIP="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip"

export CFLAGS="-arch arm64 -isysroot ${IOS_SDK_PATH} -mios-version-min=${IOS_MIN_VERSION} -fembed-bitcode"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-arch arm64 -isysroot ${IOS_SDK_PATH} -mios-version-min=${IOS_MIN_VERSION}"

export PKG_CONFIG_PATH="$IOS_PREFIX/lib/pkgconfig"
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

echo "[ffmpeg] Download FFmpeg 8.0"
if [ ! -d "ffmpeg" ]; then
  rm -f ffmpeg-8.0.tar.xz
  fetch "https://ffmpeg.org/releases/ffmpeg-8.0.tar.xz" "ffmpeg-8.0.tar.xz"
  tar -xf ffmpeg-8.0.tar.xz
  mv ffmpeg-8.0 ffmpeg
fi

cd ffmpeg

echo "[ffmpeg] Configure build"
./configure \
  --prefix="$IOS_PREFIX" \
  --arch=arm64 \
  --cpu=arm64 \
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
  --enable-pic \
  --disable-debug \
  --disable-doc \
  --disable-htmlpages \
  --disable-manpages \
  --disable-podpages \
  --disable-txtpages \
  --enable-ffmpeg \
  --enable-ffprobe \
  --enable-ffplay \
  --enable-runtime-cpudetect \
  --enable-gpl \
  --enable-version3 \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libaom \
  --enable-libopus \
  --enable-encoder=libx264 \
  --enable-encoder=libx265 \
  --enable-encoder=libvpx_vp8 \
  --enable-encoder=libvpx_vp9 \
  --enable-encoder=libaom_av1 \
  --enable-encoder=libopus \
  --enable-decoder=h264 \
  --enable-decoder=hevc \
  --enable-decoder=vp8 \
  --enable-decoder=vp9 \
  --enable-decoder=av1 \
  --enable-decoder=opus \
  --enable-protocol=file \
  --enable-protocol=http \
  --enable-protocol=https \
  --enable-protocol=ftp

echo "[ffmpeg] Build FFmpeg"
make -j"$NPROC"

echo "[ffmpeg] Install to $IOS_PREFIX"
make install

echo "[ffmpeg] Verify binaries"
ls -la "$IOS_PREFIX/bin/ffmpeg" "$IOS_PREFIX/bin/ffprobe" "$IOS_PREFIX/bin/ffplay" || true
file "$IOS_PREFIX/bin/ffmpeg" || true
otool -L "$IOS_PREFIX/bin/ffmpeg" | head -10 || true

echo "[ffmpeg] FFmpeg build complete!"