import SwiftUI

public struct DashboardCardView<Content: View>: View {
    private let title: String
    @ViewBuilder private let content: () -> Content

    public init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: title.isEmpty ? 0 : 设计系统.间距.小) {
            if !title.isEmpty {
                Text(title)
                    .font(设计系统.字体.副标题)
                    .foregroundStyle(设计系统.颜色.文字.主要)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(tvOS)
            .padding(EdgeInsets(top: 20, leading: 26, bottom: 20, trailing: 26))
        #else
            .padding(设计系统.间距.大)
        #endif
            .cardStyle()
    }
}
