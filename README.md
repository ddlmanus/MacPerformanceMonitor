# Mac 性能监控 (Mac Performance Monitor)
<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="App Icon">
</p>

<p align="center">
  <strong>一款轻量级的 macOS 状态栏性能监控工具</strong>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013+-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9+-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
</p>
---

## ✨ 功能特性

| 功能 | 说明 |
|------|------|
| 📱 **应用监控** | 查看运行中的应用及其 CPU/内存占用，可退出应用 |
| 💻 **进程监控** | 查看所有进程的 CPU/内存占用情况 |
| 🔌 **端口监控** | 查看端口占用情况，可释放端口 |
| 🧹 **缓存清理** | 一键清理浏览器缓存、系统缓存 |

## 📸 截图

<p align="center">
 
<p align="center">
  <img width="804" height="1000" alt="image" src="https://github.com/user-attachments/assets/9c6aaffe-8e09-472f-b073-a3d8e1652016" />
</p>

<p align="center">
  <strong>一款轻量级的 macOS 状态栏性能监控工具</strong>
</p>

<p align="center">
 <img width="800" height="1016" alt="image" src="https://github.com/user-attachments/assets/3ec7fd60-a57a-4de8-930f-346e330873a6" />
<img width="822" height="996" alt="image" src="https://github.com/user-attachments/assets/db7f261a-eb16-4ff2-8de6-9fd49f5bf88d" />

<img width="804" height="1008" alt="image" src="https://github.com/user-attachments/assets/c03b660e-0177-4c50-affc-d05356f2a410" />

<img width="800" height="1000" alt="image" src="https://github.com/user-attachments/assets/781639ec-fe0c-4070-8a21-6d22733b64f9" />
</p>
</p>

## 🚀 安装

### 方法一：下载 DMG（推荐）

前往 [Releases](https://github.com/YOUR_USERNAME/MacPerformanceMonitor/releases) 下载最新版本：

- `Mac性能监控-arm64.dmg` - Apple Silicon (M1/M2/M3)
- `Mac性能监控-x86_64.dmg` - Intel

### 方法二：从源码编译

```bash
# 克隆仓库
git clone https://github.com/YOUR_USERNAME/MacPerformanceMonitor.git
cd MacPerformanceMonitor

# 编译
swift build -c release

# 运行
.build/release/MacPerformanceMonitor
```

## 🛠 开发

### 要求

- macOS 13.0+
- Swift 5.9+
- Command Line Tools (`xcode-select --install`)

### 编译

```bash
# Apple Silicon
swift build -c release --arch arm64

# Intel
swift build -c release --arch x86_64

# Universal (同时支持两种架构)
swift build -c release --arch arm64 --arch x86_64
```

### 打包 DMG

```bash
./build.sh arm64      # 或 x86_64, universal
```

## 📁 项目结构

```
MacPerformanceMonitor/
├── Package.swift          # Swift Package 配置
├── Sources/
│   └── main.swift         # 完整源代码
├── build.sh               # 打包脚本
├── LICENSE                # MIT 许可证
└── README.md              # 说明文档
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。
