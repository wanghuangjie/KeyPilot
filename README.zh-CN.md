# KeyPilot

<p align="center">
  <img src="assets/keypilot-icon-master.png" width="180" alt="KeyPilot 图标">
</p>

<p align="center">
  越狱 iPadOS 全局硬件键盘快捷键。
</p>

<p align="center">
  <a href="README.md">English</a> · 简体中文
</p>

KeyPilot 是一个面向 rootless 越狱 iPadOS 的 tweak，带独立配置 App。录入硬件键盘组合键并选择已安装 App 后，即可在全局启动它；如果 App 已在后台，则直接切回前台。同时保留 URL 和 shell 动作。

## 界面截图

<p align="center">
  <img src="screenshots/ipados.jpeg" alt="KeyPilot 在 iPadOS 上的简体中文界面">
</p>

## 主要功能

- 在 SpringBoard 和前台 UIKit App 中捕获快捷键
- 图形化录入组合键，无需手写 HID key code
- 搜索并手动选择已安装 App，自动填写 Bundle ID
- 通过 Conrad Kramer 的 `open` 工具启动 App 或切回现有进程
- 支持 Control、Option、Shift、Command、Caps Lock、方向键、Esc 等
- 支持 `url:`、`shell:` 和 `sh:` 动作
- 最多 64 条规则，支持启用/停用、左滑删除和重复检测
- 修改配置后立即生效，无需 respring
- 每次实体按键只触发一次，带防抖
- 简体中文/英文界面，自动跟随系统语言
- 执行日志：`/var/mobile/Library/KeyPilot/keypilot.log`

## 兼容性

- rootless iPadOS 15 或更高版本
- arm64 和 arm64e
- 具备 UIKit/SpringBoard tweak 注入能力的越狱，如 ElleKit 或 MobileSubstrate
- 依赖 BigBoss 源的 `com.conradkramer.open`

开发目标设备是 iPadOS 17.0 的 M1 iPad。仅有 TrollStore 不够，KeyPilot 需要 tweak 注入环境。

## 动作语法

| 写法 | 含义 | 示例 |
|---|---|---|
| `app:<bundle-id>` | 启动 App 或切回前台 | `app:com.apple.mobilesafari` |
| `open:<bundle-id>` | `app:` 的别名 | `open:com.apple.Preferences` |
| `url:<URL>` | 打开 URL 或 URL Scheme | `url:https://example.com` |
| `shell:<命令>` | 用 `/bin/sh -c` 执行 | `shell:touch /var/mobile/keypilot-test` |
| `sh:<命令>` | `shell:` 的别名 | `sh:date` |
| 无前缀 | 按 App Bundle ID 处理 | `com.apple.mobilesafari` |

shell 命令以 `mobile` 用户执行，仍可能删除数据或导致 SpringBoard 反复崩溃，只配置自己理解的命令。

## 安装

从 [Releases](https://github.com/wanghuangjie/KeyPilot/releases) 下载 rootless `.deb`，使用 Sileo 或 Zebra 安装后 respring。必须同时安装 BigBoss 的 `com.conradkramer.open`。

打开桌面上的 KeyPilot，添加规则，录入组合键，再通过列表按钮选择目标 App。

## 编译

安装 [Theos](https://theos.dev/docs/installation)，在项目根目录执行：

```sh
export THEOS=/path/to/theos
make clean package FINALPACKAGE=1
```

rootless 安装包会生成在 `packages/` 目录。

## 故障恢复

- 如果快捷键只在桌面有效，请检查 tweak 注入管理器是否排除了对应 App。
- 直接读取底层 HID 而不经过 UIKit 的 App 目前不支持。
- 若 shell 规则导致反复 respring，进入越狱安全/禁用 tweak 模式，然后卸载 `com.whj.keypilot`。
- KeyPilot 不修改 iPadOS 系统文件，配置 domain 为 `com.whj.keypilot`。

## 支持开发

如果 KeyPilot 对你有帮助，欢迎通过 PayPal 捐赠：**wanghuangjie@vip.qq.com**

## 开源协议

KeyPilot 使用 [MIT License](LICENSE) 开源。
