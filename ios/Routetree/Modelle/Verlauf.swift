// Rückgängig und Wiederholen: zwei Stapel und drei Regeln.
//
// WARUM DAS EINE EIGENE DATEI IST. Ein Rückgängig, das nur die Hälfte
// zurücknimmt, ist schlimmer als keins: Wer einmal erlebt hat, dass ein
// Schritt zurück etwas anderes wiederherstellt als das, was er gerade
// geändert hat, drückt den Knopf nie wieder. Die Regeln dahinter sind
// klein genug, um sie ganz zu messen, und genau das passiert in
// `VerlaufTests` -- ohne Mac, ohne Fenster, ohne Fingerspitzengefühl.
//
// DAS VORBILD IST `editor.js`. Dort ist ein Schritt der GANZE
// Arbeitsstand und nicht die einzelne Änderung, der Stapel hört bei 60
// auf, und jede neue Änderung löscht den Weg nach vorn.
//
// SEIT R110.3 IST ES AUCH HIER DER GANZE STAND. Bis dahin stand an
// dieser Stelle, die App habe weniger zu merken als der Browser: Name,
// Kategorie und die Lage des Balls seien in ihr ohnehin nicht zu
// ändern. Das stimmte, und seit R110.3 stimmt es nicht mehr: Der Ball
// lässt sich verschieben und die Angriffsrichtung umdrehen. Ein
// Verlauf, der nur die Zeichnung zurücknimmt, hätte danach die Hälfte
// zurückgenommen -- die Figuren stünden wieder, wo sie waren, und der
// Ball läge weiter woanders. Und das ist der Fall, den der Kopf dieser
// Datei seit dem ersten Tag als den schlimmsten beschreibt.

import Foundation

/// Die beiden Stapel hinter „Rückgängig" und „Wiederholen".
///
/// Ein Wert und kein Objekt: Der `Zeichenblock` trägt ihn mit sich, und
/// wer den Block kopiert, kopiert den Verlauf mit.
struct Verlauf: Equatable {

    /// Ein Arbeitsstand des Editors -- alles, was ein Schritt zurück
    /// wiederherstellen muss.
    ///
    /// **Warum die Lage des Balls dazugehört (R110.3).** Sie ist keine
    /// Eigenschaft der Zeichnung, sondern des Plays: Die Punkte stehen
    /// in absoluten Yards auf dem Feld, die LOS sagt nur, worauf sie
    /// sich beziehen. Ändern lässt sie sich trotzdem im selben
    /// Bildschirm und mit demselben Finger -- und wer sie verschiebt
    /// und dann „Rückgängig" drückt, meint sie.
    struct Stand: Equatable {
        var zeichnung: Zeichnung
        /// Wo der Ball liegt, in Yards vom linken Feldrand.
        var los: Double
        /// Die Angriffsrichtung: 1 nach rechts, -1 nach links.
        var richtung: Int
        /// Name, Nummer, Seite, Kategorie, Situationen, Hinweise
        /// (R110.7).
        ///
        /// **Auch das ist Arbeit.** Wer einen Play umbenennt, eine
        /// Kategorie setzt oder eine Situation anhakt, hat etwas
        /// geändert -- und drückte er danach „Rückgängig", nahm es bis
        /// zum 10.09.2026 die letzte LINIE zurück und liess die
        /// Umbenennung stehen. Genau der Fall, den der Kopf dieser
        /// Datei als den schlimmsten beschreibt.
        var angaben: Playangabenstand

        init(zeichnung: Zeichnung, los: Double, richtung: Int,
             angaben: Playangabenstand) {
            self.zeichnung = zeichnung
            self.los = los
            self.richtung = richtung
            self.angaben = angaben
        }
    }

    /// Wie viele Schritte zurückgehen. Dieselbe Zahl wie im Browser.
    ///
    /// Nicht unbegrenzt: Jeder Schritt ist eine ganze Zeichnung, und ein
    /// Editor, den jemand eine Stunde offen hat, legte sonst ein paar
    /// tausend davon in den Speicher eines Telefons.
    static let grenze = 60

    private(set) var zurueck: [Stand] = []
    private(set) var vorwaerts: [Stand] = []

    var kannZurueck: Bool { !zurueck.isEmpty }
    var kannVorwaerts: Bool { !vorwaerts.isEmpty }

    /// Legt den Stand VOR einer Änderung ab.
    ///
    /// Das löscht den Weg nach vorn, und das muss so sein: Wer nach zwei
    /// Schritten zurück etwas Neues zeichnet, hat sich für diesen Ast
    /// entschieden. Ein „Wiederholen", das danach den alten Ast
    /// zurückholte, überschriebe die frische Arbeit.
    mutating func merken(_ stand: Stand) {
        zurueck.append(stand)
        if zurueck.count > Verlauf.grenze { zurueck.removeFirst() }
        vorwaerts.removeAll()
    }

    /// Einen Schritt zurück. `jetzt` wandert dabei nach vorn.
    ///
    /// Gibt `nil` zurück, wenn es nichts zurückzunehmen gibt -- dann
    /// bleibt auch der Weg nach vorn unangetastet.
    mutating func zurueckgehen(von jetzt: Stand) -> Stand? {
        guard let alt = zurueck.popLast() else { return nil }
        vorwaerts.append(jetzt)
        return alt
    }

    /// Einen Schritt nach vorn. Der Gegenweg zu `zurueckgehen`.
    mutating func vorgehen(von jetzt: Stand) -> Stand? {
        guard let neu = vorwaerts.popLast() else { return nil }
        zurueck.append(jetzt)
        return neu
    }

    mutating func leeren() {
        zurueck.removeAll()
        vorwaerts.removeAll()
    }
}
