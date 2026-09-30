# 工具模块说明

本目录存放「新 UI」下可复用的独立工具类组件。一期交付 **VLESS 节点配置可视化转换器** 的解析与转换核心。

---

## 一、模块概述

将用户粘贴的 `vless://` 分享链接，解析为结构化节点配置，再转换为 sing-box 1.14.6 标准出站 JSON，供后续导入到官方 Profile 体系使用。

一期范围：
- 仅支持 **VLESS** 协议
- 传输类型：`tcp` / `ws`
- 安全类型：`none` / `tls`
- 暂不支持 Reality / h2 / grpc / quic 等传输与扩展

---

## 二、文件清单及职责

| 文件 | 职责 |
|---|---|
| `VLESS解析器.swift` | 把 `vless://` URL 解析为 `节点配置` 结构体；包含必填校验、参数别名兼容、URL 百分号解码；内嵌 11 个自测用例 |
| `节点配置生成器.swift` | 把 `节点配置` 转成 sing-box 1.14.6 VLESS 出站 JSON 字符串；严格字段白名单，条件输出 tls / transport 块 |
| `README.md` | 本说明书 |

---

## 三、VLESS URL 格式

标准形式：

```
vless://uuid@server:port?type=传输类型&security=安全类型&path=路径&host=主机&sni=SNI&fp=指纹&flow=流控&headerType=伪装类型#备注名称
```

- `#` 之后为节点备注（fragment），支持百分号编码中文。
- `?` 之后为查询参数，`&` 分隔，`=` 键值对，支持百分号编码。
- 已做 `+` → 空格与 `%XX` 两次解码。

### 支持的参数列表

| 参数 | 别名 | 默认值 | 说明 |
|---|---|---|---|
| `type` | — | `tcp` | 传输类型：`tcp` / `ws` |
| `security` | — | `none` | 安全类型：`none` / `tls` |
| `flow` | — | 空 | 流控：通常 `xtls-rprx-vision` |
| `path` | — | 空 | WS 路径（已解码） |
| `host` | `ws-host` | 空 | WS Host 头 / TCP 伪装主机 |
| `sni` | `tls-sni` | 空 | TLS 服务器名称 |
| `fp` | — | 空 | uTLS 指纹：`chrome` / `firefox` / `safari` 等 |
| `headerType` | — | `none` | TCP 伪装类型：`none` / `http` |

### 必填校验

- `uuid` 非空
- `server` 非空
- `port` ∈ [1, 65535]

任一项不满足，`解析结果.失败(原因:)` 返回中文原因。

---

## 四、生成的 sing-box JSON 结构

严格遵守字段白名单：`type / tag / server / server_port / uuid / flow / network / tls / transport`。

### 基础结构

```json
{
  "type": "vless",
  "tag": "vless-out-1",
  "server": "example.com",
  "server_port": 443,
  "uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "network": "tcp"
}
```

### TLS 块（仅 `security=tls` 输出）

```json
"tls": {
  "enabled": true,
  "server_name": "sni.example.com",
  "insecure": false,
  "utls": {
    "enabled": true,
    "fingerprint": "chrome"
  }
}
```

- `server_name`：优先取 `sni`，缺省回退到 `server`。
- `insecure`：一期固定 `false`。
- `utls`：仅当 `fp` 非空时输出。

### WS 传输块（仅 `type=ws` 输出）

```json
"transport": {
  "type": "ws",
  "path": "/ray",
  "headers": { "Host": "host.example.com" }
}
```

- `path` 为空时不输出 `path` 字段。
- `headers.Host` 仅在 `host` 非空时输出。

### TCP 伪装块（仅 `type=tcp` 且 `headerType=http` 输出）

```json
"transport": {
  "type": "tcp",
  "header": { "type": "http" }
}
```

- `type=tcp` 且 `headerType=none` 时不输出 `transport` 块。

### tag 规则

一期固定为 `vless-out-1`；后续期次再做序号自增或基于名称哈希。

---

## 五、自测方法

由于项目无独立单元测试 target，自测逻辑内嵌在 `VLESS解析器.swift` 中。

在 App 启动时或调试入口调用：

```swift
let 报告 = VLESS解析器.运行自测()
print(报告)
```

覆盖 11 个用例：
1. 最简 vless（tcp + none，无 flow）
2. tcp + tls + sni + fp=chrome
3. tcp + tls + flow=xtls-rprx-vision
4. ws + tls + path + host + sni
5. ws + none（明文 ws）
6. tcp + headerType=http 伪装
7. URL 编码的 path 与中文备注
8. 缺少 uuid（应失败）
9. 端口超出范围（70000，应失败）
10. 参数别名（ws-host、tls-sni）
11. 缺少 port（应失败）

返回格式：`VLESS解析器自测：N/11 通过`，失败时附带每个失败用例的原因。

---

## 六、使用示例

```swift
let url = "vless://uuid@example.com:443?type=ws&security=tls&path=/ray&host=example.com&sni=example.com#我的节点"

switch VLESS解析器.解析(url) {
case .成功(let 配置):
    let json = 节点配置生成器.生成出站JSON(配置)
    print(json)
case .失败(let 原因):
    print("解析失败：\(原因)")
}
```
