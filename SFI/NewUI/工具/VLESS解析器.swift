//
//  VLESS解析器.swift
//  SFI
//
//  一/二期：VLESS URL 解析核心，支持 6 种传输 + Reality + 高级参数 + 批量解析
//  最低支持 iOS 16
//

import Foundation

// MARK: - 传输类型枚举

/// 传输类型
///
/// - tcp: 裸 TCP（可配 headerType=http 伪装）
/// - ws: WebSocket
/// - http: HTTP/1.1 传输
/// - grpc: gRPC 传输
/// - httpupgrade: HTTPUpgrade
/// - splithttp: SplitHTTP
enum 传输类型: String, Equatable {
    case tcp
    case ws
    case http
    case grpc
    case httpupgrade
    case splithttp

    /// 从 URL 参数 type 字符串构造；未知值默认 tcp
    static func 解析(_ 原始: String) -> 传输类型 {
        switch 原始.lowercased() {
        case "ws": return .ws
        case "http": return .http
        case "grpc": return .grpc
        case "httpupgrade", "http-upgrade", "http_upgrade": return .httpupgrade
        case "splithttp", "split-http", "split_http": return .splithttp
        default: return .tcp
        }
    }
}

// MARK: - 安全类型枚举

/// 安全类型
///
/// - none: 明文
/// - tls: 标准 TLS
/// - reality: Reality 协议（基于 TLS 指纹 + 公钥）
enum 安全类型: String, Equatable {
    case none
    case tls
    case reality

    /// 从 URL 参数 security 字符串构造；未知值默认 none
    static func 解析(_ 原始: String) -> 安全类型 {
        switch 原始.lowercased() {
        case "tls": return .tls
        case "reality": return .reality
        default: return .none
        }
    }
}

// MARK: - 节点配置模型

/// VLESS 节点结构化配置
///
/// 一期字段：名称/服务器/端口/uuid/传输类型/安全类型/flow/路径/Host/sni/指纹/headerType/原始参数字典
/// 二期新增：reality公钥/reality短id/grpc服务名/grpc多模式/packet编码/tcp快速打开/tcp多路径/拨号代理/http方法
struct 节点配置: Equatable {
    var 名称: String
    var 服务器: String
    var 端口: Int
    var uuid: String
    var 传输类型: 传输类型
    var 安全类型: 安全类型
    var flow: String
    var 路径: String
    var Host: String
    var sni: String
    var 指纹: String
    var headerType: String

    // MARK: 二期新增
    var reality公钥: String      // pbk
    var reality短id: String      // sid
    var grpc服务名: String       // serviceName
    var grpc多模式: Bool         // multi_mode
    var packet编码: String       // packet_encoding（如 xudp）
    var tcp快速打开: Bool        // tcp_fast_open
    var tcp多路径: Bool          // tcp_multi_path
    var 拨号代理: String         // dialer_proxy（引用另一个 outbound tag）
    var http方法: String         // http 传输的 method（如 GET/POST）

    var 原始参数字典: [String: String]
}

// MARK: - 解析结果枚举

/// 解析结果
///
/// - 成功：返回结构化节点配置
/// - 失败：返回中文失败原因
enum 解析结果 {
    case 成功(节点配置)
    case 失败(原因: String)
}

// MARK: - 批量解析结果

/// 批量解析单行结果
struct 批量解析结果: Equatable {
    var 行号: Int            // 从 1 开始
    var 原始文本: String
    var 解析结果: 解析结果
}

// MARK: - VLESS 解析器

/// VLESS URL 解析器
///
/// 支持格式：`vless://uuid@server:port?params#备注`
/// 支持百分号解码；支持参数别名；支持批量多行解析
enum VLESS解析器 {

    // MARK: 单条解析主入口

    /// 解析 VLESS URL
    static func 解析(_ url字符串: String) -> 解析结果 {
        // 1. 去除首尾空白
        let 原始 = url字符串.trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. 校验协议头
        guard 原始.lowercased().hasPrefix("vless://") else {
            return .失败(原因: "链接协议头不正确，必须以 vless:// 开头")
        }
        let 去除前缀 = String(原始.dropFirst("vless://".count))

        // 3. 拆分备注（fragment）
        var 剩余主体 = 去除前缀
        var 名称 = ""
        if let 井号范围 = 去除前缀.range(of: "#") {
            let 编码备注 = String(去除前缀[井号范围.upperBound...])
            名称 = 解码(编码备注)
            剩余主体 = String(去除前缀[..<井号范围.lowerBound])
        }

        // 4. 拆分 query 与 host 部分
        var 连接部分 = 剩余主体
        var 原始参数字典: [String: String] = [:]
        if let 问号范围 = 剩余主体.range(of: "?") {
            let 编码查询串 = String(剩余主体[问号范围.upperBound...])
            连接部分 = String(剩余主体[..<问号范围.lowerBound])
            原始参数字典 = 解析查询串(编码查询串)
        }

        // 5. 拆分 uuid@host:port
        guard let at范围 = 连接部分.range(of: "@") else {
            return .失败(原因: "链接缺少 @ 分隔符，格式应为 vless://uuid@server:port")
        }
        let uuid = String(连接部分[..<at范围.lowerBound]).trimmingCharacters(in: .whitespaces)
        let 主机端口串 = String(连接部分[at范围.upperBound...])

        guard !uuid.isEmpty else {
            return .失败(原因: "uuid 不能为空")
        }

        // 6. 拆分 host 与 port（兼容 IPv6 字面量 [::1]:443）
        let (服务器, 端口) = 拆分主机端口(主机端口串)
        guard !服务器.isEmpty else {
            return .失败(原因: "服务器地址不能为空")
        }
        guard 端口 > 0, 端口 <= 65535 else {
            return .失败(原因: "端口 \(端口) 超出合法范围（1-65535）")
        }

        // 7. 提取参数（带别名兼容）
        let 传输类型 = 传输类型.解析(取参数(原始参数字典, 键列表: ["type"]) ?? "tcp")
        let 安全类型 = 安全类型.解析(取参数(原始参数字典, 键列表: ["security"]) ?? "none")
        let flow = 取参数(原始参数字典, 键列表: ["flow"]) ?? ""
        let 路径 = 取参数(原始参数字典, 键列表: ["path", "ws-path", "ws_path"]) ?? ""
        let Host = 取参数(原始参数字典, 键列表: ["host", "ws-host", "ws_host"]) ?? ""
        let sni = 取参数(原始参数字典, 键列表: ["sni", "tls-sni", "tls_sni"]) ?? ""
        let 指纹 = 取参数(原始参数字典, 键列表: ["fp", "fingerprint"]) ?? ""
        let headerType = 取参数(原始参数字典, 键列表: ["headerType"]) ?? "none"

        // 二期新增参数
        let pbk = 取参数(原始参数字典, 键列表: ["pbk", "publicKey", "public_key"]) ?? ""
        let sid = 取参数(原始参数字典, 键列表: ["sid", "shortId", "short_id"]) ?? ""
        let serviceName = 取参数(原始参数字典, 键列表: ["serviceName", "service", "servicename"]) ?? ""
        let multiMode = 解析布尔(取参数(原始参数字典, 键列表: ["multi_mode", "multiMode"]) ?? "")
        let packetEncoding = 取参数(原始参数字典, 键列表: ["packet_encoding", "packetEncoding"]) ?? ""
        let tcpFastOpen = 解析布尔(取参数(原始参数字典, 键列表: ["tcp_fast_open", "tcpFastOpen"]) ?? "")
        let tcpMultiPath = 解析布尔(取参数(原始参数字典, 键列表: ["tcp_multi_path", "tcpMultiPath"]) ?? "")
        let dialerProxy = 取参数(原始参数字典, 键列表: ["dialer_proxy", "dialerProxy"]) ?? ""
        let method = 取参数(原始参数字典, 键列表: ["method"]) ?? ""

        // 8. 名称为空时给默认值
        let 最终名称 = 名称.isEmpty ? "\(服务器):\(端口)" : 名称

        let 配置 = 节点配置(
            名称: 最终名称,
            服务器: 服务器,
            端口: 端口,
            uuid: uuid,
            传输类型: 传输类型,
            安全类型: 安全类型,
            flow: flow,
            路径: 路径,
            Host: Host,
            sni: sni,
            指纹: 指纹,
            headerType: headerType,
            reality公钥: pbk,
            reality短id: sid,
            grpc服务名: serviceName,
            grpc多模式: multiMode,
            packet编码: packetEncoding,
            tcp快速打开: tcpFastOpen,
            tcp多路径: tcpMultiPath,
            拨号代理: dialerProxy,
            http方法: method,
            原始参数字典: 原始参数字典
        )
        return .成功(配置)
    }

    // MARK: 批量解析

    /// 批量解析多行文本
    ///
    /// 规则：
    /// - 按换行符分割
    /// - 跳过空行（trim 后为空）
    /// - 跳过整行以 `//` 或 `#` 开头的注释行（注意：URL 内部的 `#备注` 不算注释）
    /// - 每行独立调用 解析()，保留行号（从 1 开始）
    static func 批量解析(_ 多行文本: String) -> [批量解析结果] {
        let 行数组 = 多行文本.components(separatedBy: .newlines)
        var 结果: [批量解析结果] = []
        for (索引, 原始行) in 行数组.enumerated() {
            let 行号 = 索引 + 1
            let trim行 = 原始行.trimmingCharacters(in: .whitespaces)
            // 空行跳过（不产出结果）
            if trim行.isEmpty { continue }
            // 注释行跳过
            if trim行.hasPrefix("//") || trim行.hasPrefix("#") { continue }
            let 单条结果 = 解析(trim行)
            结果.append(批量解析结果(行号: 行号, 原始文本: trim行, 解析结果: 单条结果))
        }
        return 结果
    }

    // MARK: 内部工具

    /// 解析查询字符串为 [key: value] 字典（自动百分号解码）
    private static func 解析查询串(_ 查询串: String) -> [String: String] {
        guard !查询串.isEmpty else { return [:] }
        var 结果: [String: String] = [:]
        let 键值对数组 = 查询串.components(separatedBy: "&")
        for 对 in 键值对数组 {
            guard !对.isEmpty else { continue }
            let 片段 = 对.components(separatedBy: "=")
            let 键 = 片段.first.map { 解码($0) } ?? ""
            let 值 = 片段.count >= 2 ? 解码(片段[1...].joined(separator: "=")) : ""
            if !键.isEmpty {
                结果[键] = 值
            }
        }
        return 结果
    }

    /// 按候选键列表取参数值（先找到先返回）
    private static func 取参数(_ 字典: [String: String], 键列表: [String]) -> String? {
        for 键 in 键列表 {
            if let 值 = 字典[键], !值.isEmpty {
                return 值
            }
        }
        return nil
    }

    /// 解析布尔字符串：true/1/yes/on 视为真，其余视为假
    private static func 解析布尔(_ 原始: String) -> Bool {
        switch 原始.lowercased() {
        case "true", "1", "yes", "on": return true
        default: return false
        }
    }

    /// 拆分 host:port，兼容 IPv6 [::1]:443 形式
    private static func 拆分主机端口(_ 串: String) -> (服务器: String, 端口: Int) {
        let trimmed = 串.trimmingCharacters(in: .whitespaces)
        // IPv6 字面量
        if trimmed.hasPrefix("[") {
            guard let 右括号 = trimmed.lastIndex(of: "]") else {
                return (trimmed, 0)
            }
            let 主机 = String(trimmed[trimmed.index(after: trimmed.startIndex)..<右括号])
            let 剩余 = trimmed[trimmed.index(after: 右括号)...]
            var 端口 = 0
            if 剩余.hasPrefix(":") {
                let 数字串 = String(剩余.dropFirst())
                端口 = Int(数字串) ?? 0
            }
            return (主机, 端口)
        }
        // 普通 host:port
        if let 冒号范围 = trimmed.range(of: ":") {
            let 主机 = String(trimmed[..<冒号范围.lowerBound])
            let 数字串 = String(trimmed[冒号范围.upperBound...])
            let 端口 = Int(数字串) ?? 0
            return (主机, 端口)
        }
        return (trimmed, 0)
    }

    /// 百分号解码（对失败情况返回原文）
    private static func 解码(_ 串: String) -> String {
        // 先把 "+" 还原为空格（application/x-www-form-urlencoded 风格），再做百分比解码
        let 处理加号 = 串.replacingOccurrences(of: "+", with: " ")
        guard let 结果 = 处理加号.removingPercentEncoding else {
            return 处理加号
        }
        return 结果
    }
}

// MARK: - 自测

extension VLESS解析器 {

    /// 运行内置自测，返回结果摘要（通过数/总数 + 失败详情）
    static func 运行自测() -> String {
        // 每个用例返回 nil 表示通过，返回 String 表示失败原因
        let 用例列表: [(名称: String, 执行: () -> String?)] = [
            // 一期保留 11 个
            ("01.最简tcp-none", 用例_最简tcp无安全),
            ("02.tcp-tls-sni-fp", 用例_tcp带TLS指纹),
            ("03.tcp-tls-flow", 用例_tcp带Flow),
            ("04.ws-tls完整参数", 用例_ws带TLS完整参数),
            ("05.明文WS", 用例_明文WS),
            ("06.tcp-http伪装", 用例_tcp伪装HTTP),
            ("07.URL编码中文", 用例_URL编码中文),
            ("08.缺UUID应失败", 用例_缺UUID应失败),
            ("09.端口越界应失败", 用例_端口越界应失败),
            ("10.参数别名", 用例_参数别名兼容),
            ("11.缺端口应失败", 用例_缺端口应失败),
            // 二期新增
            ("12.http-tls", 用例_http带TLS),
            ("13.http-none", 用例_http明文),
            ("14.grpc-service-multimode", 用例_grpc带服务名多模式),
            ("15.grpc-service-only", 用例_grpc仅服务名),
            ("16.httpupgrade", 用例_httpupgrade传输),
            ("17.splithttp", 用例_splithttp传输),
            ("18.reality-pbk-sid-fp", 用例_Reality完整),
            ("19.reality-pbk-sid-only", 用例_Reality无指纹),
            ("20.指纹firefox", 用例_指纹firefox),
            ("21.指纹safari", 用例_指纹safari),
            ("22.指纹ios", 用例_指纹ios),
            ("23.指纹android", 用例_指纹android),
            ("24.指纹edge", 用例_指纹edge),
            ("25.指纹random", 用例_指纹random),
            ("26.指纹randomized", 用例_指纹randomized),
            ("27.packet-encoding", 用例_包编码xudp),
            ("28.tcp-fast-open", 用例_TCP快速打开),
            ("29.tcp-multi-path", 用例_TCP多路径),
            ("30.dialer-proxy", 用例_拨号代理),
            ("31.别名下划线", 用例_别名下划线风格),
            ("32.别名reality", 用例_别名Reality风格),
            ("33.批量解析混合", 用例_批量解析混合),
            ("34.批量解析注释", 用例_批量解析注释行),
            ("35.grpc-multimode-false", 用例_grpc多模式关不输出),
            ("36.http-method-post", 用例_http方法POST),
        ]

        var 通过数 = 0
        var 失败详情: [String] = []
        for 用例 in 用例列表 {
            if let 原因 = 用例.执行() {
                失败详情.append("[\(用例.名称)] \(原因)")
            } else {
                通过数 += 1
            }
        }
        return 汇总(通过数: 通过数, 总数: 用例列表.count, 失败: 失败详情)
    }

    // MARK: 一期保留用例

    private static func 用例_最简tcp无安全() -> String? {
        let url = "vless://11111111-1111-1111-1111-111111111111@example.com:443"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.uuid == "11111111-1111-1111-1111-111111111111" else { return "uuid 不匹配" }
        guard c.服务器 == "example.com" else { return "服务器不匹配" }
        guard c.端口 == 443 else { return "端口应为443, 实际\(c.端口)" }
        guard c.传输类型 == .tcp else { return "默认传输应为tcp" }
        guard c.安全类型 == .none else { return "默认安全应为none" }
        guard c.flow.isEmpty else { return "flow应为空" }
        // 生成 JSON 不应包含 tls / transport / flow
        let json = 节点配置生成器.生成出站JSON(c)
        guard !json.contains("\"tls\"") else { return "无安全不应输出tls块: \(json)" }
        guard !json.contains("\"transport\"") else { return "tcp+none伪装不应输出transport: \(json)" }
        guard !json.contains("\"flow\"") else { return "空flow不应输出: \(json)" }
        return nil
    }

    private static func 用例_tcp带TLS指纹() -> String? {
        let url = "vless://uuid2@server.com:8443?type=tcp&security=tls&sni=sni.server.com&fp=chrome#节点二"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.安全类型 == .tls else { return "security应为tls" }
        guard c.sni == "sni.server.com" else { return "sni不匹配" }
        guard c.指纹 == "chrome" else { return "fp应为chrome" }
        guard c.名称 == "节点二" else { return "名称应为节点二" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"tls\"") else { return "应输出tls块" }
        guard json.contains("\"server_name\":\"sni.server.com\"") else { return "tls.server_name 错误: \(json)" }
        guard json.contains("\"fingerprint\":\"chrome\"") else { return "utls.fingerprint 错误" }
        guard json.contains("\"insecure\":false") else { return "应输出 insecure=false" }
        return nil
    }

    private static func 用例_tcp带Flow() -> String? {
        let url = "vless://uuid3@3.3.3.3:443?type=tcp&security=tls&flow=xtls-rprx-vision"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.flow == "xtls-rprx-vision" else { return "flow应为xtls-rprx-vision" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"flow\":\"xtls-rprx-vision\"") else { return "flow 未输出: \(json)" }
        return nil
    }

    private static func 用例_ws带TLS完整参数() -> String? {
        let url = "vless://uuid4@ws.com:2053?type=ws&security=tls&path=%2Fray&host=ws.host.com&sni=ws.sni.com"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.传输类型 == .ws else { return "type应为ws" }
        guard c.路径 == "/ray" else { return "path应解码为/ray, 实际\(c.路径)" }
        guard c.Host == "ws.host.com" else { return "host不匹配" }
        guard c.sni == "ws.sni.com" else { return "sni不匹配" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"type\":\"ws\"") else { return "transport.type 应为 ws" }
        guard json.contains("\"path\":\"/ray\"") else { return "transport.path 错误: \(json)" }
        guard json.contains("\"Host\":\"ws.host.com\"") else { return "transport.headers.Host 错误" }
        return nil
    }

    private static func 用例_明文WS() -> String? {
        let url = "vless://uuid5@plain.ws:8080?type=ws&path=/abc"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.安全类型 == .none else { return "security应为none" }
        guard c.路径 == "/abc" else { return "path应为/abc" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard !json.contains("\"tls\"") else { return "明文不应输出tls" }
        return nil
    }

    private static func 用例_tcp伪装HTTP() -> String? {
        let url = "vless://uuid6@fake.com:443?type=tcp&security=tls&headerType=http"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.headerType == "http" else { return "headerType应为http" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"type\":\"tcp\"") else { return "transport.type 应为 tcp" }
        guard json.contains("\"header\":{\"type\":\"http\"}") else { return "tcp http 伪装未输出: \(json)" }
        return nil
    }

    private static func 用例_URL编码中文() -> String? {
        let url = "vless://uuid7@enc.com:443?type=ws&path=%2Fabc%3Ddef&security=tls#%E4%B8%AD%E6%96%87%E8%8A%82%E7%82%B9"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.路径 == "/abc=def" else { return "path解码错误: \(c.路径)" }
        guard c.名称 == "中文节点" else { return "名称解码错误: \(c.名称)" }
        return nil
    }

    private static func 用例_缺UUID应失败() -> String? {
        let url = "vless://@noid.com:443"
        guard case .失败(let 原因) = 解析(url) else { return "应返回失败" }
        guard 原因.contains("uuid") else { return "失败原因应提到uuid: \(原因)" }
        return nil
    }

    private static func 用例_端口越界应失败() -> String? {
        let url = "vless://uuid9@badport.com:70000"
        guard case .失败(let 原因) = 解析(url) else { return "应返回失败" }
        guard 原因.contains("端口") else { return "失败原因应提到端口: \(原因)" }
        return nil
    }

    private static func 用例_参数别名兼容() -> String? {
        let url = "vless://uuid10@alias.com:443?type=ws&security=tls&ws-host=alias.host&tls-sni=alias.sni"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.Host == "alias.host" else { return "ws-host 别名未识别: \(c.Host)" }
        guard c.sni == "alias.sni" else { return "tls-sni 别名未识别: \(c.sni)" }
        return nil
    }

    private static func 用例_缺端口应失败() -> String? {
        let url = "vless://uuid11@noport.com"
        guard case .失败(let 原因) = 解析(url) else { return "应返回失败" }
        guard 原因.contains("端口") else { return "失败原因应提到端口: \(原因)" }
        return nil
    }

    // MARK: 二期新增用例

    private static func 用例_http带TLS() -> String? {
        let url = "vless://u-http@http.com:443?type=http&security=tls&host=http.host&path=/http-path&sni=http.sni"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.传输类型 == .http else { return "type应为http, 实际\(c.传输类型.rawValue)" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"type\":\"http\"") else { return "transport.type 应为 http: \(json)" }
        guard json.contains("\"host\":[\"http.host\"]") else { return "http host 应为数组: \(json)" }
        guard json.contains("\"path\":\"/http-path\"") else { return "http path 错误: \(json)" }
        return nil
    }

    private static func 用例_http明文() -> String? {
        let url = "vless://u-http2@http2.com:8080?type=http&path=/plain"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.安全类型 == .none else { return "应为明文" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard !json.contains("\"tls\"") else { return "明文 http 不应输出 tls" }
        return nil
    }

    private static func 用例_grpc带服务名多模式() -> String? {
        let url = "vless://u-grpc@grpc.com:443?type=grpc&security=tls&serviceName=my-service&multi_mode=true&sni=grpc.sni"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.传输类型 == .grpc else { return "type应为grpc" }
        guard c.grpc服务名 == "my-service" else { return "serviceName 错误: \(c.grpc服务名)" }
        guard c.grpc多模式 == true else { return "multi_mode 应为 true" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"type\":\"grpc\"") else { return "transport.type 应为 grpc" }
        guard json.contains("\"service_name\":\"my-service\"") else { return "service_name 错误: \(json)" }
        guard json.contains("\"multi_mode\":true") else { return "multi_mode 应输出: \(json)" }
        return nil
    }

    private static func 用例_grpc仅服务名() -> String? {
        let url = "vless://u-grpc2@grpc2.com:443?type=grpc&security=tls&serviceName=only-svc"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.grpc服务名 == "only-svc" else { return "serviceName 错误" }
        guard c.grpc多模式 == false else { return "multi_mode 默认应为 false" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"service_name\":\"only-svc\"") else { return "service_name 错误: \(json)" }
        guard !json.contains("\"multi_mode\"") else { return "multi_mode=false 不应输出: \(json)" }
        return nil
    }

    private static func 用例_httpupgrade传输() -> String? {
        let url = "vless://u-hu@hu.com:443?type=httpupgrade&security=tls&host=hu.host&path=/hu-path&sni=hu.sni"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.传输类型 == .httpupgrade else { return "type应为httpupgrade" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"type\":\"httpupgrade\"") else { return "transport.type 应为 httpupgrade: \(json)" }
        guard json.contains("\"host\":\"hu.host\"") else { return "httpupgrade host 应为字符串: \(json)" }
        guard json.contains("\"path\":\"/hu-path\"") else { return "httpupgrade path 错误" }
        return nil
    }

    private static func 用例_splithttp传输() -> String? {
        let url = "vless://u-sh@sh.com:443?type=splithttp&security=tls&host=sh.host&path=/sh-path"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.传输类型 == .splithttp else { return "type应为splithttp" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"type\":\"splithttp\"") else { return "transport.type 应为 splithttp: \(json)" }
        guard json.contains("\"host\":\"sh.host\"") else { return "splithttp host 错误: \(json)" }
        return nil
    }

    private static func 用例_Reality完整() -> String? {
        let url = "vless://u-real@real.com:443?type=tcp&security=reality&pbk=my-pub-key&sid=0123abcd&fp=chrome&sni=real.sni"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.安全类型 == .reality else { return "security 应为 reality" }
        guard c.reality公钥 == "my-pub-key" else { return "pbk 错误" }
        guard c.reality短id == "0123abcd" else { return "sid 错误" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"reality\":{") else { return "应输出 reality 块: \(json)" }
        guard json.contains("\"public_key\":\"my-pub-key\"") else { return "public_key 错误" }
        guard json.contains("\"short_id\":\"0123abcd\"") else { return "short_id 错误" }
        guard !json.contains("\"insecure\"") else { return "Reality 不应输出 insecure" }
        guard json.contains("\"fingerprint\":\"chrome\"") else { return "utls.fingerprint 错误" }
        return nil
    }

    private static func 用例_Reality无指纹() -> String? {
        let url = "vless://u-real2@real2.com:443?type=tcp&security=reality&pbk=only-pbk&sid=only-sid&sni=r2.sni"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.指纹.isEmpty else { return "fp 应为空" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"public_key\":\"only-pbk\"") else { return "public_key 错误" }
        guard !json.contains("\"utls\"") else { return "无 fp 不应输出 utls: \(json)" }
        return nil
    }

    private static func 用例_指纹firefox() -> String? {
        let url = "vless://u-ff@ff.com:443?security=tls&fp=firefox"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.指纹 == "firefox" else { return "fp 应为 firefox" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"fingerprint\":\"firefox\"") else { return "fingerprint 未输出" }
        return nil
    }

    private static func 用例_指纹safari() -> String? {
        let url = "vless://u-sf@sf.com:443?security=tls&fp=safari"
        guard case .成功(let c) = 解析(url), c.指纹 == "safari" else { return "fp 应为 safari" }
        return nil
    }

    private static func 用例_指纹ios() -> String? {
        let url = "vless://u-ios@ios.com:443?security=tls&fp=ios"
        guard case .成功(let c) = 解析(url), c.指纹 == "ios" else { return "fp 应为 ios" }
        return nil
    }

    private static func 用例_指纹android() -> String? {
        let url = "vless://u-and@and.com:443?security=tls&fp=android"
        guard case .成功(let c) = 解析(url), c.指纹 == "android" else { return "fp 应为 android" }
        return nil
    }

    private static func 用例_指纹edge() -> String? {
        let url = "vless://u-edge@edge.com:443?security=tls&fp=edge"
        guard case .成功(let c) = 解析(url), c.指纹 == "edge" else { return "fp 应为 edge" }
        return nil
    }

    private static func 用例_指纹random() -> String? {
        let url = "vless://u-rand@rand.com:443?security=tls&fp=random"
        guard case .成功(let c) = 解析(url), c.指纹 == "random" else { return "fp 应为 random" }
        return nil
    }

    private static func 用例_指纹randomized() -> String? {
        let url = "vless://u-rz@rz.com:443?security=tls&fp=randomized"
        guard case .成功(let c) = 解析(url), c.指纹 == "randomized" else { return "fp 应为 randomized" }
        return nil
    }

    private static func 用例_包编码xudp() -> String? {
        let url = "vless://u-pe@pe.com:443?packet_encoding=xudp"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.packet编码 == "xudp" else { return "packet_encoding 应为 xudp" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"packet_encoding\":\"xudp\"") else { return "packet_encoding 未输出: \(json)" }
        return nil
    }

    private static func 用例_TCP快速打开() -> String? {
        let url = "vless://u-tfo@tfo.com:443?tcp_fast_open=true"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.tcp快速打开 == true else { return "tcp_fast_open 应为 true" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"tcp_fast_open\":true") else { return "tcp_fast_open 未输出: \(json)" }
        return nil
    }

    private static func 用例_TCP多路径() -> String? {
        let url = "vless://u-tmp@tmp.com:443?tcp_multi_path=true"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.tcp多路径 == true else { return "tcp_multi_path 应为 true" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"tcp_multi_path\":true") else { return "tcp_multi_path 未输出: \(json)" }
        return nil
    }

    private static func 用例_拨号代理() -> String? {
        let url = "vless://u-dp@dp.com:443?dialer_proxy=my-proxy-tag"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.拨号代理 == "my-proxy-tag" else { return "dialer_proxy 错误" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"dialer_proxy\":\"my-proxy-tag\"") else { return "dialer_proxy 未输出: \(json)" }
        return nil
    }

    private static func 用例_别名下划线风格() -> String? {
        // 测试 ws_host / tls_sni / ws_path 下划线别名
        let url = "vless://u-un@un.com:443?type=ws&security=tls&ws_host=un.host&tls_sni=un.sni&ws_path=/un-path"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.Host == "un.host" else { return "ws_host 别名未识别: \(c.Host)" }
        guard c.sni == "un.sni" else { return "tls_sni 别名未识别: \(c.sni)" }
        guard c.路径 == "/un-path" else { return "ws_path 别名未识别: \(c.路径)" }
        return nil
    }

    private static func 用例_别名Reality风格() -> String? {
        // 测试 publicKey / shortId / service / fingerprint 别名
        let url = "vless://u-al@al.com:443?type=grpc&security=reality&service=al-svc&publicKey=al-pbk&shortId=al-sid&fingerprint=chrome"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.grpc服务名 == "al-svc" else { return "service 别名未识别: \(c.grpc服务名)" }
        guard c.reality公钥 == "al-pbk" else { return "publicKey 别名未识别: \(c.reality公钥)" }
        guard c.reality短id == "al-sid" else { return "shortId 别名未识别: \(c.reality短id)" }
        guard c.指纹 == "chrome" else { return "fingerprint 别名未识别: \(c.指纹)" }
        return nil
    }

    private static func 用例_批量解析混合() -> String? {
        // 3 成功 + 1 空行 + 1 失败
        let 文本 = """
        vless://ok1@a.com:443
        vless://ok2@b.com:443?type=ws
        vless://ok3@c.com:443

        vless://@noid:443
        """
        let 结果 = 批量解析(文本)
        guard 结果.count == 4 else { return "应产出4条结果（跳过空行）, 实际\(结果.count)" }
        // 第1条成功
        guard case .成功 = 结果[0].解析结果 else { return "第1行应成功" }
        guard 结果[0].行号 == 1 else { return "第1行行号应为1, 实际\(结果[0].行号)" }
        // 第2条成功
        guard case .成功 = 结果[1].解析结果 else { return "第2行应成功" }
        guard 结果[1].行号 == 2 else { return "第2行行号应为2, 实际\(结果[1].行号)" }
        // 第3条成功
        guard case .成功 = 结果[2].解析结果 else { return "第3行应成功" }
        // 第4条失败（空 uuid）
        guard case .失败 = 结果[3].解析结果 else { return "第4行应失败" }
        guard 结果[3].行号 == 5 else { return "第5行行号应为5（空行被跳过）, 实际\(结果[3].行号)" }
        return nil
    }

    private static func 用例_批量解析注释行() -> String? {
        let 文本 = """
        # 这是一行注释，应被跳过
        // 这是双斜杠注释，也应被跳过
        vless://real@real.com:443
        """
        let 结果 = 批量解析(文本)
        guard 结果.count == 1 else { return "应仅产出1条结果（跳过2条注释）, 实际\(结果.count)" }
        guard case .成功(let c) = 结果[0].解析结果 else { return "real 行应成功" }
        guard c.服务器 == "real.com" else { return "服务器错误" }
        guard 结果[0].行号 == 3 else { return "行号应为3, 实际\(结果[0].行号)" }
        return nil
    }

    private static func 用例_grpc多模式关不输出() -> String? {
        // multi_mode=false 时不输出该字段
        let url = "vless://u-g2@g2.com:443?type=grpc&security=tls&serviceName=g2&multi_mode=false"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.grpc多模式 == false else { return "multi_mode 应为 false" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard !json.contains("\"multi_mode\"") else { return "multi_mode=false 不应输出: \(json)" }
        return nil
    }

    private static func 用例_http方法POST() -> String? {
        let url = "vless://u-m@m.com:443?type=http&method=POST&path=/post"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.http方法 == "POST" else { return "method 应为 POST" }
        let json = 节点配置生成器.生成出站JSON(c)
        guard json.contains("\"method\":\"POST\"") else { return "method 未输出: \(json)" }
        return nil
    }

    // MARK: 汇总

    private static func 汇总(通过数: Int, 总数: Int, 失败: [String]) -> String {
        var 输出 = "VLESS解析器自测：\(通过数)/\(总数) 通过"
        if !失败.isEmpty {
            输出 += "\n失败详情：\n" + 失败.joined(separator: "\n")
        } else {
            输出 += "，全部通过"
        }
        return 输出
    }
}
