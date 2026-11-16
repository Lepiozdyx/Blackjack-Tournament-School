import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(CasinoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Blackjack Club")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(ClubStyle.ivory)
                    policySection(
                        store.text("Profile and game data", "Datos del perfil y del juego"),
                        store.text(
                            "The app stores your nickname, profile photo, settings, and game progress on your device to keep your profile and restore your game. These details are not sent to AppsFlyer.",
                            "La app guarda tu apodo, foto de perfil, ajustes y progreso en tu dispositivo para conservar tu perfil y restaurar tu partida. Estos datos no se envían a AppsFlyer."
                        )
                    )
                    policySection(
                        store.text("Campaign measurement", "Medición de campañas"),
                        store.text(
                            "We use AppsFlyer to measure which advertising campaigns lead to installs and app opens. The AppsFlyer SDK may collect install and launch information, device and app identifiers, technical device details, and your IP address, which can indicate your approximate location. AppsFlyer processes and protects this data on our behalf. Where a campaign uses an advertising partner, attribution results may be shared with that partner according to the campaign settings.",
                            "Usamos AppsFlyer para medir qué campañas publicitarias generan instalaciones y aperturas de la app. El SDK de AppsFlyer puede recopilar información sobre instalaciones y aperturas, identificadores del dispositivo y de la app, datos técnicos del dispositivo y tu dirección IP, que puede indicar tu ubicación aproximada. AppsFlyer trata y protege estos datos en nuestro nombre. Si una campaña utiliza un socio publicitario, los resultados de atribución pueden compartirse con ese socio según la configuración de la campaña."
                        )
                    )
                    policySection(
                        store.text("Tracking choices", "Opciones de rastreo"),
                        store.text(
                            "We ask for permission through Apple's App Tracking Transparency prompt before using the advertising identifier (IDFA) or linking your activity with data from other companies for ad measurement. If you decline, you can still play, and AppsFlyer may measure installs without tracking you across other companies’ apps and websites. You can change your choice in iPhone Settings → Privacy & Security → Tracking.",
                            "Antes de usar el identificador publicitario (IDFA) o vincular tu actividad con datos de otras empresas para medir anuncios, te pedimos permiso mediante el aviso de transparencia de rastreo de Apple. Si no lo autorizas, puedes seguir jugando y AppsFlyer puede medir instalaciones sin rastrearte en apps y sitios web de otras empresas. Puedes cambiar tu elección en Ajustes del iPhone → Privacidad y seguridad → Rastreo."
                        )
                    )
                    policySection(
                        store.text("Camera and photos", "Cámara y fotos"),
                        store.text(
                            "Adding a profile photo is optional. The app requests camera access only when you choose to take a photo. If you choose a photo from your library, the app receives only the photo you select. You can turn off camera access in your iPhone settings at any time.",
                            "Añadir una foto de perfil es opcional. La app solicita acceso a la cámara solo cuando eliges hacer una foto. Si eliges una foto de la fototeca, la app solo recibe la imagen seleccionada. Puedes desactivar el acceso a la cámara en los ajustes del iPhone en cualquier momento."
                        )
                    )
                    policySection(
                        store.text("Keeping and deleting your data", "Conservación y eliminación de datos"),
                        store.text(
                            "To delete your local profile, photo, progress, and settings, choose Settings → Reset all progress and confirm. AppsFlyer generally keeps user-level measurement data for up to 24 months, subject to campaign settings and applicable law. To request deletion of measurement data, contact the developer through the App Support link on the Blackjack Club App Store page.",
                            "Para borrar tu perfil local, foto, progreso y ajustes, elige Ajustes → Restablecer todo el progreso y confirma. Por lo general, AppsFlyer conserva los datos de medición a nivel de usuario hasta 24 meses, según la configuración de la campaña y la legislación aplicable. Para solicitar la eliminación de los datos de medición, contacta al desarrollador mediante el enlace de soporte de Blackjack Club en el App Store."
                        )
                    )
                }
                .frame(maxWidth: 540, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(ClubStyle.background)
            .navigationTitle(store.text("Privacy policy", "Política de privacidad"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(store.text("Done", "Listo")) { dismiss() }
                }
            }
        }
        .tint(ClubStyle.gold)
    }

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline).foregroundStyle(ClubStyle.gold)
            Text(body).font(.body).foregroundStyle(ClubStyle.ivory)
        }
    }
}
