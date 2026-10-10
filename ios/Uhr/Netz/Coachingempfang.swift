// Was der Coach gerufen hat -- auf dem Handgelenk (R143).
//
// **Niklas am 01.10.2026:** „denn soll es so sein wie in spielmodus nur
// das mein coach auf seinem handy das play auswählt, und bei mir wird es
// automatisch auf der uhr angezeigt."
//
// ## Der Weg, und warum er über den Server läuft
//
// Coach und Spieler stehen hundert Meter auseinander und haben
// verschiedene Geräte. Über Bluetooth reden die beiden nie miteinander;
// `Uhrempfang` (R140) verbindet die Uhr nur mit IHREM eigenen Telefon.
//
// Der Coach ruft deshalb auf dem Server (`/api/v1/coaching/rufen/`),
// und die Uhr fragt dort nach (`/api/v1/coaching/stand/`). Welchen Weg
// die Uhr dorthin hat -- eigenes Netz oder über ihr Telefon --, sagt
// `Uhrleitung`.
//
// ## Warum die Uhr FRAGT und nicht geschoben bekommt
//
// Eine Benachrichtigung wäre sparsamer. Sie ist aber nicht verlässlich:
// watchOS stellt sie zu, wann es will, und am Spielfeldrand sind
// zwanzig Sekunden Verzögerung dasselbe wie gar nichts. Dazu bräuchte
// es APNs, Zertifikate und ein zweites Zustellsystem.
//
// Das Fragen kostet wenig, weil die Antwort fast immer leer ist: Die
// Uhr schickt den Stand mit, den sie schon hat, und bekommt
// `unveraendert` zurück. Gemessen in `test_coaching_last.py`: 68 Byte
// statt 2020, also 97 Prozent weniger je Abfrage. Ein ganzer Spieltag
// im Fünf-Sekunden-Takt kostet rund 258 Kilobyte.
//
// ## Der Schlüssel kommt vom Telefon, nicht von hier
//
// Die Uhr hat keine Anmeldung und soll keine bekommen -- auf einem
// Handgelenk ein Passwort einzutippen ist keine Bedienung. Das Telefon
// des TRÄGERS meldet die Uhr an (`/api/v1/coaching/uhr/`) und schickt
// ihr den Schlüssel über WatchConnectivity. Er gilt nur fürs Lesen
// dieser einen Adresse.

import Foundation
import SwiftUI

/// Was gerade gerufen ist -- genau so, wie der Server es schickt.
///
/// **Abgeschrieben und nicht erfunden.** Die Felder stehen in
/// `views.api_v1_coaching_stand`; wer hier eigene Namen waehlt,
/// bekommt `nil` und sucht danach im Netz statt im Quelltext.
struct Coachingstand: Equatable, Decodable {

    /// Zeitpunkt des Rufs, in MILLISEKUNDEN seit 1970.
    ///
    /// **Eine Zahl und kein Zeitstempel**, und der Grund steht im
    /// Server: Ein ISO-Zeitstempel endet auf `+00:00`, und in einer
    /// Adresse bedeutet `+` ein Leerzeichen. Der Vergleich `?seit=`
    /// schlug damit immer fehl, und die Uhr lud bei jeder Frage die
    /// ganze Zeichnung -- still, und genau da, wo der Akku knapp ist.
    let stand: Double?

    /// Wie diese Uhr beim Anmelden genannt wurde („Nummer 7").
    let name: String?

    /// Der Server sagt: seit `seit` hat sich nichts getan.
    let unveraendert: Bool?

    /// Wie viele Spielzüge der Coach vorbereitet hat (R143.2).
    ///
    /// **Sie kommt auch im Sparfall mit**, und darauf kommt es an: Der
    /// Coach reiht ein, ohne dass ein Play gerufen wird -- der Stand
    /// ändert sich dabei nicht. Hinge die Zahl an der Zeichnung, stünde
    /// auf dem Handgelenk weiter „0 warten", während drei vorbereitet
    /// sind, und der Träger tippte nie.
    let wartend: Int?

    let play: Coachingplay?
}

/// Die Antwort auf „einen weiter".
///
/// Dieselben Felder wie `Coachingstand`, aber ohne `unveraendert` --
/// wer weiterschaltet, bekommt immer eine Zeichnung (oder `nil`, wenn
/// die Reihe leer war).
private struct Weitergabe: Decodable {
    let stand: Double?
    let wartend: Int?
    let play: Coachingplay?
}

/// Der gerufene Play.
///
/// **Ein eigener Typ und nicht `Uhrpaket.Play`.** Der traegt eine
/// Kennung als Zeichenkette (sie kommt aus dem Heft), der Server
/// schickt eine Zahl. Zwei Formate in einen Typ zu zwingen hiesse,
/// an einer Stelle zu luegen.
struct Coachingplay: Equatable, Decodable, Identifiable {

    let id: Int
    let name: String
    let los: Double
    let direction: Int

    /// Die Zeichnung, wie sie auch im Heft steht. `Zeichnung.swift`
    /// gehoert beiden Zielen, deshalb liest die Uhr sie direkt.
    let data: Zeichnung

    /// Als das, was `Uhrfeld` zeichnen kann.
    ///
    /// Die Kennung wird zur Zeichenkette -- auf der Uhr dient sie nur
    /// dazu, eine Liste auseinanderzuhalten, und dort steht dieser
    /// Play allein.
    var alsUhrplay: Uhrpaket.Play {
        Uhrpaket.Play(id: String(id), name: name, los: los,
                      richtung: direction, zeichnung: data)
    }
}

/// Holt in festem Takt, was der Coach gerufen hat.
@MainActor
final class Coachingempfang: ObservableObject {

    /// Der Play, der gerade gilt.
    @Published private(set) var play: Coachingplay?

    /// Wie diese Uhr heisst. Steht auf dem Bildschirm, damit ein
    /// Spieler sieht, dass er die richtige Uhr am Arm hat.
    @Published private(set) var name: String?

    /// Wann er gerufen wurde -- für „vor 12 s" auf dem Bildschirm.
    @Published private(set) var gerufenAm: Date?

    /// Wann die Uhr zuletzt erfolgreich gefragt hat. Daran sieht der
    /// Träger, ob die Verbindung noch steht.
    @Published private(set) var zuletztGefragt: Date?

    /// Was schiefging, als ganzer Satz. `nil`, solange es läuft.
    @Published private(set) var hinweis: String?

    /// Ob gerade eine Sitzung läuft.
    @Published private(set) var laeuft = false

    /// Wie viele Spielzüge noch warten (R143.2).
    ///
    /// **Niklas am 01.10.2026:** „denn brauch der qb nur einmal auf die
    /// uhr tippen und das play wechselt automatisch."
    @Published private(set) var wartend = 0

    /// Ob gerade weitergeschaltet wird. Hält das Tippen ruhig.
    @Published private(set) var schaltet = false

    //: Wie oft gefragt wird, in Sekunden.
    //:
    //: **Fünf und nicht eins.** Gemessen in `test_coaching_last.py`:
    //: Ein Spieltag kostet bei einem Takt von einer Sekunde 832
    //: Kilobyte, bei fünf noch 258. Der Unterschied am Handgelenk ist
    //: nicht die Datenmenge, sondern wie oft das Funkmodul aufwacht --
    //: und das ist der grösste Verbraucher der Uhr.
    //:
    //: Fünf Sekunden sind zugleich die Spanne, in der am Spielfeldrand
    //: nichts passiert: Zwischen Ruf und Snap liegen mehr.
    static let takt: TimeInterval = 5

    private let schluessel: String
    private var aufgabe: Task<Void, Never>?

    init(schluessel: String) {
        self.schluessel = schluessel
    }

    deinit { aufgabe?.cancel() }

    // MARK: - An und aus

    func anfangen() {
        guard !laeuft else { return }
        laeuft = true
        aufgabe = Task { [weak self] in
            while !Task.isCancelled {
                await self?.einmalFragen()
                try? await Task.sleep(
                    for: .seconds(Coachingempfang.takt))
            }
        }
    }

    func aufhoeren() {
        aufgabe?.cancel()
        aufgabe = nil
        laeuft = false
    }

    // MARK: - Fragen

    /// Eine Abfrage. Fehler werden GEMERKT, nicht geworfen.
    ///
    /// **Ein Funkloch ist kein Fehler**, es ist der Normalfall auf
    /// einem Sportplatz. Wer hier wirft, beendet die Sitzung beim
    /// ersten Schluckauf -- und der Spieler steht ohne Play da, weil
    /// er zwischen zwei Masten durchgelaufen ist.
    func einmalFragen() async {
        var weg = "/api/v1/coaching/stand/"
        if let stand = gerufenAm?.timeIntervalSince1970 {
            weg += "?seit=\(Int(stand * 1000))"
        }
        guard let anfrage = gebaut(weg) else { return }
        do {
            let (daten, antwort) = try await URLSession.shared.data(for: anfrage)
            guard let http = antwort as? HTTPURLResponse else { return }
            guard http.statusCode == 200 else {
                hinweis = http.statusCode == 401
                    ? String(localized: "Diese Uhr ist nicht mehr angemeldet.")
                    : String(localized: "Der Server antwortet gerade nicht.")
                return
            }
            let stand = try JSONDecoder().decode(Coachingstand.self, from: daten)
            uebernehmen(stand)
            hinweis = nil
            zuletztGefragt = Date()
        } catch {
            // KEIN SATZ BEI EINEM EINZELNEN AUSSETZER. Wer bei jedem
            // verpassten Takt eine Meldung schreibt, blinkt dem
            // Spieler ins Gesicht, waehrend die Uhr laengst wieder
            // laeuft. Gemeldet wird erst, wenn eine Weile nichts kam.
            if let zuletzt = zuletztGefragt,
               Date().timeIntervalSince(zuletzt) > Coachingempfang.takt * 4 {
                hinweis = String(localized: "Keine Verbindung zum Server.")
            }
        }
    }

    private func uebernehmen(_ stand: Coachingstand) {
        // DIE ZAHL DER WARTENDEN ZUERST -- sie gilt auch im Sparfall.
        // Stünde sie hinter dem `return`, bliebe sie stehen, sobald
        // sich die Zeichnung nicht ändert, und genau das ist der
        // Normalfall beim Einreihen. Geprüft serverseitig in
        // `test_wie_viele_warten_steht_auch_im_sparfall_da`.
        if let offen = stand.wartend { wartend = offen }
        if stand.unveraendert == true { return }
        if let neu = stand.play { play = neu }
        if let ms = stand.stand { gerufenAm = Date(timeIntervalSince1970: ms / 1000) }
        if let n = stand.name { name = n }
    }

    // MARK: - Weiterschalten

    /// Einen weiter aus der Reihe (R143.2).
    ///
    /// **Das Einzige, was die Uhr schreiben darf**, und es ist eng
    /// gefasst: Sie rückt ihre eigene Reihe um eins vor. Sie kann
    /// keinen Play wählen, keinen einreihen und keine andere Uhr
    /// anfassen -- der Server lässt sie nicht (`api_v1_coaching_weiter`).
    ///
    /// **Wenn die Reihe leer ist, bleibt der Bildschirm, wie er ist.**
    /// Ein Tippen ohne Vorbereitung darf den laufenden Play nicht
    /// wegnehmen: Auf dem Feld ist ein leerer Schirm schlimmer als ein
    /// alter Spielzug.
    func weiterschalten() async {
        guard !schaltet, wartend > 0 else { return }
        guard let anfrage = gebaut("/api/v1/coaching/weiter/",
                                   methode: "POST") else { return }
        schaltet = true
        defer { schaltet = false }
        do {
            let (daten, antwort) = try await URLSession.shared.data(for: anfrage)
            guard let http = antwort as? HTTPURLResponse,
                  http.statusCode == 200 else {
                hinweis = String(localized: "Das liess sich nicht weiterschalten.")
                return
            }
            let neu = try JSONDecoder().decode(Weitergabe.self, from: daten)
            if let offen = neu.wartend { wartend = offen }
            if let p = neu.play { play = p }
            if let ms = neu.stand {
                gerufenAm = Date(timeIntervalSince1970: ms / 1000)
            }
            hinweis = nil
            zuletztGefragt = Date()
        } catch {
            hinweis = String(localized: "Keine Verbindung zum Server.")
        }
    }

    // MARK: - Werkzeug

    /// Eine Anfrage mit dem Uhrenschlüssel.
    ///
    /// **An einer Stelle und nicht an zwei.** Die Kopfzeile
    /// `Authorization` zweimal zu schreiben hiesse, dass eine von
    /// beiden beim nächsten Anfassen zurückbleibt -- und ein fehlender
    /// Schlüssel sieht am Handgelenk aus wie ein Funkloch.
    private func gebaut(_ weg: String,
                        methode: String = "GET") -> URLRequest? {
        guard let ziel = URL(string: weg, relativeTo: Uhrserver.basis) else {
            return nil
        }
        var anfrage = URLRequest(url: ziel)
        anfrage.httpMethod = methode
        anfrage.timeoutInterval = 15
        anfrage.setValue("application/json", forHTTPHeaderField: "Accept")
        anfrage.setValue("Bearer \(schluessel)",
                         forHTTPHeaderField: "Authorization")
        if methode == "POST" {
            anfrage.setValue("application/json",
                             forHTTPHeaderField: "Content-Type")
            anfrage.httpBody = Data("{}".utf8)
        }
        return anfrage
    }
}

/// Wohin die Uhr fragt.
///
/// **Eine eigene Stelle und nicht `Server.basis` aus der App.** Die
/// beiden Ziele teilen sich keinen Quelltext: `Server.swift` gehoert
/// zum Telefon und zieht die ganze Anmeldung mit. Hier steht nur die
/// Adresse, und sie steht nur einmal.
enum Uhrserver {

    static var basis: URL {
        // DIESELBE ADRESSE WIE IM TELEFON. Stand sie an zwei Stellen
        // mit zwei Werten, zeigte die Uhr Plays von einem anderen
        // Server als die App -- und niemand wuerde es merken, bis
        // jemand einen Play aendert.
        URL(string: "https://routetree.de")!
    }
}
