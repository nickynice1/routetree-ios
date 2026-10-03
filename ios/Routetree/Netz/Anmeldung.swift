import Foundation
import Security

/// Wer angemeldet ist -- und wie die App das über Neustarts hinweg behält.
///
/// **Token gehören in den Schlüsselbund, nicht in `UserDefaults`.** Das
/// ist der Unterschied zwischen „ein Backup enthält den Zugang" und
/// „nicht". `UserDefaults` liegt als lesbare Datei im Container und
/// wandert in jedes unverschlüsselte Backup.
@MainActor
final class Anmeldung: ObservableObject {

    struct Tokenpaar: Decodable {
        let zugriff: String
        let zugriffBis: Date
        let erneuerung: String
        let erneuerungBis: Date

        enum CodingKeys: String, CodingKey {
            case zugriff
            case zugriffBis = "zugriff_bis"
            case erneuerung
            case erneuerungBis = "erneuerung_bis"
        }
    }

    @Published private(set) var angemeldet = false
    @Published private(set) var laeuft = false
    @Published var fehler: String?

    private var paar: Tokenpaar? {
        didSet { angemeldet = paar != nil }
    }

    /// Die gerade laufende Erneuerung, damit es nie zwei gibt.
    /// Siehe `gueltigesToken()`.
    private var laufendeErneuerung: Task<String, Error>?

    init() {
        paar = Schluesselbund.lesen()
        angemeldet = paar != nil
    }

    // --- Anmelden und abmelden -------------------------------------------

    func anmelden(benutzername: String, passwort: String) async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            let anfrage = try Server.anfrage(
                "/api/v1/auth/token/", methode: "POST",
                rumpf: ["benutzername": benutzername,
                        "passwort": passwort,
                        "geraet": Geraetename.eigener])
            let neu = try await Server.hole(anfrage, als: Tokenpaar.self)
            Schluesselbund.schreiben(neu)
            paar = neu
        } catch {
            fehler = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Anmeldung fehlgeschlagen.")
        }
    }

    /// Mit Google oder Apple anmelden (R19).
    ///
    /// **Die App tauscht einen CODE, kein Token.** Den ganzen
    /// OAuth-Ablauf erledigt der Server in einem Systemfenster
    /// (`Fremdanmeldung`); herüber kommt eine Einmalfahrkarte, die zwei
    /// Minuten gilt. Was hier ankommt, ist dasselbe Tokenpaar wie beim
    /// Anmelden mit Passwort -- und es wird an derselben Stelle
    /// weggelegt.
    ///
    /// Abbrechen ist kein Fehler: Wer das Fenster zumacht, bekommt
    /// keine Meldung.
    func anmelden(mit code: String) async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            let anfrage = try Server.anfrage(
                "/api/v1/auth/fremd/", methode: "POST",
                rumpf: ["code": code, "geraet": Geraetename.eigener])
            let neu = try await Server.hole(anfrage, als: Tokenpaar.self)
            Schluesselbund.schreiben(neu)
            paar = neu
        } catch {
            fehler = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Anmeldung fehlgeschlagen.")
        }
    }

    /// Ein Tokenpaar übernehmen, das woanders entstanden ist (B12).
    ///
    /// Wer sich registriert oder mit einem Teamcode ein Konto anlegt,
    /// bekommt das Paar aus derselben Antwort -- er soll nicht als
    /// Nächstes eine Anmeldemaske sehen und ein Passwort eintippen, das
    /// er vor zwei Sekunden vergeben hat.
    ///
    /// **Es bleibt trotzdem diese eine Stelle, die es weglegt.** Sonst
    /// gäbe es zwei Wege, „angemeldet" zu werden, und einer davon
    /// vergisst den Schlüsselbund -- die App wäre nach dem nächsten
    /// Start wieder draußen, und niemand wüsste, warum.
    func uebernehmen(_ neu: Tokenpaar) {
        Schluesselbund.schreiben(neu)
        fehler = nil
        paar = neu
    }

    func abmelden() async {
        // Erst dem Server sagen, dann örtlich vergessen. Andersherum
        // bliebe bei einem Netzfehler ein gültiges Token auf dem Server,
        // das niemand mehr zurückziehen kann.
        if let erneuerung = paar?.erneuerung,
           let anfrage = try? Server.anfrage(
               "/api/v1/auth/logout/", methode: "POST",
               rumpf: ["erneuerung": erneuerung]) {
            _ = try? await Server.ausfuehren(anfrage)
        }
        Schluesselbund.loeschen()
        // DER VORRAT GEHT MIT (R14). Das Tablet im Vereinsheim reicht
        // von Hand zu Hand: Wer sich abmeldet und es weitergibt, hat
        // seine Plays nicht mehr darauf. Ohne diese Zeile wäre die
        // Kopie auf dem Gerät eine Tür an der Anmeldung vorbei.
        Vorrat.leeren()
        // UND DIE UNGESICHERTEN ENTWUERFE (R110.4). Sie wiegen
        // schwerer als der Vorrat: Was dort liegt, gibt es sonst
        // nirgends. Ein Play des vorigen Zugangs, der beim naechsten
        // Anmelden zur Wiederherstellung angeboten wuerde, waere fremde
        // Arbeit unter fremdem Namen.
        Entwurfslager.leeren()
        paar = nil
        // Eine laufende Erneuerung MUSS mit weg. Sonst schreibt sie
        // Sekunden nach dem Abmelden ein frisches Paar in den
        // Schlüsselbund, und die App ist wieder angemeldet -- ohne dass
        // jemand etwas getan hätte.
        laufendeErneuerung?.cancel()
        laufendeErneuerung = nil
    }

    // --- Token besorgen ---------------------------------------------------

    /// Ein gültiges Zugriffstoken -- erneuert selbst, wenn es abläuft.
    ///
    /// Eine Minute Vorlauf: Ein Token, das während der Anfrage abläuft,
    /// ergibt eine 401, die niemand erwartet hat.
    ///
    /// **NUR EINE ERNEUERUNG ZUR ZEIT** (Niklas, 09.09.2026: „Warum bin
    /// ich eigentlich ständig in der app abgemeldet?").
    ///
    /// Der Server rotiert die Erneuerungsschlüssel: Jede Erneuerung
    /// entwertet den benutzten, und taucht ein verbrauchter wieder auf,
    /// zieht er die GANZE Kette zurück. Das ist richtig -- es ist der
    /// Schutz gegen einen kopierten Schlüssel.
    ///
    /// Hier stand aber kein Riegel davor. `@MainActor` hilft nicht: Ein
    /// `await` unterbricht, und zwei Aufrufer kommen beide an der
    /// Ablaufprüfung vorbei, bevor einer von beiden fertig ist. Die App
    /// stellt reihenweise gleichzeitige Anfragen -- in `PlaybookListe`
    /// stehen zwei `async let` nebeneinander --, und sobald das
    /// Zugriffstoken nach dreißig Minuten abläuft, erneuern sie ALLE mit
    /// demselben Schlüssel. Der erste verbraucht ihn, der zweite schickt
    /// ihn hinterher, der Server zieht die Kette zurück, und der
    /// Benutzer steht vor der Anmeldung.
    ///
    /// Deshalb merkt sich die Klasse die laufende Erneuerung als
    /// `Task` und gibt sie jedem weiteren Aufrufer zurück, statt eine
    /// zweite zu starten.
    func gueltigesToken() async throws -> String {
        guard let vorhanden = paar else { throw Server.Fehler.abgemeldet }
        if vorhanden.zugriffBis.timeIntervalSinceNow > 60 {
            return vorhanden.zugriff
        }
        // Läuft schon eine? Dann auf deren Ergebnis warten.
        if let laufende = laufendeErneuerung {
            return try await laufende.value
        }
        let schluessel = vorhanden.erneuerung
        let aufgabe = Task { [weak self] () throws -> String in
            guard let self else { throw Server.Fehler.abgemeldet }
            return try await self.erneuern(mit: schluessel)
        }
        laufendeErneuerung = aufgabe
        defer { laufendeErneuerung = nil }
        return try await aufgabe.value
    }

    private func erneuern(mit erneuerung: String) async throws -> String {
        do {
            let anfrage = try Server.anfrage(
                "/api/v1/auth/refresh/", methode: "POST",
                rumpf: ["erneuerung": erneuerung])
            let neu = try await Server.hole(anfrage, als: Tokenpaar.self)
            Schluesselbund.schreiben(neu)
            paar = neu
            return neu.zugriff
        } catch Server.Fehler.abgemeldet {
            // Der Server hat die Kette zurückgezogen. Weiterprobieren
            // hätte keinen Zweck -- und ein stiller Fehlschlag wäre die
            // App, die endlos lädt.
            //
            // Der Vorrat geht auch hier mit: Wem der Server die Kette
            // zurückgezogen hat, dem ist sie zurückgezogen -- und nicht
            // „bis auf das, was noch auf dem Gerät liegt" (R14).
            Schluesselbund.loeschen()
            Vorrat.leeren()
            paar = nil
            throw Server.Fehler.abgemeldet
        }
    }

}

/// Wie das Gerät heißt, das ein Token bekommt.
///
/// An einer Stelle, weil es seit B12 DREI Wege herein gibt: anmelden,
/// registrieren und mit einem Teamcode ein Konto anlegen. Je Gerät eine
/// Kette -- abmelden auf dem Handy lässt das Tablet in Ruhe --, und das
/// geht nur, wenn überall derselbe Name drangeschrieben wird. Ein Weg
/// mit leerem Gerätenamen fällt nicht auf: Die Anmeldung klappt, und
/// erst beim Abmelden erwischt es die falsche Kette.
enum Geraetename {
    static var eigener: String {
        #if canImport(UIKit)
        return ProcessInfo.processInfo.hostName
        #else
        return "iOS"
        #endif
    }
}

// MARK: - Schlüsselbund

/// Der Schlüsselbund, auf das Nötigste beschränkt.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: Nach dem ersten
/// Entsperren lesbar (sonst käme die App nach einem Neustart im
/// Hintergrund nicht an ihre Token), aber **nicht** übertragbar auf ein
/// anderes Gerät. Ein Token, das per iCloud-Backup auf ein fremdes
/// Gerät wandert, ist ein Zugang, den niemand vergeben hat.
enum Schluesselbund {
    private static let dienst = "de.routetree.app"
    private static let konto = "tokenpaar"

    static func schreiben(_ paar: Anmeldung.Tokenpaar) {
        guard let daten = try? JSONEncoder.iso.encode(paar) else { return }
        loeschen()
        let eintrag: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
            kSecValueData as String: daten,
            kSecAttrAccessible as String:
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(eintrag as CFDictionary, nil)
    }

    static func lesen() -> Anmeldung.Tokenpaar? {
        let frage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var ergebnis: CFTypeRef?
        guard SecItemCopyMatching(frage as CFDictionary, &ergebnis) == errSecSuccess,
              let daten = ergebnis as? Data else { return nil }
        return try? Server.entschluessler.decode(Anmeldung.Tokenpaar.self, from: daten)
    }

    static func loeschen() {
        let frage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
        ]
        SecItemDelete(frage as CFDictionary)
    }
}

extension Anmeldung.Tokenpaar: Encodable {}

extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
