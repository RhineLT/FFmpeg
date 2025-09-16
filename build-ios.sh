#!/bin/bash

# FFmpeg 8.0 iOS ARM64 Build Script for Jailbroken devices
# This script builds FFmpeg with extensive codec support for iOS ARM64 architecture

set -e

# Configuration
IOS_MIN_VERSION="12.0"
PREFIX="/var/jb/usr"
ARCH="arm64"
BUILD_DIR="build-ios-arm64"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    error "This script must be run on macOS with Xcode installed"
fi

# Check Xcode installation
if ! command -v xcode-select &> /dev/null; then
    error "Xcode is not installed or not properly configured"
fi

XCODE_PATH=$(xcode-select -p)
IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)

log "Using Xcode at: $XCODE_PATH"
log "iOS SDK Path: $IOS_SDK_PATH"
log "iOS Min Version: $IOS_MIN_VERSION"
log "Target Architecture: $ARCH"

# Check for required tools
check_tool() {
    if ! command -v $1 &> /dev/null; then
        error "$1 is required but not installed. Please install via: brew install $2"
    fi
}

log "Checking build dependencies..."
check_tool "nasm" "nasm"
check_tool "yasm" "yasm"
check_tool "pkg-config" "pkg-config"

# Check for codec libraries
log "Checking codec libraries..."
LIBS_TO_CHECK="x264 x265 libvpx opus vorbis theora lame"
LIBS_TO_CHECK="$LIBS_TO_CHECK libass freetype fontconfig fribidi"
LIBS_TO_CHECK="$LIBS_TO_CHECK sox rubberband snappy zvbi zeromq"
LIBS_TO_CHECK="$LIBS_TO_CHECK webp libxml2 vid.stab zimg"

for lib in $LIBS_TO_CHECK; do
    if ! pkg-config --exists $lib 2>/dev/null && ! brew list $lib &>/dev/null; then
        warn "$lib not found via pkg-config or brew"
    fi
done

# Create build directory
log "Creating build directory: $BUILD_DIR"
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
cd $BUILD_DIR

# Set up cross-compilation environment
export CROSS_TOP="${XCODE_PATH}/Platforms/iPhoneOS.platform/Developer"
export CROSS_SDK="iPhoneOS.sdk"
export CC="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
export CXX="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++"
export AR="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar"
export NM="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/nm"
export RANLIB="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib"
export STRIP="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip"

# Configure FFmpeg
log "Configuring FFmpeg 8.0 for iOS ARM64..."

../configure \
    --prefix="$PREFIX" \
    --enable-cross-compile \
    --target-os=darwin \
    --arch="$ARCH" \
    --cc="$CC" \
    --cxx="$CXX" \
    --nm="$NM" \
    --ar="$AR" \
    --ranlib="$RANLIB" \
    --strip="$STRIP" \
    --sysroot="$IOS_SDK_PATH" \
    --extra-cflags="-arch $ARCH -mios-version-min=$IOS_MIN_VERSION -fembed-bitcode -O3" \
    --extra-ldflags="-arch $ARCH -mios-version-min=$IOS_MIN_VERSION" \
    \
    `# Basic options` \
    --enable-shared \
    --enable-pthreads \
    --enable-version3 \
    --enable-gpl \
    --enable-nonfree \
    --enable-ffplay \
    --enable-optimizations \
    --enable-small \
    \
    `# Legacy codec support (maintain compatibility with v5.1.2)` \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libvpx \
    --enable-libopus \
    --enable-libvorbis \
    --enable-libtheora \
    --enable-libmp3lame \
    --enable-libass \
    --enable-libfreetype \
    --enable-libfontconfig \
    --enable-libfribidi \
    --enable-libsoxr \
    --enable-librubberband \
    --enable-libsnappy \
    --enable-libzvbi \
    --enable-libzmq \
    --enable-libwebp \
    --enable-libxml2 \
    --enable-libvidstab \
    --enable-libzimg \
    \
    `# Modern codec support (FFmpeg 8.0 new features)` \
    --enable-libaom-av1 \
    --enable-libdav1d \
    --enable-libsvtav1 \
    --enable-librav1e \
    --enable-libvvenc \
    --enable-libjxl \
    --enable-libkvazaar \
    --enable-liblc3 \
    --enable-libshine \
    --enable-libspeex \
    --enable-libtwolame \
    \
    `# Hardware acceleration` \
    --enable-hwaccels \
    --enable-videotoolbox \
    --enable-audiotoolbox \
    \
    `# Disable unwanted features` \
    --disable-libbluray \
    --disable-libjack \
    --disable-indev=jack \
    --disable-xlib \
    --disable-debug \
    --disable-doc \
    --disable-static \
    \
    `# Enable additional formats and protocols` \
    --enable-protocol=https \
    --enable-protocol=http \
    --enable-protocol=ftp \
    --enable-protocol=tcp \
    --enable-protocol=udp \
    --enable-protocol=rtp \
    --enable-demuxer=mov \
    --enable-demuxer=mp4 \
    --enable-demuxer=avi \
    --enable-demuxer=mkv \
    --enable-demuxer=flv \
    --enable-muxer=mov \
    --enable-muxer=mp4 \
    --enable-muxer=avi \
    --enable-muxer=mkv \
    --enable-muxer=flv

if [ $? -ne 0 ]; then
    error "Configuration failed!"
fi

log "Configuration completed successfully!"

# Build FFmpeg
log "Building FFmpeg (this may take a while)..."
CPU_COUNT=$(sysctl -n hw.ncpu)
log "Using $CPU_COUNT CPU cores for compilation"

make -j$CPU_COUNT

if [ $? -ne 0 ]; then
    error "Build failed!"
fi

log "Build completed successfully!"

# Install to temporary directory
log "Installing FFmpeg..."
INSTALL_DIR="$PWD/install"
make install DESTDIR="$INSTALL_DIR"

if [ $? -ne 0 ]; then
    error "Installation failed!"
fi

# Create distribution packages
log "Creating distribution packages..."

# 1. Create simple archive
ARCHIVE_NAME="ffmpeg-8.0-ios-arm64-jailbreak"
mkdir -p "$ARCHIVE_NAME"
cp -r "$INSTALL_DIR$PREFIX"/* "$ARCHIVE_NAME/"

# Create version info file
cat > "$ARCHIVE_NAME/VERSION.txt" << EOF
FFmpeg 8.0 for iOS ARM64 (Jailbroken)
Built on: $(date)
Architecture: $ARCH
iOS Min Version: $IOS_MIN_VERSION
Build Configuration: Enhanced with modern codecs

Supported Codecs:
- Video: H.264 (x264), H.265/HEVC (x265), VP8/VP9 (libvpx), AV1 (libaom, dav1d, SVT-AV1, rav1e)
- Audio: AAC, MP3 (LAME), Opus, Vorbis, Theora, LC3
- Subtitles: ASS/SSA (libass), teletext (libzvbi)
- Images: JPEG XL (libjxl), WebP

New Features in 8.0:
- Improved AV1 encoding performance
- JPEG XL support for next-gen image compression
- VVC (H.266) experimental support
- Enhanced HDR support
- Better hardware acceleration
EOF

# Create tarball
tar -czf "$ARCHIVE_NAME.tar.gz" "$ARCHIVE_NAME/"

# 2. Create DEB package for Cydia/Sileo
DEB_DIR="deb"
mkdir -p "$DEB_DIR/DEBIAN" "$DEB_DIR$PREFIX"
cp -r "$INSTALL_DIR$PREFIX"/* "$DEB_DIR$PREFIX/"

# Create control file
cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: ffmpeg
Version: 8.0-1
Section: Multimedia
Priority: optional
Architecture: iphoneos-arm64
Depends: 
Maintainer: FFmpeg iOS Builder <ffmpeg@example.com>
Description: FFmpeg 8.0 - Complete multimedia framework
 FFmpeg is a complete, cross-platform solution to record, convert
 and stream audio and video. This version is compiled for iOS ARM64
 with extensive codec support including modern formats like AV1,
 HEVC, and JPEG XL.
 .
 Features:
  - All major video/audio codecs
  - Hardware acceleration support
  - Modern codecs (AV1, HEVC, JPEG XL)
  - Subtitle support
  - Network streaming protocols
EOF

# Create postinst script
cat > "$DEB_DIR/DEBIAN/postinst" << EOF
#!/bin/bash
echo "FFmpeg 8.0 has been installed to $PREFIX/bin/"
echo "You can now use: ffmpeg, ffplay commands"
ldid -S $PREFIX/bin/ffmpeg
ldid -S $PREFIX/bin/ffplay
EOF

chmod +x "$DEB_DIR/DEBIAN/postinst"

# Build DEB package
if command -v dpkg-deb &> /dev/null; then
    dpkg-deb --build "$DEB_DIR" "ffmpeg_8.0-1_iphoneos-arm64.deb"
    log "DEB package created: ffmpeg_8.0-1_iphoneos-arm64.deb"
else
    warn "dpkg-deb not found, skipping DEB package creation"
fi

# Display results
log "Build completed successfully!"
echo
echo "=== Build Results ==="
echo "Archive: $ARCHIVE_NAME.tar.gz"
if [ -f "ffmpeg_8.0-1_iphoneos-arm64.deb" ]; then
    echo "DEB Package: ffmpeg_8.0-1_iphoneos-arm64.deb"
fi
echo "Install Directory: $INSTALL_DIR$PREFIX"
echo
echo "=== Installation Instructions ==="
echo "For jailbroken iOS devices:"
echo "1. Transfer the DEB file to your device"
echo "2. Install via Cydia/Sileo or run: dpkg -i ffmpeg_8.0-1_iphoneos-arm64.deb"
echo "3. Or extract the archive manually to /var/jb/usr/"
echo
echo "=== Verification ==="
echo "After installation, test with:"
echo "  $PREFIX/bin/ffmpeg -version"
echo "  $PREFIX/bin/ffmpeg -encoders | grep -E '(x264|x265|aom|dav1d)'"

# Test the built binary (if possible)
if [ -f "$INSTALL_DIR$PREFIX/bin/ffmpeg" ]; then
    log "Testing built binary..."
    if "$INSTALL_DIR$PREFIX/bin/ffmpeg" -version &>/dev/null; then
        log "Binary test passed!"
    else
        warn "Binary test failed - this is normal when cross-compiling for iOS"
    fi
fi

log "All done! 🎉"