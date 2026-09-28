import SwiftUI

// MARK: - 卡片组件

/// 通用卡片容器
public struct 新UIAppCard<Content: View>: View {
    let 标题: String?
    @ViewBuilder let 内容: () -> Content

    public init(标题: String? = nil, @ViewBuilder 内容: @escaping () -> Content) {
        self.标题 = 标题
        self.内容 = 内容
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 新UI间距.中等) {
            if let 标题 = 标题 {
                Text(标题)
                    .font(新UIFont.副标题)
                    .foregroundColor(新UI颜色.主文字)
            }
            内容()
        }
        .padding(新UI间距.标准)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(新UI颜色.卡片背景)
        .cornerRadius(新UI圆角.中)
    }
}

// MARK: - 状态徽章

/// 状态徽章类型
public enum 新UI徽章类型 {
    case 成功
    case 错误
    case 警告
    case 信息

    var 颜色: Color {
        switch self {
        case .成功: return 新UI颜色.成功
        case .错误: return 新UI颜色.错误
        case .警告: return 新UI颜色.警告
        case .信息: return 新UI颜色.信息
        }
    }
}

/// 状态徽章
public struct 新UIStateBadge: View {
    let 文字: String
    let 类型: 新UI徽章类型
    let 带圆点: Bool

    public init(文字: String, 类型: 新UI徽章类型, 带圆点: Bool = true) {
        self.文字 = 文字
        self.类型 = 类型
        self.带圆点 = 带圆点
    }

    public var body: some View {
        HStack(spacing: 4) {
            if 带圆点 {
                Circle()
                    .fill(类型.颜色)
                    .frame(width: 6, height: 6)
            }
            Text(文字)
                .font(新UIFont.小字)
                .foregroundColor(类型.颜色)
        }
        .padding(.horizontal, 新UI间距.小)
        .padding(.vertical, 新UI间距.极小)
        .background(类型.颜色.opacity(0.15))
        .cornerRadius(新UI圆角.小)
    }
}

// MARK: - 空态视图

/// 空态视图
public struct 新UIEmptyStateView: View {
    let 图标: String
    let 标题: String
    let 说明: String?
    let 按钮文字: String?
    let 按钮动作: (() -> Void)?

    public init(图标: String, 标题: String, 说明: String? = nil, 按钮文字: String? = nil, 按钮动作: (() -> Void)? = nil) {
        self.图标 = 图标
        self.标题 = 标题
        self.说明 = 说明
        self.按钮文字 = 按钮文字
        self.按钮动作 = 按钮动作
    }

    public var body: some View {
        VStack(spacing: 新UI间距.中等) {
            Image(systemName: 图标)
                .font(.system(size: 40))
                .foregroundColor(新UI颜色.次文字)

            Text(标题)
                .font(新UIFont.副标题)
                .foregroundColor(新UI颜色.主文字)

            if let 说明 = 说明 {
                Text(说明)
                    .font(新UIFont.辅助说明)
                    .foregroundColor(新UI颜色.次文字)
                    .multilineTextAlignment(.center)
            }

            if let 按钮文字 = 按钮文字, let 按钮动作 = 按钮动作 {
                Button(action: 按钮动作) {
                    Text(按钮文字)
                        .font(新UIFont.正文)
                        .foregroundColor(.white)
                        .padding(.horizontal, 新UI间距.标准)
                        .padding(.vertical, 新UI间距.小)
                        .background(新UI颜色.信息)
                        .cornerRadius(新UI圆角.小)
                }
            }
        }
        .padding(新UI间距.大)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 详情行

/// 详情行（标签 + 值）
public struct 新UI详情行: View {
    let 标签: String
    let 值: String

    public init(标签: String, 值: String) {
        self.标签 = 标签
        self.值 = 值
    }

    public var body: some View {
        HStack {
            Text(标签)
                .font(新UIFont.正文)
                .foregroundColor(新UI颜色.次文字)
            Spacer()
            Text(值)
                .font(新UIFont.正文)
                .foregroundColor(新UI颜色.主文字)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
