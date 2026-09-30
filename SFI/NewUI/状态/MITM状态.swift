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

    private init() {
        加载配置()
        加载脚本列表()
        加载重写规则()
        加载本地映射()
        加载域名排除()
        // 启动时自动生成证书（如不存在）
        Task { @MainActor in
            await 确保证书已生成()
            刷新证书状态()
        }
    }

    // MARK: - 证书管理

    /// 证书生成错误信息
    @Published var 证书生成错误: String?

    /// 确保 CA 证书已生成，如不存在则自动生成
    func 确保证书已生成() async {
        let 生成器 = CACertificate生成器.共享
        let 状态 = 生成器.检测证书状态()
        if case .文件缺失 = 状态 {
            do {
                try 生成器.生成CA证书()
                证书生成错误 = nil
            } catch {
                证书生成错误 = "证书生成失败：\(error.localizedDescription)"
                print("[MITM] CA 证书生成失败：\(error.localizedDescription)")
            }
        }
        // 更新 PEM 缓存
        CA证书PEM = 生成器.获取证书PEM() ?? ""
        证书状态 = 生成器.检测证书状态()
    }

    /// 刷新证书状态
    func 刷新证书状态() {
        let 生成器 = CACertificate生成器.共享
        证书状态 = 生成器.检测证书状态()
        CA证书PEM = 生成器.获取证书PEM() ?? ""
        // 同步保存 P12 Base64 到 App Group 供内核使用
        if let p12Base64 = 生成器.获取P12Base64(),
           let 共享 = 共享默认 {
            共享.set(p12Base64, forKey: 键前缀 + "p12_base64")
            共享.synchronize()
        }
    }

    /// 重新生成 CA 证书
    func 重新生成证书() throws {
        let 生成器 = CACertificate生成器.共享
        // 清除用户已确认标记
        生成器.用户已确认安装 = false
        try 生成器.生成CA证书()
        证书生成错误 = nil
        刷新证书状态()
    }

    /// 用户确认已安装并信任证书
    func 用户确认已安装信任() {
        CACertificate生成器.共享.用户已确认安装 = true
        刷新证书状态()
    }

    /// 获取 P12 Base64（供内核配置使用）
    func 获取P12Base64() -> String? {
        CACertificate生成器.共享.获取P12Base64()
    }

    /// 导出 mobileconfig 文件
    func 导出MobileConfig() throws -> URL {
        try CACertificate生成器.共享.生成MobileConfig()
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
            // 保存 P12 Base64 供内核使用
            if let p12Base64 = 获取P12Base64() {
                共享.set(p12Base64, forKey: 键前缀 + "p12_base64")
            }
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
