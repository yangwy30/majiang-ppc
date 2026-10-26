import Foundation

public struct Player: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// 牌局规则。默认是国标竞赛规则；家规不同的地方可以改。
public struct GameRules: Hashable, Codable, Sendable {
    /// 1 分折合多少元。
    public var yuanPerPoint: Double = 1
    /// 底分（国标为 8）。
    public var basePoints: Int = 8
    /// 起和番（国标为 8，花牌不计入）。
    public var minimumFan: Int = 8
    /// 是否带花牌。
    public var includeFlowers: Bool = true
    /// 比赛规则每圈换座；朋友局一般不换。
    public var swapSeatsEachRound: Bool = false
    /// 错和赔另外三家各多少分。
    public var falseWinPenalty: Int = 10
    /// 一场几局（4 圈 16 局）。
    public var totalHands: Int = 16

    public init() {}
}

/// 一局的结果。
public enum HandOutcome: Hashable, Codable, Sendable {
    case win(WinRecord)
    /// 荒庄：不计分。
    case drawn
    /// 错和：赔另外三家。不推进局数。
    case falseWin(offender: Int)
    /// 手动记分，四个数加起来为 0。
    case manual(deltas: [Int], note: String)

    /// 这一局打完了没有（错和之后这一局继续打）。
    public var advancesHand: Bool {
        if case .falseWin = self { return false }
        return true
    }
}

public struct WinRecord: Hashable, Codable, Sendable {
    /// 和牌者（玩家下标，0–3）。
    public var winner: Int
    /// 点炮者；nil 为自摸。
    public var discarder: Int?
    /// 确认后的手牌；手动输入番数时可以为空。
    public var hand: Hand?
    public var context: WinContext
    public var fans: [FanEntry]
    public var flowerFan: Int

    public init(winner: Int, discarder: Int?, hand: Hand?, context: WinContext, fans: [FanEntry], flowerFan: Int) {
        self.winner = winner
        self.discarder = discarder
        self.hand = hand
        self.context = context
        self.fans = fans
        self.flowerFan = flowerFan
    }

    public init(winner: Int, discarder: Int?, hand: Hand, context: WinContext, result: ScoringResult) {
        self.init(winner: winner, discarder: discarder, hand: hand, context: context,
                  fans: result.fans, flowerFan: result.flowerFan)
    }

    public var totalFan: Int { fans.reduce(0) { $0 + $1.points } + flowerFan }
    public var isSelfDrawn: Bool { discarder == nil }
}

public struct HandRecord: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    /// 第几局（0 起），错和记在当前局上。
    public var handIndex: Int
    public var outcome: HandOutcome
    /// 四个玩家本局的得失分，下标同 `Game.players`。
    public var deltas: [Int]
    public var date: Date

    public init(id: UUID = UUID(), handIndex: Int, outcome: HandOutcome, deltas: [Int], date: Date = Date()) {
        self.id = id
        self.handIndex = handIndex
        self.outcome = outcome
        self.deltas = deltas
        self.date = date
    }
}

public enum GameError: Error, Hashable, Sendable {
    case finished
    case invalidPlayer
    case discarderIsWinner
    case belowMinimumFan(Int)
    case deltasMustSumToZero
}

/// 一场牌局：四个人、规则、每一局的记录。圈风、门风、庄家都从局数推出来，不用存。
public struct Game: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    /// 开局时的座位：下标 0 东、1 南、2 西、3 北。东家是第一局的庄。
    public var players: [Player]
    public var rules: GameRules
    public private(set) var records: [HandRecord]

    public init(id: UUID = UUID(), players: [Player], rules: GameRules = GameRules(), startedAt: Date = Date()) {
        precondition(players.count == 4, "国标麻将固定 4 人")
        self.id = id
        self.players = players
        self.rules = rules
        self.records = []
        self.startedAt = startedAt
    }

    // MARK: 局数、圈风、门风

    /// 已经打完的局数，也就是当前是第几局（0 起）。
    public var currentHandIndex: Int { records.filter(\.outcome.advancesHand).count }

    public var isFinished: Bool { endedAt != nil || currentHandIndex >= rules.totalHands }

    public var remainingHands: Int { max(0, rules.totalHands - currentHandIndex) }

    /// 第几圈（0 东圈、1 南圈……），超过 4 圈按北圈算。
    public func roundIndex(ofHand hand: Int) -> Int { min(hand / 4, 3) }

    public func prevalentWind(ofHand hand: Int) -> Wind { Wind(rawValue: roundIndex(ofHand: hand))! }

    public var prevalentWind: Wind { prevalentWind(ofHand: currentHandIndex) }

    /// 这一圈里，桌子东南西北四个位置上坐的是谁（玩家下标）。
    /// 每圈换座按竞赛规则：南圈东南、西北对调；西圈、北圈见下表。不换座时一直是开局座位。
    public func seating(ofRound round: Int) -> [Int] {
        guard rules.swapSeatsEachRound else { return [0, 1, 2, 3] }
        let table = [[0, 1, 2, 3], [1, 0, 3, 2], [2, 3, 1, 0], [3, 2, 0, 1]]
        return table[min(max(round, 0), 3)]
    }

    /// 某局里玩家坐在哪个位置（0 东位 … 3 北位，按这一圈开始时的座位）。
    public func position(of player: Int, inHand hand: Int) -> Int {
        seating(ofRound: roundIndex(ofHand: hand)).firstIndex(of: player)!
    }

    /// 某局的庄家（玩家下标）。不连庄，庄家每局逆时针下移一位。
    public func dealer(ofHand hand: Int) -> Int {
        seating(ofRound: roundIndex(ofHand: hand))[hand % 4]
    }

    public var dealer: Int { dealer(ofHand: currentHandIndex) }

    /// 某局玩家的门风：庄家是东，下家是南，依此类推。
    public func seatWind(of player: Int, inHand hand: Int) -> Wind {
        let offset = (position(of: player, inHand: hand) - hand % 4 + 4) % 4
        return Wind(rawValue: offset)!
    }

    public func seatWind(of player: Int) -> Wind { seatWind(of: player, inHand: currentHandIndex) }

    /// 当前局某个玩家和牌时的 WinContext（圈风、门风已经填好）。
    public func winContext(for winner: Int) -> WinContext {
        WinContext(prevalentWind: prevalentWind, seatWind: seatWind(of: winner))
    }

    // MARK: 分数

    /// 每个人的累计分。
    public var scores: [Int] {
        records.reduce(into: [0, 0, 0, 0]) { total, record in
            for i in 0..<4 { total[i] += record.deltas[i] }
        }
    }

    public func money(forPoints points: Int) -> Double { Double(points) * rules.yuanPerPoint }

    /// 本场番数最大的一手。
    public var biggestWin: (record: HandRecord, win: WinRecord)? {
        records.compactMap { record -> (HandRecord, WinRecord)? in
            if case .win(let win) = record.outcome { return (record, win) }
            return nil
        }
        .max { $0.1.totalFan < $1.1.totalFan }
    }

    // MARK: 记分

    @discardableResult
    public mutating func recordWin(_ win: WinRecord) throws -> HandRecord {
        guard !isFinished else { throw GameError.finished }
        guard (0..<4).contains(win.winner) else { throw GameError.invalidPlayer }
        if let discarder = win.discarder {
            guard (0..<4).contains(discarder) else { throw GameError.invalidPlayer }
            guard discarder != win.winner else { throw GameError.discarderIsWinner }
        }
        let fanWithoutFlowers = win.totalFan - win.flowerFan
        guard fanWithoutFlowers >= rules.minimumFan else { throw GameError.belowMinimumFan(fanWithoutFlowers) }

        let deltas = Payment.winDeltas(winner: win.winner, discarder: win.discarder,
                                       totalFan: win.totalFan, basePoints: rules.basePoints)
        return append(.win(win), deltas: deltas)
    }

    @discardableResult
    public mutating func recordDraw() throws -> HandRecord {
        guard !isFinished else { throw GameError.finished }
        return append(.drawn, deltas: [0, 0, 0, 0])
    }

    @discardableResult
    public mutating func recordFalseWin(offender: Int) throws -> HandRecord {
        guard !isFinished else { throw GameError.finished }
        guard (0..<4).contains(offender) else { throw GameError.invalidPlayer }
        let deltas = Payment.falseWinDeltas(offender: offender, penalty: rules.falseWinPenalty)
        return append(.falseWin(offender: offender), deltas: deltas)
    }

    @discardableResult
    public mutating func recordManual(deltas: [Int], note: String = "") throws -> HandRecord {
        guard !isFinished else { throw GameError.finished }
        guard deltas.count == 4, deltas.reduce(0, +) == 0 else { throw GameError.deltasMustSumToZero }
        return append(.manual(deltas: deltas, note: note), deltas: deltas)
    }

    /// 撤销最后一条记录。
    @discardableResult
    public mutating func undoLast() -> HandRecord? {
        guard !records.isEmpty else { return nil }
        endedAt = nil
        return records.removeLast()
    }

    public mutating func end(at date: Date = Date()) {
        endedAt = date
    }

    private mutating func append(_ outcome: HandOutcome, deltas: [Int]) -> HandRecord {
        let record = HandRecord(handIndex: currentHandIndex, outcome: outcome, deltas: deltas)
        records.append(record)
        return record
    }
}

/// 国标收付。
public enum Payment {
    /// 自摸：三家各付「底分 + 番数」；点炮：点炮者付「底分 + 番数」，另外两家各付底分。
    public static func winDeltas(winner: Int, discarder: Int?, totalFan: Int, basePoints: Int) -> [Int] {
        var deltas = [0, 0, 0, 0]
        for player in 0..<4 where player != winner {
            let pays: Int
            if let discarder {
                pays = player == discarder ? basePoints + totalFan : basePoints
            } else {
                pays = basePoints + totalFan
            }
            deltas[player] -= pays
            deltas[winner] += pays
        }
        return deltas
    }

    /// 错和：赔另外三家各 `penalty` 分。
    public static func falseWinDeltas(offender: Int, penalty: Int) -> [Int] {
        (0..<4).map { $0 == offender ? -3 * penalty : penalty }
    }
}
