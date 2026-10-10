// Der Coaching-Modus vom Telefon aus (R143).
//
// **Niklas am 01.10.2026:** „denn kann der coach einfach ins playbook
// gehen, hat dort oben rechts beim dropdown menü die möglichkeit den
// coaching modus zu starten. [...] und wenn er ein play auswählt also
// beim play auf die drei punkte und denn steht da nächster spielzug."
//
// ## Die Rollenteilung, und warum sie so ist
//
// Vier Adressen, drei davon gehören dem Telefon:
//
//   * **Uhr anmelden** -- legt eine Sitzung an und gibt den Schlüssel
//     GENAU EINMAL zurück. Danach kann ihn niemand mehr nachschlagen,
//     auch der Server nicht.
//   * **Uhren auflisten** -- wer wartet gerade, und lebt sie noch.
//   * **Rufen** -- jetzt sofort auf das Handgelenk.
//   * **Einreihen** -- hinten anstellen; der Quarterback holt sie ab.
//
// Die vierte (`stand`) gehört der Uhr und steht hier nicht.
//
// ## Warum ein eigener Typ und nicht `Vorrat`
//
// Der Coaching-Modus hat keinen Bestand, den man zwischenspeichern
// könnte. Was gilt, gilt für Sekunden -- und was gestern galt, ist
// heute falsch. Ein Zwischenspeicher wäre hier kein Dienst, sondern
// eine Quelle für Spielzüge, die niemand gerufen hat.

import Foundation

/// Eine angemeldete Uhr, wie der Server sie beschreibt.
struct Coachinguhr: Identifiable, Equatable, Decodable {

    let id: Int
    let name: String

    /// Ob sie sich in letzter Zeit gemeldet hat.
    ///
    /// **Der Server entscheidet das, nicht die App.** Er kennt den
    /// Zeitpunkt des letzten Abrufs; die App kennt nur, was in der
    /// Antwort steht. Zwei Rechnungen über dieselbe Frage liefen
    /// auseinander, sobald eine Uhr genau an der Grenze liegt.
    let lebt: Bool

    /// Kennung des Plays, der gerade auf diesem Handgelenk steht.
    ///
    /// **Eine Zahl und kein Name** -- so schickt der Server es. Den
    /// Namen gibt es daneben; beides stammt aus `_sitzung_kurz`.
    let play: Int?

    /// Wie der Play heisst, den die Uhr gerade zeigt.
    let play_name: String?

    /// Wie viele noch warten (R143.2).
    let wartend: Int

    /// Was in der Liste des Coaches steht.
    var zeile: String {
        var teile: [String] = []
        if let play_name { teile.append(play_name) }
        if wartend > 0 {
            teile.append(String(localized: "\(wartend) warten"))
        }
        return teile.isEmpty
            ? String(localized: "Noch nichts gerufen")
            : teile.joined(separator: " · ")
    }
}

enum Coaching {

    // MARK: - Einrichten

    /// Meldet eine Uhr an und gibt den Schlüssel zurück.
    ///
    /// **Der Rückgabewert ist das Einzige, was ihn je enthält.**
    /// Wer ihn wegwirft, muss die Uhr neu anmelden -- und die alte
    /// Sitzung ist damit tot.
    static func uhrAnmelden(team: Int, name: String,
                            token: String) async throws
    -> (uhr: Coachinguhr, schluessel: String) {
        struct Antwort: Decodable {
            let uhr: Coachinguhr
            let schluessel: String
        }
        let anfrage = try Server.anfrage(
            "/api/v1/coaching/uhr/", methode: "POST",
            rumpf: ["team": team, "name": name], token: token)
        let antwort = try await Server.hole(anfrage, als: Antwort.self)
        return (antwort.uhr, antwort.schluessel)
    }

    /// Welche Uhren dieser Mannschaft es gibt.
    static func uhren(team: Int, token: String) async throws -> [Coachinguhr] {
        struct Antwort: Decodable { let uhren: [Coachinguhr] }
        let anfrage = try Server.anfrage(
            "/api/v1/coaching/uhren/?team=\(team)", token: token)
        return try await Server.hole(anfrage, als: Antwort.self).uhren
    }

    // MARK: - Rufen

    /// Jetzt sofort auf dieses Handgelenk.
    static func rufen(uhr: Int, play: Int, token: String) async throws {
        let anfrage = try Server.anfrage(
            "/api/v1/coaching/rufen/", methode: "POST",
            rumpf: ["uhr": uhr, "play": play], token: token)
        _ = try await Server.ausfuehren(anfrage)
    }

    /// Hinten anstellen. Gibt zurück, wie viele dann warten.
    @discardableResult
    static func einreihen(uhr: Int, play: Int, token: String) async throws
    -> Int {
        struct Antwort: Decodable { let wartend: Int }
        let anfrage = try Server.anfrage(
            "/api/v1/coaching/einreihen/", methode: "POST",
            rumpf: ["uhr": uhr, "play": play], token: token)
        return try await Server.hole(anfrage, als: Antwort.self).wartend
    }

    // MARK: - Für mehrere Uhren

    /// Dasselbe an mehrere Handgelenke.
    ///
    /// **Jede Uhr einzeln und Fehler gesammelt.** Eine Uhr im
    /// Funkloch darf die anderen nicht aufhalten -- und der Coach
    /// soll hinterher wissen, welche es nicht bekommen hat, statt
    /// einer Meldung „etwas ging schief".
    static func anAlle(_ uhren: [Int], play: Int, token: String,
                       einreihen reihen: Bool = false) async -> [Int] {
        var gescheitert: [Int] = []
        for uhr in uhren {
            do {
                if reihen {
                    _ = try await einreihen(uhr: uhr, play: play, token: token)
                } else {
                    try await rufen(uhr: uhr, play: play, token: token)
                }
            } catch {
                gescheitert.append(uhr)
            }
        }
        return gescheitert
    }
}
