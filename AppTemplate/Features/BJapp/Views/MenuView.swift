import SwiftUI

enum MenuRoute: Hashable {
    case profile, leaderboard, shop, settings
}

struct MenuView: View {
    @Environment(CasinoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private var showTournament: Bool
    @State private var path: [MenuRoute]
    init(showTournament: Bool = false) {
        self.showTournament = showTournament
        _path = State(initialValue: showTournament ? [.leaderboard] : [])
    }
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    HStack(spacing: 15) {
                        ProfileAvatar(data: store.state.profile.avatarData, size: 62)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(store.state.profile.nickname).font(.system(size: 27, design: .serif))
                        }
                    }.padding(.vertical, 14)
                    VStack(spacing: 12) {
                        entry(.profile, icon: "person.crop.circle", title: store.text("Profile", "Perfil"), detail: store.text("Make the table yours", "Dale tu toque a la mesa"))
                        entry(.leaderboard, icon: "trophy", title: store.text("Leaderboard", "Clasificación"), detail: store.text("Your place among the players", "Tu puesto entre los jugadores"))
                        entry(.shop, icon: "suit.club", title: store.text("Dealer collection", "Colección de crupieres"), detail: store.text("A new face at your table", "Una nueva cara en tu mesa"))
                        entry(.settings, icon: "slider.horizontal.3", title: store.text("Settings", "Ajustes"), detail: store.text("Play your way", "Juega a tu manera"))
                    }
                }.padding(24)
            }
            .background(ClubStyle.background).navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { store.feedback(.tap); dismiss() } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).padding(8) }
                        .accessibilityLabel(store.text("Close menu", "Cerrar menú"))
                }
            }
            .navigationDestination(for: MenuRoute.self) { route in
                switch route {
                case .profile: ProfileView()
                case .leaderboard: LeaderboardView(initialTournament: showTournament)
                case .shop: ShopView()
                case .settings: SettingsView(onReset: { dismiss() })
                }
            }
        }.tint(ClubStyle.gold).preferredColorScheme(.dark)
    }
    private func entry(_ route: MenuRoute, icon: String, title: String, detail: String) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 17) {
                Image(systemName: icon).font(.system(size: 23, weight: .light)).foregroundStyle(ClubStyle.gold).frame(width: 36)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 17, weight: .medium)).foregroundStyle(ClubStyle.ivory)
                    Text(detail).font(.system(size: 12)).foregroundStyle(ClubStyle.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(ClubStyle.muted)
            }.clubPanel()
        }.simultaneousGesture(TapGesture().onEnded { store.feedback(.tap) })
    }
}

struct LeaderboardView: View {
    @Environment(CasinoStore.self) private var store
    @State private var tournament = false
    init(initialTournament: Bool = false) { _tournament = State(initialValue: initialTournament) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if store.game != nil {
                    HStack(spacing: 4) {
                        ForEach([false, true], id: \.self) { isTournament in
                            Button { tournament = isTournament; store.feedback(.tap) } label: {
                                Text(isTournament ? store.text("Tournament", "Torneo") : store.text("Club ranking", "Clasificación del club"))
                                    .font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .foregroundStyle(tournament == isTournament ? ClubStyle.background : ClubStyle.ivory)
                                    .background(tournament == isTournament ? ClubStyle.gold : .clear, in: Capsule())
                            }.buttonStyle(.plain).accessibilityAddTraits(tournament == isTournament ? .isSelected : [])
                        }
                    }.padding(4).background(ClubStyle.panel, in: Capsule())
                }
                VStack(alignment: .leading, spacing: 7) {
                    if tournament {
                        Eyebrow(text: store.text("8 seats · 10 hands", "8 puestos · 10 manos"))
                        Text(store.text("The tournament table", "La tabla del torneo"))
                            .font(.system(size: 29, design: .serif))
                    }
                    Text(tournament ? store.text("Ranked by points earned this tournament. Ties share a place.", "Por puntos ganados en este torneo. Los empates comparten puesto.") : store.text("Your current balance is your rank. Meet your local opponents.", "Tu saldo actual determina tu puesto. Conoce a tus rivales locales."))
                        .font(.footnote).foregroundStyle(ClubStyle.muted)
                }
                RankingList(rows: store.ranking(tournament: tournament), signed: tournament)
                if tournament, let game = store.game {
                    Text(store.text("Hands completed: \(game.completed) / 10", "Manos completadas: \(game.completed) / 10"))
                        .font(.footnote).foregroundStyle(ClubStyle.muted)
                }
            }.padding(22)
        }.background(ClubStyle.background).navigationTitle(store.text("Leaderboard", "Clasificación")).navigationBarTitleDisplayMode(.inline)
    }
}

struct RankingList: View {
    @Environment(CasinoStore.self) private var store
    var rows: [RankingRow]
    var signed = false
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(rows) { row in
                HStack(spacing: 11) {
                    Text(String(format: "%02d", row.rank)).font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(row.rank <= 3 ? ClubStyle.gold : ClubStyle.muted).frame(width: 25)
                    ProfileAvatar(data: row.isPlayer ? store.state.profile.avatarData : nil, bot: row.avatar, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.name).font(.system(size: 14, weight: .medium)).lineLimit(1)
                        if row.isPlayer {
                            Text(store.text("YOU", "TÚ")).font(.system(size: 8, weight: .bold)).tracking(2).foregroundStyle(ClubStyle.gold)
                        }
                    }
                    Spacer(minLength: 4)
                    Text((signed && row.amount > 0 ? "+" : "") + store.points(row.amount))
                        .font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(row.isPlayer ? ClubStyle.gold : ClubStyle.ivory)
                }
                .padding(12).background(row.isPlayer ? ClubStyle.green.opacity(0.4) : ClubStyle.panel, in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(ClubStyle.gold.opacity(row.isPlayer ? 0.5 : 0)))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct TournamentResultsView: View {
    @Environment(CasinoStore.self) private var store
    var onClose: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: store.game?.finishReason == .bankrupt ? "suit.spade" : "trophy").font(.system(size: 42, weight: .ultraLight)).foregroundStyle(ClubStyle.gold).padding(.top, 20)
                    Eyebrow(text: store.text("The final hand", "La última mano"))
                    Text(title).font(.system(size: 31, design: .serif)).multilineTextAlignment(.center)
                    HStack {
                        metric(store.text("EARNED", "GANADO"), value: (store.game?.playerEarned ?? 0) > 0 ? "+" + store.points(store.game?.playerEarned ?? 0) : store.points(store.game?.playerEarned ?? 0))
                        Spacer()
                        metric(store.text("BALANCE", "SALDO"), value: store.points(store.balance))
                        Spacer()
                        metric(store.text("HANDS", "MANOS"), value: "\(store.game?.completed ?? 0)/10")
                    }.clubPanel()
                    if store.game?.finishReason == .bankrupt {
                        Text(store.text("You've reached the −1,000 credit limit. Reset all progress in Settings to return to the table.", "Has alcanzado el límite de crédito de −1.000. Restablece el progreso en Ajustes para volver a la mesa."))
                            .font(.footnote).foregroundStyle(ClubStyle.muted).multilineTextAlignment(.center)
                    }
                    RankingList(rows: store.ranking(tournament: true), signed: true)
                }.padding(22)
            }.background(ClubStyle.background)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(store.text("OK", "OK")) {
                            store.feedback(.tap)
                            onClose()
                        }
                    }
                }
        }.tint(ClubStyle.gold).preferredColorScheme(.dark)
    }
    private var title: String {
        switch store.game?.finishReason {
        case .bankrupt: return store.text("Time for a fresh start.", "Es hora de empezar de nuevo.")
        case .stopped: return store.text("Your progress is saved.", "Tu progreso está guardado.")
        default: return store.text("Tournament complete.", "Torneo completado.")
        }
    }
    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(ClubStyle.muted)
            Text(value).font(.system(size: 20, weight: .medium, design: .rounded)).foregroundStyle(ClubStyle.gold).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}
