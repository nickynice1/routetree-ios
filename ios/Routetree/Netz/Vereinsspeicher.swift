import Foundation

/// Was sich an einem VEREIN ändern lässt -- heute genau eines: sein Wappen.
///
/// **Warum das nicht in `Teamspeicher` steht.** Es sind zwei Dinge mit
/// zwei Rechteregeln: Eine Mannschaft führt ihr Head Coach, einen Verein
/// verwaltet ein Vereinsverwalter. Sie zusammenzulegen, weil beide ein
/// Logo haben, wäre die Art Sparsamkeit, nach der beim nächsten Mal
/// jemand die falsche Regel erwischt.
enum Vereinsspeicher {

    /// Was nach dem Ändern WIRKLICH gilt.
    ///
    /// **`logo` ist nicht dasselbe wie „das eigene Logo".** Nimmt man
    /// das eigene weg, gilt wieder das der ältesten Mannschaft, und
    /// genau das steht hier drin. Ein `nil` an dieser Stelle wäre
    /// gelogen: Auf dem Bildschirm erscheint sofort wieder ein Bild.
    ///
    /// `vonMannschaft` sagt, ob es geliehen ist -- ohne diese Angabe
    /// sucht man das Ändern an der falschen Stelle.
    struct Wappenstand: Decodable {
        let logo: URL?
        let vonMannschaft: Bool

        enum CodingKeys: String, CodingKey {
            case logo
            case vonMannschaft = "von_mannschaft"
        }
    }

    static func logoSetzen(verein: Int, bild: Data, token: String)
        async throws -> Wappenstand {
        try await Server.hole(
            Server.anfrageMitDatei(
                "/api/v1/vereine/\(verein)/logo/", feld: "logo", daten: bild,
                dateiname: "logo.png", typ: "image/png", token: token),
            als: Wappenstand.self)
    }

    static func logoEntfernen(verein: Int, token: String)
        async throws -> Wappenstand {
        try await Server.hole(
            Server.anfrage("/api/v1/vereine/\(verein)/logo/",
                           methode: "DELETE", token: token),
            als: Wappenstand.self)
    }
}
