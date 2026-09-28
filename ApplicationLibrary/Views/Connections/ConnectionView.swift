import Libbox
import Library
import SwiftUI

@MainActor
public struct ConnectionView: View {
    private let connection: Connection
    public init(_ connection: Connection) {
        self.connection = connection
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private func format(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    public func formatInterval(_ createdAt: Date, _ closedAt: Date) -> String {
        LibboxFormatDuration(Int64((closedAt.timeIntervalSince1970 - createdAt.timeIntervalSince1970) * 1000))
    }

    @State private var alert: AlertState?
    @State private var showDetails = false

    /// 协议标签颜色
    private var 协议颜色: Color {
        switch connection.network.lowercased() {
        case "tcp": return .blue
        case "udp": return .orange
        default: return .gray
        }
    }

    /// 状态颜色
    private var 状态颜色: Color {
        connection.closedAt == nil ? .green : .gray
    }

    /// 状态文字
    private var 状态文字: String {
        connection.closedAt == nil ? "Active" : "Closed"
    }

    public var body: some View {
        Button {
            showDetails = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // 第一行：目标地址 + 协议标签 + 状态
                HStack(alignment: .center, spacing: 6) {
                    // 协议标签
                    Text(connection.network.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(协议颜色)
                        .cornerRadius(3)

                    // 目标地址
                    Text(connection.displayDestination)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    // 状态点 + 文字
                    HStack(spacing: 3) {
                        Circle()
                            .fill(状态颜色)
                            .frame(width: 6, height: 6)
                        Text(状态文字)
                            .font(.system(size: 10))
                            .foregroundColor(状态颜色)
                    }
                }

                // 第二行：域名（如果有）
                if !connection.domain.isEmpty && connection.domain != connection.displayDestination {
                    Text(connection.domain)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // 第三行：入站 → 出站 链路
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text("\(connection.inboundType)/\(connection.inbound)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundColor(.tertiary)

                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(connection.chain.first ?? connection.outbound)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()
                }

                // 第四行：流量 + 时间
                HStack(alignment: .center, spacing: 8) {
                    if connection.closedAt == nil {
                        // 活跃连接：实时速率
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                            Text("\(LibboxFormatBytes(connection.upload))/s")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                            Text("\(LibboxFormatBytes(connection.download))/s")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // 已关闭连接：总流量
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                            Text(LibboxFormatBytes(connection.uploadTotal))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                            Text(LibboxFormatBytes(connection.downloadTotal))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // 时间
                    if let closedAt = connection.closedAt {
                        Text(formatInterval(connection.createdAt, closedAt))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.tertiary)
                    } else {
                        Text(format(connection.createdAt))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.tertiary)
                    }
                }
            }
            .foregroundColor(.textColor)
            #if !os(tvOS)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            #endif
        }
        #if !os(tvOS)
        .buttonStyle(.plain)
        .cardStyle()
        #endif
        .alert($alert)
        .contextMenu {
            if connection.closedAt == nil {
                Button("Close", role: .destructive) {
                    Task {
                        await closeConnection()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background {
            NavigationLink(isActive: $showDetails) {
                ConnectionDetailsView(connection)
                #if os(tvOS)
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarLeading) {
                            BackButton()
                        }
                    }
                #endif
            } label: {
                EmptyView()
            }
            .opacity(0)
        }
    }

    private nonisolated func closeConnection() async {
        do {
            try await CommandTarget.standaloneClient().closeConnection(connection.id)
        } catch {
            await MainActor.run {
                alert = AlertState(action: "close connection", error: error)
            }
        }
    }
}
