import SwiftUI

// MARK: - 底部工具栏标签类型

/// 底部工具栏标签类型
public enum 新UI底部标签: String, CaseIterable, Identifiable {
    case 节点 = "节点"
    case 策略组 = "策略组"
    case 网络活动 = "网络活动"
    case 规则与日志 = "规则与日志"

    public var id: String { rawValue }

    /// 图标名称
    public var 图标: String {
        switch self {
        case .节点: return "server.rack"
        case .策略组: return "circle.grid.2x2.fill"
        case .网络活动: return "antenna.radiowaves.left.and.right"
        case .规则与日志: return "doc.text.magnifyingglass"
        }
    }
}

// MARK: - 底部工具栏

/// 底部固定工具栏
public struct 新UI底部工具栏: View {
    @Binding var 当前标签: 新UI底部标签

    public init(当前标签: Binding<新UI底部标签>) {
        self._当前标签 = 当前标签
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(新UI底部标签.allCases) { 标签 in
                Button {
                    当前标签 = 标签
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: 标签.图标)
                            .font(.system(size: 18))
                        Text(标签.rawValue)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(当前标签 == 标签 ? 新UI颜色.信息 : 新UI颜色.次文字)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 新UI间距.小)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(新UI颜色.卡片背景)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(新UI颜色.次文字.opacity(0.2)),
            alignment: .top
        )
    }
}

// MARK: - 顶部功能卡片栏

/// 顶部功能卡片类型
public enum 新UI顶部卡片: String, CaseIterable, Identifiable {
    case CPU = "CPU"
    case 内存 = "内存"
    case 扩展内存 = "扩展"
    case TCP = "TCP"
    case 调试日志 = "日志"

    public var id: String { rawValue }

    /// 图标名称
    public var 图标: String {
        switch self {
        case .CPU: return "cpu"
        case .内存: return "memorychip"
        case .扩展内存: return "externaldrive"
        case .TCP: return "network"
        case .调试日志: return "ladybug"
        }
    }
}

/// 顶部横向功能卡片栏
public struct 新UI顶部功能卡片栏: View {
    @Binding var 当前卡片: 新UI顶部卡片
    /// CPU使用率（0-100）
    let CPU使用率: Double
    /// 内存占用（字节）
    let 内存占用: UInt64
    /// 扩展内存占用（字节）
    let 扩展内存: UInt64
    /// TCP连接数
    let TCP连接数: Int

    public init(当前卡片: Binding<新UI顶部卡片>, CPU使用率: Double = 0, 内存占用: UInt64 = 0, 扩展内存: UInt64 = 0, TCP连接数: Int = 0) {
        self._当前卡片 = 当前卡片
        self.CPU使用率 = CPU使用率
        self.内存占用 = 内存占用
        self.扩展内存 = 扩展内存
        self.TCP连接数 = TCP连接数
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 新UI间距.小) {
                ForEach(新UI顶部卡片.allCases) { 卡片 in
                    Button {
                        当前卡片 = 卡片
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: 卡片.图标)
                                    .font(.system(size: 10))
                                Text(卡片.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(当前卡片 == 卡片 ? .white : 新UI颜色.次文字)

                            Text(卡片数值(卡片))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(当前卡片 == 卡片 ? .white : 新UI颜色.主文字)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(width: 72, alignment: .leading)
                        .padding(.horizontal, 新UI间距.小)
                        .padding(.vertical, 新UI间距.小)
                        .background(当前卡片 == 卡片 ? 新UI颜色.信息 : 新UI颜色.卡片背景)
                        .cornerRadius(新UI圆角.小)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 新UI间距.标准)
            .padding(.vertical, 新UI间距.小)
        }
    }

    private func 卡片数值(_ 卡片: 新UI顶部卡片) -> String {
        switch 卡片 {
        case .CPU: return String(format: "%.0f%%", CPU使用率)
        case .内存: return 新UI格式化字节(Int64(内存占用))
        case .扩展内存: return 新UI格式化字节(Int64(扩展内存))
        case .TCP: return "\(TCP连接数)"
        case .调试日志: return "查看"
        }
    }
}
