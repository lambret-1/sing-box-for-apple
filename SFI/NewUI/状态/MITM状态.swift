//
//  状态/MITM状态.swift
//  sing-box-for-apple 新UI
//
//  MITM 功能全局状态管理：开关、证书、规则、脚本、抓包数据
//

import SwiftUI
import Combine

// MARK: - MITM 证书状态枚举

enum MITM证书状态: Equatable {
    case 就绪
    case 未安装
    case 未信任
    case 文件缺失
    case 已过期
    case 文件损坏
    case 临近过期(剩余天数: Int)

    var 描述: String {
        switch self {
        case .就绪: return "证书就绪，MITM 可正常使用"
        case .未安装: return "证书已生成，请安装描述文件"
        case .未信任: return "证书已安装，请在设置中完全信任"
        case .文件缺失: return "证书文件缺失，请重新生成"
        case .已过期: return "证书已过期，请重新生成"
        case .文件损坏: return "证书文件损坏，请重新生成"
        case .临近过期(let 天数): return "证书将在 \(天数) 天后过期"
        }
    }

    var 可使用: Bool {
        if case .就绪 = self { return true }
        return false
    }
}

// MARK: - 圈 X 脚本模型

enum 圈X脚本类型: String, CaseIterable, Identifiable, Codable {
    case 请求前 = "before-request"
    case 响应前 = "before-response"
    var id: String { rawValue }
    var 显示名称: String {
        switch self {
        case .请求前: return "请求前 (before-request)"
        case .响应前: return "响应前 (before-response)"
        }
    }
}

struct 圈X脚本条目: Identifiable, Codable, Equatable {
    var id = UUID()
    var 名称: String
    var 标签: String
    var 类型: 圈X脚本类型
    var 匹配模式: String
    var 代码: String
    var 启用: Bool
    var 需要请求体: Bool
    var 超时秒数: Double
    var 最大体积: Int
    var 创建时间: Date

    init(名称: String, 标签: String = UUID().uuidString.prefix(8).description,
         类型: 圈X脚本类型 = .请求前, 匹配模式: String = ".*",
         代码: String = "// 圈X脚本示例\nfunction handleRequest(request) {\n    request.headers[\"X-Custom\"] = \"value\"\n    $done(request)\n}",
         启用: Bool = true, 需要请求体: Bool = false,
         超时秒数: Double = 10, 最大体积: Int = 131072) {
        self.名称 = 名称
        self.标签 = 标签
        self.类型 = 类型
        self.匹配模式 = 匹配模式
        self.代码 = 代码
        self.启用 = 启用
        self.需要请求体 = 需要请求体
        self.超时秒数 = 超时秒数
        self.最大体积 = 最大体积
        self.创建时间 = Date()
    }
}

// MARK: - 重写规则模型

enum 重写规则类型: String, CaseIterable, Identifiable, Codable {
    case URL重写 = "url_rewrite"
    case 请求头重写 = "header_rewrite"
    case 响应头重写 = "header_rewrite_response"
    case 请求体重写 = "body_rewrite"
    case 响应体重写 = "body_rewrite_response"
    case 拒绝 = "reject"
    case 重定向 = "redirect"
    var id: String { rawValue }
    var 显示名称: String {
        switch self {
        case .URL重写: return "URL 重写"
        case .请求头重写: return "请求头重写"
        case .响应头重写: return "响应头重写"
        case .请求体重写: return "请求体重写"
        case .响应体重写: return "响应体重写"
        case .拒绝: return "拒绝请求"
        case .重定向: return "302 重定向"
        }
    }
}

struct 重写规则条目: Identifiable, Codable, Equatable {
    var id = UUID()
    var 名称: String
    var 类型: 重写规则类型
    var 匹配模式: String
    var 目标值: String
    var 启用: Bool
    init(名称: String, 类型: 重写规则类型 = .URL重写, 匹配模式: String, 目标值: String, 启用: Bool = true) {
        self.名称 = 名称
        self.类型 = 类型
        self.匹配模式 = 匹配模式
        self.目标值 = 目标值
        self.启用 = 启用
    }
}

// MARK: - 本地映射模型

struct 本地映射条目: Identifiable, Codable, Equatable {
    var id = UUID()
    var 名称: String
    var 匹配模式: String
    var 映射类型: 映射类型
    var 数据内容: String
    var 状态码: Int
    var 启用: Bool

    enum 映射类型: String, Codable, CaseIterable {
        case 文件 = "file"
        case 文本 = "text"
        case 微缩GIF = "tiny-gif"
        case Base64 = "base64"
        var 显示名称: String {
            switch self {
            case .文件: return "本地文件"
            case .文本: return "文本内容"
            case .微缩GIF: return "1x1 透明 GIF"
            case .Base64: return "Base64 数据"
            }
        }
    }

    init(名称: String, 匹配模式: String, 映射类型: 映射类型 = .文本, 数据内容: String = "", 状态码: Int = 200, 启用: Bool = true) {
        self.名称 = 名称
        self.匹配模式 = 匹配模式
        self.映射类型 = 映射类型
        self.数据内容 = 数据内容
        self.状态码 = 状态码
        self.启用 = 启用
    }
}

// MARK: - 域名排除模型

struct 域名排除项: Identifiable, Codable, Equatable {
    var id = UUID()
    var 域名: String
    var 备注: String
    var 启用: Bool
}

// MARK: - 抓包记录模型

struct 抓包记录: Identifiable, Codable, Equatable {
    var id = UUID()
    var 方法: String
    var URL: String
    var 状态码: Int
    var 请求头: [String: String]
    var 响应头: [String: String]
    var 请求体: String
    var 响应体: String
    var 耗时毫秒: Int
    var 请求大小: Int
    var 响应大小: Int
    var 时间: Date
    var 已修改: Bool
    var 匹配脚本: String?

    var 域名: String {
        guard let url = Foundation.URL(string: URL) else { return "" }
        return url.host ?? ""
    }

    var 格式化耗时: String {
        if 耗时毫秒 < 1000 { return "\(耗时毫秒)ms" }
        return String(format: "%.1fs", Double(耗时毫秒) / 1000.0)
    }

    var 格式化响应大小: String {
        return 抓包记录.格式化字节数(响应大小)
    }

    static func 格式化字节数(_ 字节数: Int) -> String {
        if 字节数 < 1024 { return "\(字节数) B" }
        if 字节数 < 1024 * 1024 { return String(format: "%.1f KB", Double(字节数) / 1024.0) }
        return String(format: "%.1f MB", Double(字节数) / 1024.0 / 1024.0)
    }
}

// MARK: - TLS 指纹类型

enum TLS指纹类型: String, CaseIterable, Identifiable, Codable {
    case 关闭 = "disabled"
    case Chrome = "chrome"
    case Firefox = "firefox"
    case Safari = "safari"
    case Edge = "edge"
    case iOS原生 = "ios"
    var id: String { rawValue }
    var 显示名称: String {
        switch self {
        case .关闭: return "关闭（默认指纹）"
        case .Chrome: return "Chrome"
        case .Firefox: return "Firefox"
        case .Safari: return "Safari"
        case .Edge: return "Edge"
        case .iOS原生: return "iOS 原生"
        }
    }
}

// MARK: - MITM 全局状态管理器

final class MITM状态: ObservableObject {
    static let 共享 = MITM状态()

    @Published var 启用MITM: Bool = false { didSet { 保存配置() } }
    @Published var 启用抓包: Bool = true { didSet { 保存配置() } }
    @Published var 启用HTTP2: Bool = true { didSet { 保存配置() } }
    @Published var TLS指纹: TLS指纹类型 = .Chrome { didSet { 保存配置() } }

    @Published var 证书状态: MITM证书状态 = .就绪
    @Published var CA证书PEM: String = ""
    @Published var CA私钥PEM: String = ""

    @Published var 脚本列表: [圈X脚本条目] = [] { didSet { 保存脚本列表() } }
    @Published var 重写规则列表: [重写规则条目] = [] { didSet { 保存重写规则() } }
    @Published var 本地映射列表: [本地映射条目] = [] { didSet { 保存本地映射() } }
    @Published var 域名排除列表: [域名排除项] = [] { didSet { 保存域名排除() } }

    @Published var 抓包记录列表: [抓包记录] = []
    let 最大记录数 = 500

    private let 键前缀 = "mitm_"
    private var 共享默认: UserDefaults? { UserDefaults(suiteName: 全局常量.App组标识) }

    private static let 预生成CA证书 = """
-----BEGIN CERTIFICATE-----
MIIDuzCCAqOgAwIBAgIUPse4zPDlPWZCRUNE5DN98+ihzlswDQYJKoZIhvcNAQEL
BQAwbTELMAkGA1UEBhMCQ04xEjAQBgNVBAgMCUd1YW5nZG9uZzERMA8GA1UEBwwI
RG9uZ2d1YW4xDzANBgNVBAoMBk5ld1ZQTjENMAsGA1UECwwETUlUTTEXMBUGA1UE
AwwOTmV3VlBOIE1JVE0gQ0EwHhcNMjYwOTI3MDUyMTAxWhcNMzYwOTI0MDUyMTAx
WjBtMQswCQYDVQQGEwJDTjESMBAGA1UECAwJR3Vhbmdkb25nMREwDwYDVQQHDAhE
b25nZ3VhbjEPMA0GA1UECgwGTmV3VlBOMQ0wCwYDVQQLDARNSVRNMRcwFQYDVQQD
DA5OZXdWUE4gTUlUTSBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AM8pq8n3d6ocmbJAnHBg82Usr7zJDaxch4BKEQYjZ+rXF5NCjvrej7OLrzA624ME
EHzkWvM4lHrPFcwBDeNpm4KShdh3mr5fLf/qs1Yk4ar2sIKL5OwE6uRPpjwC53L9
xShMxn26Wu+m3i5iYpW/GM63JIDNR2DDDBhU0TbwJIleD94/9wDCtCqQJUCKn1nK
TJ4M9NCd7Le4yfqfWxyAl5elHJQIUiEp8c27ktVew2FiRJMLxqlvLzLb0M16P1kw
DRtC7u7gTt2/SLYxAyLz8OCR3ep9EVzTGYWfszhCZu3MMnh1NgZnWdEQn9zAqAyJ
q8TFMmEdFfaf6xMbLu/0z2MCAwEAAaNTMFEwHQYDVR0OBBYEFHIM5TzRO29Noehn
N7zh3Ir1pue+MB8GA1UdIwQYMBaAFHIM5TzRO29NoehnN7zh3Ir1pue+MA8GA1Ud
EwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBABU5Bsjr6tR/b0hKV3SdX245
G5fwLZ/EUa+j6SDtzgx3mvjaZ1bNGZbGRFuTGqTkLAF6QSS5aZRfse4RILRs4nnx
1hrWl7oFjlniHtwDskcAfsCu0JrtACpLhQk/Qu9XteORzeJMiY5HUo+FPF03ja/V
y214yyOHcp68iytOvesorZcYn1ucqeNYTpzhAr2wIuT4VgV8cWRssVJ+OWDgT7xr
QKBw/dSbFUbUDZcFmxa4S49UPLwH4Fo40am4WLxV/+RGGQmhipacSxF3l4H4We/m
HyLugfYN59l4OCPjUplaSIifgDd9/131N0OPyi0gJFFD4+4pASgCCUQCsIflqjk=
-----END CERTIFICATE-----
"""

    private static let 预生成CA私钥 = """
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDPKavJ93eqHJmy
QJxwYPNlLK+8yQ2sXIeAShEGI2fq1xeTQo763o+zi68wOtuDBBB85FrzOJR6zxXM
AQ3jaZuCkoXYd5q+Xy3/6rNWJOGq9rCCi+TsBOrkT6Y8Audy/cUoTMZ9ulrvpt4u
YmKVvxjOtySAzUdgwwwYVNE28CSJXg/eP/cAwrQqkCVAip9ZykyeDPTQney3uMn6
n1scgJeXpRyUCFIhKfHNu5LVXsNhYkSTC8apby8y29DNej9ZMA0bQu7u4E7dv0i2
MQMi8/Dgkd3qfRFc0xmFn7M4QmbtzDJ4dTYGZ1nREJ/cwKgMiavExTJhHRX2n+sT
Gy7v9M9jAgMBAAECggEAGOt21kM1+lkZZfdeuif3b166PxfiVK8Gv7hpJtdgez/n
fpfdkjDukVcGumMCH9b/0r43cJWISuOZSCKCVK5R/hl5D0qH60mQw32sl/q0yLeH
ERUZ8wg+ZztrkEF7LPp42nmt0Nb3dGeax3KfUEseBVPDiNjosquTy2N8jULC6mEW
WPNhLlNVj7oL9Ze6jqBbK8uoyLTYS7ZPGODKgKZjgl2b+8Ut367H4Pg3iHmT5ivt
KqvjQ0q9vgf5maMA9zHnhcGAnZrgvPDLMQFEZzRurwvmKOmJxbh8eoksh39ot0xZ
NcjYZnygX+EqFlacJoWTfq6bU69amnOQMIX8m+z+JQKBgQDlkG/92O2SLrXJpHoi
/hEC5uv53wMXs3c52+KWrEKXeEOmj5/DIZo6xEh7ObNYMmTqpu7dxSaWpGsyIO6W
q3Y+Dcqw1FroDBRbYScr+XcTPgvJHUphPsrM+QvL491IKfltTlhbct/RlQUkvdqR
eRogekoLHNrQXAznPbJL85YaNQKBgQDnBNakZQsfYk0o4ehP2+F+90jWj/A8V+9x
+qnjYxP1i12NjDiTQbhJsUx/g90GbabZRx3ODAvnKhd2FEsEryBZ4p70VoPU8MJq
u5bTEkZlZ5lY4xgzSHt5T/IncRpge7s+SLdzg0aflRWQmfbxJYpEzNcVdkcJOg84
HLbmAjY2NwKBgQDbXvpWRw1Hi1F2nrGEbOuOrWNFBWLsLDi71q8iMvzzyB5FtawD
CUJb9CQbdVk35/hd8CYFURf+DqLNZYD6BGHbDMzrzBIO+zQc2qtXL24luj4C8vWY
FiwwUbF/JoHYKxxK4vo2cYEGw3QF11Ndfq+D57iIBAvp3n0KIQAX6m8/HQKBgFIi
6UG33zWAWNixQUyra8gdmZsXwB1kUnDe42pCPsVtkIyUD0Vj92bUD9PCiWIQuGLG
IzWwGMdOstq7qlR3A3SR21waKnMaSrVyDtTqyXaiV+Y/j8oj+iqOnxUg5HTraQ5j
Aj6irQhuFCW+aAsjAr8laU9rJySDrQeRRgIPRUEPAoGAEc9OXlRTOlRyXKM7i0u5
Dak44bGFA7IMTWg4S8WrOfcDKhQl2s3OUyl/eLeFE1ip6DUTzzPqzCAONIFBfPF0
jK+8aP0c5duJvLOAsAuioD2+bqXEDVXK4FhX9IzgYxO7oKsTTE2VKNhNie49SFeK
FxBzaz833X+KGgOv4VBtDcY=
-----END PRIVATE KEY-----
"""

    private init() {
        加载配置()
        加载脚本列表()
        加载重写规则()
        加载本地映射()
        加载域名排除()
        CA证书PEM = Self.预生成CA证书
        CA私钥PEM = Self.预生成CA私钥
    }

    private func 保存配置() {
        let 默认 = UserDefaults.standard
        默认.set(启用MITM, forKey: 键前缀 + "enabled")
        默认.set(启用抓包, forKey: 键前缀 + "capture_enabled")
        默认.set(启用HTTP2, forKey: 键前缀 + "http2_enabled")
        默认.set(TLS指纹.rawValue, forKey: 键前缀 + "tls_fingerprint")
        if let 共享 = 共享默认 {
            共享.set(启用MITM, forKey: 键前缀 + "enabled")
            共享.set(启用抓包, forKey: 键前缀 + "capture_enabled")
            共享.set(启用HTTP2, forKey: 键前缀 + "http2_enabled")
            共享.set(TLS指纹.rawValue, forKey: 键前缀 + "tls_fingerprint")
            共享.set(CA证书PEM, forKey: 键前缀 + "ca_cert")
            共享.set(CA私钥PEM, forKey: 键前缀 + "ca_key")
            共享.synchronize()
        }
    }

    private func 加载配置() {
        let 默认 = UserDefaults.standard
        启用MITM = 默认.bool(forKey: 键前缀 + "enabled")
        启用抓包 = 默认.object(forKey: 键前缀 + "capture_enabled") as? Bool ?? true
        启用HTTP2 = 默认.object(forKey: 键前缀 + "http2_enabled") as? Bool ?? true
        if let 指纹原始 = 默认.string(forKey: 键前缀 + "tls_fingerprint"),
           let 指纹 = TLS指纹类型(rawValue: 指纹原始) {
            TLS指纹 = 指纹
        }
    }

    private func 保存脚本列表() {
        if let 数据 = try? JSONEncoder().encode(脚本列表) {
            UserDefaults.standard.set(数据, forKey: 键前缀 + "scripts")
        }
    }

    private func 加载脚本列表() {
        if let 数据 = UserDefaults.standard.data(forKey: 键前缀 + "scripts"),
           let 列表 = try? JSONDecoder().decode([圈X脚本条目].self, from: 数据) {
            脚本列表 = 列表
        }
    }

    private func 保存重写规则() {
        if let 数据 = try? JSONEncoder().encode(重写规则列表) {
            UserDefaults.standard.set(数据, forKey: 键前缀 + "rewrite_rules")
        }
    }

    private func 加载重写规则() {
        if let 数据 = UserDefaults.standard.data(forKey: 键前缀 + "rewrite_rules"),
           let 列表 = try? JSONDecoder().decode([重写规则条目].self, from: 数据) {
            重写规则列表 = 列表
        }
    }

    private func 保存本地映射() {
        if let 数据 = try? JSONEncoder().encode(本地映射列表) {
            UserDefaults.standard.set(数据, forKey: 键前缀 + "map_local")
        }
    }

    private func 加载本地映射() {
        if let 数据 = UserDefaults.standard.data(forKey: 键前缀 + "map_local"),
           let 列表 = try? JSONDecoder().decode([本地映射条目].self, from: 数据) {
            本地映射列表 = 列表
        }
    }

    private func 保存域名排除() {
        if let 数据 = try? JSONEncoder().encode(域名排除列表) {
            UserDefaults.standard.set(数据, forKey: 键前缀 + "domain_exclusions")
        }
    }

    private func 加载域名排除() {
        if let 数据 = UserDefaults.standard.data(forKey: 键前缀 + "domain_exclusions"),
           let 列表 = try? JSONDecoder().decode([域名排除项].self, from: 数据) {
            域名排除列表 = 列表
        }
        if 域名排除列表.isEmpty {
            域名排除列表 = [
                域名排除项(域名: "*.apple.com", 备注: "苹果服务", 启用: true),
                域名排除项(域名: "*.icloud.com", 备注: "iCloud", 启用: true),
                域名排除项(域名: "*.microsoft.com", 备注: "微软服务", 启用: true)
            ]
        }
    }

    func 添加抓包记录(_ 记录: 抓包记录) {
        抓包记录列表.insert(记录, at: 0)
        if 抓包记录列表.count > 最大记录数 {
            抓包记录列表 = Array(抓包记录列表.prefix(最大记录数))
        }
    }

    func 清空抓包记录() {
        抓包记录列表.removeAll()
    }

    func 导出HAR() -> String? {
        let 日期格式化器 = ISO8601DateFormatter()
        var 日志条目: [[String: Any]] = []
        for 记录 in 抓包记录列表.prefix(100) {
            var 请求头数组: [[String: String]] = []
            for (键, 值) in 记录.请求头 {
                请求头数组.append(["name": 键, "value": 值])
            }
            var 响应头数组: [[String: String]] = []
            for (键, 值) in 记录.响应头 {
                响应头数组.append(["name": 键, "value": 值])
            }
            let 条目: [String: Any] = [
                "startedDateTime": 日期格式化器.string(from: 记录.时间),
                "time": 记录.耗时毫秒,
                "request": ["method": 记录.方法, "url": 记录.URL, "headers": 请求头数组, "bodySize": 记录.请求大小] as [String: Any],
                "response": ["status": 记录.状态码, "headers": 响应头数组, "bodySize": 记录.响应大小,
                            "content": ["size": 记录.响应大小, "text": 记录.响应体] as [String: Any]] as [String: Any]
            ]
            日志条目.append(条目)
        }
        let har: [String: Any] = ["log": ["version": "1.2", "creator": ["name": "sing-box MITM", "version": "1.0"], "entries": 日志条目] as [String: Any]]
        if let jsonData = try? JSONSerialization.data(withJSONObject: har, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return nil
    }

    func 生成MITM路由配置() -> [String: Any] {
        var routeConfig: [String: Any] = ["enabled": 启用MITM, "print": 启用抓包]
        var scripts: [[String: Any]] = []
        for 脚本 in 脚本列表 where 脚本.启用 {
            scripts.append([
                "tag": 脚本.标签,
                "type": [脚本.类型.rawValue],
                "pattern": [脚本.匹配模式],
                "requires_body": 脚本.需要请求体,
                "max_size": 脚本.最大体积
            ])
        }
        if !scripts.isEmpty { routeConfig["sg_script"] = scripts }
        return routeConfig
    }
}
