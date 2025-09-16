#!/usr/bin/env bash
set -euo pipefail

echo "[ffmpeg] Configure and build FFmpeg for iOS arm64 (jailbroken)"

: "${XCODE_PATH:?}"
: "${IOS_SDK_PATH:?}"
: "${IOS_MIN_VERSION:?}"
: "${IOS_PREFIX:?}"

export CC="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
export CXX="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++"
export AR="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar"
export NM="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/nm"
export RANLIB="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib"
export STRIP="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip"

export CFLAGS="-arch arm64 -isysroot ${IOS_SDK_PATH} -mios-version-min=${IOS_MIN_VERSION} -O3"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-arch arm64 -isysroot ${IOS_SDK_PATH} -mios-version-min=${IOS_MIN_VERSION}"
export PKG_CONFIG_PATH="$IOS_PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$IOS_PREFIX/lib/pkgconfig"

# Debug pkg-config for libass
echo "Debug: PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
ls -la "$IOS_PREFIX/lib/pkgconfig/" || true
pkg-config --exists libass && echo "libass found" || echo "libass NOT found"
pkg-config --modversion libass || true
echo "Content of libass.pc:"
cat "$IOS_PREFIX/lib/pkgconfig/libass.pc" || true

BUILD_DIR=build-ios
rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR"

# Create temporary pkg-config wrapper to help with libass detection
cat > /tmp/pkg-config-wrapper <<EOF
#!/bin/bash
IOS_PREFIX="$IOS_PREFIX"
if [[ "\$1" == "--exists" && "\$2" == "libass" ]]; then
    if [[ -f "\$IOS_PREFIX/lib/libass.a" && -f "\$IOS_PREFIX/include/ass/ass.h" ]]; then
        exit 0
    else
        exit 1
    fi
elif [[ "\$1" == "--modversion" && "\$2" == "libass" ]]; then
    echo "0.17.0"
    exit 0
elif [[ "\$1" == "--cflags" && "\$2" == "libass" ]]; then
    echo "-I\$IOS_PREFIX/include"
    exit 0
elif [[ "\$1" == "--libs" && "\$2" == "libass" ]]; then
    echo "-L\$IOS_PREFIX/lib -lass -lfribidi -lfreetype"
    exit 0
else
    exec pkg-config "\$@"
fi
EOF
chmod +x /tmp/pkg-config-wrapper

# Temporarily override PKG_CONFIG
export PKG_CONFIG=/tmp/pkg-config-wrapper
pushd "$BUILD_DIR" >/dev/null

../configure \
  --prefix=/var/jb/usr \
  --enable-cross-compile \
  --target-os=darwin \
  --arch=arm64 \
  --sysroot="$IOS_SDK_PATH" \
  --cc="$CC" \
  --cxx="$CXX" \
  --nm="$NM" \
  --ar="$AR" \
  --ranlib="$RANLIB" \
  --strip="$STRIP" \
  --extra-cflags="$CFLAGS -I$IOS_PREFIX/include" \
  --extra-ldflags="$LDFLAGS -L$IOS_PREFIX/lib" \
  --extra-libs="-lass -lfribidi -lfreetype -lm" \
  --pkg-config-flags="--static" \
  --enable-static \
  --disable-shared \
  --enable-pthreads \
  --enable-version3 \
  --enable-gpl \
  --enable-nonfree \
  --enable-ffmpeg \
  --enable-ffplay \
  --enable-ffprobe \
  --enable-sdl2 \
  --enable-optimizations \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libaom \
  --enable-libopus \
  --enable-libass \
  --enable-encoder=libx264 \
  --enable-encoder=libx265 \
  --enable-encoder=libvpx_vp8 \
  --enable-encoder=libvpx_vp9 \
  --enable-encoder=libaom_av1 \
  --enable-encoder=libopus \
  --enable-encoder=aac \
  --enable-encoder=pcm_s16le \
  --enable-decoder=h264 \
  --enable-decoder=hevc \
  --enable-decoder=vp8 \
  --enable-decoder=vp9 \
  --enable-decoder=av1 \
  --enable-decoder=opus \
  --enable-decoder=mp3 \
  --enable-decoder=aac \
  --enable-muxer=mp4 \
  --enable-muxer=mov \
  --enable-muxer=matroska \
  --enable-muxer=webm \
  --enable-demuxer=mov \
  --enable-demuxer=matroska \
  --enable-demuxer=webm \
  --enable-parser=h264 \
  --enable-parser=hevc \
  --enable-parser=vp8 \
  --enable-parser=vp9 \
  --enable-parser=av1 \
  --enable-protocol=file \
  --enable-protocol=http \
  --enable-protocol=https \
  --disable-audiotoolbox \
  --disable-videotoolbox \
  --enable-securetransport \
  --disable-iconv \
  --disable-lzma \
  --disable-bzlib \
  --disable-libxml2 \
  --disable-debug \
  --disable-doc \
  --enable-small

make -j"${FFMPEG_MAKE_JOBS:-$(sysctl -n hw.ncpu || echo 4)}"

popd >/dev/null

echo "[ffmpeg] Build finished. Binaries at $BUILD_DIR/{ffmpeg,ffplay,ffprobe}"
