import SwiftUI

/// 右上角「更多」点开后从底下升起的一页：纸白底，一项一行，名字下面一句灰字说明，右边一个 ›。
/// 首页和牌桌都用它，不用系统的毛玻璃菜单。跟账本、家规一样是细线列表。
/// 点了一项先把这页收下去，等收完再打开那一项（两层弹出不叠在一起），所以这里只回传点了哪一项。
struct MoreSheet<Target: Hashable>: View {
    struct Item {
        var target: Target
        var title: String
        var detail: String
    }

    var items: [Item]
    var pick: (Target) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("更多")
                .font(.system(size: 20, weight: .semibold))
                .padding(.top, 28)
                .padding(.bottom, 8)
            ForEach(Array(items.enumerated()), id: \.element.target) { index, item in
                Button { pick(item.target) } label: {
                    // 最后一行底下不画线，免得线下面空一截
                    MenuRow(title: item.title, detail: item.detail, divider: index < items.count - 1) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.faint)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: Theme.columnWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(Theme.ink)
        // 标题一截加每行 72，再留一点底
        .presentationDetents([.height(74 + 74 * CGFloat(items.count))])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.paper)
    }
}

/// 细线列表的一行：名字，下面一句灰字，右边放开关或 ›。「更多」和「备份与换手机」用。
struct MenuRow<Trailing: View>: View {
    var title: String
    var detail: String?
    var divider = true
    /// 「更多」页高度是按一行一句算的，说明只占一行；备份页的说明可以折行。
    var detailLines: Int? = 1
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 17))
                    if let detail {
                        Text(detail)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.gray)
                            .lineLimit(detailLines)
                            .minimumScaleFactor(detailLines == 1 ? 0.85 : 1)
                            .fixedSize(horizontal: false, vertical: detailLines != 1)
                    }
                }
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.vertical, 12)
            .frame(minHeight: 72)
            if divider { Hairline() }
        }
        .contentShape(Rectangle())
    }
}
