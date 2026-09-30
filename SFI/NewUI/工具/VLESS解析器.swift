//
//  VLESS解析器.swift
//  SFI
//
//  一期：VLESS URL 解析核心，将 vless:// 链接解析为结构化节点配置
//  最低支持 iOS 16
//

import Foundation

// MARK: - 节点配置模型

/// VLESS 节点结构化配置
///
/// 字段说明：
/// - 名称：节点备注（URL fragment，已做百分号解码）
/// - 服务器：服务端域名或 IP
/// - 端口：1 ~ 65535
/// - uuid：用户凭据
/// - 传输类型：tcp / ws
/// - 安全类型：none / tls
/// - flow：流控（通常为 xtls-rprx-vision，可空）
/// - 路径：WS 路径（已解码，可空）
/// - Host：WS Host 头 / TCP 伪装主机（已解码，可空）
/// - sni：TLS 服务器名称（已解码，可空）
/// - 指纹：uTLS 指纹（chrome / firefox / safari 等，可空）
/// - headerType：TCP 伪装类型（none / http）
/// - 原始参数字典：保留解析时的全部 query 参数（已解码），便于扩展
struct 节点配置: Equatable {
    var 名称: String
    var 服务器: String
    var 端口: Int
    var uuid: String
    var 传输类型: String      // "tcp" / "ws"
    var 安全类型: String      // "none" / "tls"
    var flow: String
    var 路径: String
    var Host: String
    var sni: String
    var 指纹: String
    var headerType: String    // "none" / "http"
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

// MARK: - VLESS 解析器

/// VLESS URL 解析器
///
/// 支持格式：`vless://uuid@server:port?params#备注`
/// 支持百分号解码；支持参数别名 host↔ws-host、sni↔tls-sni
enum VLESS解析器 {

    // MARK: 主入口

    /// 解析 VLESS URL
    /// - Parameter url字符串: 完整 vless:// 链接
    /// - Returns: 解析结果
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
        let 传输类型 = 取参数(原始参数字典, 键列表: ["type"]) ?? "tcp"
        let 安全类型 = 取参数(原始参数字典, 键列表: ["security"]) ?? "none"
        let flow = 取参数(原始参数字典, 键列表: ["flow"]) ?? ""
        let 路径 = 取参数(原始参数字典, 键列表: ["path"]) ?? ""
        let Host = 取参数(原始参数字典, 键列表: ["host", "ws-host"]) ?? ""
        let sni = 取参数(原始参数字典, 键列表: ["sni", "tls-sni"]) ?? ""
        let 指纹 = 取参数(原始参数字典, 键列表: ["fp"]) ?? ""
        let headerType = 取参数(原始参数字典, 键列表: ["headerType"]) ?? "none"

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
            原始参数字典: 原始参数字典
        )
        return .成功(配置)
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

    /// 运行内置自测，返回结果摘要
    ///
    /// 覆盖 11 个用例：最简 tcp/none、tcp+tls+sni+fp、tcp+tls+flow、ws+tls+path+host+sni、
    /// 明文 ws、tcp+http 伪装、URL 编码中文、缺 uuid 失败、端口越界失败、参数别名、缺 port 失败
    static func 运行自测() -> String {
        // 每个用例返回 nil 表示通过，返回 String 表示失败原因
        let 用例列表: [(名称: String, 执行: () -> String?)] = [
            ("1.最简tcp-none", 用例_最简tcp无安全),
            ("2.tcp-tls-sni-fp", 用例_tcp带TLS指纹),
            ("3.tcp-tls-flow", 用例_tcp带Flow),
            ("4.ws-tls-path-host-sni", 用例_ws带TLS完整参数),
            ("5.ws-none", 用例_明文WS),
            ("6.tcp-http-header", 用例_tcp伪装HTTP),
            ("7.url编码", 用例_URL编码中文),
            ("8.缺uuid", 用例_缺UUID应失败),
            ("9.端口越界", 用例_端口越界应失败),
            ("10.参数别名", 用例_参数别名兼容),
            ("11.缺port", 用例_缺端口应失败),
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

    // MARK: 单个用例实现（返回 nil 表示通过）

    private static func 用例_最简tcp无安全() -> String? {
        let url = "vless://11111111-1111-1111-1111-111111111111@example.com:443"
        guard case .成功(let c) = 解析(url) else {
            return "应解析成功"
        }
        guard c.uuid == "11111111-1111-1111-1111-111111111111" else { return "uuid 不匹配: \(c.uuid)" }
        guard c.服务器 == "example.com" else { return "服务器不匹配: \(c.服务器)" }
        guard c.端口 == 443 else { return "端口应为443, 实际\(c.端口)" }
        guard c.传输类型 == "tcp" else { return "默认传输应为tcp, 实际\(c.传输类型)" }
        guard c.安全类型 == "none" else { return "默认安全应为none, 实际\(c.安全类型)" }
        guard c.flow.isEmpty else { return "flow应为空, 实际\(c.flow)" }
        return nil
    }

    private static func 用例_tcp带TLS指纹() -> String? {
        let url = "vless://uuid2@server.com:8443?type=tcp&security=tls&sni=sni.server.com&fp=chrome#节点二"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.安全类型 == "tls" else { return "security应为tls, 实际\(c.安全类型)" }
        guard c.sni == "sni.server.com" else { return "sni不匹配: \(c.sni)" }
        guard c.指纹 == "chrome" else { return "fp应为chrome, 实际\(c.指纹)" }
        guard c.名称 == "节点二" else { return "名称应为节点二, 实际\(c.名称)" }
        return nil
    }

    private static func 用例_tcp带Flow() -> String? {
        let url = "vless://uuid3@3.3.3.3:443?type=tcp&security=tls&flow=xtls-rprx-vision"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.flow == "xtls-rprx-vision" else { return "flow应为xtls-rprx-vision, 实际\(c.flow)" }
        return nil
    }

    private static func 用例_ws带TLS完整参数() -> String? {
        let url = "vless://uuid4@ws.com:2053?type=ws&security=tls&path=%2Fray&host=ws.host.com&sni=ws.sni.com"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.传输类型 == "ws" else { return "type应为ws, 实际\(c.传输类型)" }
        guard c.路径 == "/ray" else { return "path应解码为/ray, 实际\(c.路径)" }
        guard c.Host == "ws.host.com" else { return "host不匹配: \(c.Host)" }
        guard c.sni == "ws.sni.com" else { return "sni不匹配: \(c.sni)" }
        return nil
    }

    private static func 用例_明文WS() -> String? {
        let url = "vless://uuid5@plain.ws:8080?type=ws&path=/abc"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.安全类型 == "none" else { return "security应为none, 实际\(c.安全类型)" }
        guard c.路径 == "/abc" else { return "path应为/abc, 实际\(c.路径)" }
        return nil
    }

    private static func 用例_tcp伪装HTTP() -> String? {
        let url = "vless://uuid6@fake.com:443?type=tcp&security=tls&headerType=http"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.headerType == "http" else { return "headerType应为http, 实际\(c.headerType)" }
        return nil
    }

    private static func 用例_URL编码中文() -> String? {
        // %E4%B8%AD%E6%96%87 = "中文"，%3D = "="，%E8%8A%82%E7%82%B9 = "节点"
        let url = "vless://uuid7@enc.com:443?type=ws&path=%2Fabc%3Ddef&security=tls#%E4%B8%AD%E6%96%87%E8%8A%82%E7%82%B9"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.路径 == "/abc=def" else { return "path解码错误: \(c.路径)" }
        guard c.名称 == "中文节点" else { return "名称解码错误: \(c.名称)" }
        return nil
    }

    private static func 用例_缺UUID应失败() -> String? {
        let url = "vless://@noid.com:443"
        guard case .失败(let 原因) = 解析(url) else {
            return "应返回失败, 实际成功"
        }
        guard 原因.contains("uuid") else {
            return "失败原因应提到uuid, 实际: \(原因)"
        }
        return nil
    }

    private static func 用例_端口越界应失败() -> String? {
        let url = "vless://uuid9@badport.com:70000"
        guard case .失败(let 原因) = 解析(url) else {
            return "应返回失败, 实际成功"
        }
        guard 原因.contains("端口") else {
            return "失败原因应提到端口, 实际: \(原因)"
        }
        return nil
    }

    private static func 用例_参数别名兼容() -> String? {
        let url = "vless://uuid10@alias.com:443?type=ws&security=tls&ws-host=alias.host&tls-sni=alias.sni"
        guard case .成功(let c) = 解析(url) else { return "应解析成功" }
        guard c.Host == "alias.host" else { return "ws-host 别名未识别, Host=\(c.Host)" }
        guard c.sni == "alias.sni" else { return "tls-sni 别名未识别, sni=\(c.sni)" }
        return nil
    }

    private static func 用例_缺端口应失败() -> String? {
        let url = "vless://uuid11@noport.com"
        guard case .失败(let 原因) = 解析(url) else {
            return "应返回失败, 实际成功"
        }
        guard 原因.contains("端口") else {
            return "失败原因应提到端口, 实际: \(原因)"
        }
        return nil
    }

    /// 汇总测试结果
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
