import SwiftUI

struct ShopView: View {
    @Environment(CasinoStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(store.text("Collect a new host for your private table. Purchased dealers are yours to keep.", "Colecciona nuevos anfitriones para tu mesa. Los crupieres comprados son tuyos para siempre."))
                    .font(.footnote).foregroundStyle(ClubStyle.muted)
                HStack {
                    Label(store.points(store.balance), systemImage: "circle.circle").foregroundStyle(ClubStyle.gold)
                    Spacer()
                    Text(store.text("Available: ", "Disponible: ") + store.points(store.spendable)).font(.caption).foregroundStyle(ClubStyle.muted)
                }.clubPanel()
                ForEach(DealerSkin.all) { skin in dealer(skin) }
            }.padding(22)
        }.background(ClubStyle.background).navigationTitle(store.text("Shop", "Tienda")).navigationBarTitleDisplayMode(.inline)
    }
    private func dealer(_ skin: DealerSkin) -> some View {
        let owned = store.state.profile.ownedSkins.contains(skin.id)
        let selected = store.state.profile.selectedSkin == skin.id
        return VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottom) {
                RadialGradient(colors: [ClubStyle.green.opacity(0.8), ClubStyle.panel], center: .center, startRadius: 0, endRadius: 200)
                Image("dealer_\(skin.id)").resizable().scaledToFit().padding(.top, 10)
            }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 17)).accessibilityHidden(true)
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(ClubStyle.gold)
                        .padding(12).accessibilityHidden(true)
                }
            }
            ClubButton(title: selected ? store.text("Selected", "Seleccionado") : owned ? store.text("Select dealer", "Elegir crupier") : store.text("Unlock · ", "Desbloquear · ") + store.points(skin.price), icon: selected ? "checkmark" : owned ? "person" : "circle.circle", gold: !selected) {
                store.buyOrSelect(skin)
            }.disabled(selected || (!owned && store.spendable < skin.price))
            if !owned && store.spendable < skin.price {
                Text(store.text("Earn more points to unlock this dealer.", "Gana más puntos para desbloquear este crupier.")).font(.caption).foregroundStyle(ClubStyle.muted)
            }
        }.clubPanel()
    }
}

struct SettingsView: View {
    @Environment(CasinoStore.self) private var store
    var onReset: () -> Void
    @State private var showReset = false
    @State private var showTutorial = false
    @State private var showPrivacyPolicy = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 18) {
                    settingToggle(store.text("Music", "Música"), icon: "music.note", key: \.music)
                    Divider().overlay(ClubStyle.muted.opacity(0.2))
                    settingToggle(store.text("Sound effects", "Efectos de sonido"), icon: "speaker.wave.2", key: \.effects)
                    Divider().overlay(ClubStyle.muted.opacity(0.2))
                    settingToggle(store.text("Haptic effects", "Vibración háptica"), icon: "waveform", key: \.haptics)
                }.clubPanel()
                VStack(spacing: 16) {
                    HStack {
                        Label(store.text("Language", "Idioma"), systemImage: "globe").font(.system(size: 15))
                        Spacer()
                    }
                    HStack(spacing: 4) {
                        ForEach(["en", "es"], id: \.self) { language in
                            let selected = store.state.preferences.language == language
                            Button { store.setLanguage(language) } label: {
                                Text(language == "en" ? "English" : "Español")
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .foregroundStyle(selected ? ClubStyle.background : ClubStyle.ivory)
                                    .background(selected ? ClubStyle.gold : .clear, in: Capsule())
                            }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }.padding(4).background(.black.opacity(0.2), in: Capsule())
                }.clubPanel()
                ClubButton(title: store.text("How to play", "Cómo jugar"), icon: "book.closed", gold: false) { store.feedback(.tap); showTutorial = true }
                ClubButton(title: store.text("Privacy policy", "Política de privacidad"), icon: "hand.raised", gold: false) {
                    store.feedback(.tap)
                    showPrivacyPolicy = true
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(store.text("A clean slate", "Borrón y cuenta nueva")).font(.system(size: 22, design: .serif))
                    Text(store.text("Remove your profile, points, purchases, saved games and school progress. This cannot be undone.", "Elimina tu perfil, puntos, compras, partidas guardadas y progreso de la escuela. Esta acción no se puede deshacer."))
                        .font(.footnote).foregroundStyle(ClubStyle.muted)
                    Button(role: .destructive) { store.feedback(.tap); showReset = true } label: {
                        Label(store.text("Reset all progress", "Restablecer todo el progreso"), systemImage: "arrow.counterclockwise").font(.system(size: 14, weight: .medium))
                    }.padding(.top, 5)
                }.frame(maxWidth: .infinity, alignment: .leading).clubPanel()
                Text("BJapp · 1.0").font(.caption).foregroundStyle(ClubStyle.muted).frame(maxWidth: .infinity)
            }.padding(22)
        }
        .background(ClubStyle.background).navigationTitle(store.text("Settings", "Ajustes")).navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTutorial) { TutorialView(required: false, onComplete: {}).environment(store) }
        .sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicyView() }
        .alert(store.text("Reset all progress?", "¿Restablecer todo el progreso?"), isPresented: $showReset) {
            Button(store.text("Cancel", "Cancelar"), role: .cancel) {}
            Button(store.text("Reset everything", "Restablecer todo"), role: .destructive) { if store.reset() { onReset() } }
        } message: { Text(store.text("Your profile, points, purchased dealers, tournament and school progress will be deleted. You will start again with 1,000 points.", "Se borrarán tu perfil, puntos, crupieres comprados, torneo y progreso de la escuela. Empezarás de nuevo con 1.000 puntos.")) }
    }
    private func settingToggle(_ title: String, icon: String, key: WritableKeyPath<Preferences, Bool>) -> some View {
        Toggle(isOn: Binding(get: { store.state.preferences[keyPath: key] }, set: { store.setPreference(key, $0) })) {
            Label(title, systemImage: icon).font(.system(size: 15))
        }.tint(ClubStyle.green)
    }
}
