//
//  状态/VLESS转换器状态.swift
//  sing-box-for-apple 新UI
//
//  VLESS 转换器页面状态管理：输入文本、批量解析、结果列表、筛选搜索、选中集、进度、
//  导出/导入/去重/转换历史/默认参数
//

import Foundation
import Combine
import UIKit
import Library

// MARK: - 筛选枚举

/// 结果筛选状态
enum VLESS筛选状态: String, CaseIterable {
    case 全部
    case 成功
    case 失败

    /// 显示文字
    var 显示文字: String {
        switch self {
        case .全部: return "全部"
        case .成功: return "成功"
        case .失败: return "失败"
        }
    }
}

// MARK: - 转换节点项

/// 单条转换结果项
struct 转换节点项: Identifiable, Equatable {
    /// 唯一标识
    var id: UUID
    /// 原始行号（从 1 开始）
    var 行号: Int
    /// 原始文本
    var 原始文本: String
    /// 解析结果
    var 解析结果: 解析结果
    /// 节点配置（成功时才有）
    var 节点配置: 节点配置?
    /// 生成的 sing-box JSON（成功时才有）
    var 生成JSON: String?
    /// 是否选中
    var 选中: Bool
}

// MARK: - 转换历史记录

/// 转换历史记录（Codable，持久化到 UserDefaults）
struct 转换历史记录: Codable, Identifiable {
    var id: UUID
    var 时间: Date
    var 输入行数: Int
    var 成功数: Int
    var 失败数: Int
}

// MARK: - 转换器状态

/// VLESS 转换器页面状态
final class VLESS转换器状态: ObservableObject {

    // MARK: 输入与结果

    /// 用户粘贴的多行 VLESS URL
    @Published var 输入文本: String = ""

    /// 转换后的节点项列表
    @Published var 解析结果列表: [转换节点项] = []

    /// 筛选状态
    @Published var 筛选状态: VLESS筛选状态 = .全部

    /// 搜索文本
    @Published var 搜索文本: String = ""

    /// 选中集合（存节点 id）
    @Published var 选中集合: Set<UUID> = []

    /// 是否正在转换
    @Published var 转换中: Bool = false

    /// 转换进度 0.0~1.0
    @Published var 转换进度: Double = 0.0

    /// 当前展开详情的节点 id（nil 表示无展开）
    @Published var 显示详情: UUID?

    // MARK: 二期：历史与默认参数

    /// 转换历史列表（最近 10 条）
    @Published var 转换历史列表: [转换历史记录] = []

    /// 默认 uTLS 指纹
    @Published var 默认uTLS指纹: String {
        didSet { UserDefaults.standard.set(默认uTLS指纹, forKey: "vless转换器.默认指纹") }
    }

    /// 默认 TLS 不安全
    @Published var 默认TLS不安全: Bool {
        didSet { UserDefaults.standard.set(默认TLS不安全, forKey: "vless转换器.默认不安全") }
    }

    /// 默认 packet_encoding
    @Published var 默认packet编码: String {
        didSet { UserDefaults.standard.set(默认packet编码, forKey: "vless转换器.默认packet编码") }
    }

    /// 是否在导出时包含规则集
    @Published var 包含规则集: Bool = true

    // MARK: 初始化

    init() {
        // 加载默认参数
        默认uTLS指纹 = UserDefaults.standard.string(forKey: "vless转换器.默认指纹") ?? "chrome"
        默认TLS不安全 = UserDefaults.standard.bool(forKey: "vless转换器.默认不安全")
        默认packet编码 = UserDefaults.standard.string(forKey: "vless转换器.默认packet编码") ?? ""
        // 加载历史
        if let 数据 = UserDefaults.standard.data(forKey: "vless转换器.转换历史"),
           let 列表 = try? JSONDecoder().decode([转换历史记录].self, from: 数据) {
            转换历史列表 = 列表
        }
    }

    // MARK: 计算属性

    /// 已输入非空行数
    var 已输入行数: Int {
        let 行数组 = 输入文本.components(separatedBy: .newlines)
        return 行数组.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    /// 成功节点数
    var 成功数: Int {
        解析结果列表.filter {
            if case .成功 = $0.解析结果 { return true }
            return false
        }.count
    }

    /// 失败节点数
    var 失败数: Int {
        解析结果列表.filter {
            if case .失败 = $0.解析结果 { return true }
            return false
        }.count
    }

    /// 筛选 + 搜索后的列表
    var 筛选后的列表: [转换节点项] {
        解析结果列表.filter { 项 in
            switch 筛选状态 {
            case .全部: break
            case .成功:
                guard case .成功 = 项.解析结果 else { return false }
            case .失败:
                guard case .失败 = 项.解析结果 else { return false }
            }
            if !搜索文本.isEmpty {
                let 名称 = 项.节点配置?.名称 ?? ""
                let 服务器 = 项.节点配置?.服务器 ?? ""
                if !名称.localizedCaseInsensitiveContains(搜索文本),
                   !服务器.localizedCaseInsensitiveContains(搜索文本) {
                    return false
                }
            }
            return true
        }
    }

    /// 去重后的成功节点列表（按 server:port:uuid 三元组去重）
    var 去重后的节点列表: [转换节点项] {
        var 已见 = Set<String>()
        return 解析结果列表.filter { 项 in
            guard let c = 项.节点配置 else { return false }
            let 键 = "\(c.服务器):\(c.端口):\(c.uuid)"
            if 已见.contains(键) { return false }
            已见.insert(键)
            return true
        }
    }

    // MARK: 核心方法

    /// 执行转换：批量解析输入文本，生成节点项列表
    func 执行转换() {
        guard !转换中 else { return }
        转换中 = true
        转换进度 = 0.0
        选中集合.removeAll()
        显示详情 = nil

        let 输入 = 输入文本
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let 批量结果 = VLESS解析器.批量解析(输入)

            var 项列表: [转换节点项] = []
            let 总数 = max(批量结果.count, 1)

            for (索引, 单条) in 批量结果.enumerated() {
                var 配置: 节点配置?
                var json: String?
                if case .成功(var c) = 单条.解析结果 {
                    // 应用默认参数
                    if c.指纹.isEmpty { c.指纹 = self.默认uTLS指纹 }
                    if c.packet编码.isEmpty { c.packet编码 = self.默认packet编码 }
                    配置 = c
                    json = 节点配置生成器.生成出站JSON(c)
                }
                let 项 = 转换节点项(
                    id: UUID(),
                    行号: 单条.行号,
                    原始文本: 单条.原始文本,
                    解析结果: 单条.解析结果,
                    节点配置: 配置,
                    生成JSON: json,
                    选中: false
                )
                项列表.append(项)

                let 进度 = Double(索引 + 1) / Double(总数)
                DispatchQueue.main.async {
                    self.转换进度 = 进度
                }
                Thread.sleep(forTimeInterval: 0.01)
            }

            DispatchQueue.main.async {
                self.解析结果列表 = 项列表
                self.转换中 = false
                self.转换进度 = 1.0
                // 记录历史
                self.记录历史(输入行数: 批量结果.count, 成功数: 项列表.filter { $0.节点配置 != nil }.count, 失败数: 项列表.filter { $0.节点配置 == nil }.count)
            }
        }
    }

    /// 记录一条转换历史（最多保留 10 条）
    private func 记录历史(输入行数: Int, 成功数: Int, 失败数: Int) {
        let 记录 = 转换历史记录(id: UUID(), 时间: Date(), 输入行数: 输入行数, 成功数: 成功数, 失败数: 失败数)
        转换历史列表.insert(记录, at: 0)
        if 转换历史列表.count > 10 {
            转换历史列表 = Array(转换历史列表.prefix(10))
        }
        // 持久化
        if let 数据 = try? JSONEncoder().encode(转换历史列表) {
            UserDefaults.standard.set(数据, forKey: "vless转换器.转换历史")
        }
    }

    /// 清空结果列表和选中
    func 清空结果() {
        解析结果列表.removeAll()
        选中集合.removeAll()
        显示详情 = nil
        转换进度 = 0.0
    }

    /// 清空输入文本
    func 清空输入() {
        输入文本 = ""
    }

    /// 从剪贴板粘贴追加到输入文本
    func 从剪贴板粘贴() {
        guard let 剪贴板文本 = UIPasteboard.general.string, !剪贴板文本.isEmpty else {
            return
        }
        if 输入文本.isEmpty {
            输入文本 = 剪贴板文本
        } else {
            输入文本 += "\n" + 剪贴板文本
        }
    }

    /// 删除指定节点
    func 删除节点(_ id: UUID) {
        解析结果列表.removeAll { $0.id == id }
        选中集合.remove(id)
        if 显示详情 == id { 显示详情 = nil }
    }

    /// 删除所有解析失败的节点
    func 删除失败节点() {
        解析结果列表.removeAll { 项 in
            if case .失败 = 项.解析结果 { return true }
            return false
        }
    }

    /// 全选当前筛选后的成功节点
    func 全选() {
        for 项 in 筛选后的列表 where 项.节点配置 != nil {
            选中集合.insert(项.id)
        }
    }

    /// 反选当前筛选后的成功节点
    func 反选() {
        for 项 in 筛选后的列表 where 项.节点配置 != nil {
            if 选中集合.contains(项.id) {
                选中集合.remove(项.id)
            } else {
                选中集合.insert(项.id)
            }
        }
    }

    /// 取消全选
    func 取消全选() {
        选中集合.removeAll()
    }

    /// 更新节点配置并重新生成 JSON
    func 更新节点配置(_ id: UUID, 新配置: 节点配置) {
        guard let 索引 = 解析结果列表.firstIndex(where: { $0.id == id }) else { return }
        let 新JSON = 节点配置生成器.生成出站JSON(新配置)
        解析结果列表[索引].节点配置 = 新配置
        解析结果列表[索引].生成JSON = 新JSON
        解析结果列表[索引].解析结果 = .成功(新配置)
    }

    // MARK: 导出

    /// 生成导出 JSON（仅选中 / 全部）
    ///
    /// 输出格式：{ "outbounds": [...] }
    /// 自动重新分配 tag：vless-out-1, vless-out-2...
    func 生成导出JSON(仅选中: Bool) -> String {
        // 收集目标节点
        let 目标: [转换节点项]
        if 仅选中 {
            目标 = 解析结果列表.filter { 选中集合.contains($0.id) && $0.生成JSON != nil }
        } else {
            目标 = 解析结果列表.filter { $0.生成JSON != nil }
        }

        // 解析每个 JSON 为字典，重新分配 tag
        var outbounds: [[String: Any]] = []
        for (索引, 项) in 目标.enumerated() {
            guard let json串 = 项.生成JSON,
                  let 数据 = json串.data(using: .utf8),
                  var dict = try? JSONSerialization.jsonObject(with: 数据) as? [String: Any] else {
                continue
            }
            dict["tag"] = "vless-out-\(索引 + 1)"
            outbounds.append(dict)
        }

        let 根: [String: Any] = ["outbounds": outbounds]
        guard let 数据 = try? JSONSerialization.data(withJSONObject: 根, options: [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]),
              let 字符串 = String(data: 数据, encoding: .utf8) else {
            return "{}"
        }
        return 字符串
    }

    /// 复制 JSON 到剪贴板
    func 复制到剪贴板(_ json: String) {
        UIPasteboard.general.string = json
    }

    // MARK: 导入节点库

    /// 导入到官方 Profile 数据库
    ///
    /// - Returns: (新增数, 跳过数)
    func 导入节点库() async -> (新增: Int, 跳过: Int) {
        let 去重列表 = 去重后的节点列表
        let 跳过数 = 解析结果列表.filter { $0.节点配置 != nil }.count - 去重列表.count

        guard !去重列表.isEmpty else { return (0, 0) }

        // 构造 outbounds 数组，重新分配 tag
        var outbounds: [[String: Any]] = []
        for (索引, 项) in 去重列表.enumerated() {
            guard let json串 = 项.生成JSON,
                  let 数据 = json串.data(using: .utf8),
                  var dict = try? JSONSerialization.jsonObject(with: 数据) as? [String: Any] else {
                continue
            }
            dict["tag"] = "vless-out-\(索引 + 1)"
            outbounds.append(dict)
        }

        // 构造完整配置
        let 首标签 = "vless-out-1"
        let 配置字典: [String: Any] = [
            "log": ["level": "warn", "timestamp": true],
            "outbounds": outbounds,
            "route": ["rules": [], "final": 首标签]
        ]

        guard let 配置数据 = try? JSONSerialization.data(withJSONObject: 配置字典, options: []),
              let 配置JSON = String(data: 配置数据, encoding: .utf8) else {
            return (0, 跳过数)
        }

        // 创建 Profile
        let 时间戳 = Int(Date().timeIntervalSince1970)
        let 文件名 = "vless-import-\(时间戳).json"
        let 日期格式化 = DateFormatter()
        日期格式化.dateFormat = "yyyyMMdd-HHmm"
        let 名称 = "VLESS导入-\(日期格式化.string(from: Date()))"

        let profile = Profile(name: 名称, type: .local, path: 文件名)

        do {
            try await ProfileManager.create(profile)
            try await profile.writeAsync(配置JSON)
            return (1, 跳过数)
        } catch {
            return (0, 跳过数)
        }
    }

    // MARK: 文件导入

    /// 从 .txt 文件导入（VLESS 链接列表）
    func 导入文本文件(_ 内容: String) {
        let 批量结果 = VLESS解析器.批量解析(内容)
        for 单条 in 批量结果 {
            var 配置: 节点配置?
            var json: String?
            if case .成功(var c) = 单条.解析结果 {
                if c.指纹.isEmpty { c.指纹 = 默认uTLS指纹 }
                配置 = c
                json = 节点配置生成器.生成出站JSON(c)
            }
            let 项 = 转换节点项(
                id: UUID(),
                行号: 单条.行号,
                原始文本: 单条.原始文本,
                解析结果: 单条.解析结果,
                节点配置: 配置,
                生成JSON: json,
                选中: false
            )
            解析结果列表.append(项)
        }
    }

    /// 从 .json 文件导入（sing-box 配置，提取 vless outbounds）
    func 导入JSON文件(_ 内容: String) -> Int {
        guard let 数据 = 内容.data(using: .utf8),
              let 根 = try? JSONSerialization.jsonObject(with: 数据) as? [String: Any],
              let outbounds = 根["outbounds"] as? [[String: Any]] else {
            return 0
        }

        var 导入数 = 0
        for outbound in outbounds {
            // 只处理 vless 类型
            guard let type = outbound["type"] as? String, type == "vless" else { continue }
            guard let server = outbound["server"] as? String,
                  let port = outbound["server_port"] as? Int,
                  let uuid = outbound["uuid"] as? String else { continue }

            // 构造节点配置（能构造多少算多少）
            var c = 节点配置(
                名称: (outbound["tag"] as? String) ?? "\(server):\(port)",
                服务器: server,
                端口: port,
                uuid: uuid,
                传输类型: .tcp,
                安全类型: .none,
                flow: outbound["flow"] as? String ?? "",
                路径: "",
                Host: "",
                sni: "",
                指纹: "",
                headerType: "none",
                reality公钥: "",
                reality短id: "",
                grpc服务名: "",
                grpc多模式: false,
                packet编码: outbound["packet_encoding"] as? String ?? "",
                tcp快速打开: false,
                tcp多路径: false,
                拨号代理: outbound["dialer_proxy"] as? String ?? "",
                http方法: "",
                原始参数字典: [:]
            )

            // 解析 network
            if let network = outbound["network"] as? String {
                c.传输类型 = 传输类型.解析(network)
            }
            // 解析 tls
            if let tls = outbound["tls"] as? [String: Any],
               let enabled = tls["enabled"] as? Bool, enabled {
                c.安全类型 = .tls
                c.sni = tls["server_name"] as? String ?? ""
                if let reality = tls["reality"] as? [String: Any],
                   let rEnabled = reality["enabled"] as? Bool, rEnabled {
                    c.安全类型 = .reality
                    c.reality公钥 = reality["public_key"] as? String ?? ""
                    c.reality短id = reality["short_id"] as? String ?? ""
                }
                if let utls = tls["utls"] as? [String: Any],
                   let fp = utls["fingerprint"] as? String {
                    c.指纹 = fp
                }
            }
            // 解析 transport
            if let transport = outbound["transport"] as? [String: Any],
               let ttype = transport["type"] as? String {
                switch ttype {
                case "ws":
                    c.路径 = transport["path"] as? String ?? ""
                    if let headers = transport["headers"] as? [String: Any],
                       let host = headers["Host"] as? String {
                        c.Host = host
                    }
                case "http":
                    c.路径 = transport["path"] as? String ?? ""
                    c.http方法 = transport["method"] as? String ?? ""
                    if let hosts = transport["host"] as? [String], let first = hosts.first {
                        c.Host = first
                    }
                case "grpc":
                    c.grpc服务名 = transport["service_name"] as? String ?? ""
                    c.grpc多模式 = transport["multi_mode"] as? Bool ?? false
                case "httpupgrade", "splithttp":
                    c.Host = transport["host"] as? String ?? ""
                    c.路径 = transport["path"] as? String ?? ""
                case "tcp":
                    if let header = transport["header"] as? [String: Any],
                       let htype = header["type"] as? String {
                        c.headerType = htype
                    }
                default:
                    break
                }
            }

            let json = 节点配置生成器.生成出站JSON(c)
            let 项 = 转换节点项(
                id: UUID(),
                行号: 0,
                原始文本: "（从JSON导入）",
                解析结果: .成功(c),
                节点配置: c,
                生成JSON: json,
                选中: false
            )
            解析结果列表.append(项)
            导入数 += 1
        }
        return 导入数
    }
}
