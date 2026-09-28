import SwiftUI

/// CPU 占用可视化卡片（带进度条+等级标签）
public struct CPUUsageCard: View {
    @StateObject private var 监控器 = CPU占用监控器.共享

    public init() {}

    public var body: some View {
        DashboardCardView(title: "") {
            VStack(alignment: .leading, spacing: 8) {
                // 标题行
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 14))
                        .foregroundColor(监控器.等级.颜色)
                    Text("CPU")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(监控器.等级.文字)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(监控器.等级.颜色)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(监控器.等级.颜色.opacity(0.15))
                        .cornerRadius(4)
                }

                // 数值
                Text(String(format: "%.1f%%", 监控器.当前使用率))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 进度条
                GeometryReader { 几何 in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(监控器.等级.颜色)
                            .frame(width: 几何.size.width * CGFloat(min(监控器.当前使用率 / 100, 1.0)), height: 6)
                    }
                }
                .frame(height: 6)

                // 底部说明
                Text("App Process")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .onAppear {
            监控器.开始监控(间隔: 2.0)
        }
        .onDisappear {
            监控器.停止监控()
        }
    }
}
