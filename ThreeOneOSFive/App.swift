import SwiftUI
import UIKit
import Security
import Foundation

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @StateObject private var patchStore = PatchProjectStore()
    @StateObject private var repositoryStore = PackageRepositoryStore()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @Environment(\.scenePhase) private var scenePhase

    init() {
        setupLogCapture()
        // Mantenimiento en segundo plano: solo cachés temporales propios de NEXORA
        // abandonados durante al menos 48 horas. Respaldos y diarios intactos.
        DispatchQueue.global(qos: .utility).async {
            do {
                // Preservar las áreas temporales que pertenezcan a un proyecto
                // con respaldo todavía presente, aunque hayan pasado 48 horas.
                // Si no se pueden leer los respaldos, NO se realiza limpieza.
                let knownIDs = try NXOwnedTemporaryWorkspaces.knownWorkspaceIDs()
                let backupRoot = try PatchProjectLibrary.backupRootURL()
                let protectedIDs = try NXOwnedTemporaryWorkspaces.protectedWorkspaceIDs(
                    knownIDs: knownIDs, backupRoot: backupRoot
                )
                _ = try NXOwnedTemporaryWorkspaces.cleanAbandoned(keeping: protectedIDs)
            } catch {
                log("nexora: mantenimiento de caché propia pendiente: \(error.localizedDescription)")
            }
        }
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    var body: some Scene {
        WindowGroup {
            NexoraLicenseBoundary {
                ContentView()
                    .onAppear { appState.detectSupport() }
                    .onChange(of: scenePhase) { phase in
                        if phase == .active { appState.detectSupport() }
                    }
                    .environmentObject(appState)
                    .environmentObject(patchDraftCoordinator)
                    .environmentObject(fileOperationCoordinator)
                    .environmentObject(patchStore)
                    .environmentObject(repositoryStore)
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
            }
            .tint(Color(red: 1.00, green: 0.10, blue: 0.14))
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                patchDraftCoordinator.presentImport(url)
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        // iOS < 26: kernel R/W success persists (no sandbox probe)
        // iOS >= 26: verify full sandbox escape is still active
        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("app: existing sandbox access is still active; skipping kernel exploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("app: sandbox access is no longer active")
            }
        }
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("app: running kernel exploit on background...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "kexploit")
                    if KernelExploit.requiresSandboxEscape {
                        log("app: kernel exploit success — sandbox access verified")
                    } else {
                        log("app: kernel exploit success — kernel access active")
                    }
                } else {
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    log("app: kernel exploit failed — relaunch the app before retrying")
                }
            }
        }
    }
}

// NEXORA SYSTEM 2026
// Integración SwiftUI para el código fuente público 3105 (GPL-3.0).
// No depende de RX7 MODZ, .r7v, ni claves de terceros.
// Se incorpora al final del archivo ThreeOneOSFive/App.swift con instalar.py.

private enum NexoraPalette {
    static let background = Color(red: 0.022, green: 0.002, blue: 0.006)
    static let surface = Color(red: 0.072, green: 0.008, blue: 0.014)
    static let cyan = Color(red: 1.00, green: 0.18, blue: 0.22)
    static let red = Color(red: 1.00, green: 0.10, blue: 0.14)
}

private struct NexoraWirePayload: Encodable {
    let key: String
    let device_id: String
}

private struct NexoraWireResult: Decodable {
    let ok: Bool
    let active: Bool
    let expires_at: String?
    // Opcionales: si Cloudflare informa el plan, mostramos su duración real.
    let duration_days: Int?
    let duration_seconds: Int?
    let reason: String?
    let error: String?
}

private enum NexoraSecureStorage {
    static let service = "nexora.system.2026.licenses"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ text: String, _ account: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let changed = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if changed == errSecSuccess { return true }
        guard changed == errSecItemNotFound else { return false }
        var newQuery = query
        newQuery[kSecValueData as String] = data
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(newQuery as CFDictionary, nil) == errSecSuccess
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private final class NexoraNoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    // No seguir redirecciones: la key debe enviarse exclusivamente a nuestro Worker.
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
final class NexoraLicenseModel: ObservableObject {
    enum State { case checking, locked, allowed }

    @Published var state: State = .checking
    @Published var input = ""
    @Published var errorMessage = ""
    @Published var isBusy = false
    @Published var expiration: String?
    @Published private(set) var planDurationDays: Int?

    var planDurationText: String? {
        guard let planDurationDays else { return nil }
        return planDurationDays == 1 ? "1 día" : "\(planDurationDays) días"
    }

    var expirationDate: Date? {
        guard let expiration else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: expiration) ?? ISO8601DateFormatter().date(from: expiration)
    }

    /// Evita que una licencia ya vencida siga usando el panel mientras la app está abierta.
    func lockIfExpired(now: Date = Date()) {
        guard state == .allowed, let expiry = expirationDate, now >= expiry else { return }
        invalidateAndRequireNewKey("Tu key venció. Introduce una nueva key.")
    }

    /// Después de volver a la app, bloquear el panel hasta que responda Cloudflare.
    func revalidateOnReturn() async {
        guard state == .allowed, !isBusy else { return }
        state = .checking
        await revalidate()
    }

    private let endpoint = URL(string: "https://hypersex-licencias-propias.nexora-system26.workers.dev")!
    // Sesión efímera: evita guardar respuestas, cookies o caché de validación en disco.
    // No sustituye la autenticación del servidor ni protege una IPA alterada.
    private let licenseSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration, delegate: NexoraNoRedirectDelegate(), delegateQueue: nil)
    }()
    private let licenseAccount = "license"
    private let deviceAccount = "installation-id"
    private var hasStarted = false
    // Protege la pantalla de inicio si iOS deja una petición suspendida.
    // Una respuesta tardía nunca puede autorizar después del límite temporal.
    private var activeRequestNumber = 0

    private func endHungRequest(_ number: Int) {
        guard activeRequestNumber == number, isBusy, state == .checking else { return }
        activeRequestNumber += 1 // Invalida cualquier respuesta que aparezca tarde.
        isBusy = false
        state = .locked
        errorMessage = "La verificación tardó demasiado. Revisa tu conexión e inténtalo de nuevo."
    }

    // No generar una identidad distinta en cada petición si Keychain falla.
    // La licencia debe vincularse siempre a una identidad persistida y comprobada.
    private func persistentDeviceID() -> String? {
        if let existing = NexoraSecureStorage.read(deviceAccount) {
            guard UUID(uuidString: existing) != nil else { return nil }
            return existing
        }
        let id = UUID().uuidString
        guard NexoraSecureStorage.save(id, deviceAccount),
              NexoraSecureStorage.read(deviceAccount) == id else { return nil }
        return id
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await revalidate()
    }

    func revalidate() async {
        guard !isBusy else { return }
        guard let stored = NexoraSecureStorage.read(licenseAccount) else {
            state = .locked
            expiration = nil
            planDurationDays = nil
            errorMessage = ""
            return
        }
        state = .checking
        input = stored
        await request(path: "/v1/validate", key: stored, activating: false)
    }

    func activate() async {
        await request(path: "/v1/activate", key: input, activating: true)
    }

    func signOut() {
        // Una respuesta HTTPS pendiente no debe permitir la entrada tras salir.
        activeRequestNumber += 1
        isBusy = false
        NexoraSecureStorage.delete(licenseAccount)
        input = ""
        state = .locked
        errorMessage = ""
        expiration = nil
        planDurationDays = nil
    }

    private func invalidateAndRequireNewKey(_ message: String) {
        NexoraSecureStorage.delete(licenseAccount)
        input = ""
        expiration = nil
        planDurationDays = nil
        errorMessage = message
        state = .locked
    }

    private func request(path: String, key: String, activating: Bool) async {
        guard !isBusy else { return }
        let formatted = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !formatted.isEmpty, formatted.count <= 128 else {
            state = .locked
            errorMessage = "Introduce una key válida."
            return
        }
        isBusy = true
        activeRequestNumber += 1
        let requestNumber = activeRequestNumber
        // Vigilante limitado SOLO a la petición de key; NO hace escaneo de archivos.
        let deadline = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 35_000_000_000) }
            catch { return }
            self?.endHungRequest(requestNumber)
        }
        defer {
            deadline.cancel()
            if activeRequestNumber == requestNumber { isBusy = false }
        }
        errorMessage = ""
        guard let stableDeviceID = persistentDeviceID() else {
            state = .locked
            errorMessage = "No se pudo guardar la identidad del dispositivo. Revisa el acceso a Keychain."
            return
        }
        // La autoridad es Cloudflare, no una bandera local; no incluir secretos de administración.
        // La clave se envía solo al endpoint HTTPS definido por el propietario.
        guard endpoint.scheme == "https", endpoint.host != nil else {
            state = .locked
            errorMessage = "El servidor de licencias no está configurado de forma segura."
            return
        }
        var request = URLRequest(url: endpoint.appendingPathComponent(String(path.dropFirst())))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        do {
            request.httpBody = try JSONEncoder().encode(NexoraWirePayload(key: formatted, device_id: stableDeviceID))
            let (data, response) = try await licenseSession.data(for: request)
            guard activeRequestNumber == requestNumber else { return }
            // Ni redirecciones a otros hosts, ni respuestas anómalas, ni errores HTTP
            // pueden autorizar una licencia.
            guard let http = response as? HTTPURLResponse,
                  http.url?.scheme == "https",
                  http.url?.host == endpoint.host,
                  data.count <= 16_384 else {
                throw URLError(.badServerResponse)
            }
            if http.statusCode == 429 {
                state = .locked
                errorMessage = "Demasiados intentos. Espera un poco y vuelve a intentarlo."
                return
            }
            guard (200...499).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let result = try JSONDecoder().decode(NexoraWireResult.self, from: data)
            guard (200...299).contains(http.statusCode), result.ok && result.active else {
                // Una revocación/expiración conocida requiere otra key. Ante errores
                // de servidor o respuestas ambiguas, bloquear el panel SIN borrar la
                // key guardada: un fallo temporal no equivale a una revocación.
                let reason = result.reason ?? result.error
                if Self.isTerminalLicenseError(reason) {
                    invalidateAndRequireNewKey(Self.errorText(reason))
                } else {
                    state = .locked
                    errorMessage = "El servidor no pudo confirmar la licencia. Comprueba la conexión e inténtalo otra vez."
                }
                return
            }
            // Rechazar fechas de vencimiento inválidas en vez de aceptarlas
            // silenciosamente como si fueran licencias sin vencimiento.
            expiration = result.expires_at
            if let rawExpiry = result.expires_at, !rawExpiry.isEmpty, expirationDate == nil {
                invalidateAndRequireNewKey("El servidor devolvió un vencimiento no válido.")
                return
            }
            // El servidor es la fuente de verdad; nunca deducir un plan de 30 días.
            if let days = result.duration_days, days > 0 {
                planDurationDays = days
            } else if let seconds = result.duration_seconds, seconds > 0 {
                planDurationDays = Int(ceil(Double(seconds) / 86_400.0))
            } else {
                planDurationDays = nil
            }
            if let expiry = expirationDate, Date() >= expiry {
                invalidateAndRequireNewKey("Tu key venció. Introduce una nueva key.")
                return
            }
            guard NexoraSecureStorage.save(formatted, licenseAccount) else {
                state = .locked
                errorMessage = "No se pudo guardar la licencia en Keychain."
                return
            }
            state = .allowed
        } catch {
            guard activeRequestNumber == requestNumber else { return }
            // No mostrar detalles de red o del servidor en la interfaz pública.
            state = .locked
            errorMessage = "No se pudo verificar tu licencia. Comprueba la conexión e inténtalo de nuevo."
        }
    }

    private static func isTerminalLicenseError(_ reason: String?) -> Bool {
        switch reason {
        case "invalid_key", "invalid_key_format", "expired", "revoked", "device_limit":
            return true
        default: return false
        }
    }

    private static func errorText(_ reason: String?) -> String {
        switch reason {
        case "invalid_key", "invalid_key_format": return "La key no existe o no es válida."
        case "expired": return "Esta key venció."
        case "revoked": return "La key fue desactivada."
        case "device_limit": return "Se alcanzó el límite de dispositivos."
        case "device_not_activated": return "El dispositivo aún no está activado."
        // No reflejar texto arbitrario enviado por un servidor en la pantalla.
        default: return "No se pudo validar la licencia. Inténtalo de nuevo."
        }
    }
}

// El panel NEXORA solo se construye una vez validada la licencia.
struct NexoraLicenseBoundary<Content: View>: View {
    @StateObject private var model = NexoraLicenseModel()
    @Environment(\.scenePhase) private var scenePhase
    private let makeContent: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        // Construir el panel (y sus StateObject) solo después de la key válida.
        self.makeContent = content
    }

    var body: some View {
        Group {
            switch model.state {
            case .checking:
                ZStack {
                    NexoraPalette.background.ignoresSafeArea()
                    ProgressView("Verificando NEXORA...").tint(NexoraPalette.cyan)
                        .foregroundStyle(.white)
                }
            case .locked:
                NexoraKeyScreen(model: model)
            case .allowed:
                makeContent().environmentObject(model)
            }
        }
        .task { await model.start() }
        .task(id: model.state) {
            guard model.state == .allowed else { return }
            // Comprobación local por segundo; la revocación remota se confirma al volver.
            while !Task.isCancelled && model.state == .allowed {
                model.lockIfExpired()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await model.revalidateOnReturn() }
            }
        }
    }
}

private struct NexoraKeyScreen: View {
    @ObservedObject var model: NexoraLicenseModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                NXGothicBackdrop()

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: max(28, geometry.size.height * 0.085))
                        VStack(spacing: 10) {
                            HStack(spacing: 0) {
                                Text("NE").foregroundStyle(.white)
                                Text("X").foregroundStyle(NexoraPalette.red)
                                Text("ORA").foregroundStyle(.white)
                            }
                            .font(.system(size: min(72, geometry.size.width * 0.192),
                                          weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .shadow(color: NexoraPalette.red.opacity(0.85), radius: 16)
                            Text("— SYSTEM 2026 —")
                                .font(.system(size: 14, weight: .heavy))
                                .tracking(2.5)
                                .foregroundStyle(NexoraPalette.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 23))
                        .overlay(RoundedRectangle(cornerRadius: 23)
                            .stroke(LinearGradient(colors: [NexoraPalette.red,
                                                           Color(red: 0.93, green: 0.12, blue: 0.29)],
                                                   startPoint: .leading, endPoint: .trailing), lineWidth: 1.4))
                        .shadow(color: NexoraPalette.red.opacity(0.29), radius: 20)
                        .padding(.bottom, 29)

                        Text("NEXORA SYSTEM")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                            .foregroundStyle(.white)
                            .accessibilityAddTraits(.isHeader)
                        Text("Pega tu key para ingresar")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.57))
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("KEY DE ACCESO")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2.8)
                                .foregroundStyle(.white.opacity(0.62))

                            HStack(spacing: 13) {
                                Image(systemName: "key.horizontal.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(NexoraPalette.red)
                                SecureField("Introduce tu key", text: $model.input)
                                    .font(.system(size: 14))
                                    .textInputAutocapitalization(.characters)
                                    .textContentType(.password)
                                    .autocorrectionDisabled()
                                    .submitLabel(.go)
                                    .onSubmit { Task { await model.activate() } }
                                    .foregroundStyle(.white)
                                Button("PEGAR") {
                                    if let value = UIPasteboard.general.string { model.input = value }
                                }
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(NexoraPalette.cyan)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 58)
                            .background(Color.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 17))
                            .overlay(RoundedRectangle(cornerRadius: 17)
                                .stroke(NexoraPalette.red.opacity(0.88), lineWidth: 1.1))

                            if !model.errorMessage.isEmpty {
                                Text(model.errorMessage)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(red: 1.0, green: 0.41, blue: 0.42))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Button { Task { await model.activate() } } label: {
                                HStack(spacing: 12) {
                                    if model.isBusy { ProgressView().tint(.white) }
                                    Text("INGRESAR").tracking(1.6)
                                    Image(systemName: "arrow.right")
                                }
                                .font(.system(size: 15, weight: .heavy))
                                .frame(maxWidth: .infinity)
                                .frame(height: 57)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .background(
                                LinearGradient(colors: [Color(red: 0.48, green: 0.022, blue: 0.054),
                                                        Color(red: 1.00, green: 0.12, blue: 0.16)],
                                               startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 18)
                            )
                            .disabled(model.isBusy || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .padding(.top, 18)
                        }
                        .padding(.top, 33)

                        Text("NEXORA ROJO · BUILD 12 · ACCESO AUTORIZADO")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.6)
                            .foregroundStyle(.white.opacity(0.35))
                            .lineLimit(1).minimumScaleFactor(0.75)
                            .padding(.top, 30)
                        Spacer(minLength: 38)
                    }
                    .frame(maxWidth: 465)
                    .padding(.horizontal, 25)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
        .preferredColorScheme(.dark)
        .tint(NexoraPalette.red)
    }

    private static let dotX: [CGFloat] = [0.02,0.17,0.81,0.19,0.04,0.91,0.15,0.86,0.48,0.72,0.10,0.95]
    private static let dotY: [CGFloat] = [0.08,0.28,0.16,0.77,0.55,0.83,0.93,0.45,0.60,0.08,0.39,0.69]
}
