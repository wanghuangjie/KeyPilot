# Reddit release copy — KeyPilot 0.3.0

This copy already points to the public GitHub repository and v0.3.0 release asset.

## English post

### Title

`[Free Release] KeyPilot — launch or foreground apps with global hardware-keyboard shortcuts on jailbroken iPadOS`

### Body

Hi r/jailbreak! I made **KeyPilot**, a small rootless tweak for iPad users who work with a hardware keyboard.

Record a shortcut in the KeyPilot app, then choose an installed app from the searchable list. Pressing that shortcut from SpringBoard or a UIKit app launches the selected app; if it is already running in the background, it is brought to the foreground. You can also open URLs or run shell commands.

**Features**

- Visual shortcut recording—no HID key codes to type
- Searchable installed-app picker with automatic Bundle ID entry
- App launch/foreground actions via Conrad Kramer's `open` utility
- `url:` actions and `shell:` / `sh:` commands are still supported
- Enable, disable, delete, and duplicate-check up to 64 rules
- Changes apply immediately without a respring
- One action per physical key press, with debounce protection
- English and Simplified Chinese UI
- Native arm64 and arm64e slices

**Compatibility**

- Rootless jailbreak with tweak injection (ElleKit or MobileSubstrate)
- iPadOS 15 or later
- Built for arm64 and arm64e; the development target is an M1 iPad on iPadOS 17.0
- Requires `com.conradkramer.open`, available from BigBoss

**Action examples**

```text
app:com.apple.mobilesafari
url:https://reddit.com/r/jailbreak
shell:touch /var/mobile/keypilot-test
```

Shell actions run as the `mobile` user. They are powerful and potentially destructive, so only use commands you understand.

**Install**

Install the rootless `.deb` with Sileo or Zebra, then respring. Open KeyPilot from the Home Screen, add a rule, record a hardware-keyboard shortcut, and select an app with the list button.

Download: https://github.com/wanghuangjie/KeyPilot/releases/download/v0.3.0/com.whj.keypilot_0.3.0_iphoneos-arm64.deb

Source: https://github.com/wanghuangjie/KeyPilot

Icon: https://raw.githubusercontent.com/wanghuangjie/KeyPilot/main/assets/keypilot-icon-master.png

PayPal donations: **wanghuangjie@vip.qq.com**

Bug reports are welcome. If a shortcut works on SpringBoard but not inside a specific app, check whether your tweak-injection manager excludes that app. Apps that read raw HID input may not pass keyboard events through UIKit and are not supported yet.

## 中文发布文案

### 标题

`[免费发布] KeyPilot — 在越狱 iPadOS 上用全局硬件键盘快捷键启动或切换 App`

### 正文

大家好，我做了一个面向硬件键盘用户的 rootless tweak：**KeyPilot**。

在 KeyPilot 中录入组合键，再从可搜索的已安装 App 列表里选择目标。无论在桌面还是普通 UIKit App 中，按下组合键都会启动目标 App；如果 App 已在后台，则直接切回前台。它也保留了打开 URL 和执行 shell 命令的能力。

主要功能：图形化录入快捷键、手动选择 App、最多 64 条规则、规则启用/停用和删除、重复检测、配置即时生效、单次按键防重复触发，以及简体中文/英文界面。

兼容 rootless iPadOS 15+，包含 arm64 与 arm64e，开发目标设备为 iPadOS 17.0 的 M1 iPad。需要 ElleKit 或 MobileSubstrate 注入，并依赖 BigBoss 源的 `com.conradkramer.open`。

安装 rootless deb 后 respring，打开桌面上的 KeyPilot 即可配置。`shell:` 动作以 mobile 用户运行，仍可能造成数据丢失或反复 respring，只执行自己理解的命令。

下载：https://github.com/wanghuangjie/KeyPilot/releases/download/v0.3.0/com.whj.keypilot_0.3.0_iphoneos-arm64.deb

源码：https://github.com/wanghuangjie/KeyPilot

图标：https://raw.githubusercontent.com/wanghuangjie/KeyPilot/main/assets/keypilot-icon-master.png

PayPal 捐赠：**wanghuangjie@vip.qq.com**

欢迎反馈。如果快捷键只在桌面有效，请检查注入管理器是否排除了对应 App；直接读取底层 HID 的游戏或远程桌面 App 暂不支持。
