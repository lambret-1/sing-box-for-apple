//
//  节点配置生成器.swift
//  SFI
//
//  一期：将结构化节点配置转换为 sing-box 1.14.6 标准 VLESS 出站 JSON
//  最低支持 iOS 16
//
//  字段白名单（严格只输出以下字段，禁止额外字段）：
//  type / tag / server / server_port / uuid / flow / network / tls / transport
//

import Foundation

/// sing-box 出站 JSON 生成器
enum 节点配置生成器 {

    /// 生成 sing-box 1.14.6 VLESS 出站 JSON 字符串
    /// - Parameter 配置: 已解析的节点配置
    /// - Returns: 合法 JSON 字符串（UTF-8，非转义中文）
    static func 生成出站JSON(_ 配置: 节点配置) -> String {
        var 字典: [String: Any] = [:]

        // 必填基础字段
        字典["type"] = "vless"
        字典["tag"] = "vless-out-1"
        字典["server"] = 配置.服务器
        字典["server_port"] = 配置.端口
        字典["uuid"] = 配置.uuid

        // flow：非空才输出
        if !配置.flow.isEmpty {
            字典["flow"] = 配置.flow
        }

        // network：传输类型（tcp / ws），始终输出
        let 网络类型 = 配置.传输类型.isEmpty ? "tcp" : 配置.传输类型
        字典["network"] = 网络类型

        // tls 块：仅 security=tls 时输出
        if 配置.安全类型 == "tls" {
            var tls块: [String: Any] = [:]
            tls块["enabled"] = true
            // server_name：优先用 sni，缺省时回退到服务器
            tls块["server_name"] = 配置.sni.isEmpty ? 配置.服务器 : 配置.sni
            // insecure：一期固定 false
            tls块["insecure"] = false

            // utls 块：fp 非空时输出
            if !配置.指纹.isEmpty {
                tls块["utls"] = [
                    "enabled": true,
                    "fingerprint": 配置.指纹
                ]
            }
            字典["tls"] = tls块
        }

        // transport 块：按传输类型条件输出
        if 网络类型 == "ws" {
            // WS 传输：type/path/headers.Host
            var ws块: [String: Any] = [:]
            ws块["type"] = "ws"
            // path 为空时不输出
            if !配置.路径.isEmpty {
                ws块["path"] = 配置.路径
            }
            // Host 头：非空时输出
            if !配置.Host.isEmpty {
                ws块["headers"] = ["Host": 配置.Host]
            }
            字典["transport"] = ws块
        } else if 网络类型 == "tcp", 配置.headerType == "http" {
            // TCP + http 伪装：type/tcp + header.type/http
            let tcp块: [String: Any] = [
                "type": "tcp",
                "header": [
                    "type": "http"
                ]
            ]
            字典["transport"] = tcp块
        }
        // 其余情况（tcp + headerType=none）不输出 transport 块

        // 序列化为 JSON 字符串
        // 说明：JSONSerialization 默认会将非 ASCII 字符转义为 \uXXXX，这是合法 JSON，
        // sing-box 可正常解析；如需原生 UTF-8 输出可在写入文件时用 String(data:encoding:.utf8) 后再转义还原。
        guard let 数据 = try? JSONSerialization.data(
            withJSONObject: 字典,
            options: [.sortedKeys, .withoutEscapingSlashes]
        ) else {
            // 极端情况：字典构建失败，返回最小可用 JSON
            return "{\"type\":\"vless\",\"tag\":\"vless-out-1\",\"server\":\"\(配置.服务器)\",\"server_port\":\(配置.端口),\"uuid\":\"\(配置.uuid)\",\"network\":\"tcp\"}"
        }
        guard let 字符串 = String(data: 数据, encoding: .utf8) else {
            return "{}"
        }
        return 字符串
    }
}

// MARK: - JSON 输出非 ASCII 字符的辅助

extension 节点配置生成器 {
    /// 生成带美化缩进的 JSON 字符串（调试用，不在生产链路使用）
    static func 生成美化JSON(_ 配置: 节点配置) -> String {
        // 复用主逻辑，但用 .prettyPrinted 选项
        var 字典: [String: Any] = [:]
        字典["type"] = "vless"
        字典["tag"] = "vless-out-1"
        字典["server"] = 配置.服务器
        字典["server_port"] = 配置.端口
        字典["uuid"] = 配置.uuid
        if !配置.flow.isEmpty { 字典["flow"] = 配置.flow }
        let 网络类型 = 配置.传输类型.isEmpty ? "tcp" : 配置.传输类型
        字典["network"] = 网络类型
        if 配置.安全类型 == "tls" {
            var tls块: [String: Any] = [:]
            tls块["enabled"] = true
            tls块["server_name"] = 配置.sni.isEmpty ? 配置.服务器 : 配置.sni
            tls块["insecure"] = false
            if !配置.指纹.isEmpty {
                tls块["utls"] = ["enabled": true, "fingerprint": 配置.指纹]
            }
            字典["tls"] = tls块
        }
        if 网络类型 == "ws" {
            var ws块: [String: Any] = ["type": "ws"]
            if !配置.路径.isEmpty { ws块["path"] = 配置.路径 }
            if !配置.Host.isEmpty { ws块["headers"] = ["Host": 配置.Host] }
            字典["transport"] = ws块
        } else if 网络类型 == "tcp", 配置.headerType == "http" {
            字典["transport"] = ["type": "tcp", "header": ["type": "http"]]
        }
        guard let 数据 = try? JSONSerialization.data(
            withJSONObject: 字典,
            options: [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        ), let 字符串 = String(data: 数据, encoding: .utf8) else {
            return "{}"
        }
        return 字符串
    }
}
