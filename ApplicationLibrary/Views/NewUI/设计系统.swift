import SwiftUI

// MARK: - 设计系统：颜色、字体、间距

/// 颜色令牌
public enum 新UI颜色 {
    /// 页面背景
    public static var 页面背景: Color {
        #if os(iOS)
        return Color(uiColor: .systemGroupedBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
    /// 卡片背景
    public static var 卡片背景: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
    /// 主文字
    public static let 主文字 = Color.primary
    /// 次文字
    public static let 次文字 = Color.secondary
    /// 成功色
    public static let 成功 = Color.green
    /// 警告色
    public static let 警告 = Color.orange
    /// 错误色
    public static let 错误 = Color.red
    /// 信息色
    public static let 信息 = Color.blue
    /// VPN运行中颜色
    public static let 运行中 = Color.green
    /// VPN已停止颜色
    public static let 已停止 = Color.gray
}

/// 字体层级
public enum 新UIFont {
    /// 大标题（28pt bold）
    public static let 大标题 = Font.system(size: 28, weight: .bold)
    /// 标题（22pt bold）
    public static let 标题 = Font.system(size: 22, weight: .bold)
    /// 副标题（17pt semibold）
    public static let 副标题 = Font.system(size: 17, weight: .semibold)
    /// 正文（15pt regular）
    public static let 正文 = Font.system(size: 15, weight: .regular)
    /// 辅助说明（13pt regular）
    public static let 辅助说明 = Font.system(size: 13, weight: .regular)
    /// 小字（11pt regular）
    public static let 小字 = Font.system(size: 11, weight: .regular)
    /// 数据指标（22pt bold monospaced）
    public static let 数据指标 = Font.system(size: 22, weight: .bold, design: .monospaced)
}

/// 间距常量
public enum 新UI间距 {
    public static let 极小: CGFloat = 4
    public static let 小: CGFloat = 8
    public static let 中等: CGFloat = 12
    public static let 标准: CGFloat = 16
    public static let 大: CGFloat = 24
    public static let 超大: CGFloat = 32
}

/// 圆角常量
public enum 新UI圆角 {
    public static let 小: CGFloat = 8
    public static let 中: CGFloat = 12
    public static let 大: CGFloat = 16
}

// MARK: - Color 扩展

public extension Color {
    /// 页面背景色
    static let 页面背景 = 新UI颜色.页面背景
    /// 卡片背景色
    static let 卡片背景 = 新UI颜色.卡片背景
}

// MARK: - 工具函数

/// 格式化字节数
public func 新UI格式化字节(_ 字节: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: 字节, countStyle: .binary)
}

/// 格式化时长（秒 -> HH:MM:SS）
public func 新UI格式化时长(_ 秒: Int) -> String {
    let 小时 = 秒 / 3600
    let 分钟 = (秒 % 3600) / 60
    let 剩余秒 = 秒 % 60
    return String(format: "%02d:%02d:%02d", 小时, 分钟, 剩余秒)
}
