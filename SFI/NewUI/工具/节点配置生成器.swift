//
//  节点配置生成器.swift
//  SFI
//
//  一/二期：将结构化节点配置转换为 sing-box 1.14.6 标准 VLESS 出站 JSON
//  最低支持 iOS 16
//
//  字段白名单：
//  type / tag / server / server_port / uuid / flow / network / tls / transport
//  packet_encoding / tcp_fast_open / tcp_multi_path / dialer_proxy
//

import Foundation

/// sing-box 出站 JSON 生成器
enum 节点配置生成器 {

    /// 生成 sing-box 1.14.6 VLESS 出站 JSON 字符串
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

        // network：传输类型，始终输出
        let 网络类型 = 配置.传输类型.rawValue
        字典["network"] = 网络类型

        // tls 块：security=tls 或 reality 时输出
        if 配置.安全类型 == .tls || 配置.安全类型 == .reality {
            var tls块: [String: Any] = [:]
            tls块["enabled"] = true
            // server_name：优先用 sni，缺省时回退到服务器
            if !配置.sni.isEmpty {
                tls块["server_name"] = 配置.sni
            } else {
                tls块["server_name"] = 配置.服务器
            }

            // Reality 块：仅 security=reality 时输出
            if 配置.安全类型 == .reality {
                var reality块: [String: Any] = [:]
                reality块["enabled"] = true
                if !配置.reality公钥.isEmpty {
                    reality块["public_key"] = 配置.reality公钥
                }
                if !配置.reality短id.isEmpty {
                    reality块["short_id"] = 配置.reality短id
                }
                tls块["reality"] = reality块
            } else {
                // 标准 TLS：输出 insecure
                tls块["insecure"] = false
            }

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
        switch 配置.传输类型 {
        case .ws:
            var ws块: [String: Any] = [:]
            ws块["type"] = "ws"
            if !配置.路径.isEmpty { ws块["path"] = 配置.路径 }
            if !配置.Host.isEmpty {
                ws块["headers"] = ["Host": 配置.Host]
            }
            字典["transport"] = ws块

        case .http:
            var http块: [String: Any] = [:]
            http块["type"] = "http"
            // host 是数组
            if !配置.Host.isEmpty {
                http块["host"] = [配置.Host]
            }
            if !配置.路径.isEmpty { http块["path"] = 配置.路径 }
            // method 非空时输出（默认 GET 可不输出）
            if !配置.http方法.isEmpty {
                http块["method"] = 配置.http方法
            }
            字典["transport"] = http块

        case .grpc:
            var grpc块: [String: Any] = [:]
            grpc块["type"] = "grpc"
            if !配置.grpc服务名.isEmpty {
                grpc块["service_name"] = 配置.grpc服务名
            }
            if 配置.grpc多模式 {
                grpc块["multi_mode"] = true
            }
            字典["transport"] = grpc块

        case .httpupgrade:
            var hu块: [String: Any] = [:]
            hu块["type"] = "httpupgrade"
            if !配置.Host.isEmpty { hu块["host"] = 配置.Host }
            if !配置.路径.isEmpty { hu块["path"] = 配置.路径 }
            字典["transport"] = hu块

        case .splithttp:
            var sh块: [String: Any] = [:]
            sh块["type"] = "splithttp"
            if !配置.Host.isEmpty { sh块["host"] = 配置.Host }
            if !配置.路径.isEmpty { sh块["path"] = 配置.路径 }
            字典["transport"] = sh块

        case .tcp:
            // TCP + http 伪装才输出 transport 块
            if 配置.headerType == "http" {
                字典["transport"] = [
                    "type": "tcp",
                    "header": ["type": "http"]
                ]
            }
            // headerType=none 时不输出 transport 块
        }

        // 顶层高级参数
        if !配置.packet编码.isEmpty {
            字典["packet_encoding"] = 配置.packet编码
        }
        if 配置.tcp快速打开 {
            字典["tcp_fast_open"] = true
        }
        if 配置.tcp多路径 {
            字典["tcp_multi_path"] = true
        }
        if !配置.拨号代理.isEmpty {
            字典["dialer_proxy"] = 配置.拨号代理
        }

        // 序列化为 JSON 字符串
        guard let 数据 = try? JSONSerialization.data(
            withJSONObject: 字典,
            options: [.sortedKeys, .withoutEscapingSlashes]
        ) else {
            return "{\"type\":\"vless\",\"tag\":\"vless-out-1\",\"server\":\"\(配置.服务器)\",\"server_port\":\(配置.端口),\"uuid\":\"\(配置.uuid)\",\"network\":\"tcp\"}"
        }
        guard let 字符串 = String(data: 数据, encoding: .utf8) else {
            return "{}"
        }
        return 字符串
    }

    /// 生成带美化缩进的 JSON 字符串（调试用）
    static func 生成美化JSON(_ 配置: 节点配置) -> String {
        let 紧凑 = 生成出站JSON(配置)
        guard let 数据 = 紧凑.data(using: .utf8),
              let 对象 = try? JSONSerialization.jsonObject(with: 数据),
              let 美化数据 = try? JSONSerialization.data(
                withJSONObject: 对象,
                options: [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
              ),
              let 字符串 = String(data: 美化数据, encoding: .utf8) else {
            return 紧凑
        }
        return 字符串
    }
}
