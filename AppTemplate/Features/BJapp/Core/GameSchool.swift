import Foundation

enum SchoolLesson: String, Codable, CaseIterable, Identifiable {
    case hand, bust, dealer, move, distance
    var id: String { rawValue }
    var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
    var icon: String {
        switch self {
        case .hand: return "rectangle.on.rectangle.angled"
        case .bust: return "scope"
        case .dealer: return "eye"
        case .move: return "arrow.triangle.branch"
        case .distance: return "chart.xyaxis.line"
        }
    }
    func title(_ es: Bool) -> String {
        switch self {
        case .hand: return es ? "Laboratorio de manos" : "Hand Lab"
        case .bust: return es ? "Radar de riesgo" : "Bust Radar"
        case .dealer: return es ? "Lee al crupier" : "Read the Dealer"
        case .move: return es ? "La mejor jugada" : "Best Move"
        case .distance: return es ? "A largo plazo" : "The Long Run"
        }
    }
    func detail(_ es: Bool) -> String {
        switch self {
        case .hand: return es ? "Domina los ases, las manos suaves y el 21." : "Master aces, soft hands and the meaning of 21."
        case .bust: return es ? "Descubre qué cartas te hacen pasar de 21." : "Discover which cards take you over 21."
        case .dealer: return es ? "Lee la carta visible y entiende la regla del 17." : "Read the upcard and understand the rule of 17."
        case .move: return es ? "Pide, plántate o dobla con una razón." : "Hit, stand or double — with a reason."
        case .distance: return es ? "Distingue una buena decisión de un resultado afortunado." : "Separate a good decision from a lucky outcome."
        }
    }
}

enum SchoolPhase: String, Codable { case introduction, question, feedback, results }
struct SchoolAnswer: Codable {
    var questionID: String
    var selection: [String]
    var correct: Bool
    var assisted: Bool
}
struct SchoolSession: Codable, Identifiable {
    var id = UUID()
    var questions: [String]
    var index = 0
    var phase: SchoolPhase = .introduction
    var answers: [SchoolAnswer] = []
    var selection: [String] = []
    var assisted = false
    var review = false
    var labIndex = 0
    var labStep = 0
    var experimentCount = 0
    var seed = UInt64.random(in: 1...UInt64.max)
    var score: Int { answers.filter { $0.correct && !$0.assisted }.count }
    var missed: [String] { answers.filter { !$0.correct || $0.assisted }.map(\.questionID) }
    var questionID: String? { questions.indices.contains(index) ? questions[index] : nil }
}
struct SchoolRecord: Codable {
    var completed = 0
    var lastScore: Int?
    var bestScore: Int?
    var mistakes: [String] = []
    var session: SchoolSession?
}
struct SchoolProgress: Codable {
    var version = 1
    var records: [String: SchoolRecord] = [:]
    func record(_ lesson: SchoolLesson) -> SchoolRecord { records[lesson.rawValue] ?? SchoolRecord() }
}
enum SchoolAction: String, Codable, CaseIterable {
    case stand, hit, doubleDown = "double"
    func title(_ es: Bool) -> String {
        switch self {
        case .stand: return es ? "Plantarse" : "Stand"
        case .hit: return es ? "Pedir" : "Hit"
        case .doubleDown: return es ? "Doblar" : "Double"
        }
    }
}
struct SchoolDistribution: Decodable {
    var upcard: Int
    var probabilities: [Double] // 17...21, bust; conditioned on no blackjack
    var bust: Double { probabilities[5] }
}
struct SchoolDecision: Decodable, Identifiable {
    var id: String
    var ranks: [Int]
    var upcard: Int
    var stand: [Double]
    var hit: [Double]
    var doubleDown: [Double]?
    enum CodingKeys: String, CodingKey { case id, ranks, upcard, stand, hit; case doubleDown = "double" }
    var actions: [SchoolAction] { doubleDown == nil ? [.stand, .hit] : [.stand, .hit, .doubleDown] }
    func probabilities(_ action: SchoolAction) -> [Double] {
        switch action {
        case .stand: return stand
        case .hit: return hit
        case .doubleDown: return doubleDown ?? hit
        }
    }
    func expected(_ action: SchoolAction) -> Double {
        let p = probabilities(action)
        return (p[2] - p[0]) * (action == .doubleDown ? 2 : 1)
    }
    var best: SchoolAction { actions.max { expected($0) < expected($1) } ?? .stand }
    var comparison: [SchoolAction] {
        [best, actions.filter { $0 != best }.max { expected($0) < expected($1) } ?? .hit]
            .sorted { $0.rawValue < $1.rawValue }
    }
}
struct SchoolMathData: Decodable {
    var version: Int
    var dealer: [SchoolDistribution]
    var decisions: [SchoolDecision]
    static let bundled: SchoolMathData? = {
        guard let url = Bundle.main.url(forResource: "school_math", withExtension: "json"),
              let bytes = try? Data(contentsOf: url),
              let data = try? JSONDecoder().decode(Self.self, from: bytes),
              data.version == 1, data.dealer.count == 10, data.decisions.count >= 20,
              data.dealer.allSatisfy({ valid($0.probabilities, count: 6) }),
              data.decisions.allSatisfy({ item in item.actions.allSatisfy { valid(item.probabilities($0), count: 3) } }) else { return nil }
        return data
    }()
    private static func valid(_ p: [Double], count: Int) -> Bool {
        p.count == count && p.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 } && abs(p.reduce(0, +) - 1) < 0.000001
    }
    func decision(_ id: String) -> SchoolDecision? { decisions.first { $0.id == id } }
    func distribution(_ rank: Int) -> SchoolDistribution? { dealer.first { $0.upcard == rank } }
}
struct SchoolHandExercise: Identifiable {
    var id: String
    var ranks: [Int]
    var next: Int?
    var result: CardHand { SchoolRules.hand(ranks + (next.map { [$0] } ?? [])) }
}

enum SchoolRules {
    static func hand(_ ranks: [Int]) -> CardHand {
        CardHand(cards: ranks.enumerated().map { i, rank in PlayingCard(id: i, rank: rank, suit: i % 4) })
    }
    static func handCode(_ hand: CardHand) -> String {
        "\(hand.total):\(hand.blackjack ? "blackjack" : hand.bust ? "bust" : hand.soft ? "soft" : "hard")"
    }
    static func handLabel(_ hand: CardHand, spanish: Bool) -> String { label(code: handCode(hand), spanish: spanish) }
    static func label(code: String, spanish: Bool) -> String {
        let parts = code.split(separator: ":").map(String.init)
        guard parts.count == 2 else { return code }
        let kind: String
        switch parts[1] {
        case "blackjack": kind = "Blackjack"
        case "bust": kind = spanish ? "Pasada" : "Bust"
        case "soft": kind = spanish ? "Suave" : "Soft"
        default: kind = spanish ? "Dura" : "Hard"
        }
        return "\(parts[0]) · \(kind)"
    }
    static func rankLabel(_ rank: Int) -> String { rank == 1 ? "A" : rank == 10 ? "10 / J / Q / K" : "\(rank)" }
    static let exercises: [SchoolHandExercise] = {
        let examples: [([Int], Int?)] = [
            ([1,6],nil),([1,1],nil),([1,13],nil),([7,7,7],nil),([1,6],10),
            ([1,1],9),([1,1,1],8),([1,5],5),([1,7],3),([1,8],5),
            ([10,6],6),([10,5],6),([2,3,6],nil),([1,2,4],nil),([1,1,9],nil),
            ([1,1,9],10),([1,9],1),([1,4],8),([10,10],1),([2,9],nil),
            ([1,3,3],nil),([1,3,3],7),([1,1,1,7],nil),([1,2],9)
        ]
        return examples.enumerated().map { SchoolHandExercise(id: "hand_\($0.offset)", ranks: $0.element.0, next: $0.element.1) }
    }()
    static let bustHands: [[Int]] = [
        [10,2],[10,3],[10,4],[10,5],[10,6],[10,7],[10,8],[10,9],[10,10],
        [1,2],[1,6],[1,7],[1,8],[1,9],[1,1],[1,6,10],[1,1,9],
        [5,3,4],[2,3,8],[7,7],[8,8],[9,9],[1,4,9],[2,3,6]
    ]
    static let dealerPairs: [[Int]] = [
        [2,3],[2,4],[2,5],[2,6],[2,7],[2,10],[3,4],[3,5],[3,7],[3,9],
        [4,5],[4,6],[4,8],[4,10],[5,6],[5,9],[5,1],[6,7],[6,1],[7,8],[7,9],[8,9],[9,10],[10,1]
    ]
    static func dangerous(_ ranks: [Int]) -> [Int] { (1...10).filter { hand(ranks + [$0]).bust } }
    static func bustCounts(_ ranks: [Int]) -> (bad: Int, remaining: Int) {
        var counts = [24,24,24,24,24,24,24,24,24,96]
        for rank in ranks { counts[min(rank, 10) - 1] -= 1 }
        let bad = dangerous(ranks).reduce(0) { $0 + counts[$1 - 1] }
        return (bad, counts.reduce(0, +))
    }
    static func catalog(_ lesson: SchoolLesson, data: SchoolMathData) -> [String] {
        switch lesson {
        case .hand: return exercises.map(\.id)
        case .bust: return bustHands.indices.map { "bust_\($0)" }
        case .dealer: return dealerPairs.indices.map { "dealer_\($0)" }
        case .move, .distance: return data.decisions.map(\.id)
        }
    }
    static func index(_ id: String) -> Int { Int(id.split(separator: "_").last ?? "0") ?? 0 }
    static func correct(_ lesson: SchoolLesson, id: String, data: SchoolMathData) -> [String] {
        let i = index(id)
        switch lesson {
        case .hand: return [handCode(exercises[i].result)]
        case .bust: return dangerous(bustHands[i]).map(String.init)
        case .dealer:
            let pair = dealerPairs[i]
            return [String((data.distribution(pair[0])?.bust ?? 0) > (data.distribution(pair[1])?.bust ?? 0) ? pair[0] : pair[1])]
        case .move, .distance: return [data.decision(id)?.best.rawValue ?? "stand"]
        }
    }
    static func choices(_ exercise: SchoolHandExercise) -> [String] {
        let h = exercise.result, correct = handCode(exercise.result)
        var result = [correct, "\(h.total):\(h.soft ? "hard" : "soft")", "\(max(1, h.total - 10)):hard", "\(h.total + 10):bust"]
        if h.total == 21 { result = [correct, "21:blackjack", "21:hard", "11:hard", "21:soft"] }
        var unique: [String] = []
        for code in result where !unique.contains(code) { unique.append(code) }
        return unique.prefix(4).sorted()
    }
    /// Reproducible prefixes at 10, 100, 1000 trials, including after resume.
    static func experiment(_ decision: SchoolDecision, action: SchoolAction, seed: UInt64, count: Int) -> [Double] {
        var state = seed &+ UInt64(SchoolAction.allCases.firstIndex(of: action) ?? 0)
        var sum = 0.0
        let p = decision.probabilities(action)
        return (1...max(1, count)).map { n in
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            let u = Double((z ^ (z >> 31)) >> 11) / 9_007_199_254_740_992
            sum += (u < p[0] ? -1.0 : u < p[0] + p[1] ? 0.0 : 1.0) * (action == .doubleDown ? 2 : 1)
            return sum / Double(n)
        }
    }
}

extension CasinoStore {
    var school: SchoolProgress { state.school ?? SchoolProgress() }
    @discardableResult func openSchool(_ lesson: SchoolLesson, data: SchoolMathData, restart: Bool = false, review: Bool = false) -> Bool {
        let record = school.record(lesson)
        guard restart || review || record.session == nil else { return true }
        let catalog = SchoolRules.catalog(lesson, data: data)
        let questions = review ? record.mistakes.filter { catalog.contains($0) } : Array(catalog.shuffled().prefix(10))
        guard !questions.isEmpty else { return false }
        return updateSchool { progress in
            var next = progress.record(lesson)
            next.session = SchoolSession(questions: questions, phase: review ? .question : .introduction, review: review)
            progress.records[lesson.rawValue] = next
        }
    }
    @discardableResult func editSchool(_ lesson: SchoolLesson, _ edit: (inout SchoolSession) -> Void) -> Bool {
        updateSchool { progress in
            var record = progress.record(lesson)
            if var session = record.session { edit(&session); record.session = session }
            progress.records[lesson.rawValue] = record
        }
    }
    func chooseSchool(_ lesson: SchoolLesson, value: String) {
        _ = editSchool(lesson) { session in
            guard session.phase == .question else { return }
            if lesson == .bust {
                if session.selection.contains(value) { session.selection.removeAll { $0 == value } }
                else { session.selection.append(value) }
            } else { session.selection = [value] }
        }
    }
    func answerSchool(_ lesson: SchoolLesson, data: SchoolMathData) {
        let saved = editSchool(lesson) { session in
            guard session.phase == .question, let id = session.questionID,
                  lesson == .bust || !session.selection.isEmpty else { return }
            session.answers.append(SchoolAnswer(questionID: id, selection: session.selection,
                correct: Set(session.selection) == Set(SchoolRules.correct(lesson, id: id, data: data)), assisted: session.assisted))
            session.phase = .feedback
        }
        if saved { feedback(.tap) }
    }
    func advanceSchool(_ lesson: SchoolLesson) {
        _ = updateSchool { progress in
            var record = progress.record(lesson)
            guard var session = record.session, session.phase == .feedback else { return }
            if session.index + 1 < session.questions.count {
                session.index += 1; session.phase = .question
                session.selection = []; session.assisted = false; session.experimentCount = 0
            } else {
                session.phase = .results
                if !session.review {
                    record.completed += 1; record.lastScore = session.score
                    record.bestScore = max(record.bestScore ?? 0, session.score)
                }
                let resolved = session.answers.filter { $0.correct && !$0.assisted }.map(\.questionID)
                record.mistakes = Array(Set(record.mistakes.filter { !resolved.contains($0) } + session.missed)).sorted()
            }
            record.session = session
            progress.records[lesson.rawValue] = record
        }
    }
}
