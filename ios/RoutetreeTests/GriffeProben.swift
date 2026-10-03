// ERZEUGT VON scripts/griffe_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist scripts/griffe_swift.py, und dieselben Fälle laufen
// unter Node durch backend/static/designer/griffe.js. Wer hier etwas
// ändert, ändert es nur in der App -- und dann erwischt der Finger auf
// dem Handy einen anderen Stützpunkt als die Maus im Browser.
//
// Neu erzeugen:  ./scripts/griffe_swift.py
// Geprüft von:   ios/RoutetreeTests/GriffeTests.swift
//                backend/designer/test_griffe.py

import CoreGraphics
import Foundation

/// Proben für `Griffe.naechster`.
///
/// `erwartet` ist die Stelle des Stützpunktes, der unter dem Zeiger
/// liegt -- `-1` heißt: keiner.
enum GriffeProben {

    static let faelle: [(punkte: [CGPoint], ziel: CGPoint, weite: Double,
                         verankert: Bool, erwartet: Int)] = [
        // knick
        (punkte: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 40.0, y: 0.0), CGPoint(x: 40.0, y: -40.0)], ziel: CGPoint(x: 44.0, y: 3.0), weite: 12.0, verankert: false, erwartet: 1),
        // anfang_frei
        (punkte: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 30.0, y: 0.0), CGPoint(x: 30.0, y: 30.0)], ziel: CGPoint(x: 2.0, y: 2.0), weite: 12.0, verankert: false, erwartet: 0),
        // anfang_verankert
        (punkte: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 30.0, y: 0.0), CGPoint(x: 30.0, y: 30.0)], ziel: CGPoint(x: 2.0, y: 2.0), weite: 12.0, verankert: true, erwartet: -1),
        // enge_ecke
        (punkte: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 50.0, y: 0.0), CGPoint(x: 54.0, y: 3.0)], ziel: CGPoint(x: 53.0, y: 2.0), weite: 12.0, verankert: false, erwartet: 2),
        // gleich_weit
        (punkte: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 10.0, y: 0.0), CGPoint(x: -10.0, y: 0.0)], ziel: CGPoint(x: 0.0, y: 0.0), weite: 12.0, verankert: false, erwartet: 0),
        // daneben
        (punkte: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 40.0, y: 0.0)], ziel: CGPoint(x: 20.0, y: 20.0), weite: 12.0, verankert: false, erwartet: -1),
        // genau_am_rand
        (punkte: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 12.0, y: 0.0)], ziel: CGPoint(x: 0.0, y: 0.0), weite: 12.0, verankert: true, erwartet: 1),
        // leer
        (punkte: [], ziel: CGPoint(x: 0.0, y: 0.0), weite: 12.0, verankert: false, erwartet: -1),
        // nur_anfang_verankert
        (punkte: [CGPoint(x: 5.0, y: 5.0)], ziel: CGPoint(x: 5.0, y: 5.0), weite: 12.0, verankert: true, erwartet: -1),
    ]
}
