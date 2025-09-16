#!/bin/bash

# FFmpeg iOS Build Verification Script
# This script tests the compiled FFmpeg binary to ensure it works correctly

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Find FFmpeg binary
FFMPEG_PATH=""
for path in "/var/jb/usr/bin/ffmpeg" "./build-ios-arm64/install/var/jb/usr/bin/ffmpeg" "./ffmpeg-8.0-ios-arm64/bin/ffmpeg"; do
    if [ -f "$path" ]; then
        FFMPEG_PATH="$path"
        break
    fi
done

if [ -z "$FFMPEG_PATH" ]; then
    error "FFmpeg binary not found. Please build first or specify path."
    exit 1
fi

log "Found FFmpeg at: $FFMPEG_PATH"

# Test 1: Version check
log "Testing FFmpeg version..."
if $FFMPEG_PATH -version | head -1; then
    info "✅ Version check passed"
else
    error "❌ Version check failed"
    exit 1
fi

# Test 2: Check for required codecs
log "Checking codec support..."

required_encoders=("libx264" "libx265" "libvpx-vp8" "libvpx-vp9" "libmp3lame" "libopus" "aac")
missing_encoders=()

for encoder in "${required_encoders[@]}"; do
    if $FFMPEG_PATH -encoders 2>/dev/null | grep -q "$encoder"; then
        info "✅ Found encoder: $encoder"
    else
        warn "❌ Missing encoder: $encoder"
        missing_encoders+=("$encoder")
    fi
done

# Check for new FFmpeg 8.0 features
log "Checking FFmpeg 8.0 new features..."

new_features=("libaom-av1" "libdav1d" "libsvtav1" "libjxl")
found_new_features=()

for feature in "${new_features[@]}"; do
    if $FFMPEG_PATH -encoders 2>/dev/null | grep -q "$feature" || $FFMPEG_PATH -decoders 2>/dev/null | grep -q "$feature"; then
        info "✅ Found new feature: $feature"
        found_new_features+=("$feature")
    else
        info "⚠️  New feature not available: $feature"
    fi
done

# Test 3: Check supported formats
log "Checking format support..."
format_count=$($FFMPEG_PATH -formats 2>/dev/null | wc -l)
info "Supported formats: $format_count"

# Test 4: Check protocol support
log "Checking protocol support..."
if $FFMPEG_PATH -protocols 2>/dev/null | grep -q "http"; then
    info "✅ HTTP protocol supported"
else
    warn "❌ HTTP protocol missing"
fi

# Test 5: Library linkage test (if on macOS for cross-platform testing)
if [[ "$OSTYPE" == "darwin"* ]] && command -v otool &> /dev/null; then
    log "Checking library linkage..."
    libs=$(otool -L "$FFMPEG_PATH" 2>/dev/null | grep -c "dylib" || echo "0")
    info "Linked dynamic libraries: $libs"
fi

# Test 6: Basic functionality test (if we can run it)
log "Testing basic functionality..."
if command -v file &> /dev/null; then
    file_info=$(file "$FFMPEG_PATH")
    info "Binary info: $file_info"
fi

# Test 7: Create a simple test if we have input generation capability
log "Testing encoding capability..."
test_dir=$(mktemp -d)
cd "$test_dir"

# Try to create a simple test pattern
if $FFMPEG_PATH -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -y test.png 2>/dev/null; then
    info "✅ Basic encoding test passed"
    file_size=$(stat -f%z test.png 2>/dev/null || stat -c%s test.png 2>/dev/null || echo "unknown")
    info "Generated test file size: $file_size bytes"
else
    warn "❌ Basic encoding test failed (expected on cross-compiled builds)"
fi

# Cleanup
cd - >/dev/null
rm -rf "$test_dir"

# Summary
echo
log "=== Test Summary ==="
echo "FFmpeg Binary: $FFMPEG_PATH"
echo "Required encoders found: $((${#required_encoders[@]} - ${#missing_encoders[@]})/${#required_encoders[@]})"
echo "New FFmpeg 8.0 features: ${#found_new_features[@]}/${#new_features[@]}"

if [ ${#missing_encoders[@]} -eq 0 ]; then
    log "🎉 All required encoders are available!"
else
    warn "Missing encoders: ${missing_encoders[*]}"
fi

if [ ${#found_new_features[@]} -gt 0 ]; then
    log "🚀 FFmpeg 8.0 new features available: ${found_new_features[*]}"
fi

# Provide usage examples
echo
info "=== Usage Examples ==="
echo "# Basic video conversion:"
echo "$FFMPEG_PATH -i input.mp4 -c:v libx264 -c:a aac output.mp4"
echo
echo "# High quality HEVC encoding:"
echo "$FFMPEG_PATH -i input.mp4 -c:v libx265 -crf 23 -c:a libopus output.mkv"
echo
if [[ " ${found_new_features[*]} " =~ " libaom-av1 " ]]; then
    echo "# AV1 encoding (new in 8.0):"
    echo "$FFMPEG_PATH -i input.mp4 -c:v libaom-av1 -crf 30 -c:a libopus output.webm"
    echo
fi
echo "# Extract audio:"
echo "$FFMPEG_PATH -i input.mp4 -vn -c:a libmp3lame -b:a 192k output.mp3"
echo
echo "# Stream from network:"
echo "$FFMPEG_PATH -i http://example.com/stream.m3u8 -c copy output.mp4"

log "Verification complete!"