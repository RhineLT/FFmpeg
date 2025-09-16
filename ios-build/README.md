# iOS FFmpeg 构建项目说明

本项目为越狱 iOS 设备（iOS 16.5 M1 iPad）构建完整的 FFmpeg 8.0，包含 ffmpeg、ffprobe、ffplay 三个工具。

## 项目结构

```
ios-build/
├── scripts/           # 构建脚本
│   ├── setup-env.sh     # 环境变量设置
│   ├── build-deps.sh    # 构建第三方依赖（SDL2、x264、x265等）
│   ├── build-ffmpeg.sh  # FFmpeg 配置和编译
│   └── package.sh       # 打包为 tar.gz 和 .deb
└── ci/               # CI 辅助工具
    ├── validate-workflows.sh  # YAML 语法校验（Python）
    └── gh-watch-latest.sh     # GitHub 运行监控
```

## GitHub Actions 配置

- **runs-on**: `macos-13` （包含 Xcode 14.3.1 + iOS 16.x SDK）
- **Xcode版本**: 14.3.1（支持 iOS 16.5 目标设备）
- **目标架构**: arm64（适配 M1 iPad）
- **安装前缀**: `/var/jb/usr`（越狱环境标准路径）

## 本地开发工作流

### 1. 启用 pre-push 语法校验

```bash
# 配置 Git 使用项目提供的 hooks
git config core.hooksPath .githooks

# 或手动运行校验
bash ios-build/ci/validate-workflows.sh
```

### 2. 推送后监控构建

```bash
# 方法1：监控当前分支的最新构建
bash ios-build/ci/gh-watch-latest.sh

# 方法2：监控特定工作流
bash ios-build/ci/gh-watch-latest.sh build-ios.yml main

# 需要先认证 GitHub CLI
gh auth login
```

### 3. 构建产物

成功构建后会生成：
- `ffmpeg-8.0-ios-arm64.tar.gz`（手动安装包）
- `ffmpeg-8.0-ios-arm64.deb`（Cydia/Sileo 包）

## 安装到越狱设备

### DEB 包安装（推荐）
1. 下载 `ffmpeg-8.0-ios-arm64.deb`
2. 通过 Cydia、Sileo 或 `dpkg -i` 安装

### 手动安装
1. 解压 `ffmpeg-8.0-ios-arm64.tar.gz`
2. 在设备上执行 `./install.sh`
3. 使用 `ldid -S` 为二进制签名

## 技术细节

- **编译器**: Xcode 14.3.1 Clang
- **最低iOS版本**: 12.0（向下兼容）
- **优化级别**: -O3 + size optimization
- **链接方式**: 静态链接所有依赖
- **支持编解码器**: H.264/H.265、VP8/VP9、AV1、MP3、AAC、Opus
- **UI后端**: SDL2（用于 ffplay）

## 故障排除

### 构建失败
1. 检查 GitHub Actions 日志
2. 使用 `gh-watch-latest.sh` 实时监控
3. 验证依赖库构建状态

### 设备兼容性
- 要求越狱环境（/var/jb 引导程序）
- 支持：checkra1n、unc0ver、Taurine、Odyssey
- 需要约 50MB 存储空间