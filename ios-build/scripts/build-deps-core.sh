#!/usr/bin/env bash
set -euo pipefail

echo "[deps] Build iOS third-party static libraries (core only)"

: "${XCODE_PATH:?XCODE_PATH missing}"
: "${IOS_SDK_PATH:?IOS_SDK_PATH missing}"
: "${IOS_MIN_VERSION:?IOS_MIN_VERSION missing}"
: "${IOS_PREFIX:?IOS_PREFIX missing}"

export CC="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
export CXX="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++"
export AR="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar"
export RANLIB="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib"
export STRIP="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip"

# iOS 16兼容的编译选项
export CFLAGS="-arch arm64 -isysroot ${IOS_SDK_PATH} -mios-version-min=${IOS_MIN_VERSION} -fembed-bitcode -fno-common"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-arch arm64 -isysroot ${IOS_SDK_PATH} -mios-version-min=${IOS_MIN_VERSION} -Wl,-rpath,@executable_path -Wl,-rpath,@loader_path"export PKG_CONFIG_PATH="$IOS_PREFIX/lib/pkgconfig"
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
    --disable-shared \
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
    -DENABLE_STATIC=ON \
    -DENABLE_CLI=OFF \
    -DENABLE_ASSEMBLY=OFF \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${IOS_MIN_VERSION} \
    -DCMAKE_OSX_SYSROOT="$IOS_SDK_PATH" \
    ../../source
  make -j"$NPROC" && make install
  popd >/dev/null
  
  # Manually create x265.pc file since cmake doesn't generate it properly
  cat > "$IOS_PREFIX/lib/pkgconfig/x265.pc" <<PC
prefix=$IOS_PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: x265
Description: H.265/HEVC video encoder
Version: 3.6
Libs: -L\${libdir} -lx265 -lc++ -lSystem
Cflags: -I\${includedir}
PC
fi

# Temporarily disable libvpx due to installation issues
# Will re-enable after fixing header installation
echo "[deps] Skip libvpx (temporarily disabled)"
# echo "[deps] Build libvpx"
# if [ ! -f "$IOS_PREFIX/lib/libvpx.a" ]; then
#   rm -rf libvpx && git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git
#   pushd libvpx >/dev/null
#   
#   export CFLAGS="-arch arm64 -mios-version-min=$IOS_MIN_VERSION -isysroot $IOS_SDK_PATH"
#   export LDFLAGS="-arch arm64 -mios-version-min=$IOS_MIN_VERSION -isysroot $IOS_SDK_PATH"
#   
#   ./configure \
#     --target=arm64-darwin20-gcc \
#     --prefix="$IOS_PREFIX" \
#     --disable-examples \
#     --disable-docs \
#     --disable-unit-tests \
#     --enable-vp8 \
#     --enable-vp9 \
#     --enable-pic \
#     --disable-shared \
#     --enable-static
#   make -j"$NPROC" && make install
#   popd >/dev/null
#   
#   # Create pkg-config file for libvpx
#   cat > "$IOS_PREFIX/lib/pkgconfig/vpx.pc" <<PC
# prefix=$IOS_PREFIX
# exec_prefix=\${prefix}
# libdir=\${exec_prefix}/lib
# includedir=\${prefix}/include
# 
# Name: vpx
# Description: WebM VP8/VP9 Codec SDK
# Version: 1.13.1
# Requires:
# Libs: -L\${libdir} -lvpx
# Cflags: -I\${includedir}
# PC
# fi

echo "[deps] Build libaom (AV1)"
if [ ! -f "$IOS_PREFIX/lib/libaom.a" ]; then
  rm -rf aom && git clone --depth 1 https://aomedia.googlesource.com/aom
  pushd aom >/dev/null
  mkdir build_ios && cd build_ios
  cmake .. \
    -DCMAKE_INSTALL_PREFIX="$IOS_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_SHARED=OFF \
    -DENABLE_STATIC=ON \
    -DENABLE_NASM=OFF \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${IOS_MIN_VERSION} \
    -DCMAKE_OSX_SYSROOT="$IOS_SDK_PATH" \
    -DENABLE_TESTS=OFF \
    -DENABLE_EXAMPLES=OFF \
    -DAOM_TARGET_CPU=arm64
  make -j"$NPROC" && make install
  popd >/dev/null
  
  # Manually create aom.pc file since cmake doesn't generate it properly
  cat > "$IOS_PREFIX/lib/pkgconfig/aom.pc" <<PC
prefix=$IOS_PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: aom
Description: Alliance for Open Media AV1 codec library v3.13.1.
Version: 3.13.1
Libs: -L\${libdir} -laom -lc++ -lSystem
Cflags: -I\${includedir}
PC
fi

echo "[deps] Build libmp3lame"
if [ ! -f "$IOS_PREFIX/lib/libmp3lame.a" ]; then
  rm -f lame-3.100.tar.gz
  fetch "https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz" "lame-3.100.tar.gz"
  tar -xzf lame-3.100.tar.gz
  pushd lame-3.100 >/dev/null
  ./configure \
    --host=aarch64-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --disable-shared \
    --enable-static \
    --disable-frontend \
    --disable-decoder \
    --enable-nasm=no
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Build libvorbis"
if [ ! -f "$IOS_PREFIX/lib/libvorbis.a" ]; then
  rm -rf libvorbis && git clone --depth 1 https://github.com/xiph/vorbis.git libvorbis
  rm -rf libogg && git clone --depth 1 https://github.com/xiph/ogg.git libogg
  
  # Build libogg first (dependency for libvorbis)
  pushd libogg >/dev/null
  ./autogen.sh
  ./configure \
    --host=aarch64-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --disable-shared \
    --enable-static
  make -j"$NPROC" && make install
  popd >/dev/null
  
  # Build libvorbis
  pushd libvorbis >/dev/null
  ./autogen.sh
  ./configure \
    --host=aarch64-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --disable-shared \
    --enable-static \
    --with-ogg="$IOS_PREFIX"
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Build libwebp"
if [ ! -f "$IOS_PREFIX/lib/libwebp.a" ]; then
  rm -rf libwebp && git clone --depth 1 https://chromium.googlesource.com/webm/libwebp.git
  pushd libwebp >/dev/null
  ./autogen.sh
  ./configure \
    --host=aarch64-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --disable-shared \
    --enable-static \
    --disable-gl \
    --disable-sdl \
    --disable-png \
    --disable-jpeg \
    --disable-tiff \
    --disable-gif
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Build libfreetype"
if [ ! -f "$IOS_PREFIX/lib/libfreetype.a" ]; then
  rm -f freetype-2.13.2.tar.xz
  fetch "https://download.savannah.gnu.org/releases/freetype/freetype-2.13.2.tar.xz" "freetype-2.13.2.tar.xz"
  tar -xf freetype-2.13.2.tar.xz
  pushd freetype-2.13.2 >/dev/null
  ./configure \
    --host=aarch64-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --disable-shared \
    --enable-static \
    --without-png \
    --without-bzip2 \
    --without-harfbuzz
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Build libass"
if [ ! -f "$IOS_PREFIX/lib/libass.a" ]; then
  rm -rf libass && git clone --depth 1 https://github.com/libass/libass.git
  pushd libass >/dev/null
  ./autogen.sh
  ./configure \
    --host=aarch64-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --disable-shared \
    --enable-static \
    --disable-harfbuzz \
    --disable-fontconfig
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Build libtheora"
if [ ! -f "$IOS_PREFIX/lib/libtheora.a" ]; then
  rm -rf libtheora && git clone --depth 1 https://github.com/xiph/theora.git libtheora
  pushd libtheora >/dev/null
  ./autogen.sh
  ./configure \
    --host=aarch64-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --disable-shared \
    --enable-static \
    --disable-examples \
    --disable-spec \
    --with-ogg="$IOS_PREFIX"
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Build opus"
if [ ! -f "$IOS_PREFIX/lib/libopus.a" ]; then
  rm -rf opus && git clone --depth 1 https://github.com/xiph/opus.git
  pushd opus >/dev/null
  ./autogen.sh
  ./configure \
    --host=arm-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --enable-static \
    --disable-shared \
    --disable-asm \
    --disable-intrinsics
  make -j"$NPROC" && make install
  # Ensure opus headers are accessible at include root level
  if [ -d "$IOS_PREFIX/include/opus" ]; then
    echo "Copying opus headers to include root for FFmpeg compatibility..."
    cp "$IOS_PREFIX/include/opus"/*.h "$IOS_PREFIX/include/" || true
  fi
  popd >/dev/null
  # Ensure pkg-config file exists with correct paths
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
Cflags: -I\${includedir}
PC
  fi
fi

echo "[deps] Build libvpx (VP8/VP9)"
if [ ! -f "$IOS_PREFIX/lib/libvpx.a" ]; then
  rm -rf libvpx && git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git
  pushd libvpx >/dev/null
  ./configure \
    --target=arm64-darwin20-gcc \
    --prefix="$IOS_PREFIX" \
    --disable-examples \
    --disable-docs \
    --disable-unit-tests \
    --enable-vp8 \
    --enable-vp9 \
    --enable-pic \
    --disable-shared \
    --enable-static
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Build libdav1d (AV1 decoder)"
if [ ! -f "$IOS_PREFIX/lib/libdav1d.a" ]; then
  rm -rf dav1d && git clone --depth 1 https://code.videolan.org/videolan/dav1d.git
  pushd dav1d >/dev/null
  # dav1d uses meson build system
  if ! command -v meson &> /dev/null; then
    pip3 install meson ninja
  fi
  meson build --prefix="$IOS_PREFIX" \
    --buildtype=release \
    --default-library=static \
    --cross-file=../meson-cross-ios.ini || \
  meson build --prefix="$IOS_PREFIX" \
    --buildtype=release \
    --default-library=static
  ninja -C build install
  popd >/dev/null
fi

echo "[deps] Build libopenjpeg"
if [ ! -f "$IOS_PREFIX/lib/libopenjp2.a" ]; then
  rm -rf openjpeg && git clone --depth 1 https://github.com/uclouvain/openjpeg.git
  pushd openjpeg >/dev/null
  mkdir build && cd build
  cmake .. \
    -DCMAKE_INSTALL_PREFIX="$IOS_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${IOS_MIN_VERSION} \
    -DCMAKE_OSX_SYSROOT="$IOS_SDK_PATH" \
    -DBUILD_CODEC=OFF
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Build libspeex"
if [ ! -f "$IOS_PREFIX/lib/libspeex.a" ]; then
  rm -rf speex && git clone --depth 1 https://github.com/xiph/speex.git
  pushd speex >/dev/null
  ./autogen.sh
  ./configure \
    --host=aarch64-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --disable-shared \
    --enable-static
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Build libxml2"
if [ ! -f "$IOS_PREFIX/lib/libxml2.a" ]; then
  rm -f libxml2-v2.12.8.tar.xz
  fetch "https://download.gnome.org/sources/libxml2/2.12/libxml2-2.12.8.tar.xz" "libxml2-v2.12.8.tar.xz"
  tar -xf libxml2-v2.12.8.tar.xz
  pushd libxml2-2.12.8 >/dev/null
  ./configure \
    --host=aarch64-apple-darwin \
    --prefix="$IOS_PREFIX" \
    --disable-shared \
    --enable-static \
    --without-python \
    --without-lzma
  make -j"$NPROC" && make install
  popd >/dev/null
fi

echo "[deps] Summary - Core libraries built:"
ls -la "$IOS_PREFIX/lib/"*.a || true
echo "pkg-config files:"
ls -la "$IOS_PREFIX/lib/pkgconfig" || true
PKG_CONFIG_PATH="$IOS_PREFIX/lib/pkgconfig" pkg-config --list-all | grep -E "(sdl2|x264|x265|vpx|aom|opus)" || true