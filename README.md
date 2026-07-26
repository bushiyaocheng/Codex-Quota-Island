<div align="center">
  <img src="docs/images/codex-island-icon.png" width="96" height="96" alt="Codex Island 图标">
  <h1>Codex Island</h1>
  <p>在 MacBook 刘海两侧查看 Codex 剩余额度，并暂存要发送的文件。</p>
</div>

Codex Island 是一个为带刘海 MacBook 设计的原生 macOS 小工具。Codex 运行时，它会在刘海两侧显示当前 5 小时额度的剩余百分比和重置倒计时；通过单击或悬停展开岛体后，可以查看额度详情，并用 V2 文件暂存托盘把图片或文档快速拖到 Codex 输入框。

## 功能

### 刘海常驻显示

<img src="docs/images/compact.png" width="320" alt="Codex Island 在刘海两侧显示剩余额度与重置倒计时">

最重要的 5 小时剩余额度固定显示在刘海左侧，重置倒计时显示在右侧。紧凑态保持贴合刘海的固定宽度，只在 Codex/ChatGPT 运行时出现。

### 点击或悬停展开详情

<img src="docs/images/details.png" width="320" alt="Codex Island 展开后的额度详情界面">

岛体向下展开后，通过高对比度圆环显示 5 小时额度和本周额度的剩余百分比，同时突出重置时间、可用重置次数、连接状态与最近更新时间。右键菜单可在“鼠标点击展开”和“鼠标悬停展开”之间切换，两种方式互斥生效。

### V2 文件暂存

把 Finder、桌面、截图工具或其他应用中的图片和文件拖到灵动岛，岛体会切换为只显示文件的临时托盘并保持展开。把缩略图成功拖到 Codex 输入框后，对应暂存项会自动移出；最后一个文件移出后，灵动岛恢复原来的额度状态。

- 支持一次拖入多个文件
- 图片显示缩略图，其他文件显示系统图标
- 支持通过 `+` 或右键菜单选择文件
- 支持单项移除和一键清空
- 仅在当前运行会话中暂存，退出应用后自动清空
- 从不复制或删除原始文件；只有其他应用提供的临时图片表示会复制到系统临时目录，并在拖出、清空或退出时删除

### 功能列表

- 在刘海左侧显示 5 小时额度剩余百分比
- 在刘海右侧显示重置倒计时：一小时以上显示 `h`，不足一小时显示 `m`
- 可选择单击或悬停展开，两种交互方式互斥生效
- 展开后显示 5 小时额度、本周额度、重置时间和可用重置次数
- 高对比度额度圆环同时呈现剩余百分比与健康状态
- 剩余量低于 30% 显示橙色，低于 10% 显示红色
- Codex/ChatGPT 未运行时自动隐藏
- 右键支持切换展开方式、立即刷新、登录时启动和退出
- 拖入文件后在紧凑态显示暂存数量
- 从暂存托盘把原生文件直接拖到 Codex 输入框，成功后自动移出
- 只读调用本机 Codex `app-server`，不抓取界面
- 不复制、不展示、不上传 Codex 登录令牌
- 不包含分析、遥测或第三方网络请求

## 支持的 MacBook

Codex Island 只支持带实体刘海的 Apple Silicon MacBook 内建屏幕。

| 机型 | 支持情况 |
| --- | --- |
| 14 英寸 MacBook Pro（2021 年及以后、带刘海） | 支持 |
| 16 英寸 MacBook Pro（2021 年及以后、带刘海） | 支持 |
| 13 英寸 MacBook Air（M2 及以后、带刘海） | 支持 |
| 15 英寸 MacBook Air（M2 及以后、带刘海） | 支持 |
| 13 英寸无刘海 MacBook Pro | 不支持 |
| Intel MacBook、Mac mini、Mac Studio、iMac、Mac Pro | 不支持 |
| 外接显示器或合盖模式 | 暂不支持 |

最低系统要求：

- macOS 14 Sonoma 或更高版本
- Apple Silicon
- 已安装并登录 Codex 桌面应用；部分版本的应用名称可能显示为 ChatGPT

## 安装

1. 在 [Releases](https://github.com/bushiyaocheng/Codex-Quota-Island/releases) 下载最新的 `Codex-Island-v*.dmg`。
2. 打开 DMG，将 `Codex Island.app` 拖入 `Applications`。
3. 首次启动时右键应用并选择“打开”。
4. 保持 Codex/ChatGPT 正在运行，额度信息会自动出现在刘海两侧。

当前公开安装包使用 ad-hoc 签名，尚未经过 Apple Developer ID 公证。如果 macOS 阻止首次启动，可以在“系统设置 → 隐私与安全性”中选择“仍要打开”。

## 使用方式

- 单击或悬停刘海信息区域：按右键菜单中选择的方式展开详情
- 拖文件到刘海区域：自动展开并加入暂存
- 从文件缩略图拖到 Codex 输入框：作为附件发送并自动移出暂存
- 点击文件区 `+`：使用系统文件选择器批量添加
- 点击缩略图右上角 `×` 或“清空”：移除暂存记录
- 右键刘海信息区域：切换展开方式、刷新、切换登录时启动或退出
- Codex 退出：Codex Island 自动隐藏
- Codex 重新打开：Codex Island 自动恢复并刷新数据

## 数据来源与兼容性

应用仅在 Codex 正在运行时启动独立的只读 app-server 连接，并调用：

```text
account/rateLimits/read
```

读取字段包括：

- `primary` / `secondary`：服务端当前提供的额度窗口，不假设固定类型或顺序
- `windowDurationMins`：用于识别 5 小时、本周或其他持续时间的额度窗口
- `usedPercent`：对应窗口的已用百分比
- `resetsAt`：对应窗口的重置时间
- `rateLimitResetCredits.availableCount`：可用重置次数

窗口会按持续时间排序；紧凑状态显示最短窗口，展开状态按服务端实际返回数量自动增减行和高度。剩余百分比由 `100 - usedPercent` 得出。app-server 属于 Codex 客户端协议，未来 Codex 更新可能改变方法或字段；协议访问已集中在 `AppServerClient.swift` 中，便于维护。

## 从源码构建

需要 Xcode 16 或更高版本。

```bash
git clone https://github.com/bushiyaocheng/Codex-Quota-Island.git
cd Codex-Quota-Island
chmod +x scripts/package_app.sh scripts/package_release.sh
./scripts/package_app.sh
open "dist/Codex Island.app"
```

生成 DMG：

```bash
./scripts/package_release.sh
```

开发模式：

```bash
swift run CodexIsland
```

直接使用 `swift run` 时，“登录时启动”不可用，因为该功能要求应用位于 `.app` 包内。

运行测试：

```bash
swift test
```

## 隐私

- 所有额度数据只在本机处理
- 文件暂存完全在本机处理，不会由 Codex Island 主动上传
- 移除原文件的暂存记录不会删除原文件
- 文件清单不做持久化；临时图片副本会在退出时清理
- 不上传认证信息或额度数据
- 不执行额度重置；可用重置次数仅供展示
- 不包含第三方分析 SDK

## 已知限制

- 不支持无刘海屏幕的悬浮球或菜单栏回退
- 不支持外接屏幕显示
- Codex 客户端协议更新后可能需要同步适配
- 安装包尚未经过 Apple 公证

## 卸载

退出 Codex Island 后，从“应用程序”文件夹删除 `Codex Island.app`。如果启用了登录时启动，请先在右键菜单中关闭该选项。

## License

[MIT License](LICENSE)
