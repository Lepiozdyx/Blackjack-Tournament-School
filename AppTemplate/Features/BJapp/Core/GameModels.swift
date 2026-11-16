import Foundation

enum Money {
    static func rounded(_ value: Decimal) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, 2, .plain)
        return result
    }
    static func string(_ value: Decimal, language: String = "en") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.locale = Locale(identifier: language == "es" ? "es_ES" : "en_US")
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
    }
}

struct PlayingCard: Codable, Identifiable, Equatable {
    var id: Int
    var rank: Int
    var suit: Int
    var value: Int { min(rank, 10) }
    var symbol: String { ["♠", "♥", "♣", "♦"][suit] }
    var label: String { [1: "A", 11: "J", 12: "Q", 13: "K"][rank] ?? String(rank) }
    var asset: String { "card_\(suit)_\(rank)" }
    var red: Bool { suit == 1 || suit == 3 }
}

struct CardHand: Codable, Equatable {
    var cards: [PlayingCard] = []
    var total: Int {
        var sum = cards.reduce(0) { $0 + $1.value }
        if cards.contains(where: { $0.rank == 1 }) && sum + 10 <= 21 { sum += 10 }
        return sum
    }
    var soft: Bool {
        cards.contains(where: { $0.rank == 1 }) && cards.reduce(0) { $0 + $1.value } + 10 <= 21
    }
    var blackjack: Bool { cards.count == 2 && total == 21 }
    var bust: Bool { total > 21 }
}

enum HandOutcome: String, Codable { case win, lose, push, blackjack }
enum RoundPhase: String, Codable { case betting, player, settled, finished }
enum FinishReason: String, Codable { case completed, stopped, bankrupt }

struct Opponent: Codable, Identifiable {
    var id: String
    var name: String
    var avatar: Int
    var balance: Decimal
    static func initial() -> [Opponent] {
        let names = ["Valentina", "Maverick", "Elena", "Atlas", "Santiago", "Jade", "Oliver", "Sofia", "Nico", "Amara", "Felix", "Luna", "Theo", "Isabella", "Kai", "Camila", "Leo", "Maya", "Hugo", "Aria"]
        return names.enumerated().map { i, name in
            Opponent(id: "bot_\(i)", name: name, avatar: i, balance: Decimal(350 + i * 185))
        }
    }
}

struct TournamentSeat: Codable, Identifiable {
    var id: String
    var earned: Decimal = 0
    var hand = CardHand()
    var bet: Decimal = 10
    var doubled = false
    var outcome: HandOutcome?
}

struct Tournament: Codable, Identifiable {
    var id = UUID()
    var round = 1
    var completed = 0
    var elapsed = 0
    var phase: RoundPhase = .betting
    var shoe: [PlayingCard]
    var player = CardHand()
    var dealer = CardHand()
    var bet: Decimal = 10
    var doubled = false
    var seats: [TournamentSeat]
    var playerEarned: Decimal = 0
    var outcome: HandOutcome?
    var lastDelta: Decimal = 0
    var lastBonus: Decimal = 0
    var finishReason: FinishReason?
}

struct Preferences: Codable {
    var music = true
    var effects = true
    var haptics = true
    var language: String = Locale.preferredLanguages.first(where: { $0.hasPrefix("es") || $0.hasPrefix("en") })?.hasPrefix("es") == true ? "es" : "en"
}

struct PlayerProfile: Codable {
    var nickname = "Player"
    var avatarData: Data?
    var balance: Decimal = 1000
    var ownedSkins = ["classic"]
    var selectedSkin = "classic"
    var handsPlayed = 0
    var handsWon = 0
    var tutorialCompleted = false
}

struct SavedState: Codable {
    var version = 1
    var profile = PlayerProfile()
    var preferences = Preferences()
    var opponents = Opponent.initial()
    var tournament: Tournament?
    var school: SchoolProgress?
}

struct DealerSkin: Identifiable {
    var id: String
    var nameEN: String
    var nameES: String
    var detailEN: String
    var detailES: String
    var price: Decimal
    static let all: [DealerSkin] = [
        .init(id: "classic", nameEN: "The Chemist", nameES: "El Químico", detailEN: "Calm. Calculated. Classic.", detailES: "Calma, cálculo y clase.", price: 0),
        .init(id: "burgundy", nameEN: "The Gentleman", nameES: "El Caballero", detailEN: "A touch of old-world charm.", detailES: "El encanto de otra época.", price: 500),
        .init(id: "emerald", nameEN: "The Empress", nameES: "La Emperatriz", detailEN: "Every hand, an elegant affair.", detailES: "Elegancia en cada mano.", price: 1000),
        .init(id: "ivory", nameEN: "The Maestro", nameES: "El Maestro", detailEN: "Experience at the table.", detailES: "Experiencia sobre el tapete.", price: 1500)
    ]
}

struct RankingRow: Identifiable {
    var id: String
    var name: String
    var avatar: Int?
    var amount: Decimal
    var rank: Int
    var isPlayer: Bool { id == "player" }
}
