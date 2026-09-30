# 新UI（NewUI）

sing-box-for-apple 新UI层，从 new-vpn 项目迁移，仅迁移 UI 层（SwiftUI 视图、组件、设计系统），数据层使用官方 Library/ 和 ApplicationLibrary/ 中的 ExtensionProfile、CommandClient、ProfileManager 等。

## 目录结构

```
SFI/NewUI/
├── 新UI入口视图.swift        # 新UI根视图，绑定官方环境，注入全局状态
├── 设计系统/
│   └── UIConst.swift         # 设计令牌：颜色/字体/间距/圆角/动画常量
├── 状态/
│   └── 新UI状态.swift         # 全局状态桥接：对接 ExtensionProfile/CommandClient
├── 组件/
│   ├── AppButton.swift       # 统一按钮（主要/次要/危险，加载态，防抖）
│   ├── AppCard.swift         # 卡片容器（标题栏，折叠）
│   ├── AppFormRow.swift      # 表单行（标签+控件）
│   ├── AppSearchBar.swift    # 搜索栏
│   ├── EmptyStateView.swift  # 空状态视图
│   ├── StateBadge.swift      # 状态徽章
│   ├── 顶部功能卡片栏.swift    # 横向滑动功能卡片导航
│   ├── 底部工具栏.swift        # 底部固定工具栏（4入口）
│   └── 底部弹窗容器.swift      # 底部弹窗（配置管理/官方工具/官方设置/关于）+ 运行模式面板
└── 页面/
    ├── 仪表盘视图.swift        # 主页面（顶部状态区+卡片栏+内容区+工具栏）
    └── 内容区/
        ├── 节点内容区.swift      # 节点列表（骨架阶段）
        ├── 策略组内容区.swift    # 策略组列表（骨架阶段）
        ├── 网络活动内容区.swift  # 连接活动列表（骨架阶段）
        └── 规则与日志内容区.swift # 日志列表（骨架阶段）
```

## 设计原则

1. **只搬 UI 层**：不包含任何数据层实现，所有数据通过 `新UI状态` 桥接官方数据层
2. **100% 全汉化**：注释、变量名、用户可见字符串均为简体中文
3. **最低 iOS 16**：使用 NavigationStack、presentationDetents 等 iOS 16 API
4. **SwiftUI 优先**：声明式 UI，响应式状态
5. **设计令牌统一**：所有样式引用 UIConst.swift，禁止硬编码

## 数据层对接

- **VPN 状态/连接**：`ExtensionProfile`（start/stop/status），通过 `新UI状态.切换连接()` 调用
- **日志/策略组/连接**：`CommandClient`，通过 `新UI状态.命令客户端` 访问
- **配置文件管理**：`ProfileManager.list()` 读取列表，`SharedPreferences.selectedProfileID` 切换当前配置，切换后经 `ExtensionEnvironments.selectedProfileUpdate` 通知并在已连接时 `reloadService()` 重载服务

## 迁移进度

| 阶段 | 内容 | 状态 |
|------|------|------|
| 第一阶段 | 设计系统与基础组件 | ✅ 完成 |
| 第二阶段 | 主页面框架（仪表盘+状态区+工具栏） | ✅ 完成 |
| 第三阶段 | 四个内容区骨架 | ✅ 完成 |
| 第四阶段 | 底部弹窗并入官方工具/设置，完善配置管理与关于弹窗 | ✅ 完成 |
| 第五阶段 | 功能页面（DNS/MITM/抓包/重写） | ⏳ 待开始 |
| 第六阶段 | 数据层完整对接 | ⏳ 待开始 |
| 第七阶段 | 编译验证、UI微调、性能优化 | ⏳ 待开始 |

## 入口替换

`Application.swift` 已将根视图从 `MainView()` 替换为 `新UI入口视图()`，官方 MainView 代码保留在 `SFI/MainView.swift` 供参考。
