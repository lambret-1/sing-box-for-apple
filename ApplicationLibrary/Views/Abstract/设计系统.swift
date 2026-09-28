import SwiftUI

// MARK: - 统一设计系统
/// 全局设计令牌：颜色、字体、间距、圆角
/// 遵循 8pt 网格系统，适配深色模式与多平台

public enum 设计系统 {
    // MARK: - 颜色令牌

    /// 主题色
    public enum 颜色 {
        /// 主色调（品牌蓝）
        public static let 主色 = Color(red: 0.0, green: 0.478, blue: 1.0)
        /// 成功色
        public static let 成功 = Color.green
        /// 警告色
        public static let 警告 = Color.orange
        /// 危险色
        public static let 危险 = Color.red
        /// 信息色
        public static let 信息 = Color.blue

        /// 文字颜色
        public enum 文字 {
            /// 主要文字
            public static let 主要 = Color.primary
            /// 次要文字
            public static let 次要 = Color.secondary
            /// 三级文字
            public static let 三级 = Color.tertiary
        }

        /// 背景颜色
        public enum 背景 {
            /// 卡片背景（适配深色模式）
            public static var 卡片: Color {
                #if os(iOS)
                return Color(uiColor: .secondarySystemGroupedBackground)
                #elseif os(macOS)
                return Color(nsColor: .textBackgroundColor)
                #else
                return Color.white
                #endif
            }
            /// 页面背景
            public static var 页面: Color {
                #if os(iOS)
                return Color(uiColor: .systemGroupedBackground)
                #else
                return Color.clear
                #endif
            }
        }

        /// 协议颜色
        public enum 协议 {
            public static let TCP = Color.blue
            public static let UDP = Color.orange
            public static let DNS = Color.purple
            public static let TLS = Color.teal
        }
    }

    // MARK: - 字体令牌

    /// 字体系统
    public enum 字体 {
        /// 大标题
        public static let 大标题 = Font.system(size: 28, weight: .bold)
        /// 标题
        public static let 标题 = Font.system(size: 22, weight: .bold)
        /// 副标题
        public static let 副标题 = Font.system(size: 17, weight: .semibold)
        /// 正文
        public static let 正文 = Font.system(size: 15, weight: .regular)
        /// 次要文字
        public static let 次要 = Font.system(size: 13, weight: .regular)
        /// 说明文字
        public static let 说明 = Font.system(size: 11, weight: .regular)
        /// 标签文字
        public static let 标签 = Font.system(size: 10, weight: .medium)

        /// 等宽字体（用于数值显示）
        public enum 等宽 {
            public static let 大 = Font.system(size: 22, weight: .bold, design: .monospaced)
            public static let 中 = Font.system(size: 15, weight: .medium, design: .monospaced)
            public static let 小 = Font.system(size: 12, weight: .regular, design: .monospaced)
            public static let 极小 = Font.system(size: 10, weight: .regular, design: .monospaced)
        }
    }

    // MARK: - 间距令牌（8pt 网格）

    /// 间距系统（8pt 网格）
    public enum 间距 {
        /// 0pt
        public static let 零: CGFloat = 0
        /// 4pt（半格）
        public static let 极小: CGFloat = 4
        /// 8pt（一格）
        public static let 小: CGFloat = 8
        /// 12pt（一格半）
        public static let 中: CGFloat = 12
        /// 16pt（两格）
        public static let 大: CGFloat = 16
        /// 24pt（三格）
        public static let 超大: CGFloat = 24
        /// 32pt（四格）
        public static let 特大: CGFloat = 32
    }

    // MARK: - 圆角令牌

    /// 圆角系统
    public enum 圆角 {
        /// 4pt
        public static let 小: CGFloat = 4
        /// 8pt
        public static let 中: CGFloat = 8
        /// 12pt
        public static let 大: CGFloat = 12
        /// 16pt
        public static let 超大: CGFloat = 16
        /// 24pt（胶囊）
        public static let 胶囊: CGFloat = 24
    }

    // MARK: - 阴影令牌

    /// 阴影系统
    public enum 阴影 {
        /// 轻微阴影
        public static let 轻微 = Shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        /// 中等阴影
        public static let 中等 = Shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        /// 强调阴影
        public static let 强调 = Shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
    }

    /// 阴影结构体
    public struct Shadow {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat

        public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }
    }
}

// MARK: - View 扩展：便捷应用设计令牌

public extension View {
    /// 应用卡片样式（统一设计系统）
    func 统一卡片样式() -> some View {
        modifier(统一卡片样式修饰符())
    }

    /// 应用标签样式（彩色背景小标签）
    func 标签样式(背景色: Color, 文字色: Color = .white) -> some View {
        self
            .font(设计系统.字体.标签)
            .foregroundColor(文字色)
            .padding(.horizontal, 设计系统.间距.小)
            .padding(.vertical, 设计系统.间距.极小)
            .background(背景色)
            .cornerRadius(设计系统.圆角.小)
    }
}

/// 统一卡片样式修饰符
private struct 统一卡片样式修饰符: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(设计系统.颜色.背景.卡片)
            .cornerRadius(设计系统.圆角.超大)
            .shadow(color: 设计系统.阴影.轻微.color, radius: 设计系统.阴影.轻微.radius, x: 设计系统.阴影.轻微.x, y: 设计系统.阴影.轻微.y)
    }
}
