# 工具模块说明

本目录存放「新 UI」下可复用的独立工具类组件。交付 **VLESS 节点配置可视化转换器** 的解析与转换核心（一/二期合并）。

---

## 一、模块概述

将用户粘贴的 `vless://` 分享链接（或批量多行订阅内容），解析为结构化节点配置，再转换为 sing-box 1.14.6 标准出站 JSON，供后续导入到官方 Profile 体系使用。

### 一期（已交付）
- 基础 VLESS 解析：tcp / ws 两种传输，none / tls 两种安全
- 必填校验、参数别名、百分号解码
- 11 个自测用例

### 二期（本次交付）
- 6 种传输类型全覆盖：tcp / ws / http / grpc / httpupgrade / splithttp
- Reality 安全类型（pbk + sid + fp）
- 4 项高级参数：packet_encoding / tcp_fast_open / tcp_multi_path / dialer_proxy
- 完整参数别名表（驼峰 / 短横线 / 下划线三种风格）
- 批量解析（多行文本，自动跳过空行与注释行）
- 自测扩展到 36 个用例

---

## 二、文件清单及职责

| 文件 | 职责 |
|---|---|
| `VLESS解析器.swift` | 把 `vless://` URL（或多行文本）解析为 `节点配置`；包含必填校验、参数别名、URL 解码、批量解析；内嵌 36 个自测用例 |
| `节点配置生成器.swift` | 把 `节点配置` 转成 sing-box 1.14.6 VLESS 出站 JSON；严格字段白名单，按传输/安全类型条件输出 tls / transport 块 |
| `README.md` | 本说明书 |

---

## 三、VLESS URL 格式

标准形式：

```
vless://uuid@server:port?type=传输类型&security=安全类型&...#备注名称
```

### 支持的传输类型（type）

| type 值 | 说明 |
|---|---|
| `tcp` | 裸 TCP（可配 headerType=http 伪装） |
| `ws` | WebSocket |
| `http` | HTTP/1.1 传输 |
| `grpc` | gRPC 传输 |
| `httpupgrade` | HTTPUpgrade |
| `splithttp` | SplitHTTP |

### 支持的安全类型（security）

| security 值 | 说明 |
|---|---|
| `none` | 明文（默认） |
| `tls` | 标准 TLS |
| `reality` | Reality 协议 |

### 完整参数别名表

| 规范名 | 别名（均识别） |
|---|---|
| `host` | `ws-host`、`ws_host` |
| `sni` | `tls-sni`、`tls_sni` |
| `path` | `ws-path`、`ws_path` |
| `serviceName`（grpc） | `service`、`servicename` |
| `pbk`（reality 公钥） | `publicKey`、`public_key` |
| `sid`（reality 短 id） | `shortId`、`short_id` |
| `fp`（uTLS 指纹） | `fingerprint` |
| `multi_mode` | `multiMode` |
| `packet_encoding` | `packetEncoding` |
| `tcp_fast_open` | `tcpFastOpen` |
| `tcp_multi_path` | `tcpMultiPath` |
| `dialer_proxy` | `dialerProxy` |

### 其他参数

| 参数 | 默认值 | 说明 |
|---|---|---|
| `flow` | 空 | 流控，通常 `xtls-rprx-vision` |
| `headerType` | `none` | TCP 伪装：`none` / `http` |
| `method` | 空 | http 传输方法（GET / POST 等） |
| `fp` | 空 | uTLS 指纹：chrome / firefox / safari / ios / android / edge / random / randomized |

### 必填校验

- `uuid` 非空
- `server` 非空
- `port` ∈ [1, 65535]

---

## 四、生成的 sing-box JSON 结构

严格字段白名单：
`type / tag / server / server_port / uuid / flow / network / tls / transport / packet_encoding / tcp_fast_open / tcp_multi_path / dialer_proxy`

### TLS 块（security=tls）

```json
"tls": {
  "enabled": true,
  "server_name": "sni.example.com",
  "insecure": false,
  "utls": { "enabled": true, "fingerprint": "chrome" }
}
```

### Reality 块（security=reality）

```json
"tls": {
  "enabled": true,
  "server_name": "sni.example.com",
  "reality": {
    "enabled": true,
    "public_key": "pbk-value",
    "short_id": "sid-value"
  },
  "utls": { "enabled": true, "fingerprint": "chrome" }
}
```

> Reality 不输出 `insecure`；`utls` 仅在 `fp` 非空时输出。

### 各 transport 块

**ws**：
```json
"transport": { "type": "ws", "path": "/ray", "headers": { "Host": "host.example.com" } }
```

**http**（host 是数组）：
```json
"transport": { "type": "http", "host": ["host.example.com"], "path": "/path", "method": "POST" }
```

**grpc**：
```json
"transport": { "type": "grpc", "service_name": "svc", "multi_mode": true }
```

**httpupgrade / splithttp**（host 是字符串）：
```json
"transport": { "type": "httpupgrade", "host": "host.example.com", "path": "/path" }
```

**tcp + http 伪装**：
```json
"transport": { "type": "tcp", "header": { "type": "http" } }
```

### 顶层高级参数

| 参数 | 输出条件 |
|---|---|
| `packet_encoding` | 非空时输出（如 `"xudp"`） |
| `tcp_fast_open` | 为 `true` 时输出 |
| `tcp_multi_path` | 为 `true` 时输出 |
| `dialer_proxy` | 非空时输出（引用另一个 outbound tag） |

---

## 五、批量解析

```swift
let 文本 = """
# 订阅说明（整行 # 开头视为注释，自动跳过）
vless://uuid1@a.com:443?type=ws&security=tls
vless://uuid2@b.com:443?type=grpc&serviceName=svc

// 这行也跳过
vless://uuid3@c.com:443?security=reality&pbk=xxx&sid=yy
"""

let 结果 = VLESS解析器.批量解析(文本)
// 结果为 [批量解析结果]，每项含 行号 / 原始文本 / 解析结果
```

规则：
- 按换行符分割
- 空行（trim 后为空）不产出结果
- 整行以 `//` 或 `#` 开头的视为注释，不产出结果
- 注意：URL 内部的 `#备注` 是 fragment，**不算注释**
- 保留原始行号（从 1 开始，跳过的行不计入行号）

---

## 六、自测方法

```swift
let 报告 = VLESS解析器.运行自测()
print(报告)
```

共 36 个用例，覆盖：
- 一期 11 个：最简 tcp/none、tcp+tls+sni+fp、tcp+tls+flow、ws 完整、明文 ws、tcp http 伪装、URL 编码中文、缺 uuid / 端口越界 / 别名 / 缺 port
- 二期 25 个：http（tls/none）、grpc（含/不含 multi_mode）、httpupgrade、splithttp、Reality（完整/无指纹）、7 种指纹、4 项高级参数、下划线/驼峰别名、批量解析混合/注释、http method=POST

返回格式：`VLESS解析器自测：N/36 通过`，失败时附每条失败原因。

---

## 七、使用示例

```swift
let url = "vless://uuid@example.com:443?type=grpc&security=reality&serviceName=svc&pbk=xxx&sid=yy&fp=chrome#我的Reality节点"

switch VLESS解析器.解析(url) {
case .成功(let 配置):
    let json = 节点配置生成器.生成出站JSON(配置)
    print(json)
case .失败(let 原因):
    print("解析失败：\(原因)")
}
```
