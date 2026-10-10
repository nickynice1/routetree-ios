import Foundation

/// Auskunft und Mitnahme (R110.9, Art. 15 und 20 DSGVO).
///
/// **Was gefehlt hat.** Die App konnte das Konto löschen -- Apples
/// Richtlinie 5.1.1(v) verlangt das -- und sonst nichts mit den eigenen
/// Daten anfangen. Wer wissen wollte, was über ihn gespeichert ist,
/// musste in den Browser; wer es mitnehmen wollte, ebenfalls. Damit
/// stand in der App genau der Weg zur Verfügung, nach dem die Daten weg
/// sind, und keiner von den beiden davor.
///
/// Art. 15 DSGVO gibt das Recht auf Auskunft, Art. 20 das auf ein
/// gängiges, maschinenlesbares Format. Der Server kann beides seit
/// Teil 8 (`GET /api/v1/konto/auskunft/`); es fehlte der Weg dorthin.
///
/// **Warum die Antwort hier NICHT durch ein Modell geht.** Sie ist die
/// Auskunft selbst und keine Anzeige: Was darin steht, entscheidet der
/// Server, und ein Swift-Modell dazwischen wäre eine zweite Liste
/// dessen, was als personenbezogen gilt. Käme dort ein Feld dazu, das
/// die App nicht kennt, verschwände es aus der Auskunft -- und niemand
/// merkte es, weil eine unvollständige Auskunft genauso aussieht wie
/// eine vollständige.
///
/// Also: der Rumpf, wie er kommt, nur lesbar eingerückt.
enum Datenauskunft {

    /// Der Dateiname, unter dem die Auskunft im Teilen-Blatt steht.
    ///
    /// Mit Datum, weil man sie mehrmals holt und sonst drei Dateien
    /// gleichen Namens im Ordner liegen.
    static func dateiname(am tag: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return "routetree-auskunft-\(f.string(from: tag)).json"
    }

    /// Holt die Auskunft und legt sie als Datei ab.
    ///
    /// Gibt die Adresse der Datei zurück -- das Teilen-Blatt des Systems
    /// nimmt eine Datei und keinen Text: Nur so landet sie in „Dateien",
    /// in einer Mail oder in der Cloud des Menschen, und genau darum
    /// geht es bei Art. 20.
    static func holen(token: String) async throws -> URL {
        let anfrage = try Server.anfrage("/api/v1/konto/auskunft/",
                                         token: token)
        let (daten, _) = try await Server.ausfuehren(anfrage)
        return try ablegen(daten)
    }

    /// Schreibt den Rumpf in eine Datei im Zwischenspeicher.
    ///
    /// **Eingerückt, wenn es sich einrücken lässt.** Eine Auskunft ist
    /// zum Lesen da, und eine einzige Zeile JSON liest niemand. Lässt
    /// sich der Rumpf nicht als JSON lesen -- ein Fehlertext, eine
    /// Störseite --, geht er unverändert hinaus: Lieber eine Datei, die
    /// erklärt, was schiefging, als eine Fehlermeldung, die den Inhalt
    /// verschluckt.
    ///
    /// **Im Zwischenspeicher und nicht in „Dokumente".** Was hier liegt,
    /// ist eine Kopie für den Weg nach draussen; das System räumt es
    /// auf. In „Dokumente" bliebe eine vollständige Auskunft über die
    /// Person dauerhaft auf dem Gerät liegen -- und zwar unverschlüsselt
    /// in jeder Sicherung.
    static func ablegen(_ daten: Data,
                        name: String? = nil) throws -> URL {
        var hinaus = daten
        if let objekt = try? JSONSerialization.jsonObject(with: daten),
           let schoen = try? JSONSerialization.data(
               withJSONObject: objekt,
               options: [.prettyPrinted, .sortedKeys,
                         .withoutEscapingSlashes]) {
            hinaus = schoen
        }
        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent(name ?? dateiname())
        try hinaus.write(to: ziel, options: .atomic)
        return ziel
    }
}
