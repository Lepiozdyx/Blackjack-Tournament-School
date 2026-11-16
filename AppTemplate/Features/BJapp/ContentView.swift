import SwiftUI
import Combine

private enum ClubRoute: Hashable {
    case school
}

struct ContentView: View {
    @Environment(CasinoStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showMenu = false
    @State private var menuTournament = false
    @State private var menuDetent: PresentationDetent = .large
    @State private var showTutorial = false
    @State private var showResults = false
    @State private var startAfterTutorial = false
    @State private var lockedUntil = Date.distantPast
    @State private var showResultToast = false
    @State private var presentationBusy = false
    @State private var presentationDuration = 0.0
    @State private var presentationToken = UUID()
    @State private var shoeCenter: CGPoint?
    @State private var path = NavigationPath()
    @State private var adaptiveHeights = TableContentHeights()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack(path: $path) {
            table
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: ClubRoute.self) { route in
                    switch route {
                    case .school: GameSchoolView()
                    }
                }
        }
        .tint(ClubStyle.gold)
        .preferredColorScheme(.dark)
        .onChange(of: path) { _, _ in updateOverlay() }
        .onChange(of: scenePhase) { _, phase in store.foreground = phase == .active; store.syncAudio() }
    }

    private var table: some View {
        GeometryReader { geometry in
            let layout = TableLayout(geometry: geometry, horizontalSizeClass: horizontalSizeClass)
            ZStack {
                if layout.adaptive {
                    adaptiveTable(layout)
                } else {
                    classicTable(height: geometry.size.height)
                }
                if showResultToast, let game = store.game, let outcome = game.outcome {
                    Group {
                        if layout.adaptive {
                            resultToast(outcome, delta: game.lastDelta)
                                .position(x: layout.region.midX, y: layout.region.midY)
                        } else {
                            resultToast(outcome, delta: game.lastDelta)
                        }
                    }
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.7).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .foregroundStyle(ClubStyle.ivory)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showMenu) {
            MenuView(showTournament: menuTournament).environment(store)
                .presentationDetents(menuTournament ? [.medium, .large] : [.large], selection: $menuDetent)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTutorial) {
            TutorialView(required: startAfterTutorial) {
                if startAfterTutorial {
                    startAfterTutorial = false
                    store.enterTable()
                }
            }.environment(store).interactiveDismissDisabled(startAfterTutorial)
        }
        .sheet(isPresented: $showResults) {
            TournamentResultsView {
                showResults = false
                store.tableVisible = false
            }.environment(store).interactiveDismissDisabled()
        }
        .alert(store.text("Something needs attention", "Algo necesita atención"), isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .onReceive(ticker) { _ in store.tick() }
        .onChange(of: showMenu) { _, _ in updateOverlay() }
        .onChange(of: showTutorial) { _, _ in updateOverlay() }
        .onChange(of: showResults) { _, _ in updateOverlay() }
        .task(id: resultKey) {
            guard resultKey != nil else { showResultToast = false; return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.35)) { showResultToast = true }
            do { try await Task.sleep(for: .seconds(1.5)) }
            catch { return }
            withAnimation { showResultToast = false }
            if store.game?.phase == .finished && store.tableVisible { showResults = true }
        }
        .task(id: presentationToken) {
            guard presentationBusy else { return }
            do { try await Task.sleep(for: .seconds(presentationDuration)) }
            catch { return }
            presentationBusy = false
        }
        .onAppear { store.foreground = scenePhase == .active; store.syncAudio() }
        .task(id: autoAdvanceKey) {
            guard let key = autoAdvanceKey else { return }
            do { try await Task.sleep(for: .seconds(2)) }
            catch { return }
            guard !Task.isCancelled, autoAdvanceKey == key else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) {
                store.nextHand()
            }
        }
    }

    private func classicTable(height: CGFloat) -> some View {
        ZStack {
            CasinoScene(skin: store.state.profile.selectedSkin, playing: store.tableVisible)
            VStack(spacing: 8) {
                toolbar
                if store.tableVisible {
                    Color.clear.frame(height: 17).accessibilityHidden(true)
                }
                Spacer(minLength: 0).frame(height: height * (store.tableVisible ? (height < 700 ? 0.13 : 0.16) : 0.41))
                if store.tableVisible, let game = store.game {
                    playfield(game, height: height)
                } else {
                    welcome(height: height)
                }
                Spacer(minLength: 4)
                if store.tableVisible { controls.disabled(presentationBusy) }
                else { startControls }
            }.padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 12)
        }
    }

    private func adaptiveTable(_ layout: TableLayout) -> some View {
        let playing = store.tableVisible
        let fieldHeight = playing ? adaptiveHeights.field : 210
        let controlsHeight = playing ? adaptiveHeights.controls : max(62, adaptiveHeights.controls)
        let placement = layout.placement(playing: playing, fieldHeight: fieldHeight, controlsHeight: controlsHeight)
        let dx = -layout.region.minX
        let dy = -layout.region.minY
        return ZStack(alignment: .topLeading) {
            Image("casino_background").resizable().scaledToFill()
                .frame(width: layout.canvas.width, height: layout.canvas.height).clipped()
                .overlay(.black.opacity(0.16))
                .tableFrame(layout.canvas)
                .accessibilityHidden(true)
            ScrollView(.vertical) {
                ZStack(alignment: .topLeading) {
                    CasinoScene(skin: store.state.profile.selectedSkin, playing: playing,
                                placement: placement, stageWidth: layout.sceneWidth,
                                origin: layout.region.origin)
                    if playing, let game = store.game {
                        roundHeader(game)
                            .frame(width: min(layout.contentWidth, layout.toolbarFrame.width))
                            .position(x: layout.toolbarFrame.midX + dx,
                                      y: max(layout.toolbarFrame.maxY + 30, placement.railY - 30) + dy)
                        playfield(game, height: layout.referenceHeight, availableWidth: placement.field.width)
                            .fixedSize(horizontal: false, vertical: true)
                            .tableHeight("field")
                            .tableFrame(placement.field.offsetBy(dx: dx, dy: dy))
                    } else {
                        welcome(height: layout.referenceHeight, constrained: true)
                            .tableFrame(placement.field.offsetBy(dx: dx, dy: dy))
                    }
                    Group {
                        if playing { controls.disabled(presentationBusy) }
                        else { startControls }
                    }
                    .frame(width: placement.controls.width)
                    .fixedSize(horizontal: false, vertical: true)
                    .tableHeight("controls")
                    .tableFrame(placement.controls.offsetBy(dx: dx, dy: dy))
                    adaptiveToolbar.tableFrame(layout.toolbarFrame.offsetBy(dx: dx, dy: dy))
                }
                .frame(width: layout.region.width, height: placement.height)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .tableFrame(layout.region)
        }
        .onPreferenceChange(TableContentHeightKey.self) { heights in
            var next = adaptiveHeights
            if playing, let field = heights["field"] { next.field = field }
            if let controls = heights["controls"] { next.controls = controls }
            if next != adaptiveHeights { adaptiveHeights = next }
        }
    }

    private var resultKey: String? {
        guard let game = store.game, game.outcome != nil || game.phase == .finished,
              !presentationBusy, store.tableVisible, scenePhase == .active,
              path.isEmpty, !showMenu, !showTutorial, !showResults else { return nil }
        return "\(game.id)-\(game.completed)-\(game.phase)"
    }

    private var animateCards: Bool {
        presentationBusy && scenePhase == .active && path.isEmpty && !showMenu && !showTutorial && !showResults
    }

    private var autoAdvanceKey: String? {
        guard let game = store.game, game.phase == .settled, !presentationBusy,
              store.tableVisible, scenePhase == .active,
              path.isEmpty, !showMenu, !showTutorial, !showResults, store.errorMessage == nil else { return nil }
        return "\(game.id)-\(game.round)"
    }

    private func updateOverlay() { store.overlayVisible = !path.isEmpty || showMenu || showTutorial || showResults }
    private func perform(_ action: () -> Void) {
        guard !presentationBusy, Date() >= lockedUntil else { return }
        let previous = store.game
        withAnimation(reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.86)) { action() }
        guard let current = store.game else { return }
        let cardsChanged = previous?.player != current.player || previous?.dealer != current.dealer
        let openedHole = previous?.phase == .player && current.phase != .player
        guard cardsChanged || openedHole else { return }
        // Only presentation is delayed. The engine has already saved the full action atomically.
        presentationDuration = reduceMotion ? 0.15 : max(0.95, 1.1 + Double(max(0, current.dealer.cards.count - 2)) * 0.18)
        lockedUntil = Date().addingTimeInterval(presentationDuration)
        presentationBusy = true
        presentationToken = UUID()
    }

    private var toolbar: some View {
        HStack {
            leadingTool
            Spacer()
            balanceDisplay
            Spacer()
            menuTool
        }
    }

    private var adaptiveToolbar: some View {
        HStack(spacing: 12) {
            leadingTool
            balanceDisplay.frame(maxWidth: 110).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            menuTool
        }
    }

    @ViewBuilder private var leadingTool: some View {
        if store.tableVisible && store.running {
            CircleTool(icon: "stop.fill", label: store.text("End tournament", "Terminar torneo")) { perform { store.stop() } }
        } else {
            Image(systemName: "suit.spade.fill").font(.system(size: 23)).foregroundStyle(ClubStyle.gold).frame(width: 46, height: 46)
        }
    }

    private var balanceDisplay: some View {
        VStack(spacing: 3) {
            Text(store.text("YOUR BALANCE", "TU SALDO")).font(.system(size: 8, weight: .semibold)).tracking(2).foregroundStyle(ClubStyle.muted)
            HStack(spacing: 6) {
                Image(systemName: "circle.circle").font(.system(size: 13)).foregroundStyle(ClubStyle.gold)
                Text(store.points(store.balance)).font(.system(size: 23, weight: .medium, design: .rounded)).contentTransition(.numericText())
            }
        }.accessibilityElement(children: .combine)
    }

    private var menuTool: some View {
        CircleTool(icon: "ellipsis", label: store.text("Open menu", "Abrir menú")) { store.feedback(.tap); menuTournament = false; menuDetent = .large; showMenu = true }
    }

    private func welcome(height: CGFloat, constrained: Bool = false) -> some View {
        VStack(spacing: height < 650 ? 10 : 18) {
            Text("BLACKJACK").font(.system(size: min(42, height * 0.063), weight: .regular, design: .serif)).tracking(3)
                .lineLimit(constrained ? 1 : nil).minimumScaleFactor(constrained ? 0.6 : 1)
            HStack(spacing: -12) {
                CardView(card: .init(id: 0, rank: 1, suit: 0), width: min(74, height * 0.115)).rotationEffect(.degrees(-12)).offset(y: 2)
                CardView(card: .init(id: 1, rank: 13, suit: 1), width: min(74, height * 0.115)).rotationEffect(.degrees(10))
            }.padding(.vertical, 5).accessibilityHidden(true)
        }.frame(maxWidth: .infinity)
    }

    private var startControls: some View {
        VStack(spacing: 13) {
            if store.balance <= -1000 || store.loadFailed {
                Text(store.loadFailed ? store.text("Open Settings to reset unreadable progress.", "Abre Ajustes para restablecer el progreso ilegible.") : store.text("Credit limit reached. Reset progress in Settings to play again.", "Límite de crédito alcanzado. Restablece el progreso en Ajustes para jugar."))
                    .font(.footnote).multilineTextAlignment(.center).foregroundStyle(ClubStyle.gold)
                ClubButton(title: store.text("Open menu", "Abrir menú"), icon: "ellipsis") { showMenu = true }
            } else {
                ClubButton(title: store.running ? store.text("Continue tournament", "Continuar torneo") : store.text("Start tournament", "Empezar torneo"), icon: "arrow.right") {
                    if store.state.profile.tutorialCompleted { store.enterTable() }
                    else { startAfterTutorial = true; showTutorial = true }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if !store.running {
                SchoolChipButton(title: store.text("School", "Escuela"),
                                 animated: path.isEmpty && !showMenu && !showTutorial && !showResults && store.errorMessage == nil) {
                    guard !store.running, path.isEmpty else { return }
                    store.feedback(.tap)
                    path.append(ClubRoute.school)
                }
                .offset(y: -(SchoolChipButton.diameter + SchoolChipButton.startSpacing))
            }
        }
        .padding(.top, 10)
    }

    private func roundHeader(_ game: Tournament) -> some View {
        HStack {
            Eyebrow(text: store.text("Hand \(game.round) / 10", "Mano \(game.round) / 10"))
            Spacer()
            Label(store.clock, systemImage: "timer").monospacedDigit().font(.system(size: 12)).foregroundStyle(ClubStyle.gold)
            Button { menuTournament = true; menuDetent = .medium; showMenu = true } label: { Image(systemName: "person.3").font(.system(size: 14)).padding(.leading, 12) }
                .accessibilityLabel(store.text("Participants", "Participantes"))
        }.padding(.horizontal, 10).padding(.vertical, 7).background(.black.opacity(0.42), in: Capsule())
    }

    private func playfield(_ game: Tournament, height: CGFloat, availableWidth: CGFloat? = nil) -> some View {
        let cardWidth = min(65, height * (height < 700 ? 0.082 : 0.105))
        return VStack(spacing: availableWidth == nil ? (height < 650 ? 8 : 16) : 6) {
            if availableWidth == nil { roundHeader(game) }
            VStack(spacing: 6) {
                handLabel(store.text("DEALER", "CRUPIER"), total: game.dealer.cards.isEmpty ? nil : game.phase == .player ? game.dealer.cards.first?.value : game.dealer.total, hidden: game.phase == .player)
                if game.dealer.cards.isEmpty {
                    HStack(spacing: -12) { CardView(card: nil, width: cardWidth); CardView(card: nil, width: cardWidth) }.opacity(0.5).accessibilityHidden(true)
                } else {
                    HandView(hand: game.dealer, hideHole: game.phase == .player, width: cardWidth, spanish: store.spanish, animateDeals: animateCards, dealer: true, source: shoeCenter, availableWidth: availableWidth.map { $0 - 2 * (cardWidth * 0.52 + 20) })
                        .transition(cardRemoval)
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        CardView(card: nil, width: cardWidth * 0.52)
                            .offset(x: CGFloat(index) * 2, y: CGFloat(index) * -2)
                    }
                }.background(GeometryReader { proxy in
                    Color.clear.preference(key: ShoeCenterKey.self, value: CGPoint(x: proxy.frame(in: .global).midX, y: proxy.frame(in: .global).midY))
                }).padding(.trailing, 4).accessibilityLabel(store.text("Card shoe", "Mazo de cartas"))
            }
            .padding(.top, availableWidth == nil ? (height < 650 ? 12 : 18) : 0)
            HStack(spacing: 10) {
                Rectangle().fill(ClubStyle.gold.opacity(0.18)).frame(height: 1)
                Image(systemName: "suit.spade.fill").font(.system(size: 12)).foregroundStyle(ClubStyle.gold.opacity(0.5))
                Rectangle().fill(ClubStyle.gold.opacity(0.18)).frame(height: 1)
            }.padding(.horizontal, 40)
            VStack(spacing: 6) {
                if game.player.cards.isEmpty {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(ClubStyle.gold.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                        .frame(width: cardWidth * 1.7, height: cardWidth * 1.45)
                        .overlay(Text(store.text("Place your bet", "Haz tu apuesta")).font(.system(size: 10)).foregroundStyle(ClubStyle.muted))
                } else { HandView(hand: game.player, width: cardWidth, spanish: store.spanish, animateDeals: animateCards, source: shoeCenter, availableWidth: availableWidth.map { $0 - 24 }).transition(cardRemoval) }
                handLabel(store.text("YOUR HAND", "TU MANO"), total: game.player.cards.isEmpty ? nil : game.player.total)
            }
            HStack(spacing: 6) {
                Image(systemName: "circle.circle").foregroundStyle(ClubStyle.gold)
                Text(store.text("Bet", "Apuesta") + "  " + store.points(game.bet))
                if game.doubled { Text("×2").foregroundStyle(ClubStyle.gold) }
                if let result = game.outcome {
                    Text("·").foregroundStyle(ClubStyle.muted)
                    Text(outcomeTitle(result)).foregroundStyle(result == .lose ? Color.orange : ClubStyle.gold)
                }
            }.font(.system(size: 12, weight: .medium))
            if game.lastBonus > 0 && game.outcome != nil {
                Text(store.text("Includes +5 hand bonus", "Incluye +5 de bonificación"))
                    .font(.system(size: 10)).foregroundStyle(ClubStyle.muted)
                    .padding(.top, height < 650 ? -4 : -8)
            }
        }.frame(maxWidth: .infinity)
            .onPreferenceChange(ShoeCenterKey.self) { shoeCenter = $0 }
    }

    private var cardRemoval: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .identity, removal: .offset(x: -100, y: -24).combined(with: .scale(scale: 0.8)).combined(with: .opacity))
    }

    private func handLabel(_ title: String, total: Int?, hidden: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 9, weight: .semibold)).tracking(2)
            if let total {
                Text("\(total)" + (hidden ? " + ?" : "")).font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 7).padding(.vertical, 3).background(.black.opacity(0.3), in: Capsule())
            }
        }.foregroundStyle(ClubStyle.ivory.opacity(0.75))
    }

    private var controls: some View {
        VStack(spacing: 14) {
            if store.game?.phase != .finished && !(store.game?.phase == .betting && store.credit < 10) {
                HStack(spacing: 10) {
                    ForEach([10, 50, 100, 300, 500], id: \.self) { value in
                        chip(value)
                    }
                }.frame(maxWidth: .infinity).frame(height: 54).disabled(store.game?.phase != .betting)
                    .opacity(store.game?.phase == .betting ? 1 : 0.6)
            }
            if store.game?.phase == .betting {
                if store.credit > 0 && store.credit < 10 {
                    ClubButton(title: store.text("All-in · ", "Todo · ") + store.points(store.credit), icon: "circle.circle", gold: false) { store.selectBet(store.credit) }
                }
                ClubButton(title: store.text("Deal cards", "Repartir cartas"), icon: "suit.spade.fill") { perform { store.deal() } }
            } else if store.game?.phase == .player {
                HStack(spacing: 9) {
                    ClubButton(title: store.text("Hit", "Pedir"), icon: "plus", gold: false) { perform { store.hit() } }
                    ClubButton(title: store.text("Stand", "Plantarse"), icon: "hand.raised") { perform { store.stand() } }
                    ClubButton(title: store.text("Double", "Doblar"), icon: "multiply", gold: false) { perform { store.doubleDown() } }.disabled(!store.canDouble)
                }
            } else if store.game?.phase == .settled {
                Color.clear.frame(height: 52).accessibilityHidden(true)
            } else {
                ClubButton(title: store.text("View results", "Ver resultados"), icon: "trophy") { showResults = true }
            }
        }.padding(.top, 8)
    }

    private func chip(_ value: Int) -> some View {
        let selected = store.game?.bet == Decimal(value)
        return Button { store.selectBet(Decimal(value)) } label: {
            ZStack {
                Image("chip_texture").resizable().scaledToFit()
                Circle().fill(selected ? ClubStyle.gold.opacity(0.9) : ClubStyle.background.opacity(0.82)).padding(7)
                Circle().strokeBorder(ClubStyle.gold.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [4, 4])).padding(3)
                Text("\(value)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(selected ? ClubStyle.background : ClubStyle.ivory)
            }.frame(maxWidth: 60).aspectRatio(1, contentMode: .fit)
                .shadow(color: selected ? ClubStyle.gold.opacity(0.22) : .clear, radius: 8)
                .offset(y: selected && !reduceMotion ? -4 : 0)
        }.buttonStyle(.plain).disabled(Decimal(value) > store.credit)
            .opacity(Decimal(value) > store.credit ? 0.3 : 1)
            .accessibilityLabel(store.text("Bet \(value) points", "Apostar \(value) puntos"))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func outcomeTitle(_ outcome: HandOutcome) -> String {
        switch outcome {
        case .win: return store.text("You win", "Has ganado")
        case .lose: return store.text("You lose", "Has perdido")
        case .push: return store.text("Push", "Empate")
        case .blackjack: return "Blackjack!"
        }
    }
    private func resultToast(_ outcome: HandOutcome, delta: Decimal) -> some View {
        VStack(spacing: 9) {
            Image(systemName: outcome == .lose ? "suit.spade" : outcome == .push ? "equal" : "sparkles").font(.system(size: 24))
            Text(outcomeTitle(outcome)).font(.system(size: 30, design: .serif))
            Text((delta > 0 ? "+" : "") + store.points(delta)).font(.system(size: 22, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(outcome == .lose ? ClubStyle.ivory : ClubStyle.gold)
        .padding(.vertical, 24).frame(width: 240)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(ClubStyle.gold.opacity(0.4)))
        .accessibilityElement(children: .combine)
    }
}

private struct CasinoScene: View {
    var skin: String
    var playing: Bool
    var placement: TablePlacement? = nil
    var stageWidth: CGFloat = 0
    var origin: CGPoint = .zero
    var body: some View {
        if let placement {
            let dx = -(origin.x + stageWidthOffset)
            let dy = -origin.y
            ZStack(alignment: .topLeading) {
                Image("dealer_\(skin)").resizable().scaledToFit()
                    .tableFrame(placement.dealer.offsetBy(dx: dx, dy: dy))
                Image("table").resizable().scaledToFit()
                    .tableFrame(placement.table.offsetBy(dx: dx, dy: dy))
                LinearGradient(colors: [.clear, ClubStyle.background.opacity(0.65)], startPoint: .center, endPoint: .bottom)
            }
            .frame(width: stageWidth, height: placement.height).clipped()
            .position(x: stageWidthOffset + stageWidth / 2, y: placement.height / 2)
            .accessibilityHidden(true)
        } else {
            classic
        }
    }
    private var stageWidthOffset: CGFloat { (placement.map { $0.field.midX - origin.x } ?? 0) - stageWidth / 2 }
    private var classic: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                Image("casino_background").resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped()
                Color.black.opacity(0.16)
                Image("dealer_\(skin)").resizable().scaledToFit()
                    .frame(width: g.size.width * 0.88, height: g.size.height * (playing ? 0.30 : 0.39), alignment: .bottom)
                    .position(x: g.size.width / 2, y: g.size.height * (playing ? 0.285 : 0.30))
                Image("table").resizable().frame(width: g.size.width * 1.75, height: g.size.height * (playing ? 0.80 : 0.70))
                    .position(x: g.size.width / 2, y: g.size.height * (playing ? 0.71 : 0.77))
                LinearGradient(colors: [.clear, ClubStyle.background.opacity(0.18), ClubStyle.background.opacity(0.95)], startPoint: .center, endPoint: .bottom)
            }.frame(width: g.size.width, height: g.size.height).clipped()
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

private struct ShoeCenterKey: PreferenceKey {
    static var defaultValue: CGPoint? { nil }
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}
