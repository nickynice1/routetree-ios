// ERZEUGT VON scripts/feld_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/geometry.py. Wer hier etwas ändert,
// ändert es nur in der App, und dann zeichnet das Handy andere Yards als
// der Ausdruck. Genau das ist das Versprechen, mit dem Routetree
// verkauft wird.
//
// Neu erzeugen:  ./scripts/feld_swift.py
// Geprüft von:   backend/designer/test_feld_swift.py

import Foundation

// Rechenproben. Die erwarteten Werte hat Python ausgerechnet.
//
// Dass beide Seiten dieselben Zahlen HABEN, prüft
// test_feld_swift.py. Dass sie damit auch dasselbe RECHNEN, prüft
// FeldTests.swift anhand dieser Sammlung.

enum FeldProben {
    /// (x, erwartete Yard-Linie)
    static let yardLinie: [(Double, Int)] = [
        (0.0, -10),
        (5.0, -5),
        (9.9, 0),
        (10.0, 0),
        (10.1, 0),
        (14.5, 4),
        (14.9, 5),
        (15.0, 5),
        (15.1, 5),
        (15.5, 6),
        (30.0, 20),
        (34.5, 24),
        (34.9, 25),
        (35.0, 25),
        (35.1, 25),
        (54.9, 5),
        (55.0, 5),
        (55.1, 5),
        (55.5, 4),
        (59.9, 0),
        (60.0, 0),
        (70.0, -10),
    ]

    /// (x, liegt in der No-Run-Zone)
    static let keinLaufZone: [(Double, Bool)] = [
        (0.0, true),
        (5.0, true),
        (9.9, true),
        (10.0, true),
        (10.1, true),
        (14.5, true),
        (14.9, true),
        (15.0, false),
        (15.1, false),
        (15.5, false),
        (30.0, false),
        (34.5, false),
        (34.9, false),
        (35.0, false),
        (35.1, false),
        (54.9, false),
        (55.0, false),
        (55.1, true),
        (55.5, true),
        (59.9, true),
        (60.0, true),
        (70.0, true),
    ]

    /// (Line of Scrimmage, Richtung, erwartete Rushlinie)
    static let rushLinie: [(Double, Int, Double)] = [
        (10.0, 1, 17.0),
        (10.0, -1, 3.0),
        (35.0, 1, 42.0),
        (35.0, -1, 28.0),
        (55.0, 1, 62.0),
        (55.0, -1, 48.0),
    ]

    /// (x, y, begrenztes x, begrenztes y)
    static let begrenzen: [(Double, Double, Double, Double)] = [
        (-5.0, -5.0, 0.0, 0.0),
        (0.0, 0.0, 0.0, 0.0),
        (35.0, 12.5, 35.0, 12.5),
        (75.0, 30.0, 70.0, 25.0),
        (70.0, 25.0, 70.0, 25.0),
    ]
}
