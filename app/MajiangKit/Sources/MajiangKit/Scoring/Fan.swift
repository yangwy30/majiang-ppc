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
        case .bigFourWinds: "大四喜"
        case .bigThreeDragons: "大三元"
        case .allGreen: "绿一色"
        case .nineGates: "九莲宝灯"
        case .fourKongs: "四杠"
        case .sevenShiftedPairs: "连七对"
        case .thirteenOrphans: "十三幺"
        case .allTerminals: "清幺九"
        case .littleFourWinds: "小四喜"
        case .littleThreeDragons: "小三元"
        case .allHonors: "字一色"
        case .fourConcealedPungs: "四暗刻"
        case .pureTerminalChows: "一色双龙会"
        case .quadrupleChow: "一色四同顺"
        case .fourPureShiftedPungs: "一色四节高"
        case .fourPureShiftedChows: "一色四步高"
        case .threeKongs: "三杠"
        case .allTerminalsAndHonors: "混幺九"
        case .sevenPairs: "七对"
        case .greaterHonorsAndKnittedTiles: "七星不靠"
        case .allEvenPungs: "全双刻"
        case .fullFlush: "清一色"
        case .pureTripleChow: "一色三同顺"
        case .pureShiftedPungs: "一色三节高"
        case .upperTiles: "全大"
        case .middleTiles: "全中"
        case .lowerTiles: "全小"
        case .pureStraight: "清龙"
        case .threeSuitedTerminalChows: "三色双龙会"
        case .pureShiftedChows: "一色三步高"
        case .allFive: "全带五"
        case .triplePung: "三同刻"
        case .threeConcealedPungs: "三暗刻"
        case .lesserHonorsAndKnittedTiles: "全不靠"
        case .knittedStraight: "组合龙"
        case .upperFour: "大于五"
        case .lowerFour: "小于五"
        case .bigThreeWinds: "三风刻"
        case .mixedStraight: "花龙"
        case .reversibleTiles: "推不倒"
        case .mixedTripleChow: "三色三同顺"
        case .mixedShiftedPungs: "三色三节高"
        case .chickenHand: "无番和"
        case .lastTileDraw: "妙手回春"
        case .lastTileClaim: "海底捞月"
        case .outWithReplacementTile: "杠上开花"
        case .robbingTheKong: "抢杠和"
        case .allPungs: "碰碰和"
        case .halfFlush: "混一色"
        case .mixedShiftedChows: "三色三步高"
        case .allTypes: "五门齐"
        case .meldedHand: "全求人"
        case .twoConcealedKongs: "双暗杠"
        case .twoDragonsPungs: "双箭刻"
        case .outsideHand: "全带幺"
        case .fullyConcealedHand: "不求人"
        case .twoMeldedKongs: "双明杠"
        case .lastTile: "和绝张"
        case .dragonPung: "箭刻"
        case .prevalentWind: "圈风刻"
        case .seatWind: "门风刻"
        case .concealedHand: "门前清"
        case .allChows: "平和"
        case .tileHog: "四归一"
        case .doublePung: "双同刻"
        case .twoConcealedPungs: "双暗刻"
        case .concealedKong: "暗杠"
        case .allSimples: "断幺"
        case .pureDoubleChow: "一般高"
        case .mixedDoubleChow: "喜相逢"
        case .shortStraight: "连六"
        case .twoTerminalChows: "老少副"
        case .pungOfTerminalsOrHonors: "幺九刻"
        case .meldedKong: "明杠"
        case .oneVoidedSuit: "缺一门"
        case .noHonors: "无字"
        case .edgeWait: "边张"
        case .closedWait: "嵌张"
        case .singleWait: "单钓将"
        case .selfDrawn: "自摸"
        case .flowerTiles: "花牌"
        case .concealedKongAndMeldedKong: "明暗杠"
        }
    }

    /// 一句白话说明，显示在番种明细里。
    public var explanation: String {
        switch self {
        case .bigFourWinds: "东南西北四组刻子（或杠）"
        case .bigThreeDragons: "中、发、白三组刻子"
        case .allGreen: "只用 2、3、4、6、8 条和发财"
        case .nineGates: "同一花色门清 1112345678999，再和其中任意一张"
        case .fourKongs: "开了四组杠"
        case .sevenShiftedPairs: "同一花色序数相连的七个对子"
        case .thirteenOrphans: "三种数牌的 1、9 和七种字牌各一张，其中一张成对"
        case .allTerminals: "全部是数牌 1、9 的刻子和将"
        case .littleFourWinds: "三种风牌的刻子，第四种风牌做将"
        case .littleThreeDragons: "两种箭牌的刻子，第三种箭牌做将"
        case .allHonors: "全部是字牌"
        case .fourConcealedPungs: "四组暗刻（暗杠也算）"
        case .pureTerminalChows: "同一花色两组 123、两组 789，5 做将"
        case .quadrupleChow: "同一花色四组相同的顺子"
        case .fourPureShiftedPungs: "同一花色四组点数依次加 1 的刻子"
        case .fourPureShiftedChows: "同一花色四组依次错开 1 位或 2 位的顺子"
        case .threeKongs: "开了三组杠"
        case .allTerminalsAndHonors: "全部是幺九牌和字牌的刻子和将"
        case .sevenPairs: "七个对子"
        case .greaterHonorsAndKnittedTiles: "七种字牌各一张，加上 147、258、369 三种花色里互不相靠的七张"
        case .allEvenPungs: "全部是 2、4、6、8 的刻子和将"
        case .fullFlush: "全部是同一种花色的数牌"
        case .pureTripleChow: "同一花色三组相同的顺子"
        case .pureShiftedPungs: "同一花色三组点数依次加 1 的刻子"
        case .upperTiles: "全部是 7、8、9"
        case .middleTiles: "全部是 4、5、6"
        case .lowerTiles: "全部是 1、2、3"
        case .pureStraight: "同一花色的 123、456、789"
        case .threeSuitedTerminalChows: "两种花色各有 123 和 789，第三种花色的 5 做将"
        case .pureShiftedChows: "同一花色三组依次错开 1 位或 2 位的顺子"
        case .allFive: "每组面子和将都带 5"
        case .triplePung: "三种花色同一点数的刻子"
        case .threeConcealedPungs: "三组暗刻"
        case .lesserHonorsAndKnittedTiles: "147、258、369 三种花色和字牌中互不相靠的 14 张"
        case .knittedStraight: "三种花色分别取 147、258、369，拼成 1 到 9"
        case .upperFour: "全部是 6 到 9 的数牌"
        case .lowerFour: "全部是 1 到 4 的数牌"
        case .bigThreeWinds: "三种风牌的刻子"
        case .mixedStraight: "三种花色分别组成 123、456、789"
        case .reversibleTiles: "全部是上下颠倒样子不变的牌：1234589 饼、245689 条、白"
        case .mixedTripleChow: "三种花色同一点数的顺子"
        case .mixedShiftedPungs: "三种花色点数依次加 1 的刻子"
        case .chickenHand: "和了，但数不出任何番（花牌不算）"
        case .lastTileDraw: "自摸牌墙的最后一张"
        case .lastTileClaim: "和别人打出的最后一张牌"
        case .outWithReplacementTile: "开杠后补上来的那张自摸和"
        case .robbingTheKong: "和别人加杠的那张牌"
        case .allPungs: "四组刻子（或杠）加一对将"
        case .halfFlush: "一种花色的数牌加字牌"
        case .mixedShiftedChows: "三种花色依次错开 1 位的顺子"
        case .allTypes: "万、条、饼、风、箭五种都有"
        case .meldedHand: "全靠吃碰明杠，最后单钓别人打的牌"
        case .twoConcealedKongs: "两组暗杠"
        case .twoDragonsPungs: "两组箭牌刻子"
        case .outsideHand: "每组面子和将都带幺九牌或字牌"
        case .fullyConcealedHand: "没有吃碰明杠，自摸和"
        case .twoMeldedKongs: "两组明杠"
        case .lastTile: "和的那张牌桌上已经亮出三张，是最后一张"
        case .dragonPung: "中、发或白的刻子"
        case .prevalentWind: "与圈风相同的风牌刻子"
        case .seatWind: "与自己门风相同的风牌刻子"
        case .concealedHand: "没有吃碰明杠，和别人打的牌"
        case .allChows: "四组顺子，数牌做将"
        case .tileHog: "有四张相同的牌，但没有开杠"
        case .doublePung: "两种花色同一点数的刻子"
        case .twoConcealedPungs: "两组暗刻"
        case .concealedKong: "一组暗杠"
        case .allSimples: "没有幺九牌和字牌"
        case .pureDoubleChow: "同一花色两组相同的顺子"
        case .mixedDoubleChow: "两种花色同一点数的顺子"
        case .shortStraight: "同一花色六张相连的两组顺子"
        case .twoTerminalChows: "同一花色的 123 和 789"
        case .pungOfTerminalsOrHonors: "1、9 或不算番的风牌的刻子"
        case .meldedKong: "一组明杠"
        case .oneVoidedSuit: "缺少一种花色的数牌"
        case .noHonors: "没有字牌"
        case .edgeWait: "只能和 12 后面的 3，或 89 前面的 7"
        case .closedWait: "只能和顺子中间那张"
        case .singleWait: "只能和做将的那一张"
        case .selfDrawn: "自己摸到和牌"
        case .flowerTiles: "每张花牌 1 番，不计入 8 番起和"
        case .concealedKongAndMeldedKong: "一组明杠加一组暗杠"
        }
    }

    /// 每次计多少番，取自算番库的番值表。
    public var points: Int { Int(gb_fan_value(Int32(rawValue))) }
}
