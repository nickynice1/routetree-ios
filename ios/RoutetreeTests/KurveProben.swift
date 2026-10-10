// ERZEUGT VON scripts/kurve_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/render.py (_catmull_rom_to_bezier).
// Wer hier etwas ändert, ändert es nur in der App, und dann biegt das
// Handy eine Wheel Route anders als der Ausdruck.
//
// Neu erzeugen:  ./scripts/kurve_swift.py
// Geprüft von:   ios/RoutetreeTests/KurveTests.swift
//                backend/designer/test_kurve_swift.py

import CoreGraphics
import Foundation

/// Rechenproben für `Kurve.stuetzen`, gerechnet von
/// `render._catmull_rom_to_bezier`.
enum KurveProben {

    /// Der Wert aus `render.CATMULL_ROM_ALPHA`.
    static let alpha = 0.5

    /// (p0, p1, p2, p3, erwartetes b1, erwartetes b2)
    static let stuetzen: [(CGPoint, CGPoint, CGPoint, CGPoint,
                           CGPoint, CGPoint)] = [
        // wheel
            (CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.0, y: 0.0), CGPoint(x: 6.0, y: 0.0), CGPoint(x: 10.0, y: 4.0), CGPoint(x: 0.0, y: 0.0), CGPoint(x: 4.318024930322846, y: -0.696696885433708)),
            (CGPoint(x: 0.0, y: 0.0), CGPoint(x: 6.0, y: 0.0), CGPoint(x: 10.0, y: 4.0), CGPoint(x: 11.0, y: 14.0), CGPoint(x: 7.633170113090219, y: 0.6764812105043703), CGPoint(x: 9.13100550017089, y: 2.1662106448152207)),
            (CGPoint(x: 6.0, y: 0.0), CGPoint(x: 10.0, y: 4.0), CGPoint(x: 11.0, y: 14.0), CGPoint(x: 11.0, y: 14.0), CGPoint(x: 11.158270182853995, y: 6.4442312720774115), CGPoint(x: 11.0, y: 14.0)),
        // comeback
            (CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.0, y: 12.0), CGPoint(x: -2.0, y: 9.0), CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.7856009085922099, y: 11.762139183898158)),
            (CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.0, y: 12.0), CGPoint(x: -2.0, y: 9.0), CGPoint(x: -2.0, y: 9.0), CGPoint(x: -0.4306229701683073, y: 12.130382144414755), CGPoint(x: -2.0, y: 9.0)),
        // gerade
            (CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.0, y: 0.0), CGPoint(x: 5.0, y: 0.0), CGPoint(x: 10.0, y: 0.0), CGPoint(x: 0.0, y: 0.0), CGPoint(x: 3.333333333333334, y: 0.0)),
            (CGPoint(x: 0.0, y: 0.0), CGPoint(x: 5.0, y: 0.0), CGPoint(x: 10.0, y: 0.0), CGPoint(x: 10.0, y: 0.0), CGPoint(x: 6.666666666666667, y: 0.0), CGPoint(x: 10.0, y: 0.0)),
        // gleiche_punkte
            (CGPoint(x: 3.0, y: 3.0), CGPoint(x: 3.0, y: 3.0), CGPoint(x: 3.0, y: 3.0), CGPoint(x: 8.0, y: 2.0), CGPoint(x: 3.0, y: 3.0), CGPoint(x: 3.0, y: 3.0)),
            (CGPoint(x: 3.0, y: 3.0), CGPoint(x: 3.0, y: 3.0), CGPoint(x: 8.0, y: 2.0), CGPoint(x: 8.0, y: 2.0), CGPoint(x: 3.0, y: 3.0), CGPoint(x: 8.0, y: 2.0)),
            (CGPoint(x: 3.0, y: 3.0), CGPoint(x: 8.0, y: 2.0), CGPoint(x: 8.0, y: 2.0), CGPoint(x: 8.0, y: 2.0), CGPoint(x: 8.0, y: 2.0), CGPoint(x: 8.0, y: 2.0)),
        // ungleiche_abstaende
            (CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.5, y: 0.0), CGPoint(x: 18.0, y: 3.0), CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.21661771078868314, y: -0.02411402904249381)),
            (CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.5, y: 0.0), CGPoint(x: 18.0, y: 3.0), CGPoint(x: 19.0, y: 9.0), CGPoint(x: 2.1886960048705166, y: 0.14369728121938224), CGPoint(x: 15.48704709266798, y: 0.4753861209236219)),
            (CGPoint(x: 0.5, y: 0.0), CGPoint(x: 18.0, y: 3.0), CGPoint(x: 19.0, y: 9.0), CGPoint(x: 19.0, y: 9.0), CGPoint(x: 19.470858881376003, y: 4.477684175954987), CGPoint(x: 19.0, y: 9.0)),
        // rueckwaerts
            (CGPoint(x: 10.0, y: 5.0), CGPoint(x: 10.0, y: 5.0), CGPoint(x: 4.0, y: 5.0), CGPoint(x: 1.0, y: 1.0), CGPoint(x: 10.0, y: 5.0), CGPoint(x: 5.527121840165316, y: 5.763560920082659)),
            (CGPoint(x: 10.0, y: 5.0), CGPoint(x: 4.0, y: 5.0), CGPoint(x: 1.0, y: 1.0), CGPoint(x: -3.0, y: 1.0), CGPoint(x: 2.6059348668044295, y: 4.302967433402214), CGPoint(x: 2.259029213332212, y: 1.629514606666106)),
            (CGPoint(x: 4.0, y: 5.0), CGPoint(x: 1.0, y: 1.0), CGPoint(x: -3.0, y: 1.0), CGPoint(x: -3.0, y: 1.0), CGPoint(x: -0.12610996266756405, y: 0.43694501866621804), CGPoint(x: -3.0, y: 1.0)),
    ]

    /// Geschlossene Ringe -- Zonen (R8).
    ///
    /// Je Ring die Ecken und die Segmente, die daraus entstehen: so
    /// viele wie Ecken, jedes mit zwei Stützpunkten und seinem Ziel.
    /// Wer die Ränder spiegelt statt ringsum zu greifen, bekommt beim
    /// ersten und beim letzten Segment andere Stützpunkte.
    static let ringe: [(name: String, ecken: [CGPoint],
                        segmente: [(CGPoint, CGPoint, CGPoint)])] = [
        (name: "kreis_vier_ecken",
         ecken: [CGPoint(x: -5.0, y: 0.0), CGPoint(x: 0.0, y: -5.0), CGPoint(x: 5.0, y: 0.0), CGPoint(x: 0.0, y: 5.0)],
         segmente: [
                (CGPoint(x: -5.0, y: -1.6666666666666663), CGPoint(x: -1.6666666666666663, y: -5.0), CGPoint(x: 0.0, y: -5.0)),
                (CGPoint(x: 1.6666666666666663, y: -5.0), CGPoint(x: 5.0, y: -1.6666666666666663), CGPoint(x: 5.0, y: 0.0)),
                (CGPoint(x: 5.0, y: 1.6666666666666663), CGPoint(x: 1.6666666666666663, y: 5.0), CGPoint(x: 0.0, y: 5.0)),
                (CGPoint(x: -1.6666666666666663, y: 5.0), CGPoint(x: -5.0, y: 1.6666666666666663), CGPoint(x: -5.0, y: 0.0)),
         ]),
        (name: "dreieck",
         ecken: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 6.0, y: 0.0), CGPoint(x: 3.0, y: 5.0)],
         segmente: [
                (CGPoint(x: 0.48203547203058755, y: -0.8513664130222326), CGPoint(x: 5.517964527969413, y: -0.8513664130222326), CGPoint(x: 6.0, y: 0.0)),
                (CGPoint(x: 6.475196356778533, y: 0.8392872334633942), CGPoint(x: 4.000000000000001, y: 5.0), CGPoint(x: 3.0, y: 5.0)),
                (CGPoint(x: 2.0, y: 5.0), CGPoint(x: -0.4751963567785335, y: 0.8392872334633942), CGPoint(x: 0.0, y: 0.0)),
         ]),
        (name: "schmale_ellipse",
         ecken: [CGPoint(x: -9.0, y: 0.0), CGPoint(x: 0.0, y: -2.0), CGPoint(x: 9.0, y: 0.0), CGPoint(x: 0.0, y: 2.0)],
         segmente: [
                (CGPoint(x: -8.999999999999998, y: -0.6666666666666666), CGPoint(x: -3.0, y: -1.9999999999999998), CGPoint(x: 0.0, y: -2.0)),
                (CGPoint(x: 3.0, y: -1.9999999999999998), CGPoint(x: 8.999999999999998, y: -0.6666666666666666), CGPoint(x: 9.0, y: 0.0)),
                (CGPoint(x: 8.999999999999998, y: 0.6666666666666666), CGPoint(x: 3.0, y: 1.9999999999999998), CGPoint(x: 0.0, y: 2.0)),
                (CGPoint(x: -3.0, y: 1.9999999999999998), CGPoint(x: -8.999999999999998, y: 0.6666666666666666), CGPoint(x: -9.0, y: 0.0)),
         ]),
        (name: "fuenf_ecken",
         ecken: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 4.0, y: -1.0), CGPoint(x: 7.0, y: 3.0), CGPoint(x: 3.0, y: 6.0), CGPoint(x: -1.0, y: 4.0)],
         segmente: [
                (CGPoint(x: 0.8333333333333333, y: -0.8333333333333333), CGPoint(x: 2.8690478982435823, y: -1.4015339413213328), CGPoint(x: 4.0, y: -1.0)),
                (CGPoint(x: 5.24542329248065, y: -0.5578241355522473), CGPoint(x: 7.166666666666667, y: 1.8333333333333333), CGPoint(x: 7.0, y: 3.0)),
                (CGPoint(x: 6.833333333333333, y: 4.166666666666667), CGPoint(x: 4.3726474013302346, y: 5.876228461034189), CGPoint(x: 3.0, y: 6.0)),
                (CGPoint(x: 1.7018302380719157, y: 6.117055894410324), CGPoint(x: -0.5239781736375033, y: 5.0349764784236815), CGPoint(x: -1.0, y: 4.0)),
                (CGPoint(x: -1.4570688218933052, y: 3.006231535021764), CGPoint(x: -0.8333333333333333, y: 0.8333333333333333), CGPoint(x: 0.0, y: 0.0)),
         ]),
    ]

    /// Der Abstand aus `render.LABEL_OFFSET`, in Bildeinheiten (R25).
    static let labelAbstand = 9.0

    /// Die halbe Zeilenhöhe aus `render.LABEL_MITTE`, in Bildeinheiten.
    static let labelGrundlinie = 2.5

    /// Wo die MITTE der Beschriftung einer Linie liegt, gerechnet von
    /// `render._label_stelle` -- bei `faktor` 1, also in Bildeinheiten.
    ///
    /// **Der Faktor ist der Grund, warum es diese Proben gibt.** Die
    /// erste Fassung hatte dieselbe Zahl wie `render.py` und rechnete
    /// sie in der falschen Einheit auf schon gestreckte Punkte. Eine
    /// Prüfung über die Zahl war grün.
    static let beschriftungen: [(name: String, punkte: [CGPoint],
                                 mitte: CGPoint)] = [
        (name: "go_nach_vorn",
         punkte: [CGPoint(x: 30.0, y: 0.0), CGPoint(x: 30.0, y: -100.0)],
         mitte: CGPoint(x: 30.0, y: -111.5)),
        (name: "out_nach_rechts",
         punkte: [CGPoint(x: 30.0, y: -40.0), CGPoint(x: 80.0, y: -40.0)],
         mitte: CGPoint(x: 89.0, y: -42.5)),
        (name: "schraeg",
         punkte: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 30.0, y: -40.0)],
         mitte: CGPoint(x: 35.4, y: -49.7)),
        (name: "knick_zaehlt_nur_die_letzte_strecke",
         punkte: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.0, y: -50.0), CGPoint(x: 40.0, y: -50.0)],
         mitte: CGPoint(x: 49.0, y: -52.5)),
        (name: "ein_punkt",
         punkte: [CGPoint(x: 12.0, y: -7.0)],
         mitte: CGPoint(x: 12.0, y: -9.5)),
        (name: "zwei_gleiche_punkte",
         punkte: [CGPoint(x: 12.0, y: -7.0), CGPoint(x: 12.0, y: -7.0)],
         mitte: CGPoint(x: 12.0, y: -9.5)),
    ]

    /// Der Schwerpunkt einer Zone -- dieselbe Rechnung wie am
    /// Zonennamen in `render.py`. Maßstabsfrei, also ohne Faktor.
    static let zonenmitten: [(name: String, ecken: [CGPoint],
                              mitte: CGPoint)] = [
        (name: "kreis_vier_ecken",
         ecken: [CGPoint(x: -5.0, y: 0.0), CGPoint(x: 0.0, y: -5.0), CGPoint(x: 5.0, y: 0.0), CGPoint(x: 0.0, y: 5.0)],
         mitte: CGPoint(x: 0.0, y: 0.0)),
        (name: "dreieck",
         ecken: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 6.0, y: 0.0), CGPoint(x: 3.0, y: 5.0)],
         mitte: CGPoint(x: 3.0, y: 1.6666666666666667)),
        (name: "schmale_ellipse",
         ecken: [CGPoint(x: -9.0, y: 0.0), CGPoint(x: 0.0, y: -2.0), CGPoint(x: 9.0, y: 0.0), CGPoint(x: 0.0, y: 2.0)],
         mitte: CGPoint(x: 0.0, y: 0.0)),
        (name: "fuenf_ecken",
         ecken: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 4.0, y: -1.0), CGPoint(x: 7.0, y: 3.0), CGPoint(x: 3.0, y: 6.0), CGPoint(x: -1.0, y: 4.0)],
         mitte: CGPoint(x: 2.6, y: 2.4)),
    ]
}
