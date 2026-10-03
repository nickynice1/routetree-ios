import Foundation

/// Der Vorrat: die letzten Antworten des Servers, auf dem Gerät (R14).
///
/// **Was hier NICHT entschieden wird.** Welcher Weg abgelegt werden
/// darf, wie die Datei heißt und wann die App auf sie zurückgreift,
/// steht in `Vorratsblock` -- dort lässt es sich ohne Mac messen. Hier
/// steht nur das Anfassen der Platte.
///
/// **Abgelegt wird die ANTWORT, nicht das Modell.** Das ist die
/// Entscheidung, an der alles Weitere hängt:
///
/// * Ein `Modell.PlayVoll` ist `Decodable` und nicht `Encodable`. Es
///   auch schreibbar zu machen hieße, jedes Feld ein zweites Mal zu
///   pflegen -- und ein Feld, das jemand beim Schreiben vergisst,
///   fehlt am Platz und nirgends sonst.
/// * Der rohe Rumpf geht beim Hervorholen durch **genau dieselbe**
///   Stelle wie eine frische Antwort (`Server.entschluessler`). Die
///   Kopie kann also gar nicht anders gelesen werden als das Original.
///
/// **Nichts hiervon wirft.** Ein Vorrat, der beim Schreiben einen
/// Fehler auslöst, machte aus „kein Netz" einen Absturz -- also aus
/// einem Ärgernis das, was R14 überhaupt gemeldet hat. Was nicht
/// abgelegt werden kann, ist nicht abgelegt; die App merkt es beim
/// Nachsehen und holt es vom Server.
enum Vorrat {

    /// Ein Eintrag: der Rumpf, wann er entstand, und unter welcher
    /// Fassung.
    ///
    /// `marke` ist `nil`, wo es keine Versionsnummer gibt (die
    /// Heftliste hat keine). Dann heißt „da" schlicht „da".
    struct Eintrag: Codable {
        let marke: String?
        let stand: Date
        let rumpf: Data
    }

    // MARK: - Wo es liegt

    /// `Application Support`, nicht `Documents` und nicht `Caches`.
    ///
    /// * **Nicht `Documents`:** Das ist der Ordner, den der Nutzer über
    ///   die Dateien-App sieht. Ein Trainer, der dort vierzig
    ///   `-api-v1-plays-…json` findet, hält die App für kaputt.
    /// * **Nicht `Caches`:** Den räumt das System weg, wenn es eng
    ///   wird -- und zwar bevorzugt dann, wenn lange nichts benutzt
    ///   wurde. Genau das ist der Fall vor dem Spieltag.
    static var ordner: URL? {
        guard let wurzel = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let ziel = wurzel.appendingPathComponent("Vorrat", isDirectory: true)
        if !FileManager.default.fileExists(atPath: ziel.path) {
            try? FileManager.default.createDirectory(
                at: ziel, withIntermediateDirectories: true)
            // NICHT INS BACKUP. Der Vorrat ist eine Kopie; das Original
            // liegt auf dem Server. Ein iCloud-Backup mit vierzig
            // Zeichnungen darin kostet einen fremden Speicherplatz für
            // etwas, das sich in zehn Sekunden neu holen lässt -- und
            // Apple lehnt Apps dafür auch schon mal ab.
            var markiert = ziel
            var werte = URLResourceValues()
            werte.isExcludedFromBackup = true
            try? markiert.setResourceValues(werte)
        }
        return ziel
    }

    private static func datei(fuer weg: String) -> URL? {
        ordner?.appendingPathComponent(Vorratsblock.dateiname(fuer: weg))
    }

    // MARK: - Ablegen und hervorholen

    /// Eine Antwort ablegen. Ersetzt eine vorhandene.
    static func merken(_ rumpf: Data, fuer weg: String, marke: String?,
                       jetzt: Date = Date()) {
        guard let ziel = datei(fuer: weg) else { return }
        let eintrag = Eintrag(marke: marke, stand: jetzt, rumpf: rumpf)
        guard let daten = try? JSONEncoder.iso.encode(eintrag) else { return }
        // `.atomic`: erst danebenschreiben, dann umhängen. Ohne das
        // bliebe bei einem Abbruch mitten im Schreiben eine halbe Datei
        // liegen -- und die ist schlimmer als keine, weil die App sie
        // für eine Kopie hält.
        try? daten.write(to: ziel, options: .atomic)
    }

    static func holen(fuer weg: String) -> Eintrag? {
        guard let quelle = datei(fuer: weg),
              let daten = try? Data(contentsOf: quelle) else { return nil }
        return try? Server.entschluessler.decode(Eintrag.self, from: daten)
    }

    /// Unter welcher Fassung die Kopie abgelegt ist. `nil` heißt „keine
    /// Kopie da" oder „eine ohne Fassung".
    static func marke(fuer weg: String) -> String? {
        holen(fuer: weg)?.marke
    }

    // MARK: - Wegräumen

    /// Alles vergessen.
    ///
    /// **Beim Abmelden, und das ist kein Aufräumen, sondern die
    /// Bedingung dafür, dass es den Vorrat überhaupt geben darf.** Das
    /// Tablet im Vereinsheim reicht von Hand zu Hand: Wer sich abmeldet
    /// und dem Nächsten das Gerät gibt, hat seine Plays nicht mehr
    /// darauf. Ohne diese Zeile wäre der Vorrat eine Hintertür an der
    /// Anmeldung vorbei.
    static func leeren() {
        guard let ziel = ordner else { return }
        try? FileManager.default.removeItem(at: ziel)
    }
}
