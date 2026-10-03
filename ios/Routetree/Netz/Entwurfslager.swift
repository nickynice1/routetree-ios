import Foundation

/// Was im Funkloch auf dem Gerät bleibt (R110.4).
///
/// **Der Browser hat das seit R4, die App nicht.** Dort liegt ein
/// ungesicherter Stand in `localStorage`, und beim nächsten Öffnen
/// steht die Frage da: „Von 18:42 liegt hier eine Änderung, die nie
/// beim Server angekommen ist." In der App gab es nur die
/// Fehlermeldung -- App zu heisst Arbeit weg, und zwar ausgerechnet
/// dort, wo das Offline-Argument dieses Produkts herkommt.
///
/// **Warum das NICHT der `Vorrat` ist.** Der hält, was vom Server KAM,
/// und darf jederzeit weggeworfen werden -- er ist eine Kopie. Was hier
/// liegt, gibt es sonst nirgends. Zwei Dinge mit entgegengesetzter
/// Löschregel im selben Ordner sind die Sorte Nachbarschaft, bei der
/// das Aufräumen des einen das andere mitnimmt.
///
/// **Nichts hiervon wirft.** Ein Lager, das beim Schreiben einen Fehler
/// nach oben gibt, bricht das Zeichnen ab -- und zwar an der Stelle,
/// an der es gerade darum geht, nichts zu verlieren.
enum Entwurfslager {

    /// Ein ungesicherter Arbeitsstand.
    ///
    /// **Er trägt ALLES, was der Verlauf auch trägt** (R110.7):
    /// Zeichnung, Lage des Balls, Angriffsrichtung und die
    /// Playangaben. Ein Entwurf, der nur die Zeichnung rettet, rettet
    /// die Hälfte -- und die andere Hälfte fehlt danach, ohne dass es
    /// jemandem auffällt.
    struct Entwurf: Codable, Equatable {
        /// Zu welchem Play er gehört.
        let play: Int
        /// Die Fassung, auf der er aufsetzt. Passt sie nicht mehr zu
        /// der des Servers, hat jemand anderes inzwischen gespeichert
        /// -- dann ist das ein Konflikt und keine Wiederherstellung.
        let version: Int
        let zeit: Date
        let zeichnung: Zeichnung
        let los: Double
        let richtung: Int
        let angaben: Playangabenstand
    }

    // MARK: - Wo es liegt

    /// `Application Support`, nicht `Caches`.
    ///
    /// **Der Unterschied ist der ganze Punkt.** `Caches` darf iOS
    /// jederzeit leeren, wenn der Speicher knapp wird -- bei einer
    /// Kopie ist das richtig, hier wäre es der Verlust genau der
    /// Arbeit, die gerettet werden soll.
    ///
    /// **Und ausdrücklich MIT Backup**, anders als der Vorrat: Was
    /// hier liegt, gibt es sonst nirgends.
    private static var ordner: URL? {
        guard let wurzel = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true) else { return nil }
        let ziel = wurzel.appendingPathComponent("Entwuerfe", isDirectory: true)
        try? FileManager.default.createDirectory(at: ziel,
                                                 withIntermediateDirectories: true)
        return ziel
    }

    private static func datei(fuer play: Int) -> URL? {
        ordner?.appendingPathComponent("play-\(play).json")
    }

    // MARK: - Hinlegen, holen, vergessen

    static func merken(_ entwurf: Entwurf) {
        guard let ziel = datei(fuer: entwurf.play),
              let daten = try? JSONEncoder().encode(entwurf) else { return }
        try? daten.write(to: ziel, options: .atomic)
    }

    /// Was für diesen Play noch offen liegt -- oder `nil`.
    static func holen(play: Int) -> Entwurf? {
        guard let quelle = datei(fuer: play),
              let daten = try? Data(contentsOf: quelle),
              let entwurf = try? JSONDecoder().decode(Entwurf.self, from: daten)
        else { return nil }
        return entwurf
    }

    /// Nach dem Sichern. **Und nur dann.**
    ///
    /// Ein Lager, das beim Verlassen des Bildschirms räumt, räumt genau
    /// im Funkloch auf -- also in dem Fall, für den es da ist.
    static func vergessen(play: Int) {
        guard let ziel = datei(fuer: play) else { return }
        try? FileManager.default.removeItem(at: ziel)
    }

    /// Alles weg -- beim Abmelden.
    ///
    /// Ein ungesicherter Play des vorigen Zugangs auf demselben Gerät
    /// wäre fremde Arbeit unter fremdem Namen.
    static func leeren() {
        guard let ordner else { return }
        try? FileManager.default.removeItem(at: ordner)
    }

    // MARK: - Was damit zu tun ist

    /// Wie ein gefundener Entwurf zu behandeln ist.
    enum Befund: Equatable {
        /// Nichts liegt da, oder es steht ohnehin schon so am Server.
        case nichts
        /// Es liegt etwas, und es passt auf den geladenen Stand.
        case anbieten(Entwurf)
        /// Es liegt etwas, aber inzwischen hat jemand anderes
        /// gespeichert. Das ist ein Konflikt und keine
        /// Wiederherstellung -- wer es hier stillschweigend
        /// zurückspielte, überschriebe fremde Arbeit.
        case veraltet(Entwurf)
    }

    /// Rechnet den Befund aus. **Ohne Bildschirm und deshalb messbar.**
    static func befund(fuer play: Int, serverVersion: Int,
                       serverZeichnung: Zeichnung) -> Befund {
        guard let entwurf = holen(play: play) else { return .nichts }
        // NICHTS ANBIETEN, WAS OHNEHIN SCHON SO DASTEHT. Eine Frage,
        // deren beide Antworten dasselbe bewirken, ist eine Frage zu
        // viel.
        if entwurf.zeichnung == serverZeichnung && entwurf.version == serverVersion {
            return .nichts
        }
        if entwurf.version != serverVersion { return .veraltet(entwurf) }
        return .anbieten(entwurf)
    }
}
