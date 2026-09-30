//
//  状态/VLESS转换器状态.swift
//  sing-box-for-apple 新UI
//
//  VLESS 转换器页面状态管理：输入文本、批量解析、结果列表、筛选搜索、选中集、进度
//

import Foundation
import Combine
import UIKit

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
            // 筛选状态
            switch 筛选状态 {
            case .全部: break
            case .成功:
                guard case .成功 = 项.解析结果 else { return false }
            case .失败:
                guard case .失败 = 项.解析结果 else { return false }
            }
            // 搜索：按节点名称或服务器过滤
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

    // MARK: 核心方法

    /// 执行转换：批量解析输入文本，生成节点项列表
    func 执行转换() {
        guard !转换中 else { return }
        转换中 = true
        转换进度 = 0.0
        选中集合.removeAll()
        显示详情 = nil

        // 先在后台批量解析
        let 输入 = 输入文本
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let 批量结果 = VLESS解析器.批量解析(输入)

            // 构造节点项，逐条生成 JSON（模拟分批进度）
            var 项列表: [转换节点项] = []
            let 总数 = max(批量结果.count, 1)

            for (索引, 单条) in 批量结果.enumerated() {
                var 配置: 节点配置?
                var json: String?
                if case .成功(let c) = 单条.解析结果 {
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

                // 更新进度（分批）
                let 进度 = Double(索引 + 1) / Double(总数)
                DispatchQueue.main.async {
                    self.转换进度 = 进度
                }
                // 小延时模拟分批，避免一次性刷新
                Thread.sleep(forTimeInterval: 0.01)
            }

            DispatchQueue.main.async {
                self.解析结果列表 = 项列表
                self.转换中 = false
                self.转换进度 = 1.0
            }
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
}
