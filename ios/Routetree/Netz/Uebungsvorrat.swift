import Foundation

/// Das Übungspaket und die noch nicht gesendeten Antworten -- auf dem Gerät (R14).
///
/// **Warum eine eigene Ablage und nicht der Vorrat.** `Vorratsblock`
/// führt eine Positivliste, und `uebung` steht dort ausdrücklich NICHT
/// drauf; `test_vorrat.py` hält das fest. Das ist kein Versehen: Der
/// Vorrat legt die rohe Antwort zu EINEM Weg ab und ersetzt sie beim
/// nächsten Mal. Ein Übungspaket wird Frage für Frage abgearbeitet, und
/// dazu gehört eine Liste, die WÄCHST -- zwei verschiedene Dinge.
///
/// **Warum trotzdem IM Vorratsordner.** `Vorrat.leeren()` löscht diesen
/// Ordner rekursiv und wird an beiden Abmeldewegen gerufen. Alles, was
/// darin liegt, erbt das: Application Support (das System räumt es
/// nicht weg), kein iCloud-Backup, und weg beim Abmelden. Danebenzubauen
/// hieße, diese drei Eigenschaften ein zweites Mal herzustellen -- und
/// die dritte ist keine Bequemlichkeit, sondern die Bedingung dafür,
/// dass etwas auf dem Gerät liegen darf: Das Tablet im Vereinsheim
/// reicht von Hand zu Hand.
///
/// **Was hier liegt, und in welcher Form.**
///
/// * Das Paket als **rohe Antwort des Servers**, nicht als Modell.
///   Dieselbe Entscheidung wie beim Vorrat: Was hervorgeholt wird, geht
///   durch dieselbe Entschlüsselung wie eine frische Antwort. Ein Modell
///   schreibbar zu machen hieße, jedes Feld zweimal zu pflegen.
/// * Die offenen Antworten als **eigener kleiner Typ**
///   (`Modell.OffeneAntwort`, drei Felder). Der spiegelt kein
///   Servermodell, sondern ist das, was am Platz entsteht.
enum Uebungsvorrat {

    /// Ein Paket je Playbook. Wer zwei Hefte übt, hat zwei Pakete.
    private static func paketdatei(_ playbook: Int) -> URL? {
        Vorrat.ordner?.appendingPathComponent("uebungspaket-\(playbook).json")
    }

    /// **Die Antworten liegen je Playbook getrennt**, weil sie auch je
    /// Playbook nachgetragen werden -- die Adresse trägt die Kennung.
    private static func antwortdatei(_ playbook: Int) -> URL? {
        Vorrat.ordner?.appendingPathComponent("uebungsantworten-\(playbook).json")
    }

    // MARK: - Das Paket

    /// **Die rohe Antwort ablegen**, nicht das entschlüsselte Modell.
    static func paketMerken(_ rumpf: Data, playbook: Int) {
        guard let ziel = paketdatei(playbook) else { return }
        try? rumpf.write(to: ziel, options: .atomic)
    }

    /// Das abgelegte Paket -- durch dieselbe Entschlüsselung wie eine
    /// frische Antwort.
    ///
    /// `nil`, wenn keins da ist ODER es sich nicht lesen lässt. Beides
    /// bedeutet dasselbe: Es gibt nichts zu üben, also muss geholt
    /// werden. Ein halb gelesenes Paket wäre schlimmer als keins.
    static func paket(playbook: Int) -> Modell.Uebungspaket? {
        guard let ziel = paketdatei(playbook),
              let daten = try? Data(contentsOf: ziel)
        else { return nil }
        return try? Server.entschluessler.decode(
            Modell.Uebungspaket.self, from: daten)
    }

    static func paketWeg(playbook: Int) {
        guard let ziel = paketdatei(playbook) else { return }
        try? FileManager.default.removeItem(at: ziel)
    }

    // MARK: - Die Warteschlange

    static func offeneAntworten(playbook: Int) -> [Modell.OffeneAntwort] {
        guard let ziel = antwortdatei(playbook),
              let daten = try? Data(contentsOf: ziel),
              let liste = try? Server.entschluessler.decode(
                  [Modell.OffeneAntwort].self, from: daten)
        else { return [] }
        return liste
    }

    /// Eine Antwort anhängen.
    ///
    /// **Angehängt und nicht ersetzt**, und die Reihenfolge bleibt, wie
    /// sie entstanden ist: `Lernstand.serie` hängt daran -- erst richtig
    /// und dann falsch ergibt eine andere Serie als umgekehrt.
    ///
    /// **Dieselbe Marke kommt nicht zweimal hinein.** Am Platz tippt
    /// jemand zweimal, weil nichts passiert; ohne diese Zeile stünde die
    /// Antwort doppelt in der Schlange. Gezählt würde sie zwar trotzdem
    /// nur einmal (der Server verbraucht die Zeile), aber die App
    /// zeigte eine Frage als offen, die längst beantwortet ist.
    static func antwortMerken(_ antwort: Modell.OffeneAntwort,
                              playbook: Int) {
        var liste = offeneAntworten(playbook: playbook)
        guard !liste.contains(where: { $0.marke == antwort.marke }) else {
            return
        }
        liste.append(antwort)
        schreiben(liste, playbook: playbook)
    }

    /// Die genannten Marken aus der Schlange nehmen -- nach dem
    /// Nachtragen.
    ///
    /// **Auch die, die der Server als `gewertet: false` zurückgibt.**
    /// Das heißt „schon gezählt oder zu alt", und beides ist erledigt.
    /// Wer sie liegen ließe, schickte sie bis in alle Ewigkeit erneut.
    static func antwortenEntfernen(_ marken: Set<String>, playbook: Int) {
        let bleibt = offeneAntworten(playbook: playbook)
            .filter { !marken.contains($0.marke) }
        schreiben(bleibt, playbook: playbook)
    }

    private static func schreiben(_ liste: [Modell.OffeneAntwort],
                                  playbook: Int) {
        guard let ziel = antwortdatei(playbook) else { return }
        if liste.isEmpty {
            try? FileManager.default.removeItem(at: ziel)
            return
        }
        // `JSONEncoder.iso` und kein eigener: Er schreibt Zeiten so,
        // wie `Server.entschluessler` sie liest. Zwei Einstellungen
        // für dieselbe Sache wären die Stelle, an der ein Datum beim
        // Zurücklesen zerbricht -- und zwar erst auf dem Gerät.
        guard let daten = try? JSONEncoder.iso.encode(liste) else {
            return
        }
        try? daten.write(to: ziel, options: .atomic)
    }
}
