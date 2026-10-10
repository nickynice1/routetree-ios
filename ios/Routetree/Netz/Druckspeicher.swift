// Drucken über die Schnittstelle (B10).
//
// WAS HIER NICHT PASSIERT: Es wird nichts gesetzt. Playcards, Call
// Sheet, Armbandeinlagen und Bilder entstehen auf dem SERVER, mit
// derselben Rechnung, die auch die Druckseite im Browser benutzt
// (`designer/printing.py`). Die App holt eine fertige Datei ab und legt
// sie auf das Gerät.
//
// WARUM NICHT NATIV GESETZT. Weil ein zweiter Satzapparat ein zweites
// Aussehen ergibt, und der Unterschied fiele erst am Spieltag auf: Der
// Trainer hält den Ausdruck vom Rechner in der einen Hand und den vom
// Telefon in der anderen, und die Nummern stehen woanders. Das GIF, die
// Schnittmarken und der Streifen der Demo hängen alle daran.

import Foundation

/// Holt Druckausgaben als Datei.
enum Druckspeicher {

    /// Eine abgeholte Datei auf dem Gerät.
    struct Datei: Identifiable, Equatable {
        let url: URL
        let art: String
        var id: URL { url }
        /// Ob sie sich an einen Drucker schicken lässt.
        var druckbar: Bool { Druckblock.druckbar(art) }
    }

    /// Was an diesem Heft hängt: Seiten, Logo, Streifen der Demo.
    static func auskunft(playbook: Int,
                         token: String) async throws -> Modell.Druckauskunft {
        try await Server.hole(
            Server.anfrage("/api/v1/playbooks/\(playbook)/druck/", token: token),
            als: Modell.Druckauskunft.self)
    }

    /// Holt die Ausgabe und legt sie als Datei ab.
    ///
    /// **Der Dateiname kommt vom Server**, wo es einen gibt: Er kennt den
    /// Namen des Hefts in dem Moment, in dem gedruckt wird. Die App
    /// kennt nur den, den sie zuletzt geladen hat. Geglaubt wird er
    /// trotzdem nicht -- `Druckblock.dateinameAusKopf` weist alles ab,
    /// was mehr als ein Dateiname ist.
    ///
    /// **Und der alte Stand wird überschrieben, nicht danebengelegt.**
    /// Wer zweimal dasselbe Armband druckt, hätte sonst „…-2.pdf" im
    /// Teilen-Blatt und schickte der Mannschaft den ersten Versuch.
    static func holen(_ wunsch: Druckwunsch, kennung: Int,
                      ersatzname: String = "routetree",
                      token: String) async throws -> Datei {
        let anfrage = try Server.anfrage(
            wunsch.weg(kennung: kennung), token: token, annehmen: "*/*",
            // Ein Bogen mit vierzig Diagrammen braucht auf dem Server
            // spürbar länger als eine Liste. Zwanzig Sekunden wären hier
            // ein Abbruch mitten im Satz.
            wartezeit: 90)
        let (daten, antwort) = try await Server.ausfuehren(anfrage)

        let kopf = (antwort as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition")
        let name = Druckblock.dateinameAusKopf(kopf)
            ?? Druckblock.dateiname(art: wunsch.art, stamm: ersatzname)

        let ordner = FileManager.default.temporaryDirectory
            .appendingPathComponent("Druck", isDirectory: true)
        try FileManager.default.createDirectory(at: ordner,
                                                withIntermediateDirectories: true)
        let ziel = ordner.appendingPathComponent(name)
        try daten.write(to: ziel, options: .atomic)
        return Datei(url: ziel, art: wunsch.art)
    }
}
