# FFmpeg 8.0 for iOS ARM64 (Jailbroken Devices)

This repository provides automated builds of FFmpeg 8.0 specifically compiled for iOS ARM64 devices that are jailbroken. The build maintains compatibility with your existing FFmpeg 5.1.2 configuration while adding new features and improvements from FFmpeg 8.0.

## 🎯 Features

### Codec Support (Same as your v5.1.2 + More)
- **Video Codecs**: H.264 (x264), H.265/HEVC (x265), VP8/VP9 (libvpx)
- **Audio Codecs**: AAC, MP3 (LAME), Opus, Vorbis, Theora
- **Subtitle Support**: ASS/SSA (libass), Teletext (libzvbi)
- **Image Formats**: WebP support

### New in FFmpeg 8.0
- **Modern Video Codecs**: AV1 (libaom, dav1d, SVT-AV1, rav1e)
- **Next-Gen Formats**: JPEG XL (libjxl), VVC/H.266 (experimental)
- **Improved Performance**: Better hardware acceleration, optimized encoding
- **Enhanced HDR**: Better support for HDR10, HDR10+, Dolby Vision
- **Audio**: LC3 codec support

### Build Configuration
```bash
# Your original v5.1.2 config (preserved):
--enable-libx264 --enable-libx265 --enable-libvpx --enable-libopus 
--enable-libvorbis --enable-libtheora --enable-libmp3lame --enable-libass 
--enable-libfreetype --enable-libfontconfig --enable-libfribidi 
--enable-libsoxr --enable-librubberband --enable-libsnappy 
--enable-libzvbi --enable-libzmq --enable-libwebp --enable-libxml2 
--enable-libvidstab --enable-libzimg

# New additions in v8.0:
--enable-libaom-av1 --enable-libdav1d --enable-libsvtav1 --enable-librav1e
--enable-libvvenc --enable-libjxl --enable-libkvazaar --enable-liblc3
```

## 🚀 Quick Start

### Option 1: Download Pre-built Binaries (Recommended)

1. Go to the [Releases](../../releases) page
2. Download the latest `ffmpeg-8.0-ios-arm64.tar.gz` or `.deb` file
3. Install on your jailbroken iOS device (see installation instructions below)

### Option 2: Build Using GitHub Actions

1. Fork this repository
2. Enable GitHub Actions in your fork
3. Push changes or manually trigger the workflow
4. Download the built artifacts from the Actions tab

### Option 3: Build Locally on macOS

```bash
# Prerequisites: macOS with Xcode installed
git clone https://github.com/yourusername/ffmpeg.git
cd ffmpeg
./build-ios.sh
```

## 📱 Installation on Jailbroken iOS

### Method 1: Using DEB Package (Cydia/Sileo)
```bash
# Transfer the .deb file to your device and install
dpkg -i ffmpeg_8.0-1_iphoneos-arm64.deb

# Or install via Cydia/Sileo if you have a local repository
```

### Method 2: Manual Installation
```bash
# Extract and copy files
tar -xzf ffmpeg-8.0-ios-arm64.tar.gz
cp -r ffmpeg-8.0-ios-arm64/* /var/jb/usr/

# Sign the binaries (important for iOS)
ldid -S /var/jb/usr/bin/ffmpeg
ldid -S /var/jb/usr/bin/ffplay
```

## ✅ Verification

After installation, verify FFmpeg is working:

```bash
# Check version
ffmpeg -version

# List available encoders
ffmpeg -encoders | grep -E "(x264|x265|aom|dav1d)"

# List available formats
ffmpeg -formats | head -20

# Test encoding (example)
ffmpeg -f lavfi -i testsrc2=duration=5:size=1920x1080:rate=30 \
       -c:v libx264 -preset fast -crf 23 test_output.mp4
```

Expected output should show:
```
ffmpeg version 8.0 Copyright (c) 2000-2024 the FFmpeg developers
built with Apple clang version...
configuration: --prefix=/var/jb/usr --enable-cross-compile --target-os=darwin --arch=arm64...
```

## 🏗️ Build System

### GitHub Actions Workflows

1. **`build-ios.yml`** - Full-featured build with all codecs
2. **`build-ios-simple.yml`** - Simplified build for faster CI

### Local Build Script

The `build-ios.sh` script provides:
- Automatic dependency checking
- Cross-compilation setup for iOS ARM64
- Comprehensive codec support
- Package creation (tar.gz and .deb)

## 📊 Comparison: v5.1.2 vs v8.0

| Feature | v5.1.2 | v8.0 |
|---------|---------|------|
| H.264 (x264) | ✅ | ✅ |
| H.265/HEVC (x265) | ✅ | ✅ |
| VP8/VP9 (libvpx) | ✅ | ✅ |
| AV1 | ❌ | ✅ (4 encoders) |
| JPEG XL | ❌ | ✅ |
| VVC/H.266 | ❌ | ✅ (experimental) |
| LC3 Audio | ❌ | ✅ |
| Hardware Accel | Limited | Enhanced |
| HDR Support | Basic | Advanced |

## 🛠️ Development

### Prerequisites
- macOS with Xcode 14.0+
- Homebrew for dependencies
- iOS SDK (comes with Xcode)

### Building Dependencies
```bash
# Install build tools
brew install nasm yasm pkg-config

# Install codec libraries
brew install x264 x265 libvpx opus vorbis theora lame
brew install libass freetype fontconfig fribidi
brew install sox rubberband snappy zvbi zeromq webp libxml2
```

### Customizing the Build
Edit the configure options in `build-ios.sh` or the GitHub Actions workflow to:
- Add/remove codec support
- Modify optimization settings
- Change installation prefix
- Adjust iOS minimum version

## 🐛 Troubleshooting

### Common Issues

1. **Binary won't run on iOS**
   - Ensure you've signed the binary: `ldid -S /var/jb/usr/bin/ffmpeg`
   - Check iOS version compatibility (built for iOS 12.0+)

2. **Missing codec errors**
   - Verify the codec was enabled during build
   - Check library dependencies are installed

3. **Permission denied**
   - Make sure binaries are executable: `chmod +x /var/jb/usr/bin/ffmpeg`

### Debug Build
For debugging, you can create a debug build:
```bash
# Edit build-ios.sh and add:
--enable-debug --disable-optimizations --disable-stripping
```

## 📄 License

This project follows FFmpeg's licensing:
- **GPL v3** - Due to GPL-licensed components (x264, x265, etc.)
- **LGPL v2.1** - For LGPL-only builds (remove GPL components)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes with the build script
4. Submit a pull request

## 📞 Support

- Check the [Issues](../../issues) page for known problems
- For FFmpeg usage questions, see the [official documentation](https://ffmpeg.org/documentation.html)
- For iOS-specific issues, include your iOS version and jailbreak type

## 🔄 Update Notes

### Version 8.0 Highlights
- **Performance**: Up to 20% faster encoding for common formats
- **Quality**: Improved rate-distortion for HEVC and AV1
- **Compatibility**: Better support for modern streaming formats
- **Hardware**: Enhanced VideoToolbox integration
- **New Formats**: JPEG XL, VVC, LC3 support

---

*Built with ❤️ for the iOS jailbreak community*