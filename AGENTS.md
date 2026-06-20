# 项目级执行提示词

## 每次接手先读

- 先阅读 [docs/文件结构架构.md](docs/文件结构架构.md)，按其中的“任务到文件索引”定位代码。
- 找文件优先用 `rg --files`、找符号优先用 `rg "关键词" lib test`，避免全项目盲改。
- 先看 `git status --short`，不得覆盖、回退或格式化用户已有改动。

## 修改边界

- 只做需求相关的手术式局部修改，不做顺手重构、批量格式化或无关依赖升级。
- 代码文件不得添加头部元数据、生成器署名、时间戳、版权块。
- 新增变量、字段、方法需写功能性中文注释，说明业务用途或边界；避免“赋值给变量”这类空注释。
- 保持现有 Flutter/Dart 风格，遵循 `analysis_options.yaml` 的 `flutter_lints`。

## Flutter 与 UI 约定

- 项目是 Flutter 应用，UI 组件优先使用 `shadcn_ui`。
- 业务页面优先从 `lib/shared/app_ui.dart` 引入通用 UI 出口和辅助方法，不在页面内重复封装同类组件。
- 颜色、间距、主题优先使用 `lib/theme/app_theme.dart` 中的 `imageAccent`、`AppGap`、`buildAppTheme()` 等统一定义。
- 按钮、输入框、弹窗、Sheet、Tabs、Badge、Card、图标优先使用 `ShadButton`、`ShadInput`、`ShadDialog`、`ShadSheet`、`ShadTabs`、`ShadBadge`、`ShadCard`、`LucideIcons`。
- 页面级脚手架优先使用 `AppPageScaffold`，提示优先使用 `showAppToast`，确认弹窗优先使用 `showAppConfirmDialog`。

## 业务分层

- 页面与交互放 `lib/features/<业务域>/`。
- API 调用统一收敛到 `lib/services/api_client.dart`，本地认证存储放 `lib/services/auth_store.dart`。
- 接口数据结构统一放 `lib/models/`，不要在页面里临时解析复杂 JSON。
- 跨页面 UI、预览、更新、Toast 放 `lib/shared/`；轮询等通用逻辑放 `lib/utils/`。

## 验证标准

- Dart 代码改动后至少运行 `flutter analyze`。
- 改动涉及启动、认证、导航、模型解析或共享组件时运行 `flutter test`。
- 改动涉及 Android 更新包、下载、平台配置时补充对应平台构建或手动验证说明。
- 仅文档改动可不跑 Flutter 测试，但需确认新增/修改文档可读取且路径正确。

## 交付格式

- 交付必须包含“变更摘要”和“受影响文件列表”。
- 如未运行测试，明确说明原因。
