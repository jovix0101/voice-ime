# VoiceIME

## AI 源码
本项目复刻自: https://github.com/yetone/voice-input-src ，感谢提供了一种全部的开源形式。

本项目的 AI 源码指令如下：

```shell
mkdir -p voice-ime && cd voice-ime && \
codex exec \
  --full-auto \
  --sandbox danger-full-access <<'EOF'

请实现一个 macOS menu-bar 语音输入法应用（Swift，macOS 14+），具体要求：

1. 按住 Fn 键录音，松开后将转录文字注入当前聚焦的输入框。优先使用流式转录（Apple Speech Recognition framework）。Fn 键通过 CGEvent tap 全局监听，需抑制 Fn 事件传递以防止触发 emoji 选择器。
2. 默认语言必须为简体中文（zh-CN），确保开箱即用就能识别中文输入。同时在菜单栏提供语言切换选项（英语、简体中文、繁体中文、日语、韩语）。语言选择存储在 UserDefaults 中。
3. 录音时在屏幕底部居中显示一个特别优雅精致的无边框胶囊状悬浮窗，不要有红绿灯和 titlebar。使用 NSPanel（nonactivatingPanel）+ NSVisualEffectView（.hudWindow 材质），高度 56px，圆角半径 28px，包含：
   - 左侧 5 根竖条波形动画（44×32px），必须由实时音频 RMS 电平驱动。说话声音大波形就大，安静时波形就小。权重为 [0.5, 0.8, 1.0, 0.75, 0.55]，带平滑包络（attack 40%、release 15%），每根竖条加入 ±4% 随机抖动，波形清晰可见。
   - 右侧文字标签（宽度 160-560px 自适应）实时显示转录文本，随内容增长自动扩展
   - 入场弹簧动画（0.35s）、宽度过渡（0.25s）、退场缩放动画（0.22s）
4. 文字注入使用剪贴板 + 模拟 Cmd+V。注入前检测输入法，如为 CJK 输入法则临时切换到 ASCII（ABC/US），粘贴完成后恢复原输入法，并恢复剪贴板内容。
5. 接入 LLM 提升识别准确率（支持 OpenAI 兼容 API）。可配置 API Base URL、API Key、Model。LLM 只允许“极保守纠错”：仅修复明显识别错误（如“配森→Python”、“杰森→JSON”），禁止改写或润色。
6. 菜单栏提供 LLM Refinement 子菜单（启用开关 + Settings）。Settings 包含 API Base URL、API Key、Model 输入框，支持清空 API Key，并有 Test 和 Save 按钮。松开 Fn 后若启用 LLM，则显示“Refining...”并在完成后注入文本。
7. 应用使用 LSUIElement 模式运行（仅菜单栏，无 Dock 图标）。使用 Swift Package Manager 构建，提供 Makefile（build/run/install/clean），输出为签名 .app bundle。

【工程要求】
- 在当前目录创建完整项目（SPM）
- 项目名：VoiceIME
- 自动创建目录结构和所有 Swift 文件
- 自动生成 Makefile

【执行策略】
- 自动 build 项目
- 如果 build 失败，自动分析并修复
- 最多循环 5 次，直到成功
- 最终输出运行方式

EOF
```

*使用 GPT-5.4 模型*


VoiceIME 是一个基于 Swift + Swift Package Manager 的 macOS 菜单栏语音输入工具，面向 macOS 14+。按住 `Fn` 开始录音，松开后自动结束识别，并把转录结果注入当前聚焦的输入框。

应用以 `LSUIElement` 模式运行，仅显示菜单栏图标，不显示 Dock 图标。默认识别语言为简体中文，开箱即用即可进行中文语音输入。

## 功能特性

- 按住 `Fn` 键录音，松开后结束识别并自动注入文本
- 使用 Apple Speech Recognition 进行流式转录，录音过程中实时更新文本
- 全局监听 `Fn` 的 `flagsChanged` 事件，并吞掉该事件，尽量避免触发系统 emoji 选择器
- 默认语言为 `zh-CN`，支持从菜单栏切换 `English`、`简体中文`、`繁體中文`、`日本語`、`한국어`
- 语言与 LLM 配置持久化保存到 `UserDefaults`
- 底部居中 HUD 悬浮窗：
  - `NSPanel` + `NSVisualEffectView(.hudWindow)` 的无边框胶囊样式
  - 5 根由实时音频 RMS 电平驱动的波形条
  - 文本宽度会随转录内容自适应扩展
  - 包含入场、宽度变化、退场动画
- 使用“剪贴板 + 模拟 `Cmd+V`”完成文本注入
- 注入前会检测当前输入法；如果是中日韩输入法，会临时切换到 ASCII 输入源，粘贴结束后恢复
- 支持 OpenAI 兼容 API 的 LLM 保守纠错
  - 只允许修复明显识别错误
  - 禁止改写、润色、翻译、扩写、缩写
- 菜单栏提供 `LLM Refinement` 子菜单和设置窗口，可配置：
  - API Base URL
  - API Key
  - Model
  - Test / Save / Clear API Key

## 项目结构

```text
.
├── Makefile
├── Package.swift
├── README.md
├── Resources
│   └── App
│       └── Info.plist
└── Sources
    └── VoiceIME
        ├── AppDelegate.swift
        ├── AppSettingsStore.swift
        ├── AudioSpeechController.swift
        ├── HUDContentView.swift
        ├── HUDPanelController.swift
        ├── HUDViewModel.swift
        ├── HotkeyMonitor.swift
        ├── InputSourceManager.swift
        ├── LLMRefiner.swift
        ├── MenuBarController.swift
        ├── Models.swift
        ├── PermissionsManager.swift
        ├── SettingsWindowController.swift
        ├── TextInjector.swift
        ├── VoiceIMEController.swift
        └── main.swift
```

## 运行要求

- macOS 14+
- Xcode 15+ 或可用的 Swift 5.10 工具链
- 麦克风权限
- 语音识别权限
- 辅助功能权限
- 某些系统环境下，全局键盘监听可能还需要“输入监控”权限

## 构建与运行

### 构建 App

```bash
make build
```

构建完成后产物位于：

```text
Dist/VoiceIME.app
```

### 直接运行

```bash
make run
```

### 安装到用户 Applications

```bash
make install
```

安装位置：

```text
~/Applications/VoiceIME.app
```

### 清理构建产物

```bash
make clean
```

## 首次使用

1. 执行 `make run` 或打开 `Dist/VoiceIME.app`
2. 根据系统提示授予麦克风、语音识别、辅助功能权限
3. 如果 `Fn` 无法被全局监听，再到“系统设置 -> 隐私与安全性 -> 输入监控”中检查是否需要手动放行
4. 菜单栏出现 VoiceIME 图标后，按住 `Fn` 开始说话
5. 松开 `Fn` 后，文本会自动注入当前聚焦的输入框

## LLM Conservative Refinement

默认关闭。启用方式：

1. 点击菜单栏图标
2. 打开 `LLM Refinement`
3. 勾选 `Enable Conservative Refinement`
4. 进入 `Settings…`
5. 填写：
   - `API Base URL`
   - `API Key`
   - `Model`
6. 点击 `Test` 验证接口可用
7. 点击 `Save`

当前默认配置：

- Base URL: `https://api.openai.com/v1`
- Model: `gpt-4o-mini`

测试按钮会用一段典型的中文误识别样例验证“极保守纠错”链路，例如把“配森 / 杰森”纠正为更合理的技术词。

## 权限与实现说明

- `Fn` 键监听由 `CGEvent.tapCreate` 实现
- 录音与实时识别由 `AVAudioEngine` + `SFSpeechRecognizer` 实现
- 文本注入通过剪贴板写入后模拟 `Cmd+V`
- 为减少对用户环境的影响，粘贴结束后会恢复原剪贴板内容与原输入法
- 应用 `Info.plist` 中启用了 `LSUIElement`，因此是纯菜单栏应用

## 已验证

已在当前仓库执行：

```bash
make build
```

构建成功，并生成签名后的 `Dist/VoiceIME.app`。