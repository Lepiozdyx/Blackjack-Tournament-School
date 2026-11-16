import Foundation

/// Pure game rules. UI effects never decide or apply a payout.
enum BlackjackEngine {
    static func makeTournament(opponents: [Opponent]) -> Tournament {
        let shoe = (0..<312).map { PlayingCard(id: $0, rank: ($0 % 52) % 13 + 1, suit: ($0 % 52) / 13) }.shuffled()
        return Tournament(shoe: shoe, seats: opponents.shuffled().prefix(7).map { TournamentSeat(id: $0.id) })
    }

    static func draw(_ game: inout Tournament) -> PlayingCard {
        // Six decks cover ten ordinary rounds; replenish only if the shoe is exhausted.
        if game.shoe.isEmpty {
            game.shoe = (0..<312).map { PlayingCard(id: 312 * (game.round + 1) + $0, rank: ($0 % 52) % 13 + 1, suit: ($0 % 52) / 13) }.shuffled()
        }
        return game.shoe.removeLast()
    }

    static func deal(_ game: inout Tournament, opponents: [Opponent]) {
        game.player = CardHand()
        game.dealer = CardHand()
        game.doubled = false
        game.outcome = nil
        game.lastDelta = 0
        game.lastBonus = 0
        for i in game.seats.indices {
            game.seats[i].hand = CardHand()
            game.seats[i].outcome = nil
            game.seats[i].doubled = false
            let balance = opponents.first(where: { $0.id == game.seats[i].id })?.balance ?? 0
            let suggested = Decimal([10, 50, 100][(game.round + i) % 3])
            game.seats[i].bet = min(suggested, max(0, balance + 1000))
        }
        for _ in 0..<2 {
            let playerCard = draw(&game)
            game.player.cards.append(playerCard)
            let dealerCard = draw(&game)
            game.dealer.cards.append(dealerCard)
            for i in game.seats.indices where game.seats[i].bet > 0 {
                let card = draw(&game)
                game.seats[i].hand.cards.append(card)
            }
        }
        game.phase = .player
    }

    static func outcome(player: CardHand, dealer: CardHand) -> HandOutcome {
        if player.bust { return .lose }
        if player.blackjack && dealer.blackjack { return .push }
        if dealer.blackjack { return .lose }
        if player.blackjack { return .blackjack }
        if dealer.bust || player.total > dealer.total { return .win }
        if player.total == dealer.total { return .push }
        return .lose
    }

    static func net(_ outcome: HandOutcome, bet: Decimal) -> Decimal {
        switch outcome {
        case .lose: return -bet
        case .push: return 0
        case .win: return bet
        case .blackjack: return Money.rounded(bet * Decimal(string: "1.5")!)
        }
    }

    private static func botAction(_ hand: CardHand, upcard: Int) -> String {
        if hand.soft {
            if hand.total >= 19 { return "stand" }
            if hand.total == 18 { return (3...6).contains(upcard) ? "double" : (upcard >= 9 ? "hit" : "stand") }
            if (hand.total == 17 && (3...6).contains(upcard)) || ((15...16).contains(hand.total) && (4...6).contains(upcard)) || ((13...14).contains(hand.total) && (5...6).contains(upcard)) { return "double" }
            return "hit"
        }
        if hand.total >= 17 { return "stand" }
        if hand.total == 11 && upcard != 11 { return "double" }
        if hand.total == 10 && upcard <= 9 { return "double" }
        if hand.total == 9 && (3...6).contains(upcard) { return "double" }
        if (13...16).contains(hand.total) && upcard <= 6 { return "stand" }
        if hand.total == 12 && (4...6).contains(upcard) { return "stand" }
        return "hit"
    }

    static func finishRound(_ state: inout SavedState) {
        guard var game = state.tournament, game.phase == .player else { return }
        let upcard = game.dealer.cards.first.map { $0.rank == 1 ? 11 : $0.value } ?? 10
        for i in game.seats.indices where game.seats[i].bet > 0 {
            let balance = state.opponents.first(where: { $0.id == game.seats[i].id })?.balance ?? 0
            if !game.dealer.blackjack {
                while !game.seats[i].hand.bust && !game.seats[i].hand.blackjack {
                    let action = botAction(game.seats[i].hand, upcard: upcard)
                    if action == "stand" { break }
                    let mayDouble = game.seats[i].hand.cards.count == 2 && game.seats[i].bet * 2 <= balance + 1000
                    if action == "double" && mayDouble {
                        game.seats[i].bet *= 2
                        game.seats[i].doubled = true
                        let card = draw(&game)
                        game.seats[i].hand.cards.append(card)
                        break
                    }
                    // A soft 18 double falls back to stand if doubling is unavailable.
                    if action == "double" && game.seats[i].hand.soft && game.seats[i].hand.total == 18 { break }
                    let card = draw(&game)
                    game.seats[i].hand.cards.append(card)
                }
            }
        }
        while game.dealer.total < 17 {
            let card = draw(&game)
            game.dealer.cards.append(card)
        }
        let result = outcome(player: game.player, dealer: game.dealer)
        let wagerDelta = net(result, bet: game.bet)
        let afterWager = max(-1000, Money.rounded(state.profile.balance + wagerDelta))
        let bonus: Decimal = afterWager <= -1000 ? 0 : 5
        let delta = Money.rounded(afterWager + bonus - state.profile.balance)
        state.profile.balance = afterWager + bonus
        state.profile.handsPlayed += 1
        if result == .win || result == .blackjack { state.profile.handsWon += 1 }
        game.playerEarned += delta
        game.lastDelta = delta
        game.lastBonus = bonus
        game.outcome = result
        for i in game.seats.indices where game.seats[i].bet > 0 {
            guard let index = state.opponents.firstIndex(where: { $0.id == game.seats[i].id }) else { continue }
            let result = outcome(player: game.seats[i].hand, dealer: game.dealer)
            let old = state.opponents[index].balance
            let settled = max(-1000, Money.rounded(old + net(result, bet: game.seats[i].bet)))
            let updated = settled + (settled > -1000 ? 5 : 0)
            state.opponents[index].balance = updated
            game.seats[i].earned += updated - old
            game.seats[i].outcome = result
        }
        game.completed += 1
        game.phase = .settled
        if state.profile.balance <= -1000 {
            game.phase = .finished
            game.finishReason = .bankrupt
        } else if game.completed == 10 {
            game.phase = .finished
            game.finishReason = .completed
        }
        state.tournament = game
    }
}
