import SwiftUI
import Charts

struct GameSchoolView: View {
    @Environment(CasinoStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
//                Label(store.text("Practice without stakes", "Practica sin apuestas"), systemImage: "graduationcap")
//                    .font(.title2.weight(.medium)).foregroundStyle(ClubStyle.gold)
                if SchoolMathData.bundled != nil {
                    ForEach(SchoolLesson.allCases) { lesson in
                        NavigationLink(value: lesson) { lessonCard(lesson) }.buttonStyle(.plain)
                    }
                } else {
                    ContentUnavailableView(store.text("Lessons unavailable", "Lecciones no disponibles"), systemImage: "book.closed",
                        description: Text(store.text("The lesson resources could not be read. Please reinstall the app without deleting your progress.", "No se pudieron leer los recursos. Reinstala la app sin eliminar tu progreso.")))
                }
            }.padding(22)
        }
        .background(ClubStyle.background).foregroundStyle(ClubStyle.ivory)
        .navigationTitle(store.text("Game School", "Escuela de blackjack")).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationDestination(for: SchoolLesson.self) { lesson in
            if let data = SchoolMathData.bundled { SchoolLessonView(lesson: lesson, data: data) }
        }
    }
    private func lessonCard(_ lesson: SchoolLesson) -> some View {
        // Keep the original, content-driven footprint in every language and progress state.
        // This measuring layer is neither drawn nor exposed to accessibility.
        ZStack(alignment: .leading) {
            lessonCardContent(lesson, measuring: true).hidden().accessibilityHidden(true)
            lessonCardContent(lesson, measuring: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            GeometryReader { geometry in
                Image("school_" + lesson.rawValue)
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(stops: [
                            .init(color: .black.opacity(0.86), location: 0),
                            .init(color: .black.opacity(0.73), location: 0.6),
                            .init(color: .black.opacity(0.43), location: 1)
                        ], startPoint: .leading, endPoint: .trailing)
                    }
            }
            .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.06)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("schoolLesson_" + lesson.rawValue)
    }

    private func lessonCardContent(_ lesson: SchoolLesson, measuring: Bool) -> some View {
        let record = store.school.record(lesson)
        let active = record.session != nil && record.session?.phase != .results
        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 14) {
                if measuring {
                    Image(systemName: lesson.icon).font(.system(size: 24)).frame(width: 30)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text((measuring ? "0\(lesson.number) · " : "") + lesson.title(store.spanish))
                        .font(.title3.weight(.medium))
                    Text(lesson.detail(store.spanish)).font(.subheadline).foregroundStyle(ClubStyle.ivory.opacity(0.88))
                }
                Spacer(minLength: 0)
                if measuring { Image(systemName: "chevron.right").font(.system(size: 12)) }
            }
            if let last = record.lastScore, let best = record.bestScore {
                Text(store.text("Last: \(last)/10 · Best: \(best)/10", "Último: \(last)/10 · Mejor: \(best)/10"))
                    .font(.caption).foregroundStyle(ClubStyle.ivory.opacity(0.88))
            }
            let status = active ? store.text("Continue", "Continuar") : record.completed > 0 ? store.text("Completed · Practice again", "Completado · Volver a practicar") : store.text("Explore lesson", "Explorar lección")
            Group {
                if measuring {
                    Label(status, systemImage: active ? "play.circle" : record.completed > 0 ? "checkmark.circle" : "arrow.right.circle")
                } else { Text(status) }
            }
            .font(.subheadline.weight(.medium)).foregroundStyle(ClubStyle.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

struct SchoolLessonView: View {
    @Environment(CasinoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var lesson: SchoolLesson
    var data: SchoolMathData
    @State private var confirmRestart = false
    @AccessibilityFocusState private var focusHeading: Bool
    private var session: SchoolSession? { store.school.record(lesson).session }
    private func t(_ en: String, _ es: String) -> String { store.text(en, es) }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let s = session {
                        heading(s).id("schoolTop").accessibilityFocused($focusHeading)
                        switch s.phase {
                        case .introduction: introduction(s)
                        case .question, .feedback: exercise(s)
                        case .results: results(s)
                        }
                    } else {
                        SchoolButton(title: t("Open lesson", "Abrir lección")) { store.openSchool(lesson, data: data) }
                    }
                }.padding(22)
            }.onChange(of: session?.phase) { _, _ in scrollToTop(proxy) }
                .onChange(of: session?.index) { _, _ in scrollToTop(proxy) }
        }
        .background(ClubStyle.background).foregroundStyle(ClubStyle.ivory)
        .navigationTitle(lesson.title(store.spanish)).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { confirmRestart = true } label: { Image(systemName: "arrow.counterclockwise") }
                    .accessibilityLabel(t("Start again", "Empezar de nuevo"))
            }
        }
        .onAppear { store.openSchool(lesson, data: data) }
        .alert(t("Start this lesson again?", "¿Empezar esta lección de nuevo?"), isPresented: $confirmRestart) {
            Button(t("Cancel", "Cancelar"), role: .cancel) {}
            Button(t("Start again", "Empezar de nuevo")) { store.openSchool(lesson, data: data, restart: true) }
        } message: { Text(t("This replaces the unfinished session. Completed results are kept.", "Se reemplazará la sesión en curso. Los resultados completados se conservan.")) }
        .alert(t("Progress could not be saved", "No se pudo guardar el progreso"), isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
    private func scrollToTop(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { proxy.scrollTo("schoolTop", anchor: .top) }
        focusHeading = true
    }
    private func heading(_ s: SchoolSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(s.phase == .introduction ? t("Explore first", "Primero, explora") : s.phase == .results ? t("Session complete", "Sesión completada") :
                 (s.review ? t("Review", "Repaso") : t("Practice", "Práctica")) + (s.phase == .question || s.phase == .feedback ? " · \(s.index + 1)/\(s.questions.count)" : ""))
                .font(.subheadline.weight(.semibold)).foregroundStyle(ClubStyle.gold)
            if s.phase == .question || s.phase == .feedback {
                ProgressView(value: Double(s.index), total: Double(s.questions.count)).tint(ClubStyle.gold)
                    .accessibilityLabel(t("Lesson progress", "Progreso de la lección"))
            }
        }.accessibilityAddTraits(.isHeader)
    }
    @ViewBuilder private func introduction(_ s: SchoolSession) -> some View {
        Text(lesson.detail(store.spanish)).font(.title2.weight(.medium))
        switch lesson {
        case .hand:
            Text(t("An ace is 11 only when it fits. A soft hand has an ace still worth 11. Blackjack requires exactly two cards.", "Un as vale 11 solo si no te pasas. Una mano suave tiene un as que aún vale 11. El blackjack requiere exactamente dos cartas."))
            let examples = [4, 2, 3, 6]
            let q = SchoolRules.exercises[examples[s.labIndex % examples.count]]
            handLab(q, revealed: s.labStep > 0)
            SchoolButton(title: s.labStep == 0 ? t("Reveal the change", "Revelar el cambio") : t("Try another hand", "Probar otra mano"), primary: false) {
                store.editSchool(lesson) { s in
                    if s.labStep == 0 { s.labStep = 1 } else { s.labIndex += 1; s.labStep = 0 }
                }
            }
        case .bust:
            Text(t("Select every value that would bust your hand. Ten, jack, queen and king share one value: together they start with 96 cards, versus 24 for each other value.", "Selecciona todos los valores que te harían pasar de 21. Diez, jota, reina y rey comparten valor: empiezan con 96 cartas, frente a 24 de cada otro valor."))
            let ranks = SchoolRules.bustHands[s.labIndex % SchoolRules.bustHands.count]
            SchoolCards(ranks: ranks, revealValues: true)
            Text(SchoolRules.handLabel(SchoolRules.hand(ranks), spanish: store.spanish)).font(.title3)
            bustBreakdown(ranks)
            SchoolButton(title: t("Change hand", "Cambiar mano"), primary: false) { store.editSchool(lesson) { $0.labIndex += 1 } }
        case .dealer:
            Text(t("The dealer has no choice: hit below 17, stand on every 17, including A + 6. A weak upcard increases bust risk; it never guarantees a bust.", "El crupier no elige: pide por debajo de 17 y se planta en cualquier 17, incluido A + 6. Una carta débil aumenta el riesgo; nunca garantiza pasarse."))
            dealerLab(s)
        case .move:
            Text(t("Choose the action with the highest expected net return. Double gives exactly one card for twice the exposure. After a hit, only Hit and Stand remain.", "Elige la acción con mayor resultado neto esperado. Doblar da exactamente una carta con el doble en juego. Después de pedir, solo quedan Pedir y Plantarse."))
            if !data.decisions.isEmpty {
                let d = data.decisions[s.labIndex % data.decisions.count]
                decisionCards(d)
                expectedValues(d, actions: d.actions)
                Text(decisionReason(d))
                SchoolButton(title: t("Change example", "Cambiar ejemplo"), primary: false) { store.editSchool(lesson) { $0.labIndex += 1 } }
            }
        case .distance:
            Text(t("Expected value is the average net result per unit of stake over many repetitions. −0.2 is better than −0.4, even though both lose on average. A good choice can lose a single hand.", "El valor esperado es el resultado neto medio por unidad apostada tras muchas repeticiones. −0,2 es mejor que −0,4, aunque ambos pierdan de media. Una buena elección puede perder una mano."))
            if let d = data.decisions.first {
                decisionCards(d)
                experiment(d, session: s)
            }
        }
        Text(t("10 questions · No timer · Progress saves automatically", "10 preguntas · Sin cronómetro · El progreso se guarda automáticamente"))
            .font(.footnote).foregroundStyle(ClubStyle.muted)
        SchoolButton(title: t("Start practice", "Empezar práctica")) {
            store.editSchool(lesson) { $0.phase = .question; $0.experimentCount = 0 }
        }
    }
    @ViewBuilder private func exercise(_ s: SchoolSession) -> some View {
        if let id = s.questionID {
            let i = SchoolRules.index(id)
            let answered = s.phase == .feedback
            Text(prompt).font(.title2.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            switch lesson {
            case .hand:
                let q = SchoolRules.exercises[i]
                handLab(q, revealed: answered)
                ForEach(SchoolRules.choices(q), id: \.self) { value in
                    choice(SchoolRules.label(code: value, spanish: store.spanish), value: value, session: s)
                }
            case .bust:
                let ranks = SchoolRules.bustHands[i]
                SchoolCards(ranks: ranks, revealValues: true)
                Text(SchoolRules.handLabel(SchoolRules.hand(ranks), spanish: store.spanish)).font(.title3)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
                    ForEach(1...10, id: \.self) { rank in choice(SchoolRules.rankLabel(rank), value: String(rank), session: s) }
                }
                Text(t("Select all dangerous values. Leave all unselected if none bust.", "Marca todos los valores peligrosos. Si ninguno te hace pasar, no marques nada."))
                    .font(.footnote).foregroundStyle(ClubStyle.muted)
                if answered { bustBreakdown(ranks) }
            case .dealer:
                let pair = SchoolRules.dealerPairs[i]
                HStack {
                    ForEach(pair, id: \.self) { rank in
                        VStack {
                            SchoolCards(ranks: [rank], revealValues: false)
                            choice(rank == 1 ? t("Ace", "As") : "\(rank)", value: String(rank), session: s)
                        }.frame(maxWidth: .infinity)
                    }
                }
                if answered {
                    ForEach(pair, id: \.self) { rank in if let d = data.distribution(rank) { dealerBreakdown(d) } }
                }
            case .move, .distance:
                if let d = data.decision(id) {
                    decisionCards(d)
                    let actions = lesson == .distance ? d.comparison : d.actions
                    if lesson == .distance {
                        Text(t("Expected net result per 1 unit of stake", "Resultado neto esperado por 1 unidad apostada")).font(.subheadline).foregroundStyle(ClubStyle.muted)
                    }
                    ForEach(actions, id: \.self) { action in
                        choice(action.title(store.spanish) + (lesson == .distance ? " · " + number(d.expected(action)) : ""), value: action.rawValue, session: s)
                    }
                    if d.doubleDown == nil { Text(t("Three cards: Double is unavailable.", "Tres cartas: no se puede doblar.")).font(.footnote).foregroundStyle(ClubStyle.muted) }
                    if answered {
                        expectedValues(d, actions: actions)
                        Text(decisionReason(d)).fixedSize(horizontal: false, vertical: true)
                        if lesson == .distance { experiment(d, session: s) }
                    }
                }
            }
            if answered {
                feedback(s)
                SchoolButton(title: s.index + 1 == s.questions.count ? t("See results", "Ver resultados") : t("Next question", "Siguiente pregunta")) { store.advanceSchool(lesson) }
            } else {
                if s.assisted { Text(hint(id)).font(.subheadline).foregroundStyle(ClubStyle.gold).clubPanel() }
                SchoolButton(title: t("Check answer", "Comprobar respuesta")) { store.answerSchool(lesson, data: data) }
                    .disabled(lesson != .bust && s.selection.isEmpty)
                if !s.assisted {
                    SchoolButton(title: t("Show hint", "Mostrar pista"), primary: false) { store.editSchool(lesson) { $0.assisted = true } }
                }
            }
        }
    }
    private var prompt: String {
        switch lesson {
        case .hand: return t("What is the final hand?", "¿Cuál es la mano final?")
        case .bust: return t("Which values would bust?", "¿Qué valores te harían pasar?")
        case .dealer: return t("Which upcard has more bust risk?", "¿Con qué carta es más probable pasarse?")
        case .move: return t("What is the best move?", "¿Cuál es la mejor jugada?")
        case .distance: return t("Which choice is better over time?", "¿Qué opción es mejor a largo plazo?")
        }
    }
    private func choice(_ title: String, value: String, session s: SchoolSession) -> some View {
        let locked = s.phase == .feedback
        let selected = s.selection.contains(value)
        let correct = locked && (s.questionID.map { SchoolRules.correct(lesson, id: $0, data: data).contains(value) } ?? false)
        return Button { store.chooseSchool(lesson, value: value) } label: {
            HStack(spacing: 10) {
                Text(title).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                Spacer(minLength: 2)
                Image(systemName: correct ? "checkmark.circle.fill" : locked && selected ? "xmark.circle" : selected ? "checkmark.circle.fill" : "circle")
                    .accessibilityHidden(true)
            }.foregroundStyle(correct || selected ? ClubStyle.gold : ClubStyle.ivory)
                .padding(14).frame(maxWidth: .infinity, minHeight: 48)
                .background(selected ? ClubStyle.green.opacity(0.3) : ClubStyle.panel, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(ClubStyle.gold.opacity(correct || selected ? 0.8 : 0.15)))
                .contentShape(RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain).disabled(locked)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityValue(locked ? correct ? t("Correct answer", "Respuesta correcta") : selected ? t("Incorrect answer", "Respuesta incorrecta") : "" : "")
    }
    private func feedback(_ s: SchoolSession) -> some View {
        let answer = s.answers.last
        return VStack(alignment: .leading, spacing: 8) {
            Label(answer?.correct == true ? t("Correct", "Correcto") : t("Let's look closer", "Veámoslo con calma"), systemImage: answer?.correct == true ? "checkmark.circle" : "lightbulb")
                .font(.headline).foregroundStyle(ClubStyle.gold)
            if answer?.assisted == true { Text(t("Answered with a hint. This question does not count toward independent accuracy.", "Respuesta con pista. Esta pregunta no cuenta como acierto sin ayuda.")).font(.footnote) }
            if lesson == .dealer { Text(t("These are probabilities, not promises. Even a 6 can finish strong. A dealer blackjack has already been ruled out.", "Son probabilidades, no promesas. Incluso un 6 puede acabar fuerte. Ya se ha descartado un blackjack del crupier.")) }
        }.frame(maxWidth: .infinity, alignment: .leading).clubPanel()
    }
    private func hint(_ id: String) -> String {
        switch lesson {
        case .hand: return t("Count every ace as 1 first. Add 10 once if the total stays at 21 or below. Blackjack needs two cards.", "Cuenta primero cada as como 1. Suma 10 una vez si no superas 21. El blackjack necesita dos cartas.")
        case .bust: return t("Add each value to the hand, then let an ace drop from 11 to 1 if needed. Mark only totals above 21.", "Añade cada valor y baja un as de 11 a 1 si hace falta. Marca solo los totales superiores a 21.")
        case .dealer:
            let answer = SchoolRules.correct(lesson, id: id, data: data).first ?? ""
            return t("Compare the full dealer paths. Here, the higher bust risk belongs to ", "Compara todas las continuaciones. Aquí, el mayor riesgo corresponde a ") + (answer == "1" ? t("Ace", "As") : answer) + "."
        case .move, .distance:
            let best = data.decision(id)?.best ?? .stand
            return t("The highest expected return here is ", "El mayor resultado esperado aquí es ") + best.title(store.spanish) + t(". A smaller expected loss is still the better choice.", ". Una pérdida esperada menor sigue siendo la mejor opción.")
        }
    }
    @ViewBuilder private func handLab(_ q: SchoolHandExercise, revealed: Bool) -> some View {
        if q.next != nil { Text(t("Starting hand", "Mano inicial")).font(.caption).foregroundStyle(ClubStyle.muted) }
        SchoolCards(ranks: q.ranks, revealValues: revealed)
        if let next = q.next {
            Label(t("Next card", "Siguiente carta"), systemImage: "plus").font(.subheadline).foregroundStyle(ClubStyle.gold)
            SchoolCards(ranks: [next], revealValues: false)
        }
        if revealed {
            if let next = q.next {
                Text(t("After Hit", "Después de pedir")).font(.caption).foregroundStyle(ClubStyle.gold)
                SchoolCards(ranks: q.ranks + [next], revealValues: true)
            }
            Text(SchoolRules.handLabel(q.result, spanish: store.spanish)).font(.title2.weight(.medium)).foregroundStyle(ClubStyle.gold)
            Text(t("An ace is 11 only if the hand can stay at 21 or below. Otherwise it is 1. Only a two-card 21 is blackjack.", "Un as vale 11 solo si la mano no supera 21. En caso contrario vale 1. Solo un 21 de dos cartas es blackjack."))
                .font(.subheadline).foregroundStyle(ClubStyle.muted)
        }
    }
    private func bustBreakdown(_ ranks: [Int]) -> some View {
        let counts = SchoolRules.bustCounts(ranks)
        let bad = SchoolRules.dangerous(ranks)
        return VStack(alignment: .leading, spacing: 12) {
            Text(t("Bust risk: ", "Riesgo de pasarse: ") + percent(Double(counts.bad) / Double(counts.remaining))).font(.title3.weight(.semibold)).foregroundStyle(ClubStyle.gold)
            Text("\(counts.bad) / \(counts.remaining) " + t("unseen cards", "cartas no vistas")).font(.subheadline)
            ForEach(1...10, id: \.self) { r in
                HStack {
                    Text(SchoolRules.rankLabel(r))
                    Spacer()
                    Label(bad.contains(r) ? t("Bust", "Te pasas") : t("Safe", "Sin pasarse"), systemImage: bad.contains(r) ? "xmark.circle" : "checkmark.circle")
                }.font(.caption).foregroundStyle(bad.contains(r) ? ClubStyle.gold : ClubStyle.muted)
            }
            Text(t("Fresh six-deck shoe, minus the cards shown. No dealer card or peek information is used in this exercise.", "Seis barajas nuevas, menos las cartas mostradas. Este ejercicio no usa carta del crupier ni información sobre blackjack."))
                .font(.caption).foregroundStyle(ClubStyle.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).clubPanel()
    }
    @ViewBuilder private func dealerLab(_ s: SchoolSession) -> some View {
        let paths = [[1,6], [6,5,3,4], [10,6,10], [1,2,4]]
        let path = paths[s.labIndex % paths.count]
        let count = min(2 + s.labStep, path.count)
        let ranks = Array(path.prefix(count))
        let hand = SchoolRules.hand(ranks)
        SchoolCards(ranks: ranks, revealValues: true)
        Text(SchoolRules.handLabel(hand, spanish: store.spanish)).font(.title3)
        Text(hand.bust ? t("Bust. The dealer's turn is over.", "Se pasa. El turno termina.") : hand.total >= 17 ? t("Stand. This includes soft 17.", "Se planta. También en 17 suave.") : t("Below 17: the dealer must hit.", "Por debajo de 17: el crupier debe pedir."))
        if hand.total < 17 {
            SchoolButton(title: t("Deal the required card", "Repartir la carta obligatoria"), primary: false) { store.editSchool(lesson) { $0.labStep += 1 } }
        } else {
            SchoolButton(title: t("Try another dealer hand", "Probar otra mano del crupier"), primary: false) { store.editSchool(lesson) { $0.labIndex += 1; $0.labStep = 0 } }
        }
    }
    private func dealerBreakdown(_ d: SchoolDistribution) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Upcard: ", "Carta visible: ") + (d.upcard == 1 ? t("Ace", "As") : String(d.upcard))).font(.headline)
            ForEach(0..<6) { i in
                HStack {
                    Text(i == 5 ? t("Bust", "Se pasa") : String(17 + i)).frame(width: 65, alignment: .leading)
                    GeometryReader { g in
                        Capsule().fill(ClubStyle.gold.opacity(i == 5 ? 1 : 0.45))
                            .frame(width: max(2, g.size.width * d.probabilities[i]))
                    }.frame(height: 8).accessibilityHidden(true)
                    Text(percent(d.probabilities[i])).monospacedDigit()
                }.font(.caption).accessibilityElement(children: .combine)
            }
            Text(t("Six decks · S17 · No dealer blackjack · Only the upcard is known", "Seis barajas · S17 · Sin blackjack del crupier · Solo se conoce la carta visible"))
                .font(.caption).foregroundStyle(ClubStyle.muted)
        }.clubPanel()
    }
    private func decisionCards(_ d: SchoolDecision) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Dealer upcard", "Carta visible del crupier")).font(.caption).foregroundStyle(ClubStyle.muted)
            SchoolCards(ranks: [d.upcard], revealValues: false)
            Text(t("Your hand", "Tu mano")).font(.caption).foregroundStyle(ClubStyle.muted)
            SchoolCards(ranks: d.ranks, revealValues: true)
            Text(SchoolRules.handLabel(SchoolRules.hand(d.ranks), spanish: store.spanish)).font(.title3)
        }
    }
    private func expectedValues(_ d: SchoolDecision, actions: [SchoolAction]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Expected net result / 1 unit", "Resultado neto esperado / 1 unidad")).font(.subheadline.weight(.medium))
            ForEach(actions, id: \.self) { action in
                HStack {
                    Label(action.title(store.spanish), systemImage: action == d.best ? "checkmark.circle" : "circle")
                    Spacer()
                    Text(number(d.expected(action))).monospacedDigit()
                }.foregroundStyle(action == d.best ? ClubStyle.gold : ClubStyle.muted)
            }
            Text(t("Fresh six-deck shoe minus visible cards. No dealer blackjack. After Hit, further choices maximise expected return. Double includes twice the stake.", "Seis barajas nuevas menos las cartas visibles. Sin blackjack del crupier. Tras Pedir, las decisiones siguientes maximizan el resultado esperado. Doblar incluye el doble de apuesta."))
                .font(.caption).foregroundStyle(ClubStyle.muted)
        }.clubPanel()
    }
    private func decisionReason(_ d: SchoolDecision) -> String {
        let h = SchoolRules.hand(d.ranks)
        if d.id == "move_1" {
            return t("This is a close composition-dependent exception: 10 + 2 against 4 slightly favours Hit. A general chart groups all hard 12s together; this calculation uses the exact cards removed from six decks.", "Esta es una excepción muy ajustada según la composición: 10 + 2 contra 4 favorece ligeramente Pedir. Una tabla general agrupa todas las manos duras de 12; este cálculo usa las cartas exactas retiradas de seis barajas.")
        }
        if d.best == .doubleDown { return t("Double has the highest average net return here, even with twice the exposure and only one extra card.", "Doblar tiene aquí el mayor resultado neto medio, incluso con el doble en juego y solo una carta adicional.") }
        if d.best == .hit && d.expected(.hit) < 0 { return t("Hit loses less on average than the alternatives. Standing feels safer, but avoiding an immediate bust is not the same as maximising the result.", "Pedir pierde menos de media que las alternativas. Plantarse parece más seguro, pero evitar un riesgo inmediato no equivale a maximizar el resultado.") }
        if d.best == .stand && h.soft { return t("A soft hand is flexible, but another card is not always better. Standing preserves the stronger expected result here.", "Una mano suave es flexible, pero otra carta no siempre ayuda. Plantarse conserva aquí el mejor resultado esperado.") }
        return d.best == .stand ? t("Stand has the highest expected result against this upcard. A weak dealer card is a reason to compare the odds, not a guarantee of winning.", "Plantarse tiene el mayor resultado esperado contra esta carta. Una carta débil invita a comparar probabilidades; no garantiza ganar.") : t("Hit improves the expected result. The ace can absorb a high card when the hand is soft.", "Pedir mejora el resultado esperado. En una mano suave, el as puede absorber una carta alta.")
    }
    @ViewBuilder private func experiment(_ d: SchoolDecision, session s: SchoolSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("Run an experiment", "Haz un experimento")).font(.headline)
            ForEach([10,100,1000], id: \.self) { count in
                SchoolButton(title: t("Run \(count) repetitions", "Simular \(count) repeticiones"), primary: false) {
                    store.editSchool(lesson) { $0.experimentCount = count }
                }
            }
            if s.experimentCount > 0 {
                ForEach(d.comparison, id: \.self) { action in
                    let values = SchoolRules.experiment(d, action: action, seed: s.seed &+ UInt64(s.index), count: s.experimentCount)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(action.title(store.spanish)).font(.headline).foregroundStyle(ClubStyle.gold)
                        Chart {
                            RuleMark(y: .value(t("Expected", "Esperado"), d.expected(action)))
                                .foregroundStyle(ClubStyle.muted).lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                                LineMark(x: .value(t("Repetitions", "Repeticiones"), index + 1), y: .value(t("Average", "Media"), value))
                                    .foregroundStyle(ClubStyle.gold)
                            }
                        }.frame(height: 140).allowsHitTesting(false).accessibilityHidden(true)
                        Text(t("Observed: ", "Observado: ") + number(values.last ?? 0) + t(" · Expected: ", " · Esperado: ") + number(d.expected(action)))
                            .font(.subheadline).accessibilityLabel(action.title(store.spanish) + ": " + t("observed ", "observado ") + number(values.last ?? 0) + t(", expected ", ", esperado ") + number(d.expected(action)))
                    }
                }
                Text(t("Gold: observed average. Dashed: theoretical average. These are random samples of the calculated outcomes, not a new tournament. More repetitions tend to stabilise the average; convergence is not guaranteed in one sample.", "Dorado: media observada. Discontinuo: media teórica. Son muestras aleatorias de los resultados calculados, no un torneo. Más repeticiones suelen estabilizar la media; una sola muestra no garantiza convergencia."))
                    .font(.caption).foregroundStyle(ClubStyle.muted)
            }
        }.clubPanel()
    }
    @ViewBuilder private func results(_ s: SchoolSession) -> some View {
        Image(systemName: "checkmark.seal").font(.system(size: 46, weight: .light)).foregroundStyle(ClubStyle.gold).accessibilityHidden(true)
        Text("\(s.score) / \(s.questions.count)").font(.largeTitle.weight(.medium)).foregroundStyle(ClubStyle.gold)
        Text(t("Correct first answers without hints", "Primeras respuestas correctas sin pistas")).font(.headline)
        Text(s.review ? t("Review leaves your original session result unchanged.", "El repaso no cambia el resultado de la sesión original.") : t("Every question is a chance to understand a decision. Revisit the tricky ones whenever you like.", "Cada pregunta ayuda a entender una decisión. Repasa las más difíciles cuando quieras."))
            .foregroundStyle(ClubStyle.muted)
        let record = store.school.record(lesson)
        if !record.mistakes.isEmpty {
            SchoolButton(title: t("Review tricky questions", "Repasar preguntas difíciles")) { store.openSchool(lesson, data: data, review: true) }
        }
        SchoolButton(title: t("New session", "Nueva sesión"), primary: false) { store.openSchool(lesson, data: data, restart: true) }
        ForEach(Array(s.answers.enumerated()), id: \.offset) { index, answer in
            HStack {
                Text(t("Question \(index + 1)", "Pregunta \(index + 1)"))
                Spacer()
                Label(answer.assisted ? t("With hint", "Con pista") : answer.correct ? t("Correct", "Correcta") : t("Review", "Repasar"), systemImage: answer.assisted ? "lightbulb" : answer.correct ? "checkmark.circle" : "arrow.counterclockwise")
            }.font(.subheadline).foregroundStyle(ClubStyle.muted)
        }
    }
    private func percent(_ value: Double) -> String { value.formatted(.percent.precision(.fractionLength(1)).locale(Locale(identifier: store.state.preferences.language))) }
    private func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(4)).sign(strategy: .always()).locale(Locale(identifier: store.state.preferences.language))) }
}

private struct SchoolCards: View {
    @Environment(CasinoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var valueLabelHeight = 28
    var ranks: [Int]
    var revealValues: Bool
    var body: some View {
        GeometryReader { g in
            let width = min(72, (g.size.width - CGFloat(max(0, ranks.count - 1)) * 8) / CGFloat(max(1, ranks.count)))
            let hand = SchoolRules.hand(ranks)
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(hand.cards.enumerated()), id: \.offset) { index, card in
                    VStack(spacing: 5) {
                        CardView(card: card, width: width, accessibilityText: cardName(card))
                        if revealValues && card.rank == 1 {
                            Text("A = \(hand.soft && index == ranks.firstIndex(of: 1) ? 11 : 1)")
                                .font(.caption.weight(.semibold)).foregroundStyle(ClubStyle.gold)
                                .transition(.opacity)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .center)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: revealValues)
        }.frame(height: 110 + (revealValues && ranks.contains(1) ? valueLabelHeight : 0))
    }
    private func cardName(_ card: PlayingCard) -> String {
        let en = ["spades", "hearts", "clubs", "diamonds"]
        let es = ["picas", "corazones", "tréboles", "diamantes"]
        let rank: String
        switch card.rank {
        case 1: rank = store.text("Ace", "As")
        case 11: rank = store.text("Jack", "Jota")
        case 12: rank = store.text("Queen", "Reina")
        case 13: rank = store.text("King", "Rey")
        default: rank = card.label
        }
        return rank + " " + (store.spanish ? es[card.suit] : en[card.suit])
    }
}

private struct SchoolButton: View {
    @Environment(\.isEnabled) private var enabled
    var title: String
    var primary = true
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.body.weight(.semibold)).multilineTextAlignment(.center)
                .padding(15).frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(primary ? ClubStyle.background : ClubStyle.gold)
                .background(primary ? ClubStyle.gold : ClubStyle.panel, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(ClubStyle.gold.opacity(primary ? 0 : 0.3)))
                .opacity(enabled ? 1 : 0.4)
        }.buttonStyle(.plain)
    }
}
