# MITM 抓包功能说明书

## 功能概述
HTTPS 中间人解密（MITM）功能，支持抓包、重写规则、圈 X 脚本自定义。

## 目录结构
- `状态/MITM状态.swift` — 全局状态管理器（开关/证书/规则/脚本/抓包）
- `工具/圈X脚本引擎.swift` — JavaScriptCore 脚本执行引擎
- `页面/功能页面/MITM设置页面.swift` — MITM 主设置页
- `页面/功能页面/圈X脚本列表页面.swift` — 脚本列表/编辑/测试
- `页面/功能页面/抓包列表页面.swift` — 抓包记录列表/详情/HAR导出
- `页面/功能页面/重写规则设置页面.swift` — URL重写/本地映射

## 圈 X 脚本格式
兼容 Quantumult X 脚本规范：
- 请求阶段：`function handleRequest(request) { $done(request) }`
- 响应阶段：`function handleResponse(response) { $done(response) }`
- 支持 `$request` / `$response` / `$done()` 全局对象

## CI 构建
- 工作流：`.github/workflows/build-ios-mitm.yml`
- 分支：`feature/mitm`
- 产物：`App-unsigned.ipa`
