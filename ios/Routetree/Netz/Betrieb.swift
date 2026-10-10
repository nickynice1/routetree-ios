import Foundation

/// Die abgespeckte Verwaltung -- das, was auf einen Menschen wartet.
///
/// **Woher der Punkt kommt.** Niklas am 09.09.2026: „und am
/// allercoolsten wäre es wenn ich sie sogar über die app in die
/// verwaltung komme also dort eine abgespeckte verwaltung nur unter
/// meinem username habe weißt du?"
///
/// **Abgespeckt heisst: NICHT der Verwaltungsbereich im Kleinen.** Ein
/// Datenbankeditor auf einem Telefon ist ein Weg, sich zu vertippen. Was
/// hier hineingehört, ist der Teil, der eilig ist und unterwegs
/// passiert: Ein Schulantrag liegt an, eine Kündigung ist eingegangen,
/// eine Zahlung ist schiefgegangen. Preise, Rechtstexte und
/// Funktionsschalter bleiben im Browser -- das macht niemand an der
/// Ampel.
///
/// **Wer hier hereinkommt.** Nicht `is_staff`, nicht ein Vereinsadmin,
/// sondern die eigene Rolle `Betreiber` (ADR-0010). Der Server
/// entscheidet das; die App fragt nur nach und zeigt den Eintrag
/// überhaupt erst, wenn die Antwort kommt. Ein Menüpunkt, der bei jedem
/// steht und bei allen ausser einem 403 liefert, verrät den Bereich
/// ohne Grund.
enum Betrieb {

    /// Was anliegt -- als Zahlen, nicht als Listen.
    ///
    /// Gezählt wird, was WARTET, nicht was da ist. „412 Schulanträge"
    /// sagt nichts; „2 offen" sagt alles.
    struct Ueberblick: Decodable {
        let stufe: String
        let darfAendern: Bool
        let wartet: Wartet
        let zahlungBereit: Bool
        let testbetrieb: Bool

        struct Wartet: Decodable {
            let schulantraege: Int
            let anfragen: Int
            let erklaerungen: Int
            let zahlungsfehler: Int

            /// Alles zusammen. Die Zahl fürs Abzeichen am Menüpunkt:
            /// Wer sie sieht, weiss, ob er hineinsehen muss.
            var summe: Int {
                schulantraege + anfragen + erklaerungen + zahlungsfehler
            }
        }

        enum CodingKeys: String, CodingKey {
            case stufe
            case darfAendern = "darf_aendern"
            case wartet
            case zahlungBereit = "zahlung_bereit"
            case testbetrieb
        }
    }

    struct Schulantrag: Decodable, Identifiable {
        let id: Int
        let schule: String
        let adresse: String
        let weg: String
        let zustand: String
        let angelegtAm: String
        let gueltigBis: String
        let bestaetigt: Bool
        let eingeloest: Bool
        let verein: String?

        enum CodingKeys: String, CodingKey {
            case id, schule, adresse, weg, zustand, bestaetigt, eingeloest,
                 verein
            case angelegtAm = "angelegt_am"
            case gueltigBis = "gueltig_bis"
        }
    }

    struct Schulantraege: Decodable {
        let gesamt: Int
        let antraege: [Schulantrag]
    }

    struct Erklaerung: Decodable, Identifiable {
        let id: Int
        let art: String
        let eingegangenAm: String
        let name: String
        let mail: String
        let bezeichnung: String
        let zeitpunkt: String
        let bemerkung: String
        let bestaetigt: Bool
        let erledigt: Bool

        enum CodingKeys: String, CodingKey {
            case id, art, name, mail, bezeichnung, zeitpunkt, bemerkung,
                 bestaetigt, erledigt
            case eingegangenAm = "eingegangen_am"
        }
    }

    struct Erklaerungen: Decodable {
        let gesamt: Int
        let erklaerungen: [Erklaerung]
    }

    static func ueberblick(token: String) async throws -> Ueberblick {
        try await Server.hole(
            Server.anfrage("/api/v1/admin/uebersicht/", token: token),
            als: Ueberblick.self)
    }

    static func schulantraege(token: String) async throws -> Schulantraege {
        try await Server.hole(
            Server.anfrage("/api/v1/admin/schulantraege/", token: token),
            als: Schulantraege.self)
    }

    /// **Der Grund ist Pflicht, und das ist keine Formsache.** Der
    /// Server weist einen Antrag ohne Begründung mit 400 ab -- weil
    /// später nur hier steht, WIE die Echtheit geprüft wurde. „Auf der
    /// Schulseite angerufen" ist eine Auskunft; ein leeres Feld ist
    /// keine.
    static func schulantragBestaetigen(_ kennung: Int, grund: String,
                                       token: String) async throws
        -> Schulantrag {
        try await Server.hole(
            Server.anfrage("/api/v1/admin/schulantraege/\(kennung)/bestaetigen/",
                           methode: "POST", rumpf: ["grund": grund],
                           token: token),
            als: Schulantrag.self)
    }

    static func erklaerungen(token: String) async throws -> Erklaerungen {
        try await Server.hole(
            Server.anfrage("/api/v1/admin/erklaerungen/", token: token),
            als: Erklaerungen.self)
    }

    struct Abgehakt: Decodable {
        let id: Int
        let erledigt: Bool
    }

    static func erklaerungErledigen(_ kennung: Int, grund: String,
                                    token: String) async throws -> Abgehakt {
        try await Server.hole(
            Server.anfrage("/api/v1/admin/erklaerungen/\(kennung)/erledigen/",
                           methode: "POST", rumpf: ["grund": grund],
                           token: token),
            als: Abgehakt.self)
    }
}
