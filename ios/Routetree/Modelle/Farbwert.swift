// Ist das eine Farbe? Dieselbe Antwort wie der Server (B7).
//
// Wer auf dem Telefon eine Kategorie anlegt, tippt einen Hexwert oder
// tippt auf einen Vorschlag. Bevor „Anlegen" hell wird, muss die App
// entscheiden, ob der Wert taugt -- und zwar genauso, wie der Server es
// gleich entscheiden wird.
//
// WARUM DAS GEMESSEN WIRD UND NICHT BEHAUPTET. Die Regel steht in
// `backend/designer/farben.py`. Swift kann diese Datei nicht lesen, also
// steht sie hier ein zweites Mal. Läuft sie auseinander, passiert eins
// von zwei Dingen, und beide sehen aus, als sei die App kaputt: Sie
// sperrt einen Wert, den der Browser nebenan anstandslos nimmt, oder sie
// schickt einen los und bekommt 400 zurück, nachdem der Coach ihn
// dreimal getippt hat.
//
// Deshalb prüft der SERVER eine Reihe von Fällen, und seine Antworten
// liegen als `FarbProben` in den Tests. `FarbeTests` misst diese Datei
// dagegen. Dasselbe Muster wie bei Feldmaßen, Spiegelung, Laufplan und
// Umordnung.

import Foundation

/// Die Farbregel, an einer Stelle.
enum Farbwert {

    /// Was bei einer Prüfung herauskommt.
    ///
    /// Kein `Result` und kein `throws`: Der Fehler ist hier keine
    /// Ausnahme, sondern der Normalfall beim Tippen. Wer „#1a5" schon
    /// eingegeben hat, ist noch nicht fertig, und ein Formular, das
    /// dabei wirft, müsste jedes Zeichen in ein `do/catch` packen.
    struct Ergebnis {
        /// Die Farbe, wie sie gespeichert wird. `nil` heißt: geht nicht.
        let wert: String?
        /// Der Satz für den Menschen. `nil` heißt: alles in Ordnung.
        let fehler: String?

        var taugt: Bool { wert != nil }
    }

    /// Womit eine Kategorie anfängt, wenn niemand etwas sagt.
    ///
    /// **Nicht klein geschrieben, und das ist Absicht.** Ein geprüfter
    /// Wert kommt klein zurück, dieser hier nicht: Er wird gar nicht
    /// geprüft, sondern eingesetzt, wenn nichts dasteht. Genauso hält es
    /// der Server, und die Probe „leer" hält es fest. Wer hier
    /// aufräumt, hat zwei Fassungen.
    static var standard: String { Farbvorschlaege.standard }

    /// Die sechzehn Ziffern, aus denen ein Hexwert besteht.
    ///
    /// Ausgeschrieben und nicht über `Int(text, radix: 16)`: Der
    /// Zahlleser nimmt Vorzeichen und andere Ziffernschriften an, ein
    /// Browser zeichnet damit nichts. Der Server hatte genau diese Lücke
    /// bis B7.
    private static let hexziffern = Set("0123456789abcdefABCDEF")

    /// Prüft einen Hexwert.
    ///
    /// Leer heißt „keine Meinung" und ergibt den Standard, nicht einen
    /// Fehler: Ein Formular, das ein leeres Feld abweist, zwingt jeden
    /// dazu, eine Farbe zu erfinden.
    static func pruefen(_ eingabe: String) -> Ergebnis {
        let farbe = eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
        if farbe.isEmpty {
            return Ergebnis(wert: standard, fehler: nil)
        }
        // Nach ZEICHEN gezählt und nicht nach Bytes: „#１２３４５６" ist
        // sieben Zeichen lang und wäre in UTF-8 neunzehn. Eine Prüfung
        // auf die Byteanzahl wiese es mit dem falschen Satz ab.
        guard farbe.hasPrefix("#"), farbe.count == 7 else {
            return Ergebnis(wert: nil, fehler: FEHLER_FORM)
        }
        guard farbe.dropFirst().allSatisfy({ hexziffern.contains($0) }) else {
            return Ergebnis(wert: nil, fehler: FEHLER_WERT)
        }
        return Ergebnis(wert: farbe.lowercased(), fehler: nil)
    }

    /// Ob zwei gespeicherte Farben dieselbe sind.
    ///
    /// **Wofür das gebraucht wird.** Die Vorschläge stehen groß
    /// geschrieben (`#1A5364`), gespeichert wird klein (`#1a5364`).
    /// Ein Vergleich Zeichen für Zeichen zeigte den gewählten Tupfer
    /// nach dem Sichern als nicht gewählt -- und der Coach tippt ihn
    /// nochmal.
    static func gleich(_ eine: String?, _ andere: String?) -> Bool {
        guard let eine, let andere else { return eine == nil && andere == nil }
        return eine.lowercased() == andere.lowercased()
    }

    // Die beiden Sätze stehen wörtlich so im Server (`farben.FEHLER_FORM`
    // und `FEHLER_WERT`) und werden von `FarbeTests` gegen die Proben
    // gemessen. Sie hier zu verkürzen hieße, dem Coach auf dem Telefon
    // etwas anderes zu sagen als am Schreibtisch.
    static let FEHLER_FORM = String(localized:
        "Die Farbe muss als Hexwert angegeben werden, zum Beispiel #1A5364.")
    static let FEHLER_WERT = String(localized:
        "Das ist kein gültiger Farbwert.")
}
