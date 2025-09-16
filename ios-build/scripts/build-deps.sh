#!/usr/bin/env bash
set -euo pipefail

echo "[deps] Build iOS third-party static libraries"

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
mkdir -p "$IOS_PREFIX/lib/pkgconfig" "$IOS_PREFIX/lib" "$IOS_PREFIX/include"

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

echo "[deps] Build SDL2 (for ffplay UI)"
if [ ! -f "$IOS_PREFIX/lib/libSDL2.a" ]; then
  rm -rf SDL && git clone --depth 1 https://github.com/libsdl-org/SDL.git
  pushd SDL >/dev/null
  xcodebuild -project Xcode-iOS/SDL/SDL.xcodeproj \
    -scheme SDL \
    -configuration Release \
    -sdk iphoneos \
    -arch arm64 \
    IPHONEOS_DEPLOYMENT_TARGET=${IOS_MIN_VERSION} \
    build | xcpretty || true
  mkdir -p "$IOS_PREFIX/lib" "$IOS_PREFIX/include/SDL2"
  if [ -f "build/Release-iphoneos/libSDL2.a" ]; then
    cp -f build/Release-iphoneos/libSDL2.a "$IOS_PREFIX/lib/"
  else
    cp -f build/*-iphoneos/libSDL2.a "$IOS_PREFIX/lib/" 2>/dev/null || true
  fi
  cp -R include/* "$IOS_PREFIX/include/SDL2/"
  popd >/dev/null
  cat > "$IOS_PREFIX/lib/pkgconfig/sdl2.pc" <<PC
prefix=$IOS_PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: sdl2
Description: Simple DirectMedia Layer 2 (iOS)
Version: 2.30.0
Requires:
Libs: -L\${libdir} -lSDL2
Libs.private: -Wl,-framework,UIKit -Wl,-framework,CoreFoundation -Wl,-framework,CoreGraphics -Wl,-framework,Foundation -Wl,-framework,QuartzCore -Wl,-framework,AVFoundation -Wl,-framework,AudioToolbox -Wl,-framework,CoreAudio -Wl,-framework,GameController -Wl,-framework,CoreMotion -Wl,-framework,CoreHaptics -Wl,-framework,Metal -Wl,-framework,MetalKit -Wl,-framework,OpenGLES
Cflags: -I\${includedir}/SDL2
PC
fi

echo "[deps] Build x264"
if [ ! -f "$IOS_PREFIX/lib/libx264.a" ]; then
  rm -rf x264 && git clone --depth 1 https://code.videolan.org/videolan/x264.git
  pushd x264 >/dev/null
  ./configure \
    --host=arm-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --enable-static \
    --disable-asm \
    --disable-opencl \
    --enable-pic
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Build x265"
if [ ! -f "$IOS_PREFIX/lib/libx265.a" ]; then
  rm -rf x265 && git clone --depth 1 https://bitbucket.org/multicoreware/x265_git.git x265
  pushd x265/build/linux >/dev/null
  cmake -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$IOS_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_SHARED=OFF \
    -DENABLE_CLI=OFF \
    -DENABLE_ASSEMBLY=OFF \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${IOS_MIN_VERSION} \
    -DCMAKE_OSX_SYSROOT="$IOS_SDK_PATH" \
    ../../source
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Build libvpx"
if [ ! -f "$IOS_PREFIX/lib/libvpx.a" ]; then
  rm -rf libvpx && git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git
  pushd libvpx >/dev/null
  ./configure \
    --target=arm64-darwin20-gcc \
    --prefix="$IOS_PREFIX" \
    --disable-examples \
    --disable-docs \
    --enable-vp8 \
    --enable-vp9 \
    --enable-pic \
    --disable-shared \
    --enable-static
  make -j"$NPROC" && make install
  popd >/dev/null
  cat > "$IOS_PREFIX/lib/pkgconfig/vpx.pc" <<PC
prefix=$IOS_PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: vpx
Description: WebM VP8/VP9 Codec SDK
Version: 1.13.1
Requires:
Libs: -L\${libdir} -lvpx
Cflags: -I\${includedir}
PC
fi

echo "[deps] Build libaom (AV1)"
if [ ! -f "$IOS_PREFIX/lib/libaom.a" ]; then
  rm -rf aom && git clone --depth 1 https://aomedia.googlesource.com/aom
  pushd aom >/dev/null
  mkdir build_ios && cd build_ios
  cmake .. \
    -DCMAKE_INSTALL_PREFIX="$IOS_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_SHARED=OFF \
    -DENABLE_NASM=OFF \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${IOS_MIN_VERSION} \
    -DCMAKE_OSX_SYSROOT="$IOS_SDK_PATH" \
    -DENABLE_TESTS=OFF \
    -DENABLE_EXAMPLES=OFF \
    -DAOM_TARGET_CPU=arm64
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Build lame (MP3)"
if [ ! -f "$IOS_PREFIX/lib/libmp3lame.a" ]; then
  fetch http://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz lame-3.100.tar.gz
  rm -rf lame-3.100 && tar -xzf lame-3.100.tar.gz
  pushd lame-3.100 >/dev/null
  ./configure \
    --host=arm-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --enable-static \
    --disable-shared \
    --disable-frontend
  make -j"$NPROC" && make install
  popd >/dev/null
  cat > "$IOS_PREFIX/lib/pkgconfig/lame.pc" <<PC
prefix=$IOS_PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: lame
Description: LAME MP3 Encoder
Version: 3.100
Requires:
Libs: -L\${libdir} -lmp3lame
Cflags: -I\${includedir}
PC
fi

echo "[deps] Build freetype + fribidi + libass"
if [ ! -f "$IOS_PREFIX/lib/libass.a" ]; then
  # freetype
  fetch https://download.savannah.gnu.org/releases/freetype/freetype-2.13.2.tar.xz freetype-2.13.2.tar.xz
  rm -rf freetype-2.13.2 && tar -xf freetype-2.13.2.tar.xz
  pushd freetype-2.13.2 >/dev/null
  ./configure \
    --host=arm-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --enable-static \
    --disable-shared \
    --without-harfbuzz
  make -j"$NPROC" && make install
  popd >/dev/null

  # fribidi
  fetch https://github.com/fribidi/fribidi/releases/download/v1.0.13/fribidi-1.0.13.tar.xz fribidi-1.0.13.tar.xz
  rm -rf fribidi-1.0.13 && tar -xf fribidi-1.0.13.tar.xz
  pushd fribidi-1.0.13 >/dev/null
  ./configure \
    --host=arm-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --enable-static \
    --disable-shared
  make -j"$NPROC" && make install
  popd >/dev/null

  # libass
  rm -rf libass && git clone --depth 1 https://github.com/libass/libass.git
  pushd libass >/dev/null
  ./autogen.sh
  PKG_CONFIG_PATH="$IOS_PREFIX/lib/pkgconfig" \
  ./configure \
    --host=arm-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --enable-static \
    --disable-shared \
    --disable-require-system-font-provider
  make -j"$NPROC" && make install
  popd >/dev/null

  cat > "$IOS_PREFIX/lib/pkgconfig/libass.pc" <<PC
prefix=$IOS_PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libass
Description: Subtitle rendering library
Version: 0.17.0
Requires: freetype2 fribidi
Libs: -L\${libdir} -lass
Cflags: -I\${includedir}
PC
fi

echo "[deps] Build opus"
if [ ! -f "$IOS_PREFIX/lib/libopus.a" ]; then
  rm -rf opus && git clone --depth 1 https://github.com/xiph/opus.git
  pushd opus >/dev/null
  ./autogen.sh
  CFLAGS="$CFLAGS -DOPUS_ARM_NEON_INTR" \
  ./configure \
    --host=arm-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --enable-static \
    --disable-shared \
    --disable-asm \
    --disable-intrinsics
  make -j"$NPROC" && make install
  popd >/dev/null
  if [ ! -f "$IOS_PREFIX/lib/pkgconfig/opus.pc" ]; then
    cat > "$IOS_PREFIX/lib/pkgconfig/opus.pc" <<PC
prefix=$IOS_PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: Opus
Description: Opus IETF audio codec
Version: 1.4.0
Requires:
Libs: -L\${libdir} -lopus
Cflags: -I\${includedir}/opus
PC
  fi
fi

echo "[deps] Summary pkg-config:"
ls -la "$IOS_PREFIX/lib/pkgconfig" || true
PKG_CONFIG_PATH="$IOS_PREFIX/lib/pkgconfig" pkg-config --list-all | sort || true
