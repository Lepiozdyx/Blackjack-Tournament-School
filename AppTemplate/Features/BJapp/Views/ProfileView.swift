import SwiftUI
import PhotosUI
import AVFoundation
import ImageIO

struct ProfileView: View {
    @Environment(CasinoStore.self) private var store
    @State private var nickname = ""
    @State private var showSources = false
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showCameraAlert = false
    @State private var cameraUnavailable = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoError = false
    @State private var loadingPhoto = false
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                Button { store.feedback(.tap); showSources = true } label: {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileAvatar(data: store.state.profile.avatarData, size: 112)
                        Image(systemName: "camera.fill").font(.system(size: 14)).foregroundStyle(ClubStyle.background)
                            .padding(10).background(ClubStyle.gold, in: Circle())
                    }
                }.buttonStyle(.plain).accessibilityLabel(store.text("Change profile photo", "Cambiar foto de perfil"))
                if loadingPhoto { ProgressView().tint(ClubStyle.gold) }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: store.text("Nickname", "Apodo"))
                    TextField(store.text("Your nickname", "Tu apodo"), text: $nickname)
                        .font(.system(size: 19)).textInputAutocapitalization(.words).autocorrectionDisabled()
                        .submitLabel(.done).focused($focused)
                        .onSubmit { saveName() }
                        .onChange(of: nickname) { _, new in if new.count > 24 { nickname = String(new.prefix(24)) } }
                }.clubPanel()
                ClubButton(title: store.text("Save profile", "Guardar perfil"), icon: "checkmark") { saveName(); store.feedback(.tap) }
                HStack {
                    stat(store.text("HANDS PLAYED", "MANOS JUGADAS"), String(store.state.profile.handsPlayed))
                    Spacer()
                    stat(store.text("WINS", "VICTORIAS"), String(store.state.profile.handsWon))
                    Spacer()
                    stat(store.text("POINTS", "PUNTOS"), store.points(store.balance))
                }.clubPanel()
            }.padding(24)
        }
        .background(ClubStyle.background).navigationTitle(store.text("Profile", "Perfil")).navigationBarTitleDisplayMode(.inline)
        .onAppear { nickname = store.state.profile.nickname }
        .onDisappear { if nickname != store.state.profile.nickname { store.setNickname(nickname) } }
        .confirmationDialog(store.text("Profile photo", "Foto de perfil"), isPresented: $showSources, titleVisibility: .visible) {
            Button(store.text("Camera", "Cámara")) { openCamera() }
            Button(store.text("Photo Library", "Fototeca")) { showLibrary = true }
            Button(store.text("Cancel", "Cancelar"), role: .cancel) {}
        }
        .photosPicker(isPresented: $showLibrary, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            loadingPhoto = true
            Task {
                defer { loadingPhoto = false; photoItem = nil }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let source = CGImageSourceCreateWithData(data as CFData, nil),
                          let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1024, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary)
                    else { photoError = true; return }
                    store.setAvatar(UIImage(cgImage: cg))
                } catch { photoError = true }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in if let image { store.setAvatar(image) } }.ignoresSafeArea()
        }
        .alert(store.text("Camera unavailable", "Cámara no disponible"), isPresented: $showCameraAlert) {
            if !cameraUnavailable {
                Button(store.text("Open Settings", "Abrir Ajustes")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Button(store.text("Cancel", "Cancelar"), role: .cancel) {}
        } message: {
            Text(cameraUnavailable ? store.text("This device has no available camera. You can choose a photo from your library.", "Este dispositivo no tiene una cámara disponible. Puedes elegir una foto de tu fototeca.") : store.text("Allow camera access in Settings to take a profile photo. You can still choose a photo from your library.", "Permite el acceso a la cámara en Ajustes para hacer una foto de perfil. También puedes elegir una foto de tu fototeca."))
        }
        .alert(store.text("Photo could not be opened", "No se pudo abrir la foto"), isPresented: $photoError) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.text("Choose another image and try again.", "Elige otra imagen e inténtalo de nuevo.")) }
    }
    private func saveName() { store.setNickname(nickname); nickname = store.state.profile.nickname; focused = false }
    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(ClubStyle.muted)
            Text(value).font(.system(size: 21, weight: .medium, design: .rounded)).foregroundStyle(ClubStyle.gold).lineLimit(1).minimumScaleFactor(0.65)
        }
    }
    private func openCamera() {
        cameraUnavailable = !UIImagePickerController.isSourceTypeAvailable(.camera)
        guard !cameraUnavailable else { showCameraAlert = true; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: showCamera = true
        case .notDetermined:
            Task { let allowed = await AVCaptureDevice.requestAccess(for: .video); if allowed { showCamera = true } else { showCameraAlert = true } }
        default: showCameraAlert = true
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onPhoto: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.onPhoto(info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage)
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
