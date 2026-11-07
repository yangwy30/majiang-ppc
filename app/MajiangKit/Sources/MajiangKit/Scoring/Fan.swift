import CGuobiao

/// 国标番种。raw value 是算番库番表里的下标，顺序必须和 vendor/fan_calculator.h 的 fan_t 一致（测试里会核对）。
public enum Fan: Int, CaseIterable, Codable, Sendable {
    case bigFourWinds = 1
    case bigThreeDragons
    case allGreen
    case nineGates
    case fourKongs
    case sevenShiftedPairs
    case thirteenOrphans
    case allTerminals
    case littleFourWinds
    case littleThreeDragons
    case allHonors
    case fourConcealedPungs
    case pureTerminalChows
    case quadrupleChow
    case fourPureShiftedPungs
    case fourPureShiftedChows
    case threeKongs
    case allTerminalsAndHonors
    case sevenPairs
    case greaterHonorsAndKnittedTiles
    case allEvenPungs
    case fullFlush
    case pureTripleChow
    case pureShiftedPungs
    case upperTiles
    case middleTiles
    case lowerTiles
    case pureStraight
    case threeSuitedTerminalChows
    case pureShiftedChows
    case allFive
    case triplePung
    case threeConcealedPungs
    case lesserHonorsAndKnittedTiles
    case knittedStraight
    case upperFour
    case lowerFour
    case bigThreeWinds
    case mixedStraight
    case reversibleTiles
    case mixedTripleChow
    case mixedShiftedPungs
    case chickenHand
    case lastTileDraw
    case lastTileClaim
    case outWithReplacementTile
    case robbingTheKong
    case allPungs
    case halfFlush
    case mixedShiftedChows
    case allTypes
    case meldedHand
    case twoConcealedKongs
    case twoDragonsPungs
    case outsideHand
    case fullyConcealedHand
    case twoMeldedKongs
    case lastTile
    case dragonPung
    case prevalentWind
    case seatWind
    case concealedHand
    case allChows
    case tileHog
    case doublePung
    case twoConcealedPungs
    case concealedKong
    case allSimples
    case pureDoubleChow
    case mixedDoubleChow
    case shortStraight
    case twoTerminalChows
    case pungOfTerminalsOrHonors
    case meldedKong
    case oneVoidedSuit
    case noHonors
    case edgeWait
    case closedWait
    case singleWait
    case selfDrawn
    case flowerTiles
    case concealedKongAndMeldedKong

    /// 番种名。
    public var name: String {
        switch self {
        case .bigFourWinds: L("大四喜")
        case .bigThreeDragons: L("大三元")
        case .allGreen: L("绿一色")
        case .nineGates: L("九莲宝灯")
        case .fourKongs: L("四杠")
        case .sevenShiftedPairs: L("连七对")
        case .thirteenOrphans: L("十三幺")
        case .allTerminals: L("清幺九")
        case .littleFourWinds: L("小四喜")
        case .littleThreeDragons: L("小三元")
        case .allHonors: L("字一色")
        case .fourConcealedPungs: L("四暗刻")
        case .pureTerminalChows: L("一色双龙会")
        case .quadrupleChow: L("一色四同顺")
        case .fourPureShiftedPungs: L("一色四节高")
        case .fourPureShiftedChows: L("一色四步高")
        case .threeKongs: L("三杠")
        case .allTerminalsAndHonors: L("混幺九")
        case .sevenPairs: L("七对")
        case .greaterHonorsAndKnittedTiles: L("七星不靠")
        case .allEvenPungs: L("全双刻")
        case .fullFlush: L("清一色")
        case .pureTripleChow: L("一色三同顺")
        case .pureShiftedPungs: L("一色三节高")
        case .upperTiles: L("全大")
        case .middleTiles: L("全中")
        case .lowerTiles: L("全小")
        case .pureStraight: L("清龙")
        case .threeSuitedTerminalChows: L("三色双龙会")
        case .pureShiftedChows: L("一色三步高")
        case .allFive: L("全带五")
        case .triplePung: L("三同刻")
        case .threeConcealedPungs: L("三暗刻")
        case .lesserHonorsAndKnittedTiles: L("全不靠")
        case .knittedStraight: L("组合龙")
        case .upperFour: L("大于五")
        case .lowerFour: L("小于五")
        case .bigThreeWinds: L("三风刻")
        case .mixedStraight: L("花龙")
        case .reversibleTiles: L("推不倒")
        case .mixedTripleChow: L("三色三同顺")
        case .mixedShiftedPungs: L("三色三节高")
        case .chickenHand: L("无番和")
        case .lastTileDraw: L("妙手回春")
        case .lastTileClaim: L("海底捞月")
        case .outWithReplacementTile: L("杠上开花")
        case .robbingTheKong: L("抢杠和")
        case .allPungs: L("碰碰和")
        case .halfFlush: L("混一色")
        case .mixedShiftedChows: L("三色三步高")
        case .allTypes: L("五门齐")
        case .meldedHand: L("全求人")
        case .twoConcealedKongs: L("双暗杠")
        case .twoDragonsPungs: L("双箭刻")
        case .outsideHand: L("全带幺")
        case .fullyConcealedHand: L("不求人")
        case .twoMeldedKongs: L("双明杠")
        case .lastTile: L("和绝张")
        case .dragonPung: L("箭刻")
        case .prevalentWind: L("圈风刻")
        case .seatWind: L("门风刻")
        case .concealedHand: L("门前清")
        case .allChows: L("平和")
        case .tileHog: L("四归一")
        case .doublePung: L("双同刻")
        case .twoConcealedPungs: L("双暗刻")
        case .concealedKong: L("暗杠")
        case .allSimples: L("断幺")
        case .pureDoubleChow: L("一般高")
        case .mixedDoubleChow: L("喜相逢")
        case .shortStraight: L("连六")
        case .twoTerminalChows: L("老少副")
        case .pungOfTerminalsOrHonors: L("幺九刻")
        case .meldedKong: L("明杠")
        case .oneVoidedSuit: L("缺一门")
        case .noHonors: L("无字")
        case .edgeWait: L("边张")
        case .closedWait: L("嵌张")
        case .singleWait: L("单钓将")
        case .selfDrawn: L("自摸")
        case .flowerTiles: L("花牌")
        case .concealedKongAndMeldedKong: L("明暗杠")
        }
    }

    /// 一句白话说明，显示在番种明细里。
    public var explanation: String {
        switch self {
        case .bigFourWinds: L("东南西北四组刻子（或杠）")
        case .bigThreeDragons: L("中、发、白三组刻子")
        case .allGreen: L("只用 2、3、4、6、8 条和发财")
        case .nineGates: L("同一花色门清 1112345678999，再和其中任意一张")
        case .fourKongs: L("开了四组杠")
        case .sevenShiftedPairs: L("同一花色序数相连的七个对子")
        case .thirteenOrphans: L("三种数牌的 1、9 和七种字牌各一张，其中一张成对")
        case .allTerminals: L("全部是数牌 1、9 的刻子和将")
        case .littleFourWinds: L("三种风牌的刻子，第四种风牌做将")
        case .littleThreeDragons: L("两种箭牌的刻子，第三种箭牌做将")
        case .allHonors: L("全部是字牌")
        case .fourConcealedPungs: L("四组暗刻（暗杠也算）")
        case .pureTerminalChows: L("同一花色两组 123、两组 789，5 做将")
        case .quadrupleChow: L("同一花色四组相同的顺子")
        case .fourPureShiftedPungs: L("同一花色四组点数依次加 1 的刻子")
        case .fourPureShiftedChows: L("同一花色四组依次错开 1 位或 2 位的顺子")
        case .threeKongs: L("开了三组杠")
        case .allTerminalsAndHonors: L("全部是幺九牌和字牌的刻子和将")
        case .sevenPairs: L("七个对子")
        case .greaterHonorsAndKnittedTiles: L("七种字牌各一张，加上 147、258、369 三种花色里互不相靠的七张")
        case .allEvenPungs: L("全部是 2、4、6、8 的刻子和将")
        case .fullFlush: L("全部是同一种花色的数牌")
        case .pureTripleChow: L("同一花色三组相同的顺子")
        case .pureShiftedPungs: L("同一花色三组点数依次加 1 的刻子")
        case .upperTiles: L("全部是 7、8、9")
        case .middleTiles: L("全部是 4、5、6")
        case .lowerTiles: L("全部是 1、2、3")
        case .pureStraight: L("同一花色的 123、456、789")
        case .threeSuitedTerminalChows: L("两种花色各有 123 和 789，第三种花色的 5 做将")
        case .pureShiftedChows: L("同一花色三组依次错开 1 位或 2 位的顺子")
        case .allFive: L("每组面子和将都带 5")
        case .triplePung: L("三种花色同一点数的刻子")
        case .threeConcealedPungs: L("三组暗刻")
        case .lesserHonorsAndKnittedTiles: L("147、258、369 三种花色和字牌中互不相靠的 14 张")
        case .knittedStraight: L("三种花色分别取 147、258、369，拼成 1 到 9")
        case .upperFour: L("全部是 6 到 9 的数牌")
        case .lowerFour: L("全部是 1 到 4 的数牌")
        case .bigThreeWinds: L("三种风牌的刻子")
        case .mixedStraight: L("三种花色分别组成 123、456、789")
        case .reversibleTiles: L("全部是上下颠倒样子不变的牌：1234589 饼、245689 条、白")
        case .mixedTripleChow: L("三种花色同一点数的顺子")
        case .mixedShiftedPungs: L("三种花色点数依次加 1 的刻子")
        case .chickenHand: L("和了，但数不出任何番（花牌不算）")
        case .lastTileDraw: L("自摸牌墙的最后一张")
        case .lastTileClaim: L("和别人打出的最后一张牌")
        case .outWithReplacementTile: L("开杠后补上来的那张自摸和")
        case .robbingTheKong: L("和别人加杠的那张牌")
        case .allPungs: L("四组刻子（或杠）加一对将")
        case .halfFlush: L("一种花色的数牌加字牌")
        case .mixedShiftedChows: L("三种花色依次错开 1 位的顺子")
        case .allTypes: L("万、条、饼、风、箭五种都有")
        case .meldedHand: L("全靠吃碰明杠，最后单钓别人打的牌")
        case .twoConcealedKongs: L("两组暗杠")
        case .twoDragonsPungs: L("两组箭牌刻子")
        case .outsideHand: L("每组面子和将都带幺九牌或字牌")
        case .fullyConcealedHand: L("没有吃碰明杠，自摸和")
        case .twoMeldedKongs: L("两组明杠")
        case .lastTile: L("和的那张牌桌上已经亮出三张，是最后一张")
        case .dragonPung: L("中、发或白的刻子")
        case .prevalentWind: L("与圈风相同的风牌刻子")
        case .seatWind: L("与自己门风相同的风牌刻子")
        case .concealedHand: L("没有吃碰明杠，和别人打的牌")
        case .allChows: L("四组顺子，数牌做将")
        case .tileHog: L("有四张相同的牌，但没有开杠")
        case .doublePung: L("两种花色同一点数的刻子")
        case .twoConcealedPungs: L("两组暗刻")
        case .concealedKong: L("一组暗杠")
        case .allSimples: L("没有幺九牌和字牌")
        case .pureDoubleChow: L("同一花色两组相同的顺子")
        case .mixedDoubleChow: L("两种花色同一点数的顺子")
        case .shortStraight: L("同一花色六张相连的两组顺子")
        case .twoTerminalChows: L("同一花色的 123 和 789")
        case .pungOfTerminalsOrHonors: L("1、9 或不算番的风牌的刻子")
        case .meldedKong: L("一组明杠")
        case .oneVoidedSuit: L("缺少一种花色的数牌")
        case .noHonors: L("没有字牌")
        case .edgeWait: L("只能和 12 后面的 3，或 89 前面的 7")
        case .closedWait: L("只能和顺子中间那张")
        case .singleWait: L("只能和做将的那一张")
        case .selfDrawn: L("自己摸到和牌")
        case .flowerTiles: L("每张花牌 1 番，不计入 8 番起和")
        case .concealedKongAndMeldedKong: L("一组明杠加一组暗杠")
        }
    }

    /// 每次计多少番，取自算番库的番值表。
    public var points: Int { Int(gb_fan_value(Int32(rawValue))) }
}
