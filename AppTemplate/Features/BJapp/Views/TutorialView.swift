import SwiftUI

struct TutorialView: View {
    @Environment(CasinoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var required: Bool
    var onComplete: () -> Void
    @State private var page = 0
    private let count = 5
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 6) {
                    ForEach(0..<count, id: \.self) { index in
                        Capsule().fill(index <= page ? ClubStyle.gold : ClubStyle.muted.opacity(0.2)).frame(height: 3)
                    }
                }.padding(.top, 10)
                ScrollView {
                    VStack(spacing: 23) {
                        Eyebrow(text: store.text("A seat at the table", "Tu sitio en la mesa") + " · \(page + 1)/\(count)")
                        illustration.frame(height: 180).padding(.top, 15).accessibilityHidden(true)
                        Text(title).font(.system(size: 32, design: .serif)).multilineTextAlignment(.center)
                        Text(detail).font(.system(size: 16)).lineSpacing(6).foregroundStyle(ClubStyle.muted).multilineTextAlignment(.center)
                        Text(note).font(.system(size: 13, weight: .medium)).foregroundStyle(ClubStyle.gold)
                            .multilineTextAlignment(.center).padding(16).frame(maxWidth: .infinity)
                            .background(ClubStyle.panel, in: RoundedRectangle(cornerRadius: 16))
                    }.padding(.vertical, 14)
                }
                HStack(spacing: 12) {
                    if page > 0 {
                        ClubButton(title: store.text("Back", "Atrás"), gold: false) { changePage(-1) }
                    }
                    ClubButton(title: page == count - 1 ? store.text("Let's play", "A jugar") : store.text("Continue", "Continuar"), icon: "arrow.right") {
                        store.feedback(.tap)
                        if page == count - 1 {
                            store.completeTutorial()
                            guard store.state.profile.tutorialCompleted else { return }
                            dismiss()
                            onComplete()
                        } else { changePage(1) }
                    }
                }.padding(.bottom, 10)
            }.padding(.horizontal, 25).background(ClubStyle.background)
                .navigationTitle(store.text("How to play", "Cómo jugar")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !required {
                        ToolbarItem(placement: .topBarTrailing) { Button(store.text("Done", "Listo")) { dismiss() } }
                    }
                }
        }.preferredColorScheme(.dark)
    }
    private func changePage(_ delta: Int) {
        store.feedback(.tap)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { page += delta }
    }
    @ViewBuilder private var illustration: some View {
        switch page {
        case 0:
            HStack(spacing: -10) {
                CardView(card: .init(id: 0, rank: 1, suit: 0), width: 96).rotationEffect(.degrees(-9))
                CardView(card: .init(id: 1, rank: 13, suit: 1), width: 96).rotationEffect(.degrees(9))
            }
        case 1:
            HStack(spacing: 14) {
                ForEach([10, 50, 100], id: \.self) { bet in
                    ZStack {
                        Image("chip_texture").resizable().scaledToFit()
                        Circle().fill(ClubStyle.background).padding(13)
                        Text("\(bet)").font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(ClubStyle.gold)
                    }.frame(width: 80, height: 80).offset(y: bet == 50 ? -16 : 0)
                }
            }
        case 2:
            HStack(spacing: -10) {
                CardView(card: .init(id: 0, rank: 5, suit: 2), width: 78).rotationEffect(.degrees(-10))
                CardView(card: .init(id: 1, rank: 6, suit: 1), width: 78)
                CardView(card: .init(id: 2, rank: 10, suit: 0), width: 78).rotationEffect(.degrees(10)).offset(y: -18)
            }
        case 3:
            VStack(spacing: 12) {
                Image(systemName: "trophy").font(.system(size: 56, weight: .ultraLight))
                Text("3:2").font(.system(size: 42, design: .serif))
            }.foregroundStyle(ClubStyle.gold)
        default:
            HStack(spacing: -8) {
                ForEach(0..<4, id: \.self) { i in
                    ProfileAvatar(data: nil, bot: i, size: 75).offset(y: i % 2 == 0 ? -10 : 10)
                }
            }
        }
    }
    private var title: String {
        switch page {
        case 0: return store.text("Get closer to 21.", "Acércate al 21.")
        case 1: return store.text("A little skin in the game.", "Pon algo en juego.")
        case 2: return store.text("Your next move.", "Tu siguiente jugada.")
        case 3: return store.text("Know your winnings.", "Conoce tus premios.")
        default: return store.text("Play the long game.", "Piensa a largo plazo.")
        }
    }
    private var detail: String {
        switch page {
        case 0: return store.text("Beat the dealer without going over 21. Number cards keep their value; J, Q and K count as 10. An ace is 1 or 11, whichever helps your hand. An ace and a ten-value card in your first two cards is blackjack.", "Gana al crupier sin pasarte de 21. Las cartas numéricas valen su número; J, Q y K valen 10. El as vale 1 u 11, lo que más te convenga. Un as y una carta de valor 10 en tus dos primeras cartas forman blackjack.")
        case 1: return store.text("Choose a chip: 10, 50, 100, 300 or 500 points. Tap Deal to lock your bet. You start with 1,000 points and may use credit down to −1,000. If less than 10 remains, use All-in. At −1,000, only a full reset lets you play again.", "Elige una ficha: 10, 50, 100, 300 o 500 puntos. Pulsa Repartir para confirmar. Empiezas con 1.000 puntos y puedes usar crédito hasta −1.000. Si quedan menos de 10, apuesta todo. En −1.000 solo podrás volver a jugar tras restablecer el progreso.")
        case 2: return store.text("Hit takes another card. Stand keeps your hand and lets the dealer play. Double doubles your bet, gives exactly one card, then stands. Double is available on your first two cards when your credit allows. The dealer stands on all 17s, including soft 17.", "Pedir añade una carta. Plantarse conserva tu mano y da paso al crupier. Doblar duplica tu apuesta, da exactamente una carta y termina tu turno. Solo puedes doblar con las dos primeras cartas y crédito suficiente. El crupier se planta con cualquier 17, también suave.")
        case 3: return store.text("A win earns your bet, blackjack earns 1.5 times your bet, and a tie returns your stake. A loss costs your bet. Every completed hand adds 5 points, unless the loss reaches −1,000. There is no split, insurance or surrender at this table.", "Una victoria gana el valor de tu apuesta; blackjack gana 1,5 veces la apuesta y un empate devuelve lo apostado. Una derrota pierde la apuesta. Cada mano completada añade 5 puntos, salvo al llegar a −1.000. Esta mesa no ofrece dividir, seguro ni rendición.")
        default: return store.text("Play 10 hands against seven local opponents. Tournament rank uses points earned in those hands. Club rank uses your current balance, so buying dealer skins can lower it. Stop finishes your hand as Stand and ends the tournament. Closing the app saves the exact game for later.", "Juega 10 manos contra siete rivales locales. El puesto del torneo depende de los puntos ganados en esas manos. El del club depende de tu saldo: comprar crupieres puede bajarlo. Stop termina tu mano como Plantarse y finaliza el torneo. Cerrar la app guarda la partida exacta para continuar.")
        }
    }
    private var note: String {
        switch page {
        case 0: return store.text("Six decks. One goal: beat the dealer.", "Seis barajas. Un objetivo: ganar al crupier.")
        case 1: return store.text("Points are your only currency. No real-money bets.", "Los puntos son tu única moneda. Sin apuestas de dinero real.")
        case 2: return store.text("Going over 21 is a bust, even if the dealer busts too.", "Pasarte de 21 es perder, aunque el crupier también se pase.")
        case 3: return store.text("Both have blackjack? It's a push.", "¿Ambos tienen blackjack? Es un empate.")
        default: return store.text("Menu, shop and settings pause your game and timer.", "El menú, la tienda y los ajustes pausan la partida y el reloj.")
        }
    }
}
