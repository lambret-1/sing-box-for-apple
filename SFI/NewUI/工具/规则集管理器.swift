//
//  工具/规则集管理器.swift
//  sing-box-for-apple 新UI
//
//  官方远程规则集（rule_set）管理：geoip/geosite 等二进制规则集的持久化、下载、配置生成
//

import Foundation
import Combine

// MARK: - 下载状态枚举

/// 规则集下载状态
enum 规则集下载状态: String, Codable {
    case 未下载
    case 已下载
    case 下载失败
}

// MARK: - 规则集配置模型

/// 单条规则集配置
struct 规则集配置: Codable, Identifiable, Equatable {
    var id: UUID
    /// 标签名（如 geoip / geosite）
    var tag: String
    /// 格式（固定 binary）
    var format: String
    /// 下载 URL
    var url: String
    /// 下载出口（direct / proxy）
    var download_detour: String
    /// 更新间隔（1d / 7d / 30d）
    var update_interval: String
    /// 本地文件名（派生自 tag）
    var 本地文件名: String
    /// 最后更新时间
    var 最后更新时间: Date?
    /// 文件大小（字节）
    var 文件大小: Int64?
    /// 下载状态
    var 下载状态: 规则集下载状态

    /// 初始化
    init(id: UUID = UUID(),
         tag: String,
         format: String = "binary",
         url: String,
         download_detour: String = "direct",
         update_interval: String = "1d",
         最后更新时间: Date? = nil,
         文件大小: Int64? = nil,
         下载状态: 规则集下载状态 = .未下载) {
        self.id = id
        self.tag = tag
        self.format = format
        self.url = url
        self.download_detour = download_detour
        self.update_interval = update_interval
        self.本地文件名 = "\(tag).srs"
        self.最后更新时间 = 最后更新时间
        self.文件大小 = 文件大小
        self.下载状态 = 下载状态
    }
}

// MARK: - 规则集管理器

/// 规则集管理器：持久化 + 下载 + 配置生成
final class 规则集管理器: ObservableObject {

    /// UserDefaults 存储键
    private let 存储键 = "vless转换器.规则集列表"

    /// 规则集列表
    @Published var 规则集列表: [规则集配置] = []

    /// 是否正在下载
    @Published var 下载中: Bool = false

    init() {
        从存储加载()
    }

    // MARK: 持久化

    /// 从 UserDefaults 加载
    private func 从存储加载() {
        guard let 数据 = UserDefaults.standard.data(forKey: 存储键),
              let 列表 = try? JSONDecoder().decode([规则集配置].self, from: 数据) else {
            规则集列表 = []
            return
        }
        规则集列表 = 列表
    }

    /// 持久化到 UserDefaults
    private func 保存到存储() {
        guard let 数据 = try? JSONEncoder().encode(规则集列表) else { return }
        UserDefaults.standard.set(数据, forKey: 存储键)
    }

    // MARK: CRUD

    /// 添加规则集
    func 添加规则集(_ 配置: 规则集配置) {
        规则集列表.append(配置)
        保存到存储()
    }

    /// 删除规则集（同时删除本地文件）
    func 删除规则集(_ id: UUID) {
        guard let 索引 = 规则集列表.firstIndex(where: { $0.id == id }) else { return }
        let 配置 = 规则集列表[索引]
        // 删除本地文件
        let 文件路径 = 文件本地路径(配置.本地文件名)
        try? FileManager.default.removeItem(at: 文件路径)
        规则集列表.remove(at: 索引)
        保存到存储()
    }

    /// 更新规则集
    func 更新规则集(_ 配置: 规则集配置) {
        guard let 索引 = 规则集列表.firstIndex(where: { $0.id == 配置.id }) else { return }
        规则集列表[索引] = 配置
        保存到存储()
    }

    /// 恢复官方预设（如果列表为空）
    func 恢复官方预设() {
        guard 规则集列表.isEmpty else { return }
        let geoip = 规则集配置(
            tag: "geoip",
            url: "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.srs"
        )
        let geosite = 规则集配置(
            tag: "geosite",
            url: "https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.srs"
        )
        规则集列表 = [geoip, geosite]
        保存到存储()
    }

    // MARK: 下载

    /// 规则集文件本地路径（App Group 共享目录）
    private func 文件本地路径(_ 文件名: String) -> URL {
        FilePath.sharedDirectory.appendingPathComponent(文件名)
    }

    /// 下载规则集
    func 下载规则集(_ id: UUID) async {
        guard let 索引 = 规则集列表.firstIndex(where: { $0.id == id }) else { return }
        let 配置 = 规则集列表[索引]

        await MainActor.run {
            self.下载中 = true
        }

        do {
            let 远程URL = URL(string: 配置.url)!
            let (临时URL, 响应) = try await URLSession.shared.download(from: 远程URL)

            // 校验响应
            guard let http响应 = 响应 as? HTTPURLResponse,
                  http响应.statusCode == 200 else {
                await MainActor.run {
                    self.规则集列表[索引].下载状态 = .下载失败
                    self.下载中 = false
                }
                return
            }

            // 移动到共享目录
            let 目标路径 = 文件本地路径(配置.本地文件名)
            if FileManager.default.fileExists(atPath: 目标路径.path) {
                try FileManager.default.removeItem(at: 目标路径)
            }
            try FileManager.default.copyItem(at: 临时URL, to: 目标路径)

            // 更新状态
            let 文件大小 = (try? FileManager.default.attributesOfItem(atPath: 目标路径.path)[.size] as? Int64) ?? 0
            await MainActor.run {
                self.规则集列表[索引].下载状态 = .已下载
                self.规则集列表[索引].最后更新时间 = Date()
                self.规则集列表[索引].文件大小 = 文件大小
                self.下载中 = false
                self.保存到存储()
            }
        } catch {
            await MainActor.run {
                self.规则集列表[索引].下载状态 = .下载失败
                self.下载中 = false
            }
        }
    }

    // MARK: 配置生成

    /// 生成 sing-box route.rule_set JSON 数组字符串
    func 生成规则集配置块() -> String {
        guard !规则集列表.isEmpty else { return "[]" }
        var 数组: [[String: Any]] = []
        for 配置 in 规则集列表 {
            let 项: [String: Any] = [
                "tag": 配置.tag,
                "format": 配置.format,
                "url": 配置.url,
                "download_detour": 配置.download_detour,
                "update_interval": 配置.update_interval
            ]
            数组.append(项)
        }
        guard let 数据 = try? JSONSerialization.data(withJSONObject: 数组, options: [.sortedKeys]),
              let 字符串 = String(data: 数据, encoding: .utf8) else {
            return "[]"
        }
        return 字符串
    }

    /// 获取该规则集类型常见的 rule_key 提示（静态，不解析 srs 文件）
    func 获取可用ruleKeys(_ 配置: 规则集配置) -> [String] {
        switch 配置.tag.lowercased() {
        case "geoip":
            return ["geoip-cn", "geoip-private", "geoip-google", "geoip-apple", "geoip-telegram"]
        case "geosite":
            return ["geosite-cn", "geosite-google", "geosite-github", "geosite-netflix", "geosite-youtube", "geosite-telegram"]
        default:
            return []
        }
    }
}
