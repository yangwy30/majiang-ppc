import Foundation

/// 所有牌局和常用牌友，存成一个 JSON 文件。
public struct GameArchive: Codable, Hashable, Sendable {
    public var games: [Game] = []
    public var frequentPlayers: [Player] = []
    public var lastRules = GameRules()

    public init() {}

    public var activeGame: Game? { games.last { !$0.isFinished } }

    public var finishedGames: [Game] {
        games.filter(\.isFinished).sorted { $0.startedAt > $1.startedAt }
    }

    public mutating func upsert(_ game: Game) {
        if let i = games.firstIndex(where: { $0.id == game.id }) {
            games[i] = game
        } else {
            games.append(game)
        }
    }

    /// 记住用过的名字，新建牌局时可以一点就加。
    public mutating func remember(_ players: [Player]) {
        for player in players where !player.name.isEmpty {
            frequentPlayers.removeAll { $0.name == player.name }
            frequentPlayers.insert(player, at: 0)
        }
        frequentPlayers = Array(frequentPlayers.prefix(12))
    }

    public static func load(from url: URL) throws -> GameArchive {
        guard FileManager.default.fileExists(atPath: url.path) else { return GameArchive() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GameArchive.self, from: Data(contentsOf: url))
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
