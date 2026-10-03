// ERZEUGT VON scripts/farben_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/farben.py -- dieselbe Prüfung, die
// `forms.farbe_pruefen` im Browser und `_farbe_oder_400` an der
// Schnittstelle wirklich ausführen. Die Antworten unten hat der SERVER
// gegeben, nicht ein Mensch abgeschrieben.
//
// Neu erzeugen:  ./scripts/farben_swift.py
// Geprüft von:   backend/designer/test_farben_swift.py (Gleichstand)
//                RoutetreeTests/FarbeTests.swift (Swift prüft gleich)

import Foundation

enum FarbProben {

    /// Ein Fall: was eingegeben wurde und was dabei herauskam.
    ///
    /// Genau eins von beiden ist gesetzt. `wert` ist die Farbe, wie sie
    /// gespeichert wird -- klein geschrieben und ohne Leerzeichen.
    /// `fehler` ist der Satz, den ein Mensch zu sehen bekommt.
    struct Fall {
        let name: String
        let hinweis: String
        let eingabe: String
        let wert: String?
        let fehler: String?
    }

    static let faelle: [Fall] = [
        Fall(
            name: "gross_geschrieben",
            hinweis: "Kommt klein zurueck. Wer das vergisst, speichert zwei Schreibweisen derselben Farbe.",
            eingabe: "#1A5364",
            wert: "#1a5364",
            fehler: nil),
        Fall(
            name: "klein_geschrieben",
            hinweis: "Bleibt, wie er ist.",
            eingabe: "#1a5364",
            wert: "#1a5364",
            fehler: nil),
        Fall(
            name: "gemischt",
            hinweis: "Gemischte Schreibweise, auch die wird klein.",
            eingabe: "#aB12Cd",
            wert: "#ab12cd",
            fehler: nil),
        Fall(
            name: "leerzeichen_ringsum",
            hinweis: "Wird abgeschnitten, nicht abgewiesen. Wer aus einer Tabelle einfuegt, bringt Leerzeichen mit.",
            eingabe: "  #C8871F  ",
            wert: "#c8871f",
            fehler: nil),
        Fall(
            name: "leer",
            hinweis: "Leer heisst „keine Meinung“ und ergibt den Standard.",
            eingabe: "",
            wert: "#1A5364",
            fehler: nil),
        Fall(
            name: "nur_leerzeichen",
            hinweis: "Auch das ist leer.",
            eingabe: "   ",
            wert: "#1A5364",
            fehler: nil),
        Fall(
            name: "kurzform",
            hinweis: "Im CSS gueltig, hier nicht. Genau der Fall, den eine nachgebaute Pruefung durchlaesst.",
            eingabe: "#abc",
            wert: nil,
            fehler: "Die Farbe muss als Hexwert angegeben werden, zum Beispiel #1A5364."),
        Fall(
            name: "ohne_raute",
            hinweis: "Ohne Raute keine Farbe.",
            eingabe: "1a5364",
            wert: nil,
            fehler: "Die Farbe muss als Hexwert angegeben werden, zum Beispiel #1A5364."),
        Fall(
            name: "zu_lang",
            hinweis: "Acht Stellen mit Alpha. Wird abgewiesen, nicht beschnitten.",
            eingabe: "#1a5364ff",
            wert: nil,
            fehler: "Die Farbe muss als Hexwert angegeben werden, zum Beispiel #1A5364."),
        Fall(
            name: "keine_hexziffern",
            hinweis: "Sieben Zeichen, aber keine Zahl. Der zweite Fehlersatz.",
            eingabe: "#zzzzzz",
            wert: nil,
            fehler: "Das ist kein gültiger Farbwert."),
        Fall(
            name: "leerzeichen_mittendrin",
            hinweis: "Sah aus wie eine Zahl und war keine Farbe. Kam bis B7 durch und faerbte danach nichts.",
            eingabe: "# 12345",
            wert: nil,
            fehler: "Das ist kein gültiger Farbwert."),
        Fall(
            name: "unterstrich",
            hinweis: "Python liest den Unterstrich als Tausendertrennung, ein Browser liest gar nichts.",
            eingabe: "#1_2345",
            wert: nil,
            fehler: "Das ist kein gültiger Farbwert."),
        Fall(
            name: "vorzeichen",
            hinweis: "Ein Vorzeichen gehoert zu einer Zahl, nicht zu einer Farbe.",
            eingabe: "#+12345",
            wert: nil,
            fehler: "Das ist kein gültiger Farbwert."),
        Fall(
            name: "fremde_ziffern",
            hinweis: "Ziffern aus einer anderen Schrift. Sieben Zeichen, lesbar als Zahl, keine Farbe.",
            eingabe: "#１２３４５６",
            wert: nil,
            fehler: "Das ist kein gültiger Farbwert."),
        Fall(
            name: "wort",
            hinweis: "Ein Farbname ist kein Hexwert.",
            eingabe: "petrol",
            wert: nil,
            fehler: "Die Farbe muss als Hexwert angegeben werden, zum Beispiel #1A5364."),
        Fall(
            name: "schwarz",
            hinweis: "Nullen sind gueltige Hexziffern. Eine Pruefung, die auf „wahr“ testet statt auf „vorhanden“, faellt hier um.",
            eingabe: "#000000",
            wert: "#000000",
            fehler: nil),
        Fall(
            name: "weiss",
            hinweis: "Die Gegenprobe, ebenfalls klein zurueck.",
            eingabe: "#FFFFFF",
            wert: "#ffffff",
            fehler: nil),
    ]
}
