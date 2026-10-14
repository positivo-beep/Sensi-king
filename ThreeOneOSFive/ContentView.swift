import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AVFoundation

// NEXORA SYSTEM: visual personalizado; el motor GPLv3 3105 permanece separado.
private enum NXColors {
    static let background = Color(red: 0.017, green: 0.009, blue: 0.034)
    static let surface = Color(red: 0.045, green: 0.027, blue: 0.065)
    static let elevated = Color(red: 0.11, green: 0.064, blue: 0.15)
    static let green = Color(red: 0.65, green: 0.22, blue: 0.96) // Violeta NEXORA; verde solo para estado online
    static let cyan = Color(red: 0.65, green: 0.22, blue: 0.96)
    static let border = Color(red: 0.26, green: 0.12, blue: 0.38)
    static let muted = Color(red: 0.65, green: 0.61, blue: 0.70)
    static let purple = Color(red: 0.69, green: 0.28, blue: 0.98)
}

private enum NexoraSocialLinks {
    // Dejar vacíos hasta que el propietario proporcione los enlaces reales.
    static let discord = ""
    static let whatsapp = ""
}

private struct NXFeedback: Identifiable {
    let id = UUID()
    let message: String
}

private struct NXCategory: Identifiable {
    let title: String
    let symbol: String
    var id: String { title }
}

struct ContentView: View {
    @EnvironmentObject private var store: PatchProjectStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var license: NexoraLicenseModel
    @Environment(\.appLanguage) private var language
    @StateObject private var music = NXMusicPlayer()
    @State private var selectedCategory = "AIMBOT"
    @State private var showSettings = false
    @State private var showImporter = false
    @State private var showCreator = false
    @State private var showBrowser = false
    @State private var fileTabs = FilesTabSession()
    @State private var busyProject: UUID?
    @State private var restoreConflict: PatchTransactionReceipt?
    @State private var feedback: NXFeedback?
    @State private var compatibilityNoticeShown = false
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
                    NXColors.background.ignoresSafeArea()
                    LinearGradient(
                        colors: [
                            Color(red: 0.018, green: 0.010, blue: 0.034),
                            Color(red: 0.053, green: 0.012, blue: 0.078),
                            NXColors.background
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

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
                NXSettingsView(music: music)
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
                "El archivo de destino cambió después de aplicar el paquete.",
                isPresented: Binding(
                    get: { restoreConflict != nil },
                    set: { if !$0 { restoreConflict = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Restaurar de todas formas", role: .destructive) {
                    if let receipt = restoreConflict {
                        restoreConflict = nil
                        restore(receipt: receipt, allowChangedTargets: true)
                    }
                }
                Button("Cancelar", role: .cancel) { restoreConflict = nil }
            } message: {
                Text("Restaurar puede sobrescribir cambios posteriores. Comprueba que no estás usando la app asociada.")
            }
            .patchStorePresentation(store)
            .preferredColorScheme(.dark)
            .tint(NXColors.cyan)
            .onAppear {
                store.reload()
                nxMotorDemoIsApplied = NXLocalMotorDemo.isApplied
                if let unsupported = appState.unsupportedMessage, !compatibilityNoticeShown {
                    compatibilityNoticeShown = true
                    feedback = NXFeedback(message: "Tu sistema \(unsupported) no está verificado para el motor 3105. La licencia puede ser válida, pero las funciones de archivos quedan desactivadas.")
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

    private var brandHeader: some View {
        ZStack {
            VStack(spacing: 0) {
                Text("NEXORA")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .italic()
                    .tracking(1.8)
                    .foregroundStyle(LinearGradient(
                        colors: [.white, NXColors.purple, .white],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: NXColors.purple.opacity(0.55), radius: 13)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("— SYSTEM 2026 —")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(NXColors.purple)
            }
            HStack {
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .frame(width: 43, height: 43)
                        .background(NXColors.surface, in: Circle())
                }
                .accessibilityLabel("Configuración")
            }
            .foregroundStyle(.white)
        }
        .frame(height: 76)
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
                            .background(selected ? NXColors.cyan : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(4)
        }
        .background(Color(red: 0.055, green: 0.032, blue: 0.080), in: Capsule())
        .overlay(Capsule().stroke(NXColors.cyan.opacity(0.33), lineWidth: 1))
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
        if selectedCategory == "AIMBOT" {
            LazyVStack(spacing: 10) {
                ForEach(defaultAimbotNames, id: \.self) { name in
                    if let item = itemForDefault(name) {
                        patchRow(item)
                    } else {
                        missingPackageRow(name)
                    }
                }
                ForEach(filteredPackages.filter { item in
                    !defaultAimbotNames.contains(where: { name in
                        canonical(item.project?.name ?? item.packageURL.deletingPathExtension().lastPathComponent)
                            .contains(canonical(name))
                    })
                }) { item in
                    patchRow(item)
                }
            }
        } else if filteredPackages.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 19))
                    .foregroundStyle(NXColors.cyan)
                Text("Sin paquetes en esta categoría")
                    .font(.system(size: 13, weight: .semibold))
                Text("Puedes importar archivos .3105 desde Configuración cuando los tengas.")
                    .font(.system(size: 11))
                    .foregroundStyle(NXColors.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 23)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(filteredPackages) { item in patchRow(item) }
            }
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
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.60))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .layoutPriority(1)
            Spacer(minLength: 1)
            Toggle(name, isOn: .constant(false))
                .labelsHidden()
                .disabled(true)
                .scaleEffect(0.78, anchor: .trailing)
                .frame(width: 48, height: 38, alignment: .trailing)
                .accessibilityHint("Sin paquete importado")
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(NXColors.surface.opacity(0.84), in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(NXColors.border.opacity(0.65), lineWidth: 1))
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
        .background(NXColors.surface.opacity(0.84), in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(NXColors.border.opacity(0.65), lineWidth: 1))
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
        .background(Color(red: 0.055, green: 0.032, blue: 0.077), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(NXColors.border, lineWidth: 1))
        .padding(.horizontal, 19)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.96))
    }

    private func toggle(_ item: PatchLibraryItem, enabled: Bool) {
        guard busyProject == nil else { return }
        if enabled {
            guard let baseProject = item.project, appState.isSupported else {
                feedback = NXFeedback(message: "El paquete o la versión de iOS no están verificados.")
                return
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
                    }
                } catch {
                    await MainActor.run {
                        busyProject = nil
                        feedback = NXFeedback(message: "No se pudo aplicar \(baseProject.name): \(error.localizedDescription)")
                    }
                }
            }
        } else if let receipt = DevicePatchService.latestReceipt(projectID: item.id) {
            restore(receipt: receipt)
        }
    }

    private func restore(receipt: PatchTransactionReceipt, allowChangedTargets: Bool = false) {
        guard busyProject == nil else { return }
        busyProject = receipt.projectID
        Task.detached(priority: .userInitiated) {
            do {
                if !allowChangedTargets {
                    let inspection = try DevicePatchService.inspectRestore(receipt: receipt)
                    if !inspection.changedTargets.isEmpty {
                        await MainActor.run {
                            busyProject = nil
                            restoreConflict = receipt
                        }
                        return
                    }
                }
                try DevicePatchService.restore(receipt: receipt, allowChangedTargets: allowChangedTargets)
                await MainActor.run {
                    busyProject = nil
                    store.reload()
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
    @State private var settingsImporter = false
    @State private var settingsError: String?
    @State private var demoIsApplied = NXLocalMotorDemo.isApplied
    @State private var demoBusy = false
    @State private var demoResult = "Sin ejecutar"
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var music: NXMusicPlayer

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    identity
                    card("MIS REDES", icon: "person.2.fill") {
                        social("Servidor de Discord", systemImage: "bubble.left.and.bubble.right.fill", url: NexoraSocialLinks.discord)
                        Divider().overlay(NXColors.border)
                        social("Canal de WhatsApp", systemImage: "message.fill", url: NexoraSocialLinks.whatsapp)
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
                        HStack(spacing: 8) {
                            Circle().fill(Color.green).frame(width: 7, height: 7)
                            Text("Key validada en Cloudflare")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        if let duration = license.planDurationText {
                            settingsDetail("Duración de la key", value: duration)
                        } else {
                            Text("El servidor no informó la duración contratada. Mostramos el vencimiento real cuando esté disponible.")
                                .font(.system(size: 11)).foregroundStyle(NXColors.muted)
                        }
                        if let expiresAt = license.expirationDate {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Tiempo restante")
                                        .font(.system(size: 11)).foregroundStyle(NXColors.muted)
                                    Text(Self.remaining(to: expiresAt, now: context.date))
                                        .monospacedDigit()
                                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(NXColors.cyan)
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                }
                            }
                            settingsDetail("Vencimiento", value: expiresAt.formatted(date: .abbreviated, time: .shortened))
                        } else {
                            Text("Cloudflare no devolvió la fecha de vencimiento. No se puede calcular el tiempo restante sin ella.")
                                .font(.system(size: 12)).foregroundStyle(NXColors.muted)
                        }
                        Button("Comprobar key") { Task { await license.revalidate() } }
                            .disabled(license.isBusy)
                        Button("Cerrar sesión", role: .destructive) { license.signOut(); dismiss() }
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
                                .tint(NXColors.purple)
                            }
                            Text(demoResult).font(.system(size: 11)).foregroundStyle(NXColors.purple)
                            Text("No comprueba acceso a datos de otras apps")
                                .font(.system(size: 11)).foregroundStyle(NXColors.muted)
                        }
                        .padding(.top, 11)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .tint(NXColors.purple)
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
