import Foundation

// Was auf dem Blatt „Playangaben" steht -- als eigener Typ und nicht
// mehr in der Ansicht (R110.7).
//
// WARUM ER UMGEZOGEN IST. Bis zum 10.09.2026 hiess er
// `Playangaben.Stand` und wohnte in der Ansicht. Das ging, solange nur
// die Ansicht ihn brauchte. Seit R110.7 gehoert er in den Verlauf: Was
// in den Playangaben geaendert wird, muss sich zuruecknehmen lassen,
// und der Verlauf liegt im `Zeichenblock`. Ein Modell, das einen Typ
// aus einer SwiftUI-Ansicht holt, haette die Schichten verdreht.
//
// `Playangaben.Stand` gibt es weiterhin -- als `typealias`. Achtzehn
// Stellen heissen so, und eine Umbenennung ohne Compiler ist eine
// Wette.

/// Was auf dem Blatt steht. Ein eigener Wert und kein Griff in den
/// Editor: So lässt sich „Abbrechen" halten, ohne etwas
/// zurückzurechnen -- der alte Stand liegt einfach noch da.
///
/// **Auch `Codable` (R110.4).** Der Entwurf, der im Funkloch auf dem
/// Geraet liegen bleibt, traegt ihn mit: Wer im Zug einen Play
/// umbenennt und die App schliesst, hat die Umbenennung sonst
/// verloren -- und zwar lautlos, was der schlimmere Teil ist.
struct Playangabenstand: Codable, Equatable {
    var name: String = ""
    /// Als Text und nicht als Zahl, weil das Feld leer sein darf und
    /// „leer" keine Zahl ist. Aus dem Text wird erst beim Übernehmen
    /// eine, und dabei wird geprüft.
    var nummer: String = ""
    var seite: String = Seite.vorgabe
    /// Die Kennung, nicht der Name. `nil` heißt „ohne Kategorie".
    var kategorie: Int?
    /// Als Menge, weil die Reihenfolge auf dem Bogen steht und nicht
    /// in der Auswahl. Geordnet wird beim Hinausschicken.
    var situationen: Set<String> = []
    var hinweise: String = ""

    /// Der Stand, wie er aus einem geladenen Play kommt.
    init(von play: Modell.PlayVoll) {
        name = play.name
        // `map` und kein `?? ""` auf der Zahl: `String(nil)` gäbe
        // es nicht, und ein `0` als Ersatz wäre eine Nummer, die
        // niemand vergeben hat.
        //
        // Der Abschluss ausgeschrieben statt `String.init`: Davon
        // gibt es ein Dutzend Fassungen, und welche gemeint ist,
        // entscheidet der Compiler -- der hier nicht steht.
        nummer = play.nummer.map { zahl in String(zahl) } ?? ""
        seite = play.seite ?? Seite.vorgabe
        kategorie = play.kategorieId
        situationen = Set(play.situationen)
        hinweise = play.hinweise ?? ""
    }

    init() {}

    /// Ist die Nummer brauchbar? Leer zählt als brauchbar.
    var nummerTaugt: Bool {
        let roh = nummer.trimmingCharacters(in: .whitespaces)
        if roh.isEmpty { return true }
        guard let zahl = Int(roh) else { return false }
        return (1...Playgrenzen.nummerMax).contains(zahl)
    }

    var nameTaugt: Bool {
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !sauber.isEmpty && sauber.count <= Playgrenzen.nameLaenge
    }

    /// **Der Server SCHNEIDET AB, er lehnt nicht ab.**
    /// `_play_felder` nimmt `str(...)[:HINWEISE_MAX]` -- was darüber
    /// hinausgeht, ist weg, und die Antwort ist trotzdem ein 200.
    /// Ein Trainer, der drei Absätze schreibt, bekäme zwei zurück
    /// und keine Erklärung.
    ///
    /// Deshalb hält die App an derselben Zahl an, und deshalb ist
    /// sie erzeugt und nicht getippt (`Playgrenzen`).
    var hinweiseTaugt: Bool {
        hinweise.count <= Playgrenzen.hinweiseLaenge
    }

    /// Wie viele Zeichen noch gehen. Negativ heißt: zu viele.
    var hinweiseUebrig: Int {
        Playgrenzen.hinweiseLaenge - hinweise.count
    }

    var taugt: Bool { nameTaugt && nummerTaugt && hinweiseTaugt }

    /// Was sich gegenüber `alt` geändert hat -- und NUR das.
    ///
    /// **Warum nicht einfach alles mitschicken.** Ein weggelassener
    /// Schlüssel heißt beim Server „keine Meinung". Wer jedes Mal
    /// alles schickt, lässt den Server jedes Mal alles prüfen --
    /// und dann scheitert das Sichern einer Route daran, dass
    /// jemand anderes inzwischen dieselbe Playnummer vergeben hat.
    /// Der Trainer sähe eine Fehlermeldung über Nummern, während er
    /// eine Linie gezogen hat.
    // DER EIGENE NAME, nicht `Stand`: Den gibt es nur als
    // `typealias` INNERHALB von `Playangaben` (der Ansicht).
    // Hier draussen kennt ihn niemand.
    func unterschied(zu alt: Playangabenstand)
        -> Playspeicher.Eigenschaften {
        var heraus = Playspeicher.Eigenschaften()
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // EIN LEERER NAME GEHT NICHT MIT (30.09.2026).
        //
        // **Gesehen bei einem echten Nutzer.** Er benannte „Spread
        // Mesh" in „A" um; waehrend das Feld leer war, feuerte die
        // Autosicherung, und der Server lehnte sie mit 400 ab („Der
        // Play braucht einen Namen"). Die Ansicht sagt denselben Satz
        // schon unter dem Feld -- die Meldung war also nicht neu, nur
        // die abgewiesene Sicherung war es.
        //
        // WEGGELASSEN UND NICHT ERSETZT: Ein leerer Name ist kein
        // Wunsch, sondern ein Zwischenstand beim Tippen. Der Server
        // behaelt den alten, bis wieder einer dasteht -- und die
        // Zeichnung wird derweil weiter gesichert, was der Punkt der
        // Autosicherung ist.
        if sauber != alt.name, !sauber.isEmpty { heraus.name = sauber }
        if nummer != alt.nummer {
            let roh = nummer.trimmingCharacters(in: .whitespaces)
            // Das doppelte Optional ist der Unterschied zwischen
            // „nicht erwähnt" und „ausdrücklich keine": Das äußere
            // `nil` lässt den Schlüssel weg, das innere schickt
            // `null` und löscht die Nummer.
            //
            // Der Typ steht ausdrücklich da. Ohne ihn müsste Swift
            // das `nil` im Fragezeichen-Ausdruck aus der anderen
            // Hälfte erraten, und bei einem doppelten Optional ist
            // das eine Stelle, an der man nicht raten lassen will.
            let zahl: Int? = roh.isEmpty ? nil : Int(roh)
            heraus.nummer = .some(zahl)
        }
        if seite != alt.seite { heraus.seite = seite }
        if kategorie != alt.kategorie { heraus.kategorie = .some(kategorie) }
        if situationen != alt.situationen {
            heraus.situationen = Situation.geordnet(Array(situationen))
        }
        if hinweise != alt.hinweise { heraus.hinweise = hinweise }
        return heraus
    }
}
