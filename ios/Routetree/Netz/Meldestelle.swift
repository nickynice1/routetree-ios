// Einen Inhalt melden (Apple-Richtlinie 1.2).
//
// WARUM DIE GRÜNDE HIER STEHEN UND NICHT VOM SERVER KOMMEN. Ein
// Meldeblatt, das erst eine Liste holen muss, ist am Platz ohne Empfang
// kein Meldeblatt. Die Gründe ändern sich so gut wie nie -- und dass
// beide Fassungen gleich bleiben, hält `test_meldegruende.py` fest: Er
// vergleicht diese Datei mit `Inhaltsmeldung.Grund` im Server.
//
// Der Server nimmt nur Gründe an, die er kennt (400 sonst). Das ist
// Absicht: Ein unbekannter Wert würde stillschweigend zu „Etwas
// anderes", und eine Meldung, deren Grund niemand mehr kennt, ist die
// Sorte, die liegen bleibt.

import Foundation

/// Meldet einen Spielzug, der gegen die Hausordnung verstößt.
enum Meldestelle {

    /// Warum jemand meldet.
    ///
    /// Die Rohwerte sind die des Servers. Die Beschriftungen stehen ein
    /// zweites Mal hier, weil das Blatt sie ohne Netz zeigen können
    /// muss -- derselbe Grund wie bei den beiden Pflichtschaltflächen
    /// im Konto.
    enum Grund: String, CaseIterable, Identifiable {
        case beleidigung
        case hetze
        case sexuell
        case rechte
        case daten
        case sonst

        var id: String { rawValue }

        var beschriftung: String {
            switch self {
            case .beleidigung:
                return String(localized: "Beleidigend, bedrohlich oder schikanierend")
            case .hetze:
                return String(localized: "Hetze gegen Personen oder Gruppen")
            case .sexuell:
                return String(localized: "Sexuelle oder anzügliche Darstellung")
            case .rechte:
                return String(localized: "Verletzt fremde Rechte")
            case .daten:
                return String(localized: "Gibt Daten anderer preis")
            case .sonst:
                return String(localized: "Etwas anderes")
            }
        }
    }

    /// Was der Server zurückgibt. Die Kennung wird nicht angezeigt --
    /// sie steht hier, damit eine Meldung im Protokoll wiederfindbar
    /// ist, wenn jemand nachfragt.
    struct Bestaetigung: Decodable {
        let gemeldet: Bool
        let id: Int
    }

    /// - Parameter inGutemGlauben: Die Erklärung nach Artikel 16
    ///   Absatz 2 Buchstabe d DSA. **Kein Vorgabewert.** Ein `= true`
    ///   hier wäre bequem und falsch: Die Erklärung gibt der Mensch ab,
    ///   nicht der Aufrufer. Ohne sie antwortet der Server mit 400 --
    ///   dieselbe Regel wie im Browser, nur an einer Stelle geprüft.
    static func melden(play: Int, grund: Grund, text: String,
                       inGutemGlauben: Bool,
                       token: String) async throws -> Bestaetigung {
        try await Server.hole(
            Server.anfrage("/api/v1/plays/\(play)/melden/",
                           methode: "POST",
                           rumpf: ["grund": grund.rawValue, "text": text,
                                   "in_gutem_glauben": inGutemGlauben],
                           token: token),
            als: Bestaetigung.self)
    }
}
