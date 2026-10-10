import Foundation

/// Was in der App wirklich getippt wird -- damit Umständliches messbar
/// wird und nicht geschätzt (R86).
///
/// **Woher der Punkt kommt.** Niklas am 09.09.2026, mitten im Testen des
/// umgebauten Editors: „kannst du fix ein logging einbauen was ich so
/// alles antippe denn siehst du ja was übel umständlich ist und was
/// nicht, und wir können so analyiseren was verbessert werden muss."
///
/// Der Anlass davor war eine falsche Zahl von mir: Ich hatte einen Umbau
/// mit „von drei Schritten auf einen" angekündigt, nachgerechnet waren
/// es zwei. Diese Spur ist das Gegenmittel -- danach steht die Zahl in
/// der Datenbank statt in einer Einschätzung.
///
/// **Sie ist AUS, bis jemand sie im Konto einschaltet.** Was jemand wann
/// antippt, ist sein Verhalten; das wird nicht nebenbei mitgenommen. Der
/// Server sagt beim Start, ob eingewilligt wurde (`GET`), und ein
/// Widerruf löscht drüben, was schon liegt.
///
/// **Warum diese Klasse nicht an den Hauptfaden gebunden ist.** Gemeldet
/// wird aus `Zeichenblock` heraus -- einer Struktur ohne Isolation, die
/// aus Gesten aufgerufen wird. Eine `@MainActor`-Klasse liesse sich von
/// dort nicht aufrufen, und den Aufrufweg dafür umzubauen hiesse, das
/// Messgerät ins Werkstück zu bauen. Der Zustand liegt deshalb unter
/// einem Schloss, und die Netzarbeit springt für den Zugriff auf das
/// Token selbst auf den Hauptfaden.
///
/// **Kein Inhalt, nur Handgriffe.** Ansicht, Handlung, ein kurzes
/// Beiwort. Kein Playname, kein Spielername, keine Koordinaten. Was
/// gezeichnet wurde, geht diese Messung nichts an.
final class Bedienspur: @unchecked Sendable {

    static let gemeinsam = Bedienspur()

    /// Ab so vielen Schritten wird sofort abgeliefert. Zwanzig sind
    /// wenige Sekunden Arbeit im Editor und ein Rumpf von zwei
    /// Kilobyte -- klein genug, um am Platz nicht aufzufallen.
    private static let buendel = 20

    /// So lange wird sonst gewartet. Wer aufhört zu tippen, hat meistens
    /// gerade etwas gefunden oder aufgegeben; beides will man sehen,
    /// ohne dass es erst beim nächsten Bündel ankommt.
    private static let ruheSekunden: UInt64 = 15

    /// Die Anmeldung, für das Token. `@MainActor`, weil sie dort lebt --
    /// so bleibt der Zugriff auch unter strenger Prüfung sauber.
    @MainActor static weak var anmeldung: Anmeldung?

    private struct Schritt {
        let folge: Int
        let wann: Date
        let ansicht: String
        let aktion: String
        let detail: String

        var alsJson: [String: Any] {
            ["folge": folge,
             "wann": Bedienspur.zeitform.string(from: wann),
             "ansicht": ansicht,
             "aktion": aktion,
             "detail": detail]
        }
    }

    private static let zeitform: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private let schloss = NSLock()
    private var an = false
    private var puffer: [Schritt] = []
    private var folge = 0
    /// Ein App-Start. Neu bei jedem Start, damit sich eine Sitzung am
    /// Stück lesen lässt, ohne dass daraus ein Wiedererkennungswert
    /// über Wochen wird.
    private let sitzung = UUID().uuidString
    /// Läuft schon eine Wartezeit? Sonst stünden nach zwanzig Tipps
    /// zwanzig Aufgaben in der Warteschlange.
    private var wartetSchon = false

    // --- An und aus -------------------------------------------------------

    /// Was der Server über die Einwilligung sagt, übernehmen.
    func einstellen(an neu: Bool) {
        schloss.lock()
        an = neu
        if !neu { puffer.removeAll() }
        schloss.unlock()
    }

    var istAn: Bool {
        schloss.lock()
        defer { schloss.unlock() }
        return an
    }

    /// Beim Start fragen, ob aufgezeichnet werden darf.
    @MainActor
    static func nachfragen() async {
        guard let anmeldung, anmeldung.angemeldet else { return }
        struct Antwort: Decodable { let an: Bool }
        do {
            let token = try await anmeldung.gueltigesToken()
            let antwort = try await Server.hole(
                Server.anfrage("/api/v1/konto/bedienspur/", token: token),
                als: Antwort.self)
            gemeinsam.einstellen(an: antwort.an)
        } catch {
            // Ein Fehler hier darf nichts nach sich ziehen: Die Messung
            // ist das Unwichtigste in dieser App. Aus bleibt aus.
            gemeinsam.einstellen(an: false)
        }
    }

    /// Den Schalter umlegen. Zurück kommt, was der Server danach sagt --
    /// nicht, was die App gerade wollte.
    @MainActor
    static func schalten(_ an: Bool) async throws {
        guard let anmeldung else { throw Server.Fehler.abgemeldet }
        struct Antwort: Decodable { let an: Bool }
        let token = try await anmeldung.gueltigesToken()
        let antwort = try await Server.hole(
            Server.anfrage("/api/v1/konto/bedienspur/", methode: "PUT",
                           rumpf: ["an": an], token: token),
            als: Antwort.self)
        gemeinsam.einstellen(an: antwort.an)
    }

    // --- Mitschreiben -----------------------------------------------------

    func merken(_ ansicht: String, _ aktion: String, _ detail: String = "") {
        schloss.lock()
        guard an else { schloss.unlock(); return }
        folge += 1
        puffer.append(Schritt(folge: folge, wann: Date(), ansicht: ansicht,
                              aktion: aktion, detail: detail))
        let voll = puffer.count >= Bedienspur.buendel
        let wartetBereits = wartetSchon
        if !voll { wartetSchon = true }
        schloss.unlock()

        if voll {
            abliefern()
        } else if !wartetBereits {
            Task.detached { [weak self] in
                try? await Task.sleep(nanoseconds:
                    Bedienspur.ruheSekunden * 1_000_000_000)
                self?.abliefern()
            }
        }
    }

    /// Alles Gesammelte hinüberschicken. Auch beim Wechsel in den
    /// Hintergrund -- sonst fehlt genau der letzte Handgriff vor dem
    /// Weglegen, und der ist oft der aufschlussreichste.
    func abliefern() {
        schloss.lock()
        wartetSchon = false
        let fracht = puffer
        puffer.removeAll()
        schloss.unlock()
        guard !fracht.isEmpty else { return }

        let sitzung = self.sitzung
        Task { @MainActor in
            guard let anmeldung = Bedienspur.anmeldung,
                  anmeldung.angemeldet else { return }
            do {
                let token = try await anmeldung.gueltigesToken()
                let anfrage = try Server.anfrage(
                    "/api/v1/konto/bedienspur/", methode: "POST",
                    rumpf: ["sitzung": sitzung,
                            "geraet": Bedienspur.geraet,
                            "schritte": fracht.map(\.alsJson)],
                    token: token)
                _ = try await Server.ausfuehren(anfrage)
            } catch {
                // VERLOREN IST VERLOREN, und das ist Absicht. Eine
                // Messung, die bei schlechtem Netz erneut anklopft,
                // bremst die App, die sie vermessen soll.
            }
        }
    }

    /// Gerät und Fassung, roh. Damit sich ein Bedienproblem, das nur auf
    /// einem kleinen Bildschirm auftritt, von einem allgemeinen
    /// unterscheiden lässt.
    static var geraet: String {
        let fassung = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let bau = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        #if canImport(UIKit)
        let system = ProcessInfo.processInfo.operatingSystemVersionString
        return "\(system) / \(fassung) (\(bau))"
        #else
        return "\(fassung) (\(bau))"
        #endif
    }
}

/// Kurzform für die Aufrufstellen.
///
/// Absichtlich eine freie Funktion und kein Aufruf über die Klasse: Sie
/// steht mitten in Bedienlogik, und `spur("editor", "werkzeug", "zone")`
/// verschwindet dort, wo `Bedienspur.gemeinsam.merken(...)` die Zeile
/// darunter verdecken würde. Was nicht lesbar ist, wird beim nächsten
/// Umbau mit entfernt.
func spur(_ ansicht: String, _ aktion: String, _ detail: String = "") {
    Bedienspur.gemeinsam.merken(ansicht, aktion, detail)
}
