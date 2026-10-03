// ERZEUGT VON scripts/gestaltung_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quellen sind backend/static/designer/app.css (die Oberfläche) und
// scripts/marke.mjs (das Zeichen). Wer hier eine Farbe ändert, ändert sie
// nur in der App -- und dann sehen Website und App aus wie zwei Produkte,
// die derselbe Verein aus zwei Quellen bezogen hat.
//
// Neu erzeugen:  ./scripts/gestaltung_swift.py
// Geprüft von:   backend/designer/test_gestaltung_swift.py

import Foundation

// Proben. Die erwarteten Werte hat Python ausgerechnet.
//
// Dass beide Seiten dieselben Zahlen HABEN, prüft
// test_gestaltung_swift.py, indem es die Dateien neu erzeugt und
// vergleicht. Diese Sammlung ist für die andere Hälfte: dass SwiftUI aus
// den Zahlen auch dieselbe Farbe MACHT und dass die Paarungen im Gerät
// noch lesbar sind. Das kann nur ein Swift-Test.

enum GestaltungProben {

    /// (Name, erwarteter Hexwert der Oberflächenfarbe)
    static let oberflaeche: [(String, String)] = [
        ("flaeche", "#0C1115"),
        ("flaeche-panel", "#141A1F"),
        ("flaeche-hoch", "#1C2328"),
        ("flaeche-tief", "#070B0F"),
        ("ink", "#E9EDF0"),
        ("ink-leise", "#B7BDC2"),
        ("ink-still", "#8A9297"),
        ("linie", "#293036"),
        ("linie-stark", "#414A51"),
        ("petrol", "#75BCD2"),
        ("akzent", "#75BCD2"),
        ("petrol-tief", "#92D1E5"),
        ("auf-petrol", "#090E12"),
        ("petrol-hell", "#142E37"),
        ("petrol-rand", "#274F5C"),
        ("gold", "#E0B26A"),
        ("gold-hell", "#372613"),
        ("ziegel", "#E18775"),
        ("ziegel-hell", "#3B1F19"),
        ("gut", "#69BF89"),
        ("warnung", "#E0B26A"),
        ("fehler", "#EF7F74"),
        ("fehler-hell", "#3D1B17"),
    ]

    /// (Name, erwarteter Hexwert der Zeichenfarbe)
    static let zeichen: [(String, String)] = [
        ("tief", "#0E2A33"),
        ("petrol", "#14606F"),
        ("klar", "#3E9DB8"),
        ("kreide", "#E8F1F2"),
        ("papier", "#FBFBF9"),
        ("tinte", "#0F141A"),
        ("gold", "#C8871F"),
    ]

    /// (Name der Paarung, Kontrastverhältnis nach WCAG 2)
    static let kontrast: [(String, Double)] = [
        ("body", 16.1476),
        ("knopf", 13.5302),
        ("knopfHaupt", 9.0799),
        ("chip", 8.3690),
        ("chipWarn", 7.3928),
        ("meldungFehler", 5.8373),
        ("beispiel", 10.3878),
        ("aufgabenmarke", 8.4458),
        ("kontoblockSprachfeldSelect", 14.9053),
        ("anderesprache", 9.2195),
        ("wissenNummerSpan", 9.4308),
    ]

    /// Ab hier gilt Fließtext als lesbar (WCAG 2.1, AA).
    static let lesbar: Double = 4.5
}
