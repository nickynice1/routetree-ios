import Foundation

/// Der Satz zu einem Fehler -- an EINER Stelle.
///
/// **Warum das eine eigene Datei ist (R22).** Bis heute stand in
/// einundvierzig `catch`-Zweigen dieselbe Zeile:
///
///     fehler = (error as? LocalizedError)?.errorDescription
///         ?? "Unbekannter Fehler."
///
/// Solange die App nur Deutsch konnte, war das nur Wiederholung. Mit
/// fünf Sprachen ist es etwas anderes: einundvierzig Gelegenheiten, eine
/// davon zu übersehen -- und die eine übersehene fällt niemandem auf,
/// weil sie nur im Fehlerfall erscheint, und dort auch nur auf einem
/// Telefon, das nicht auf Deutsch steht. Dieselbe Lehre wie aus R6 (vier
/// Schreibwege, ein Schloss) und R11 (eine Griffebene, durch die alle
/// Linienarten müssen): Wo alle durchmüssen, kann keine Stelle mehr die
/// Hälfte vergessen.
///
/// **Der Satz des Servers hat Vorrang.** Er ist genauer als alles, was
/// die App raten könnte -- und er kommt in der Sprache des Servers.
/// Übersetzt wird hier nur der Notnagel für den Fall, dass gar keiner
/// da ist.
enum Fehlertext {

    static func von(_ fehler: Error) -> String {
        (fehler as? LocalizedError)?.errorDescription
            ?? String(localized: "Unbekannter Fehler.")
    }
}
