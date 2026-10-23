import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AVFoundation

// NEXORA SYSTEM: visual personalizado; el motor GPLv3 3105 permanece separado.
private enum NXColors {
    // Diseño confirmado por el propietario: negro + rojo neón en todas las pantallas.
    // Estos son colores reales de controles SwiftUI, no una captura pegada encima.
    static let background = Color(red: 0.022, green: 0.002, blue: 0.006)
    static let surface = Color(red: 0.072, green: 0.008, blue: 0.014)
    static let elevated = Color(red: 0.18, green: 0.018, blue: 0.029)
    static let green = Color(red: 0.13, green: 0.89, blue: 0.40) // indicador únicamente
    static let cyan = Color(red: 1.00, green: 0.18, blue: 0.22) // rojo luminoso
    static let border = Color(red: 0.96, green: 0.12, blue: 0.18)
    static let muted = Color(red: 0.74, green: 0.66, blue: 0.67)
    static let red = Color(red: 1.00, green: 0.10, blue: 0.14) // rojo NEXORA
}

// Fondo decorativo real para ambas pantallas. Los botones siguen siendo controles
// nativos y accesibles; nunca se utiliza una captura de la UI como interfaz.
struct NXGothicBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            Image("NexoraDarkCity")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                // La ilustración de ciudad, héroe oscuro y murciélagos se tiñe rojo,
                // como la referencia elegida; no incluye botones ni texto aplanados.
                .colorMultiply(Color(red: 1.0, green: 0.27, blue: 0.29))
                .overlay {
                    LinearGradient(colors: [
                        Color(red: 0.48, green: 0.01, blue: 0.04).opacity(0.28),
                        Color(red: 0.08, green: 0.001, blue: 0.004).opacity(0.49),
                        Color.black.opacity(0.78)
                    ], startPoint: .top, endPoint: .bottom)
                }
                .overlay(Color(red: 0.22, green: 0.001, blue: 0.004).opacity(0.10))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}


private enum NexoraSocialLinks {
    // Enlaces oficiales proporcionados por el propietario de NEXORA.
    static let discord = "https://discord.gg/RyAu7yrhE"
    static let whatsapp = "https://chat.whatsapp.com/KKHuqvBtbnH45JNuIVBJVB?mode=gi_t"
}

private struct NXFeedback: Identifiable {
    let id = UUID()
    let message: String
}

/// Aviso antes de continuar cuando el original cambió desde la última operación.
private struct NXOriginalVersionNotice: Identifiable {
    let id = UUID()
    let details: String
}

private struct NXCategory: Identifiable {
    let title: String
    let symbol: String
    var id: String { title }
}

// NEXORA V12: paquetes suministrados por el usuario, incluidos en Assets.xcassets.
// No altera el gestor original 3105 ni el sistema de keys.
private struct NXBundledOption: Identifiable {
    let id: UUID
    let title: String
    let category: String
    let dataAsset: String
    let targetPath: String
    let filename: String

    static let all: [NXBundledOption] = [
        NXBundledOption(id: UUID(uuidString: "5B9C2FC1-54FC-5145-9F96-F379556F9D23")!, title: "AIMDRAG", category: "AIMBOT", dataAsset: "NXModAimDrag", targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D", filename: "assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D"),
        NXBundledOption(id: UUID(uuidString: "0DF7E99C-276C-5FD6-AC99-250A2283430A")!, title: "AIMBOT CABEZA", category: "AIMBOT", dataAsset: "NXModAimCabeza", targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D", filename: "assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D"),
        NXBundledOption(id: UUID(uuidString: "B1BEA509-3487-538D-9A72-653AD31BA1E9")!, title: "AIMBOT CUELLO", category: "AIMBOT", dataAsset: "NXModAimCuello", targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D", filename: "assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D"),
        NXBundledOption(id: UUID(uuidString: "AF7FFFAF-EEB3-5BF8-AEBA-1B6FF3B7C538")!, title: "AIMBOT PECHO", category: "AIMBOT", dataAsset: "NXModAimPecho", targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D", filename: "assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D"),
        NXBundledOption(id: UUID(uuidString: "7E4E6CED-F65A-538A-9924-3D17AED6D957")!, title: "AIM DRAG ANTENA", category: "AIMBOT CON ANTENA", dataAsset: "NXModAntenaDrag", targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D", filename: "assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D"),
        NXBundledOption(id: UUID(uuidString: "D152E8C1-1866-5D39-AB06-334558C45E4A")!, title: "AIM CUELLO ANTENA", category: "AIMBOT CON ANTENA", dataAsset: "NXModAntenaCuello", targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D", filename: "assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D"),
        NXBundledOption(id: UUID(uuidString: "9DAE3BC4-B812-5C6A-87D9-BCD8FAE69498")!, title: "AIM PECHO ANTENA", category: "AIMBOT CON ANTENA", dataAsset: "NXModAntenaPecho", targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D", filename: "assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D"),
        NXBundledOption(id: UUID(uuidString: "1F01CB76-4465-5BB9-89D4-EE24BB006D94")!, title: "AZUL CON VERDE", category: "HOLO ARM", dataAsset: "NXModHoloAzul", targetPath: "Documents/contentcache/Optional/ios/gameassetbundles/shaders.P0K3UG2TfecMBhWMMV~2Fu8ReudIk~3D", filename: "shaders.P0K3UG2TfecMBhWMMV~2Fu8ReudIk~3D"),
        NXBundledOption(id: UUID(uuidString: "D9B35EA9-DE70-5016-8424-37403118CF6D")!, title: "RAINBOW COLOR ROJO", category: "HOLO ARM", dataAsset: "NXModHoloRainbowRojo", targetPath: "Documents/contentcache/Optional/ios/gameassetbundles/shaders.P0K3UG2TfecMBhWMMV~2Fu8ReudIk~3D", filename: "shaders.P0K3UG2TfecMBhWMMV~2Fu8ReudIk~3D"),
        NXBundledOption(id: UUID(uuidString: "1F6E508C-660E-5236-9DCF-524AC4D4B54A")!, title: "HOLO ARM RAINBOW", category: "HOLO ARM", dataAsset: "NXModHoloRainbow", targetPath: "Documents/contentcache/Optional/ios/gameassetbundles/shaders.P0K3UG2TfecMBhWMMV~2Fu8ReudIk~3D", filename: "shaders.P0K3UG2TfecMBhWMMV~2Fu8ReudIk~3D"),
        NXBundledOption(id: UUID(uuidString: "BC2E6E51-5EA3-4F1E-89BD-DB6B23C2071A")!, title: "HOLOGRAMA PERSONAJE AZUL", category: "HOLO PJ", dataAsset: "NXModHoloPjAzul", targetPath: "Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles/optionalavatarres_commonab_shader.BNrjwQsbTrqz6jACY9i6FB6DyYI~3D", filename: "optionalavatarres_commonab_shader.BNrjwQsbTrqz6jACY9i6FB6DyYI~3D"),
        NXBundledOption(id: UUID(uuidString: "6A2759B8-35AD-55D2-93F8-0961B712026D")!, title: "HOLOGRAMA PERSONAJE AMARILLO", category: "HOLO PJ", dataAsset: "NXModHoloPjAmarillo", targetPath: "Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles/optionalavatarres_commonab_shader.BNrjwQsbTrqz6jACY9i6FB6DyYI~3D", filename: "optionalavatarres_commonab_shader.BNrjwQsbTrqz6jACY9i6FB6DyYI~3D"),
        NXBundledOption(id: UUID(uuidString: "444C2683-B2BF-52B9-A5B2-3960AA7C71BB")!, title: "HOLOGRAMA PERSONAJE RAINBOW", category: "HOLO PJ", dataAsset: "NXModHoloPjRainbow", targetPath: "Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles/optionalavatarres_commonab_shader.BNrjwQsbTrqz6jACY9i6FB6DyYI~3D", filename: "optionalavatarres_commonab_shader.BNrjwQsbTrqz6jACY9i6FB6DyYI~3D"),
        NXBundledOption(id: UUID(uuidString: "49EC8EDD-72F3-55F3-B9AA-B68DC3690A4E")!, title: "HOLOGRAMA PERSONA OSCURO RAINBOW OSCURO", category: "HOLO PJ", dataAsset: "NXModHoloPjOscuroRainbowOscuro", targetPath: "Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles/optionalavatarres_commonab_shader.BNrjwQsbTrqz6jACY9i6FB6DyYI~3D", filename: "optionalavatarres_commonab_shader.BNrjwQsbTrqz6jACY9i6FB6DyYI~3D"),
        NXBundledOption(id: UUID(uuidString: "B9128CC3-09D5-520F-A1A7-F9C92FE19CDE")!, title: "TEXTURA ALOK", category: "TEXTURA", dataAsset: "NXModTexturaAlok", targetPath: "Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles/optionalab_avatar_66.1GZrX1l5Sm~2FgqXYqB7dDyULWdn4~3D", filename: "optionalab_avatar_66.1GZrX1l5Sm~2FgqXYqB7dDyULWdn4~3D"),
    ]

    // Cada boton usa su NSDataAsset (archivo modificado) y su targetPath.
    // No inventamos archivos originales: PatchTransaction crea el respaldo al activar.
    // Varios AIMBOT usan el mismo destino: son alternativas, NO acumulables.
    // Las opciones futuras permanecen visibles pero apagadas mientras no haya
    // un paquete válido. Al importar un .3105 con el mismo nombre, la fila
    // pendiente se sustituye por la fila conectada al motor original.
    static let pendingByCategory: [String: [String]] = [
        "AIMBOT": ["BALAS MÁGICAS"],
        "AIMBOT CON ANTENA": ["AIM CABEZA ANTENA"],
        "HOLO ARM": ["HOLO ARM PERSONALIZADO 2"],
        "HOLO PJ": ["HOLOGRAMA PERSONAJE VERDE"],
        "TEXTURA": ["TEXTURA CLARA", "TEXTURA OSCURA"],
        "WALK HACK": ["WALK HACK"]
    ]

    /// Una sola opcion puede ocupar cada archivo original. Las coincidencias
    /// se buscan tambien entre categorias distintas (AIMBOT / ANTENA).
    func activeOptionForSameTarget() -> NXBundledOption? {
        Self.all.first { other in
            other.id != id && other.targetPath == targetPath &&
                DevicePatchService.latestReceipt(projectID: other.id) != nil
        }
    }

    // El nombre del recurso es fijo y Xcode lo incorpora a Assets.car.
    // Sin archivo correspondiente se impide el reemplazo, no se finge éxito.
    func makeProject() throws -> PatchProject {
        guard let payload = NSDataAsset(name: dataAsset)?.data else {
            throw NSError(domain: "NEXORA", code: 1, userInfo: [NSLocalizedDescriptionKey: "Falta el archivo de esta opción en la IPA."])
        }
        try NXActivationPreflight.validateBundledResource(payload)
        let appID = "com.dts.freefireth"
        let rule = PatchRule(bundleID: appID, relativePath: targetPath,
                             replacementFilename: filename, replacementData: payload)
        return PatchProject(id: id, name: title, author: "NEXORA SYSTEM 2026",
                            bundleIdentifiers: [appID], rules: [rule])
    }

    // No se debe crear un destino vacío: al hacerlo se perdería la posibilidad
    // de restaurar los bytes originales. Requiere archivo original existente.
    func originalURL() throws -> URL {
        let appID = "com.dts.freefireth"
        guard let root = ContainerStore.resolveAppContainerPath(bundleID: appID),
              ContainerStore.isApplicationContainerPath(root) else {
            throw NSError(domain: "NEXORA", code: 2, userInfo: [NSLocalizedDescriptionKey: "No hay acceso verificable al contenedor de la aplicación. No se modificó ningún archivo."])
        }
        let target = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent(targetPath)
        guard FileManager.default.fileExists(atPath: target.path) else {
            throw NSError(domain: "NEXORA", code: 3, userInfo: [NSLocalizedDescriptionKey: "No se encontró el archivo original esperado. El reemplazo se canceló para evitar pérdida de datos."])
        }
        try NXActivationPreflight.validateReadableWritableOriginal(at: target)
        return target
    }

    func checkOriginalExists() throws { _ = try originalURL() }
}

struct ContentView: View {
    @EnvironmentObject private var store: PatchProjectStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var license: NexoraLicenseModel
    @Environment(\.appLanguage) private var language
    @StateObject private var music = NXMusicPlayer()
    @StateObject private var ownedUpdater = NXOwnedResourceUpdater()
    @StateObject private var activationFeedback = NXActivationFeedback()
    @Environment(\.scenePhase) private var nxScenePhase
    @State private var selectedCategory = "AIMBOT"
    @State private var showSettings = false
    @State private var showImporter = false
    @State private var showCreator = false
    @State private var showBrowser = false
    @State private var fileTabs = FilesTabSession()
    @State private var busyProject: UUID?
    @State private var feedback: NXFeedback?
    @State private var updatedOriginalNotice: NXOriginalVersionNotice?
    @State private var compatibilityNoticeShown = false
    @State private var originalAuditIsRunning = false
    // El monitor vive dentro de ContentView, que solo existe tras validar la licencia.
    @AppStorage("nexora.safeAudit.blocks.v1") private var blockedPathsJSON = "[]"
    @AppStorage("nexora.safeAudit.enabled.v1") private var periodicAuditEnabled = true
    @AppStorage("nexora.safeAudit.status.v1") private var periodicAuditStatus = "Todavía no se han comprobado los archivos."
    private var blockedPaths: Set<String> {
        guard let data = blockedPathsJSON.data(using: .utf8),
              let saved = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(saved).intersection(Set(NXBundledOption.all.map(\.targetPath)))
    }
    private func isChanged(_ path: String) -> Bool { blockedPaths.contains(path) }
    private func changedMessage(_ path: String) -> String {
        "Archivo diferente al respaldo: \(URL(fileURLWithPath: path).lastPathComponent). La nueva versión podría provenir de un parche u otra modificación; solo se bloquean las opciones que compartan esta base hasta validar una variante compatible."
    }
    // Diagnóstico opcional (plegado en Configuración): archivos internos propios.
    @State private var nxMotorDemoIsApplied = false
    @State private var nxMotorDemoBusy = false
    @State private var nxMotorDemoResult = "Prueba local pendiente"

    // Los nombres se muestran desde el primer inicio para respetar la maqueta.
    // Sin paquete real importado, el interruptor permanece deshabilitado.
    private let defaultAimbotNames = ["AIMDRAG", "AIMBOT CABEZA", "AIMBOT CUELLO", "AIMBOT PECHO", "BALAS MÁGICA"]

    private let categories: [NXCategory] = [
        .init(title: "AIMBOT", symbol: "scope"),
        .init(title: "AIMBOT CON ANTENA", symbol: "scope"),
        .init(title: "HOLO ARM", symbol: "sparkles"),
        .init(title: "HOLO PJ", symbol: "person.fill"),
        .init(title: "TEXTURA", symbol: "paintpalette.fill"),
        .init(title: "WALK HACK", symbol: "figure.walk")
    ]

    private func matches(_ item: PatchLibraryItem, category: String) -> Bool {
        let text = (item.project?.name ?? item.packageURL.lastPathComponent).uppercased()
        switch category {
        case "AIMBOT": return (text.contains("AIM") || text.contains("DRAG")) && !text.contains("ANTENA")
        case "AIMBOT CON ANTENA": return text.contains("ANTENA")
        case "HOLO ARM": return text.contains("HOLO") && text.contains("ARM")
        case "HOLO PJ": return text.contains("HOLO") && (text.contains("PJ") || text.contains("PERSONA"))
        case "TEXTURA": return text.contains("TEXTUR")
        case "WALK HACK": return text.contains("WALK")
        default: return false
        }
    }

    private var filteredPackages: [PatchLibraryItem] {
        selectedCategory == "TODAS" ? store.items : store.items.filter { matches($0, category: selectedCategory) }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    NXGothicBackdrop()

                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            brandHeader
                                .padding(.bottom, 10)
                            Text("Panel de control")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .padding(.bottom, 6)
                                .accessibilityAddTraits(.isHeader)
                            HStack(spacing: 6) {
                                Circle().fill(NXColors.cyan)
                                    .frame(width: 6, height: 6)
                                Text("FREE FIRE TH")
                                    .tracking(1.5)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(NXColors.cyan)
                            }
                            .padding(.bottom, 23)
                            onlineStatus
                                .padding(.bottom, 17)
                            categoryTabs
                                .padding(.bottom, 17)
                            installedPatchSection
                        }
                        // El ancho y las fuentes son en puntos iOS, NO en píxeles de captura.
                        // Evita paneles gigantes y mantiene la proporción RX7 en iPhone.
                        .frame(maxWidth: 440)
                        .padding(.horizontal, geometry.size.width < 360 ? 17 : 23)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 5)
                        .padding(.bottom, 14)
                    }
                    .scrollIndicators(.hidden)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    musicBar
                        .background {
                            LinearGradient(
                                colors: [NXColors.background.opacity(0.40), NXColors.background],
                                startPoint: .top, endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .bottom)
                        }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                NXSettingsView(music: music, onCheckOriginals: checkOriginalsOnForeground)
                    .environmentObject(ownedUpdater)
                    .environmentObject(appState)
                    .environmentObject(license)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showCreator) {
                PatchProjectEditorView(existingProject: nil, passwordIsProtected: false) { project, password in
                    store.create(project: project, password: password)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType(filenameExtension: "3105") ?? .data, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        guard url.pathExtension.lowercased() == "3105" else {
                            feedback = NXFeedback(message: "Selecciona un paquete .3105 válido.")
                            return
                        }
                        store.importPackage(at: url)
                    }
                case .failure(let error): feedback = NXFeedback(message: error.localizedDescription)
                }
            }
            .alert(item: $feedback) { entry in
                Alert(title: Text("NEXORA SYSTEM"), message: Text(entry.message), dismissButton: .default(Text("Aceptar")))
            }
            .confirmationDialog(
                "El archivo original ha cambiado",
                isPresented: Binding(
                    get: { updatedOriginalNotice != nil },
                    set: { if !$0 { updatedOriginalNotice = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Entendido", role: .cancel) { updatedOriginalNotice = nil }
            } message: {
                Text((updatedOriginalNotice?.details ?? "") +
                     "\nNEXORA detectó una versión original diferente mediante SHA-256. No activará el recurso anterior. Solo una variante verificada para esta versión permitirá continuar. El respaldo no se eliminará.")
            }
            .patchStorePresentation(store)
            .preferredColorScheme(.dark)
            .tint(NXColors.cyan)
            .onAppear {
                // La biblioteca ya realiza su primera carga en segundo plano.
                // No repetirla sincrónicamente al mostrar el panel.
                nxMotorDemoIsApplied = NXLocalMotorDemo.isApplied
                if let unsupported = appState.unsupportedMessage, !compatibilityNoticeShown {
                    compatibilityNoticeShown = true
                    feedback = NXFeedback(message: "Tu sistema \(unsupported) no está verificado para el motor 3105. La licencia puede ser válida, pero las funciones de archivos quedan desactivadas.")
                }
            }
            .task {
                // La actualización de recursos propios se consulta DESPUÉS de dibujar
                // el panel autorizado. Nunca participa en verificar la key.
                do { try await Task.sleep(nanoseconds: 1_000_000_000) }
                catch { return }
                guard !Task.isCancelled, nxScenePhase == .active,
                      license.state == .allowed else { return }
                ownedUpdater.checkWhenActive()
            }
            .onChange(of: nxScenePhase) { phase in
                if phase == .active {
                    ownedUpdater.checkWhenActive()
                }
            }
            .task(id: nxScenePhase == .active && periodicAuditEnabled && license.state == .allowed) {
                guard nxScenePhase == .active, periodicAuditEnabled, license.state == .allowed else { return }
                // Retrasar el primer escaneo hasta tener el panel dibujado.
                do { try await Task.sleep(nanoseconds: 30_000_000_000) }
                catch { return }
                while !Task.isCancelled && license.state == .allowed && nxScenePhase == .active {
                    checkOriginalsOnForeground()
                    do { try await Task.sleep(nanoseconds: 300_000_000_000) }
                    catch { break }
                }
            }
            .onChange(of: appState.unsupportedMessage) { unsupported in
                if let unsupported = unsupported, !compatibilityNoticeShown {
                    compatibilityNoticeShown = true
                    feedback = NXFeedback(message: "Tu sistema \(unsupported) no está verificado para el motor 3105. La licencia puede ser válida, pero las funciones de archivos quedan desactivadas.")
                }
            }
        }
    }

    /// Reutiliza el detector de la versión funcional. No altera licencias ni el motor.
    /// Solo se registra un bloqueo si SHA-256 difiere de un respaldo ya conocido.
    private func checkOriginalsOnForeground() {
        guard !originalAuditIsRunning, busyProject == nil, appState.isSupported,
              nxScenePhase == .active, license.state == .allowed else { return }
        originalAuditIsRunning = true
        let paths = Array(Set(NXBundledOption.all.map(\.targetPath))).sorted()
        Task.detached(priority: .utility) {
            let result = Result {
                try DevicePatchService.auditKnownOriginals(
                    bundleID: "com.dts.freefireth", relativePaths: paths)
            }
            await MainActor.run {
                originalAuditIsRunning = false
                // Si la licencia dejó de estar autorizada durante la inspección,
                // descartar el resultado sin mostrar alertas ni tocar bloqueos.
                guard license.state == .allowed, nxScenePhase == .active else { return }
                let when = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
                switch result {
                case .success(let observed):
                    let prefix = "com.dts.freefireth/"
                    let discovered = observed.compactMap { key -> String? in
                        guard key.hasPrefix(prefix) else { return nil }
                        let path = String(key.dropFirst(prefix.count))
                        return paths.contains(path) ? path : nil
                    }
                    if !discovered.isEmpty {
                        let saved = blockedPaths.union(discovered)
                        if let bytes = try? JSONEncoder().encode(saved.sorted()),
                           let json = String(data: bytes, encoding: .utf8) {
                            blockedPathsJSON = json
                        }
                        let titles = discovered.map { URL(fileURLWithPath: $0).lastPathComponent }
                        updatedOriginalNotice = NXOriginalVersionNotice(
                            details: "SHA-256 diferente en " + titles.joined(separator: ", ") +
                            ". Solo se bloquean las opciones relacionadas.")
                    }
                    periodicAuditStatus = "Última comprobación: \(when). Nuevos cambios: \(discovered.count). Archivos con bloqueo: \(blockedPaths.count)."
                case .failure:
                    // La falta de permisos o respaldos NO demuestra que el archivo haya cambiado.
                    periodicAuditStatus = "Último intento: \(when). Verificación incompleta; no se bloquearon otras opciones."
                }
            }
        }
    }

    private var brandHeader: some View {
        ZStack {
            VStack(spacing: 3) {
                HStack(spacing: 0) {
                    Text("NE").foregroundStyle(.white)
                    Text("X")
                        .foregroundStyle(NXColors.cyan)
                        .shadow(color: NXColors.cyan.opacity(0.9), radius: 12)
                    Text("ORA").foregroundStyle(.white)
                }
                .font(.system(size: 49, weight: .black, design: .rounded))
                .tracking(1.1)
                .shadow(color: NXColors.red.opacity(0.82), radius: 12)
                .lineLimit(1)
                .minimumScaleFactor(0.70)

                Text("— SYSTEM 2026 —")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(NXColors.red)
            }
            .padding(.trailing, 44)
            HStack {
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .frame(width: 45, height: 45)
                        .background(.black.opacity(0.72), in: Circle())
                        .overlay(Circle().stroke(NXColors.border, lineWidth: 1))
                        .shadow(color: NXColors.cyan.opacity(0.3), radius: 10)
                }
                .accessibilityLabel("Configuración")
            }
            .foregroundStyle(.white)
        }
        .frame(height: 111)
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(categories) { category in
                    let selected = selectedCategory == category.title
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedCategory = category.title }
                    } label: {
                        Text(category.title)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.66))
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background {
                                if selected {
                                    Capsule()
                                        .fill(LinearGradient(colors: [NXColors.elevated, NXColors.cyan],
                                                             startPoint: .leading, endPoint: .trailing))
                                        .overlay(Capsule().stroke(NXColors.cyan.opacity(0.95), lineWidth: 1.2))
                                        .shadow(color: NXColors.cyan.opacity(0.62), radius: 11)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(4)
        }
        .background(Color.black.opacity(0.70), in: Capsule())
        .overlay(Capsule().stroke(NXColors.border.opacity(0.78), lineWidth: 1))
    }

    private var onlineStatus: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(appState.isSupported ? Color(red: 0.10, green: 0.85, blue: 0.36) : .orange)
                .frame(width: 9, height: 9)
            Text(appState.isSupported ? "Sistema en línea" : "Versión sin verificar")
                .foregroundStyle(.white.opacity(0.60))
                .font(.system(size: 13, weight: .medium))
            Spacer()
            // Identificador visual para comprobar que no se ejecuta una IPA anterior.
            Text("B16 · ROJO")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(NXColors.red)
                .accessibilityLabel("Interfaz roja, compilación 16")
        }
        .padding(.horizontal, 2)
    }

    private func canonical(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .uppercased().replacingOccurrences(of: " ", with: "")
    }

    private func itemForDefault(_ name: String) -> PatchLibraryItem? {
        filteredPackages.first {
            canonical($0.project?.name ?? $0.packageURL.deletingPathExtension().lastPathComponent)
                .contains(canonical(name))
        }
    }

    @ViewBuilder
    private var installedPatchSection: some View {
        let builtIn = NXBundledOption.all.filter { $0.category == selectedCategory }
        LazyVStack(spacing: 10) {
            // Este nuevo holograma se muestra al FINAL de HOLO PJ, incluso
            // después de las filas pendientes o paquetes importados.
            ForEach(builtIn.filter { $0.dataAsset != "NXModHoloPjOscuroRainbowOscuro" }) { option in
                builtInPatchRow(option)
            }
            // Los paquetes .3105 importados por el usuario siguen funcionando.
            ForEach(filteredPackages) { item in
                patchRow(item)
            }
            // Las filas pendientes se sustituyen al importar un paquete .3105
            // con el nombre correspondiente; no se anuncian como activadas antes.
            ForEach(NXBundledOption.pendingByCategory[selectedCategory] ?? [], id: \.self) { title in
                if itemForDefault(title) == nil {
                    missingPackageRow(title)
                }
            }
            if selectedCategory == "HOLO PJ",
               let finalHologram = builtIn.first(where: { $0.dataAsset == "NXModHoloPjOscuroRainbowOscuro" }) {
                builtInPatchRow(finalHologram)
            }
            if builtIn.isEmpty && filteredPackages.isEmpty &&
               (NXBundledOption.pendingByCategory[selectedCategory] ?? []).isEmpty {
                Text("Aún no hay opciones con archivos verificados.")
                    .font(.system(size: 12))
                    .foregroundStyle(NXColors.muted)
                    .padding(.vertical, 24)
            }
        }
    }

    private func builtInPatchRow(_ option: NXBundledOption) -> some View {
        let loading = busyProject == option.id
        let applied = DevicePatchService.latestReceipt(projectID: option.id) != nil
        return HStack(spacing: 14) {
            Image(systemName: "scope")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(NXColors.cyan)
                .frame(width: 25)
            Text(option.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
            Spacer(minLength: 1)
            if isChanged(option.targetPath) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Archivo actualizado, esta opción no se activará")
            }
            if loading { ProgressView().tint(NXColors.cyan) }
            Toggle(option.title, isOn: Binding(
                get: { DevicePatchService.latestReceipt(projectID: option.id) != nil },
                set: { enabled in toggleBuiltIn(option, enabled: enabled) }
            ))
            .labelsHidden()
            .tint(NXColors.cyan)
            .disabled(loading || busyProject != nil || store.isBusy || !appState.isSupported )
            .scaleEffect(0.78, anchor: .trailing)
            .frame(width: 48, height: 38, alignment: .trailing)
            .accessibilityValue(applied ? "Modificado activo" : "Original restaurado")
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.73), in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(
            LinearGradient(colors: [NXColors.cyan.opacity(0.98), NXColors.border.opacity(0.58)],
                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.1))
        .shadow(color: NXColors.cyan.opacity(0.23), radius: 10, y: 2)
    }

    // Protege el mismo destino cuando unas opciones usan recursos incorporados
    // y otras se han agregado más tarde con paquetes .3105.
    private func activeConflict(bundleID: String, path: String, excluding: UUID) -> String? {
        if bundleID == "com.dts.freefireth" {
            for option in NXBundledOption.all where option.id != excluding && option.targetPath == path {
                if DevicePatchService.latestReceipt(projectID: option.id) != nil { return option.title }
            }
        }
        for item in store.items where item.id != excluding {
            guard DevicePatchService.latestReceipt(projectID: item.id) != nil,
                  let project = item.project else { continue }
            if project.rules.contains(where: { $0.bundleID == bundleID && $0.relativePath == path }) {
                return project.name
            }
        }
        return nil
    }

    private func toggleBuiltIn(_ option: NXBundledOption, enabled: Bool) {
        guard busyProject == nil else { return }
        if enabled {
            // Si una versión cambió, permitir continuar SOLO si la pareja
            // verificada para el original ACTUAL está disponible.
            let requiresUpdatedPair = isChanged(option.targetPath)
            if let activeName = activeConflict(bundleID: "com.dts.freefireth", path: option.targetPath, excluding: option.id) {
                feedback = NXFeedback(message: "El archivo de destino ya lo utiliza \(activeName). Desactiva esa opción antes de activar \(option.title).")
                return
            }
            busyProject = option.id
            Task.detached(priority: .userInitiated) {
                do {
                    let originalURL = try option.originalURL()
                    var project = try option.makeProject()
                    // Solo si el catálogo publicó una variante del identificador real
                    // Y su original coincide byte por byte con el archivo accesible.
                    // Sin pareja validada, se conserva el control previo por respaldos.
                    let matching = try NXVersionedPairStore.compatibleVariant(
                        id: option.id.uuidString, originalURL: originalURL
                    )
                    // Un cambio confirmado por la vigilancia nunca se resuelve
                    // con el archivo embebido antiguo. Requiere pareja nueva exacta.
                    if requiresUpdatedPair && matching == nil {
                        throw NXPairFailure.originalChanged
                    }
                    if let matching {
                        guard project.rules.count == 1 else { throw NXPairFailure.invalidPair }
                        project.rules[0].replacementData = matching.data
                        _ = try DevicePatchService.apply(
                            project: project,
                            verifiedOriginals: [project.rules[0].id: matching.originalDigest]
                        )
                    } else {
                        _ = try DevicePatchService.apply(project: project)
                    }
                    await MainActor.run {
                        if requiresUpdatedPair {
                            // Solo tras instalar con éxito la versión compatible.
                            let next = blockedPaths.subtracting([option.targetPath]).sorted()
                            if let data = try? JSONEncoder().encode(next),
                               let json = String(data: data, encoding: .utf8) {
                                blockedPathsJSON = json
                            }
                        }
                        busyProject = nil
                        store.reload()
                        activationFeedback.play()
                    }
                } catch {
                    let changed = (error as? PatchPackageError).flatMap { patchError -> [String]? in
                        if case .originalVersionChanged(let paths) = patchError { return paths }
                        return nil
                    }
                    await MainActor.run {
                        busyProject = nil
                        if let changed {
                            updatedOriginalNotice = NXOriginalVersionNotice(
                                details: changed.prefix(3).joined(separator: "\n")
                            )
                        } else {
                            feedback = NXFeedback(message: "No se aplicó \(option.title): \(error.localizedDescription)")
                        }
                    }
                }
            }
        } else if let receipt = DevicePatchService.latestReceipt(projectID: option.id) {
            restore(receipt: receipt)
        }
    }

    /// Una fila por función, con la misma estructura compacta que la foto de referencia.
    /// Los nombres no se dividen en dos líneas y no hay iconos de importar archivos.
    private func missingPackageRow(_ name: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "scope")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(NXColors.cyan.opacity(0.55))
                .frame(width: 25)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.67))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("Pendiente de archivo")
                    .font(.system(size: 10))
                    .foregroundStyle(NXColors.muted)
            }
            .layoutPriority(1)
            Spacer(minLength: 1)
            Toggle(name, isOn: .constant(false))
                .labelsHidden()
                .disabled(true)
                .scaleEffect(0.78, anchor: .trailing)
                .frame(width: 48, height: 38, alignment: .trailing)
                .accessibilityHint("No disponible. Se habilitará cuando exista un paquete válido con archivo y destino.")
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.73), in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(
            LinearGradient(colors: [NXColors.cyan.opacity(0.98), NXColors.border.opacity(0.58)],
                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.1))
        .shadow(color: NXColors.cyan.opacity(0.23), radius: 10, y: 2)
    }

    private func patchRow(_ item: PatchLibraryItem) -> some View {
        let loading = busyProject == item.id
        let applied = DevicePatchService.latestReceipt(projectID: item.id) != nil
        return HStack(spacing: 14) {
            Image(systemName: "scope")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(NXColors.cyan)
                .frame(width: 25)
            Text(item.project?.name ?? "Paquete protegido")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .layoutPriority(1)
            Spacer(minLength: 1)
            if loading { ProgressView().tint(NXColors.cyan) }
            Toggle(item.project?.name ?? "Paquete", isOn: Binding(
                get: { DevicePatchService.latestReceipt(projectID: item.id) != nil },
                set: { enabled in toggle(item, enabled: enabled) }
            ))
            .labelsHidden()
            .tint(NXColors.cyan)
            .disabled(loading || busyProject != nil || store.isBusy || item.isLocked || !appState.isSupported)
            .scaleEffect(0.78, anchor: .trailing)
            .frame(width: 48, height: 38, alignment: .trailing)
            .accessibilityValue(applied ? "Modificación activa" : "Original restaurado")
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.73), in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(
            LinearGradient(colors: [NXColors.cyan.opacity(0.98), NXColors.border.opacity(0.58)],
                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.1))
        .shadow(color: NXColors.cyan.opacity(0.23), radius: 10, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 21))
        .onTapGesture { if item.isLocked { store.requestUnlock(for: item) } }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button { showImporter = true } label: {
                Label("IMPORTAR .3105", systemImage: "square.and.arrow.down.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .frame(maxWidth: .infinity).frame(height: 43)
            }
            .buttonStyle(.plain)
            .background(NXColors.green, in: RoundedRectangle(cornerRadius: 13))
            .foregroundStyle(.black)
            Button { showCreator = true } label: {
                Image(systemName: "plus.square.fill")
                    .font(.system(size: 18)).frame(width: 50, height: 43)
            }
            .buttonStyle(.plain)
            .background(NXColors.surface, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(NXColors.border))
        }
    }

    // Esta sección prueba PatchTransaction en el propio sandbox de NEXORA.
    // Nunca selecciona ni escribe archivos de Free Fire u otras apps.
    private var motorDemoSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(NXColors.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PRUEBA DEL MOTOR 3105")
                        .font(.system(size: 12, weight: .heavy))
                    Text(nxMotorDemoIsApplied ? "Archivo de prueba MODIFICADO" : "Archivo de prueba ORIGINAL")
                        .font(.system(size: 10))
                        .foregroundStyle(NXColors.muted)
                }
                Spacer(minLength: 0)
                if nxMotorDemoBusy { ProgressView().tint(NXColors.cyan) }
                Toggle("Prueba local", isOn: Binding(
                    get: { nxMotorDemoIsApplied },
                    set: { enabled in runMotorDemo(enabled: enabled) }
                ))
                .labelsHidden()
                .disabled(nxMotorDemoBusy)
                .tint(NXColors.cyan)
                .scaleEffect(0.85, anchor: .trailing)
                .frame(width: 49)
            }
            Text(nxMotorDemoResult)
                .font(.system(size: 11))
                .foregroundStyle(NXColors.cyan)
                .fixedSize(horizontal: false, vertical: true)
            Text("Prueba con archivos originales/modificados propios, incluidos en la IPA. No modifica otros juegos ni prueba permisos de sus contenedores.")
                .font(.system(size: 10))
                .foregroundStyle(NXColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NXColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(NXColors.border))
    }

    private func runMotorDemo(enabled: Bool) {
        guard !nxMotorDemoBusy else { return }
        nxMotorDemoBusy = true
        Task.detached(priority: .userInitiated) {
            do {
                let message = try NXLocalMotorDemo.setEnabled(enabled)
                await MainActor.run {
                    nxMotorDemoIsApplied = NXLocalMotorDemo.isApplied
                    nxMotorDemoResult = message
                    nxMotorDemoBusy = false
                    if enabled { activationFeedback.play() }
                }
            } catch {
                await MainActor.run {
                    nxMotorDemoIsApplied = NXLocalMotorDemo.isApplied
                    nxMotorDemoResult = "Error de prueba: \(error.localizedDescription)"
                    nxMotorDemoBusy = false
                }
            }
        }
    }

    private var musicBar: some View {
        HStack(spacing: 10) {
            Image("NexoraMark")
                .resizable().scaledToFill().frame(width: 47, height: 47)
                .clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                Text("NEXORA PANEL").font(.system(size: 13, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text("Pista gratuita incluida")
                    .font(.system(size: 11)).foregroundStyle(NXColors.muted)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 2)
            Button { music.toggle() } label: {
                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18)).frame(width: 40, height: 36)
            }
            .buttonStyle(.plain).accessibilityLabel(music.isPlaying ? "Pausar" : "Reproducir")
        }
        .padding(10)
        .frame(maxWidth: 440)
        .background(Color(red: 0.070, green: 0.006, blue: 0.016), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(NXColors.border, lineWidth: 1))
        .padding(.horizontal, 19)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.96))
    }

    private func toggle(_ item: PatchLibraryItem, enabled: Bool) {
        guard busyProject == nil else { return }
        if enabled, let project = item.project,
           let changed = project.rules.first(where: {
               $0.bundleID == "com.dts.freefireth" && isChanged($0.relativePath)
           }) {
            feedback = NXFeedback(message: changedMessage(changed.relativePath))
            return
        }
        if enabled {
            guard let baseProject = item.project, appState.isSupported else {
                feedback = NXFeedback(message: "El paquete o la versión de iOS no están verificados.")
                return
            }
            for rule in baseProject.rules {
                if let conflict = activeConflict(bundleID: rule.bundleID, path: rule.relativePath, excluding: item.id) {
                    feedback = NXFeedback(message: "El archivo ya está ocupado por \(conflict). Primero restaura esa opción para conservar el respaldo original.")
                    return
                }
            }
            busyProject = item.id
            Task.detached(priority: .userInitiated) {
                do {
                    let project = item.summary.schemaVersion >= 2 && item.canInspectContents
                        ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                        : baseProject
                    _ = try DevicePatchService.apply(project: project)
                    await MainActor.run {
                        busyProject = nil
                        store.reload()
                        activationFeedback.play()
                    }
                } catch {
                    let changed = (error as? PatchPackageError).flatMap { patchError -> [String]? in
                        if case .originalVersionChanged(let paths) = patchError { return paths }
                        return nil
                    }
                    await MainActor.run {
                        busyProject = nil
                        if let changed {
                            updatedOriginalNotice = NXOriginalVersionNotice(
                                details: changed.prefix(3).joined(separator: "\n")
                            )
                        } else {
                            feedback = NXFeedback(message: "No se pudo aplicar \(baseProject.name): \(error.localizedDescription)")
                        }
                    }
                }
            }
        } else if let receipt = DevicePatchService.latestReceipt(projectID: item.id) {
            restore(receipt: receipt)
        }
    }

    private func restore(receipt: PatchTransactionReceipt) {
        guard busyProject == nil else { return }
        busyProject = receipt.projectID
        Task.detached(priority: .userInitiated) {
            do {
                let inspection = try DevicePatchService.inspectRestore(receipt: receipt)
                    // Los archivos diferentes (pero presentes) se preservan
                    // automáticamente: nunca pisar una posible actualización.
                    // Si algún archivo desapareció, detener y avisar sin forzar.
                    if inspection.changedTargets.contains(where: { $0.kind == .missing }) {
                        await MainActor.run {
                            busyProject = nil
                            feedback = NXFeedback(message: "Se detectó un archivo ausente mientras la opción estaba activa. No se sobrescribió ni reconstruyó automáticamente. Revisa la actualización del juego antes de continuar.")
                        }
                        return
                    }
                let cleanup = try DevicePatchService.restore(
                    receipt: receipt,
                    allowChangedTargets: false,
                    preserveExternallyChangedTargets: true
                )
                await MainActor.run {
                    busyProject = nil
                    store.reload()
                    if let warning = cleanup.warning {
                        feedback = NXFeedback(message: warning)
                    }
                }
            } catch {
                await MainActor.run {
                    busyProject = nil
                    feedback = NXFeedback(message: "No se pudo restaurar el original: \(error.localizedDescription)")
                }
            }
        }
    }
}

// Aviso sonoro de activación. Usa un recurso opcional o la voz del sistema.
// No modifica archivos de terceros ni registros de seguridad.
@MainActor
private final class NXActivationFeedback: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?

    func play() {
        // Evita avisos superpuestos si se activan opciones consecutivas.
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()

        // Reproduce la grabación personalizada incluida en Assets.xcassets.
        // La voz del sistema queda como respaldo si no se puede reproducir.
        if let data = NSDataAsset(name: "NexoraActivation")?.data,
           let audio = try? AVAudioPlayer(data: data) {
            player = audio
            audio.numberOfLoops = 0
            audio.prepareToPlay()
            if audio.play() { return }
            player = nil
        }

        let message = AVSpeechUtterance(string: "Opción activada")
        message.voice = AVSpeechSynthesisVoice(language: "es-ES")
        message.rate = 0.47
        synthesizer.speak(message)
    }
}

private final class NXMusicPlayer: ObservableObject {
    @Published var isPlaying = false
    private var player: AVAudioPlayer?

    init() {
        guard let data = NSDataAsset(name: "NexoraPulse")?.data else { return }
        do {
            player = try AVAudioPlayer(data: data)
            player?.numberOfLoops = -1
            player?.prepareToPlay()
        } catch { player = nil }
    }

    func restart() {
        guard let player else { return }
        player.currentTime = 0
        _ = player.play()
        isPlaying = player.isPlaying
    }

    func toggle() {
        guard let player else { return }
        if player.isPlaying { player.pause() } else { _ = player.play() }
        isPlaying = player.isPlaying
    }
}

private struct NXSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var license: NexoraLicenseModel
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var fileOperationCoordinator: FileOperationCoordinator
    @EnvironmentObject private var ownedUpdater: NXOwnedResourceUpdater
    @State private var settingsImporter = false
    @State private var settingsError: String?
    @State private var demoIsApplied = NXLocalMotorDemo.isApplied
    @State private var demoBusy = false
    @State private var demoResult = "Sin ejecutar"
    @State private var cleanupResult = "Limpieza de temporales: sin probar"
    @State private var showOwnedCleanupConfirmation = false
    @State private var ownedCleanupResult = "No se ha ejecutado la limpieza manual."
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var music: NXMusicPlayer
    let onCheckOriginals: () -> Void
    @AppStorage("nexora.safeAudit.enabled.v1") private var periodicAuditEnabled = true
    @AppStorage("nexora.safeAudit.status.v1") private var periodicAuditStatus = "Todavía no se han comprobado los archivos."

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    identity
                    card("MIS REDES", icon: "person.2.fill") {
                        social("Servidor de Discord", systemImage: "bubble.left.and.bubble.right.fill", url: NexoraSocialLinks.discord)
                        Divider().overlay(NXColors.border)
                        social("Grupo de WhatsApp", systemImage: "message.fill", url: NexoraSocialLinks.whatsapp)
                    }
                    card("COMPATIBILIDAD DE 3105", icon: "iphone") {
                        settingsDetail("Dispositivo", value: AppInfo.machineName)
                        settingsDetail("Sistema actual", value: "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))")
                        HStack(spacing: 8) {
                            Image(systemName: appState.isSupported ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(appState.isSupported ? Color.green : Color.orange)
                            Text(appState.isSupported ? "Versión reconocida por 3105" : "Versión no verificada por 3105")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text("3105 documenta iOS 17.0–17.7.x, 18.0–18.7.1, 26.0–26.6.1 y cuatro compilaciones beta de iOS 27. La firma y el acceso a datos requieren verificación aparte.")
                            .font(.system(size: 11))
                            .foregroundStyle(NXColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    card("MI LICENCIA", icon: "key.fill") {
                        // El usuario solo consulta el tiempo restante. Las keys
                        // se administran desde el panel privado del propietario.
                        if let expiresAt = license.expirationDate {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("Tiempo restante de tu key")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(NXColors.muted)
                                    Text(Self.remaining(to: expiresAt, now: context.date))
                                        .monospacedDigit()
                                        .font(.system(size: 23, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(NXColors.cyan)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.65)
                                        .accessibilityLabel("Tiempo restante de la licencia")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            Text("Tiempo restante no disponible: el servidor todavía no informó una fecha de vencimiento.")
                                .font(.system(size: 12))
                                .foregroundStyle(NXColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    card("VIGILANCIA DE ARCHIVOS", icon: "shield.checkered") {
                        Toggle("Revisar cada 5 minutos con NEXORA abierta", isOn: $periodicAuditEnabled)
                            .font(.system(size: 12))
                            .tint(NXColors.red)
                        Button("Comprobar ahora", action: onCheckOriginals)
                            .font(.system(size: 12, weight: .bold))
                        Text(periodicAuditStatus)
                            .font(.system(size: 11))
                            .foregroundStyle(NXColors.muted)
                        Text("Detecta diferencias contra respaldos conocidos. Si falla la lectura no bloquea otras opciones. No vigila todos los parches posibles.")
                            .font(.system(size: 10))
                            .foregroundStyle(NXColors.muted)
                    }
                    card("ACTUALIZACIONES DE NEXORA", icon: "arrow.triangle.2.circlepath.circle.fill") {
                        Toggle("Buscar automáticamente al abrir", isOn: $ownedUpdater.autoEnabled)
                            .font(.system(size: 12, weight: .semibold))
                            .tint(NXColors.red)
                        Text("Solo recursos y archivos de la propia app; no modifica otras aplicaciones ni instala nuevas IPAs.")
                            .font(.system(size: 11))
                            .foregroundStyle(NXColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField("URL HTTPS del catálogo de NEXORA", text: $ownedUpdater.manifestInput)
                            .font(.system(size: 11))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .padding(10)
                            .background(NXColors.elevated, in: RoundedRectangle(cornerRadius: 9))
                        TextField("Clave pública Ed25519 Base64 de tu catálogo (opcional)", text: $ownedUpdater.trustedSigningKeyInput)
                            .font(.system(size: 11))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(10)
                            .background(NXColors.elevated, in: RoundedRectangle(cornerRadius: 9))
                        Text("Las parejas original/variante solo se descargan si el catálogo tiene una firma válida. Sin firma, únicamente recursos propios.")
                            .font(.system(size: 10))
                            .foregroundStyle(NXColors.muted)
                        Text(ownedUpdater.provenanceStatus)
                            .font(.system(size: 10))
                            .foregroundStyle(NXColors.muted)
                        Button {
                            Task { await ownedUpdater.checkNow() }
                        } label: {
                            Label(ownedUpdater.isBusy ? "Comprobando…" : "Buscar actualizaciones ahora", systemImage: "arrow.down.circle")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .disabled(ownedUpdater.isBusy)
                        if ownedUpdater.isBusy { ProgressView().tint(NXColors.red) }
                        Text(ownedUpdater.status)
                            .font(.system(size: 11))
                            .foregroundStyle(NXColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        settingsDetail("Recursos gestionados", value: "\(ownedUpdater.installedCount)")
                        Divider().overlay(NXColors.border)
                        Text("ORIGINALES Y VARIANTES COMPATIBLES")
                            .font(.system(size: 11, weight: .bold))
                        Text("Una sola letra o byte distinto cambia el SHA-256. Si el original cambia, NEXORA no activa una variante de una versión anterior.")
                            .font(.system(size: 11))
                            .foregroundStyle(NXColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        settingsDetail("Parejas verificadas", value: "\(ownedUpdater.compatiblePairsCount)")
                        Button("Revisar versiones originales") {
                            ownedUpdater.inspectCompatibility()
                        }
                        .font(.system(size: 12, weight: .semibold))
                        Text(ownedUpdater.compatibilityStatus)
                            .font(.system(size: 11))
                            .foregroundStyle(NXColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 10) {
                            Button("Probar variante propia") {
                                ownedUpdater.runOwnedPairDemo(activate: true)
                            }
                            Button("Restaurar prueba") {
                                ownedUpdater.runOwnedPairDemo(activate: false)
                            }
                        }
                        .font(.system(size: 11, weight: .semibold))
                        Text(ownedUpdater.demoStatus)
                            .font(.system(size: 11))
                            .foregroundStyle(NXColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        if !ownedUpdater.releaseNotes.isEmpty {
                            Text("Notas del recurso actualizado")
                                .font(.system(size: 11, weight: .bold))
                            Text(ownedUpdater.releaseNotes)
                                .font(.system(size: 11))
                                .foregroundStyle(NXColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    card("ESTADO DE OPCIONES", icon: "checkmark.shield.fill") {
                        HStack(spacing: 10) {
                            Image(systemName: "archivebox.fill")
                                .foregroundStyle(NXColors.cyan)
                            Text("Activaciones con recibo registrado")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("\(activeReceiptCount)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(NXColors.cyan)
                        }
                        Text("Este contador muestra registros locales; no sustituye una prueba de restauración ni implica acceso a otras aplicaciones.")
                            .font(.system(size: 11))
                            .foregroundStyle(NXColors.muted)
                    }
                    DisclosureGroup("Diagnóstico técnico del motor 3105") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Prueba reversible con archivos propios de NEXORA")
                                .font(.system(size: 12))
                            HStack {
                                Text(demoIsApplied ? "Prueba: modificado" : "Prueba: original")
                                    .font(.system(size: 12))
                                Spacer()
                                if demoBusy { ProgressView() }
                                Toggle("Probar", isOn: Binding(
                                    get: { demoIsApplied },
                                    set: { testLocalMotor(enabled: $0) }
                                ))
                                .labelsHidden().disabled(demoBusy)
                                .tint(NXColors.red)
                            }
                            Text(demoResult).font(.system(size: 11)).foregroundStyle(NXColors.red)
                            Button {
                                testOwnedTemporaryCleanup()
                            } label: {
                                Label("Probar limpieza por opción", systemImage: "checkmark.shield.fill")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .disabled(demoBusy)
                            Text(cleanupResult)
                                .font(.system(size: 11))
                                .foregroundStyle(NXColors.red)
                            Button(role: .destructive) {
                                showOwnedCleanupConfirmation = true
                            } label: {
                                Label("Limpiar temporales propios ahora", systemImage: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .disabled(demoBusy || patchStore.isBusy || fileOperationCoordinator.payload != nil)
                            Text(ownedCleanupResult)
                                .font(.system(size: 11))
                                .foregroundStyle(NXColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Solo comprueba temporales dentro de NEXORA; no borra respaldos, registros ni datos externos.")
                                .font(.system(size: 11))
                                .foregroundStyle(NXColors.muted)
                            Text("No comprueba acceso a datos de otras apps")
                                .font(.system(size: 11)).foregroundStyle(NXColors.muted)
                        }
                        .padding(.top, 11)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .tint(NXColors.red)
                    .padding(15)
                    .background(NXColors.surface, in: RoundedRectangle(cornerRadius: 18))
                    card("INFORMACIÓN", icon: "info.circle.fill") {
                        Text("NEXORA SYSTEM 2026 · interfaz personalizada")
                            .font(.system(size: 12))
                        Text("Motor de parches derivado de 3105, software libre GPLv3. Los permisos no están garantizados por el diseño ni por la activación de una key.")
                            .font(.system(size: 11)).foregroundStyle(NXColors.muted)
                    }
                }
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 19).padding(.vertical, 17)
            }
            .background(NXColors.background)
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Listo") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .tint(NXColors.cyan)
        .confirmationDialog(
            "¿Limpiar los temporales propios de NEXORA?",
            isPresented: $showOwnedCleanupConfirmation,
            titleVisibility: .visible
        ) {
            Button("Limpiar temporales propios", role: .destructive) {
                cleanOwnedTemporaryWorkspaces()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Solo limpia temporales de NEXORA. No elimina respaldos, registros, licencias ni datos de otras apps.")
        }
        .fileImporter(
            isPresented: $settingsImporter,
            allowedContentTypes: [UTType(filenameExtension: "3105") ?? .data, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.pathExtension.lowercased() == "3105" else {
                    settingsError = "Debes seleccionar un paquete .3105"
                    return
                }
                patchStore.importPackage(at: url)
            case .failure(let error):
                settingsError = error.localizedDescription
            }
        }
        .alert("Importación", isPresented: Binding(
            get: { settingsError != nil },
            set: { if !$0 { settingsError = nil } }
        )) {
            Button("Aceptar") { settingsError = nil }
        } message: { Text(settingsError ?? "") }
    }

    private var activeReceiptCount: Int {
        let identifiers = Set(NXBundledOption.all.map(\.id) + patchStore.items.map(\.id))
        return identifiers.filter { DevicePatchService.latestReceipt(projectID: $0) != nil }.count
    }

    private func cleanOwnedTemporaryWorkspaces() {
        guard !demoBusy, !patchStore.isBusy,
              fileOperationCoordinator.payload == nil else {
            ownedCleanupResult = "Hay una operación activa; limpieza cancelada para proteger datos."
            return
        }
        // Mantener intactos los temporales de cualquier modificación que
        // todavía posea un recibo de restauración pendiente.
        let protectedIDs: Set<UUID>
        do {
            let knownIDs = try NXOwnedTemporaryWorkspaces.knownWorkspaceIDs()
            let catalogIDs = Set(NXBundledOption.all.map(\.id) + patchStore.items.map(\.id))
            protectedIDs = Set(knownIDs.union(catalogIDs).filter {
                DevicePatchService.latestReceipt(projectID: $0) != nil
            })
        } catch {
            ownedCleanupResult = "No se pudo verificar el estado de los temporales: \(error.localizedDescription)"
            return
        }
        demoBusy = true
        Task.detached(priority: .userInitiated) {
            do {
                let result = try NXOwnedTemporaryWorkspaces.cleanAll(keeping: protectedIDs)
                let message: String
                if result.isComplete {
                    message = "Limpieza verificada: \(result.cleanedWorkspaces) áreas y \(result.removedEntries) entradas temporales propias eliminadas. Respaldos conservados."
                } else {
                    message = "Limpieza PARCIAL: \(result.cleanedWorkspaces) áreas eliminadas; \(result.protectedWorkspaces) protegidas por restauración pendiente, \(result.failedWorkspaces.count) errores y \(result.unrecognizedEntries) entradas no reconocidas. Respaldos intactos."
                }
                await MainActor.run {
                    ownedCleanupResult = message
                    demoBusy = false
                }
            } catch {
                await MainActor.run {
                    ownedCleanupResult = "No se completó la limpieza: \(error.localizedDescription)"
                    demoBusy = false
                }
            }
        }
    }

    private func testOwnedTemporaryCleanup() {
        guard !demoBusy else { return }
        demoBusy = true
        Task.detached(priority: .userInitiated) {
            do {
                let message = try NXOwnedTemporaryWorkspaces.selfTest()
                await MainActor.run {
                    cleanupResult = message
                    demoBusy = false
                }
            } catch {
                await MainActor.run {
                    cleanupResult = "Error de limpieza: \(error.localizedDescription)"
                    demoBusy = false
                }
            }
        }
    }

    private func testLocalMotor(enabled: Bool) {
        guard !demoBusy else { return }
        demoBusy = true
        Task.detached(priority: .userInitiated) {
            do {
                let message = try NXLocalMotorDemo.setEnabled(enabled)
                await MainActor.run {
                    demoIsApplied = NXLocalMotorDemo.isApplied
                    demoResult = message
                    demoBusy = false
                }
            } catch {
                await MainActor.run {
                    demoIsApplied = NXLocalMotorDemo.isApplied
                    demoResult = "Error: \(error.localizedDescription)"
                    demoBusy = false
                }
            }
        }
    }

    private var identity: some View {
        HStack(spacing: 13) {
            Image("NexoraMark")
                .resizable().scaledToFit().frame(width: 55, height: 55)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("NEXORA SYSTEM").font(.system(size: 18, weight: .heavy))
                Text("2026 · Centro de configuración")
                    .font(.system(size: 12)).foregroundStyle(NXColors.muted)
            }
            Spacer()
        }
        .padding(16)
        .background(NXColors.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.0).foregroundStyle(NXColors.cyan)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(NXColors.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(NXColors.border))
    }

    private func settingsDetail(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundStyle(NXColors.muted)
            Text(value).font(.system(size: 13, weight: .medium))
        }
    }

    private func social(_ label: String, systemImage: String, url: String) -> some View {
        let address = URL(string: url)
        let valid = address?.scheme == "https" && address?.host != nil
        return Button {
            if let address = address, valid { openURL(address) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage).foregroundStyle(NXColors.cyan).frame(width: 23)
                Text(label).font(.system(size: 13)).foregroundStyle(.white)
                Spacer()
                Text(valid ? "Abrir" : "Pendiente")
                    .font(.system(size: 10)).foregroundStyle(NXColors.muted)
                Image(systemName: "arrow.up.right").font(.system(size: 10))
            }
        }
        .disabled(!valid)
    }

    private static func remaining(to date: Date, now: Date) -> String {
        let t = max(0, Int(date.timeIntervalSince(now)))
        return String(format: "%dd %02dh %02dm %02ds", t / 86400, (t % 86400) / 3600, (t % 3600) / 60, t % 60)
    }
}

// MARK: - NEXORA: autoprueba reversible (motor real 3105, solo archivos propios)
private enum NXLocalMotorDemo {
    private static let appID = "com.nexora.demo.local"
    private static let projectID = UUID(uuidString: "A67F94F8-1692-48FC-80F7-2C7D72F91805")!
    private static let relativePath = "Prueba/estado.txt"

    private static func root() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return support.appendingPathComponent("NexoraDemoMotor3105", isDirectory: true)
    }

    private static func roots() throws -> (container: URL, backups: URL) {
        let base = try root()
        let container = base.appendingPathComponent("Sandbox", isDirectory: true)
        let backups = base.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
        return (container, backups)
    }

    private static func asset(_ name: String) throws -> Data {
        guard let contents = NSDataAsset(name: name)?.data else {
            throw NSError(domain: "NEXORA", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Falta el recurso \(name) dentro de la IPA"])
        }
        return contents
    }

    static var isApplied: Bool {
        guard let base = try? root() else { return false }
        return PatchTransaction.latestReceipt(
            projectID: projectID, backupRoot: base.appendingPathComponent("Backups")
        ) != nil
    }

    static func setEnabled(_ enabled: Bool) throws -> String {
        let locations = try roots()
        let container = locations.container
        let backupRoot = locations.backups
        let target = container.appendingPathComponent(relativePath)
        let original = try asset("NXMotorOriginal")
        let replacement = try asset("NXMotorModificado")
        let existing = PatchTransaction.latestReceipt(projectID: projectID, backupRoot: backupRoot)

        let resolver: (String) throws -> URL = { requested in
            guard requested == appID else { throw PatchPackageError.targetAppUnavailable(requested) }
            return container
        }
        if enabled {
            guard existing == nil else { throw PatchPackageError.projectAlreadyApplied }
            let folder = target.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            // No borrar un archivo ya existente. Solo crear el original en una prueba nueva.
            if !FileManager.default.fileExists(atPath: target.path) {
                try original.write(to: target, options: .atomic)
            }
            guard try Data(contentsOf: target) == original else {
                throw NSError(domain: "NEXORA", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "El archivo de prueba original cambió. No se sobreescribirá."])
            }
            let rule = PatchRule(bundleID: appID, relativePath: relativePath,
                                 replacementFilename: "modificado.txt", replacementData: replacement)
            let project = PatchProject(id: projectID, name: "NEXORA - DEMO DE MOTOR",
                                       author: "NEXORA", bundleIdentifiers: [appID], rules: [rule])
            let receipt = try PatchTransaction.apply(project: project,
                                                     backupRoot: backupRoot,
                                                     containerResolver: resolver)
            guard FileManager.default.fileExists(atPath: receipt.journalURL.path),
                  try Data(contentsOf: target) == replacement else {
                throw NSError(domain: "NEXORA", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "No se pudo confirmar el reemplazo y su respaldo."])
            }
            return "Activación OK: reemplazo aplicado y respaldo del original creado."
        } else {
            guard let receipt = existing else {
                return "El archivo de prueba ya está en estado original."
            }
            let inspection = try PatchTransaction.inspectRestore(
                receipt: receipt, containerResolver: resolver)
            guard inspection.changedTargets.isEmpty else {
                throw NSError(domain: "NEXORA", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "El destino cambió. Se conserva el respaldo; restauración cancelada."])
            }
            try PatchTransaction.restore(receipt: receipt, containerResolver: resolver)
            guard try Data(contentsOf: target) == original else {
                throw NSError(domain: "NEXORA", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "La restauración no coincide con el original."])
            }
            return "Restauración OK: archivo ORIGINAL recuperado byte por byte."
        }
    }
}
