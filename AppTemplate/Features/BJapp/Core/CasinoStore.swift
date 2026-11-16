import SwiftUI
import Observation

@MainActor @Observable
final class CasinoStore {
    private(set) var state: SavedState
    var tableVisible = false
    var overlayVisible = false
    var foreground = true
    var errorMessage: String?
    private(set) var loadFailed = false
    private let repository = StateRepository()
    let media = CasinoMedia()
    private var lastTick = Date()

    init() {
        do { state = try repository.load() }
        catch {
            state = SavedState()
            loadFailed = true
            errorMessage = state.preferences.language == "es" ? "No se pudo leer el progreso guardado. No se ha sobrescrito." : "Saved progress could not be read. It has not been overwritten."
        }
    }

    var spanish: Bool { state.preferences.language == "es" }
    func text(_ en: String, _ es: String) -> String { spanish ? es : en }
    func points(_ value: Decimal) -> String { Money.string(value, language: state.preferences.language) }
    var game: Tournament? { state.tournament }
    var running: Bool { game != nil && game?.phase != .finished }
    var balance: Decimal { state.profile.balance }
    var credit: Decimal { max(0, balance + 1000) }
    var reservedBet: Decimal { game?.phase == .player ? game?.bet ?? 0 : 0 }
    var spendable: Decimal { max(0, balance - reservedBet) }
    var canDouble: Bool { game?.phase == .player && game?.player.cards.count == 2 && (game?.bet ?? 0) * 2 <= credit }
    var clock: String { String(format: "%02d:%02d", (game?.elapsed ?? 0) / 60, (game?.elapsed ?? 0) % 60) }
    var paused: Bool { !foreground || overlayVisible || !tableVisible }

    @discardableResult
    private func commit(_ mutation: (inout SavedState) -> Void, allowRecovery: Bool = false) -> Bool {
        guard !loadFailed || allowRecovery else { return false }
        var next = state
        mutation(&next)
        do {
            try repository.save(next)
            state = next
            syncAudio()
            return true
        } catch {
            errorMessage = text("Progress could not be saved. The action was not applied. Please free some storage and try again.", "No se pudo guardar el progreso. La acción no se ha aplicado. Libera espacio e inténtalo de nuevo.")
            return false
        }
    }

    func setPreference(_ keyPath: WritableKeyPath<Preferences, Bool>, _ value: Bool) {
        if commit({ $0.preferences[keyPath: keyPath] = value }) { feedback(.tap) }
    }
    func setLanguage(_ language: String) { if commit({ $0.preferences.language = language }) { feedback(.tap) } }
    func setNickname(_ name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        _ = commit { $0.profile.nickname = trimmed.isEmpty ? "Player" : trimmed }
    }
    func setAvatar(_ image: UIImage) {
        let size = CGSize(width: 384, height: 384)
        let renderer = UIGraphicsImageRenderer(size: size)
        let square = renderer.image { _ in
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let rect = CGRect(x: (384 - image.size.width * scale) / 2, y: (384 - image.size.height * scale) / 2, width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: rect)
        }
        guard let data = square.jpegData(compressionQuality: 0.85) else { return }
        if commit({ $0.profile.avatarData = data }) { feedback(.tap) }
    }
    func completeTutorial() { _ = commit { $0.profile.tutorialCompleted = true } }

    /// Only the educational portion of the atomic save is writable here.
    @discardableResult
    func updateSchool(_ mutation: (inout SchoolProgress) -> Void) -> Bool {
        commit { state in
            var school = state.school ?? SchoolProgress()
            mutation(&school)
            state.school = school
        }
    }

    func enterTable() {
        guard !loadFailed, balance > -1000 else { return }
        if !running {
            guard commit({ state in
                var tournament = BlackjackEngine.makeTournament(opponents: state.opponents)
                tournament.bet = min(10, max(0, state.profile.balance + 1000))
                state.tournament = tournament
            }) else { return }
        }
        tableVisible = true
        lastTick = Date()
        feedback(.tap)
    }

    func selectBet(_ amount: Decimal) {
        guard !paused, game?.phase == .betting, amount > 0, amount <= credit else { return }
        if commit({ $0.tournament?.bet = amount }) { feedback(.chip) }
    }

    func deal() {
        guard !paused, var tournament = game, tournament.phase == .betting, balance > -1000 else { return }
        tournament.bet = min(tournament.bet, credit)
        guard tournament.bet > 0 else { return }
        let success = commit { state in
            BlackjackEngine.deal(&tournament, opponents: state.opponents)
            state.tournament = tournament
            if tournament.player.blackjack || tournament.dealer.blackjack { BlackjackEngine.finishRound(&state) }
        }
        if success { feedback(.deal); announceResult() }
    }

    func hit() {
        guard !paused, game?.phase == .player else { return }
        let success = commit { state in
            guard var tournament = state.tournament else { return }
            let card = BlackjackEngine.draw(&tournament)
            tournament.player.cards.append(card)
            state.tournament = tournament
            if tournament.player.total >= 21 { BlackjackEngine.finishRound(&state) }
        }
        if success { feedback(.deal); announceResult() }
    }

    func stand() {
        guard !paused, game?.phase == .player else { return }
        if commit({ BlackjackEngine.finishRound(&$0) }) { feedback(.flip); announceResult() }
    }

    func doubleDown() {
        guard !paused, canDouble else { return }
        let success = commit { state in
            guard var tournament = state.tournament else { return }
            tournament.bet *= 2
            tournament.doubled = true
            let card = BlackjackEngine.draw(&tournament)
            tournament.player.cards.append(card)
            state.tournament = tournament
            BlackjackEngine.finishRound(&state)
        }
        if success { feedback(.chip); announceResult() }
    }

    func nextHand() {
        guard !paused, game?.phase == .settled else { return }
        if commit({ state in
            guard var tournament = state.tournament else { return }
            tournament.round += 1
            tournament.phase = .betting
            tournament.player = CardHand()
            tournament.dealer = CardHand()
            tournament.outcome = nil
            tournament.bet = min(tournament.bet, max(0, state.profile.balance + 1000))
            state.tournament = tournament
        }) { feedback(.tap) }
    }

    func stop() {
        guard running, !paused else { return }
        let success = commit { state in
            if state.tournament?.phase == .player { BlackjackEngine.finishRound(&state) }
            state.tournament?.phase = .finished
            if state.tournament?.finishReason == nil { state.tournament?.finishReason = .stopped }
        }
        if success { feedback(.tap); announceResult() }
    }

    func buyOrSelect(_ skin: DealerSkin) {
        let owned = state.profile.ownedSkins.contains(skin.id)
        guard owned || spendable >= skin.price else { return }
        if commit({ state in
            if !owned {
                state.profile.balance -= skin.price
                state.profile.ownedSkins.append(skin.id)
            }
            state.profile.selectedSkin = skin.id
        }) { feedback(owned ? .tap : .purchase) }
    }

    @discardableResult func reset() -> Bool {
        if commit({ $0 = SavedState() }, allowRecovery: true) {
            loadFailed = false
            tableVisible = false
            lastTick = Date()
            feedback(.tap)
            return true
        }
        return false
    }

    func tick() {
        let now = Date()
        defer { lastTick = now }
        guard !paused, running else { return }
        let delta = min(2, max(0, Int(now.timeIntervalSince(lastTick).rounded())))
        if delta > 0 { _ = commit { $0.tournament?.elapsed += delta } }
    }

    func syncAudio() {
        media.configure(preferences: state.preferences, foreground: foreground)
    }
    func feedback(_ event: CasinoMedia.Event) { media.play(event, preferences: state.preferences) }
    private func announceResult() {
        guard let outcome = game?.outcome else { return }
        feedback(outcome == .lose ? .lose : outcome == .push ? .tap : .win)
        if (game?.lastBonus ?? 0) > 0 {
            let id = game?.id
            let completed = game?.completed
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(240))
                guard let self, self.game?.id == id, self.game?.completed == completed else { return }
                self.feedback(.coins)
            }
        }
    }

    func ranking(tournament: Bool = false) -> [RankingRow] {
        var rows: [RankingRow] = [.init(id: "player", name: state.profile.nickname, avatar: nil, amount: tournament ? game?.playerEarned ?? 0 : balance, rank: 0)]
        if tournament, let game {
            rows += game.seats.compactMap { seat in
                guard let opponent = state.opponents.first(where: { $0.id == seat.id }) else { return nil }
                return RankingRow(id: seat.id, name: opponent.name, avatar: opponent.avatar, amount: seat.earned, rank: 0)
            }
        } else {
            rows += state.opponents.map { RankingRow(id: $0.id, name: $0.name, avatar: $0.avatar, amount: $0.balance, rank: 0) }
        }
        rows.sort { $0.amount == $1.amount ? $0.id < $1.id : $0.amount > $1.amount }
        for i in rows.indices {
            rows[i].rank = i > 0 && rows[i].amount == rows[i - 1].amount ? rows[i - 1].rank : i + 1
        }
        return rows
    }
}
