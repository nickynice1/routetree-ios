// ERZEUGT VON scripts/linienstile_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/render.py (LINE_STYLES, LINE_SHORT,
// LINE_CSSVAR). Wer hier etwas ändert, ändert es nur in der App, und dann
// heißt dieselbe Linie im Browser „Motion" und auf dem Handy „Pass".
//
// Neu erzeugen:  ./scripts/linienstile_swift.py
// Geprüft von:   backend/designer/test_linienstile_swift.py

import Foundation

/// Wie eine Linienart aussieht und wie sie heißt.
///
/// Die Maße sind Bildeinheiten wie im SVG des Servers: zehn Einheiten je
/// Yard. Wer sie auf dem Bildschirm benutzt, muss sie mit demselben
/// Faktor strecken wie die Punkte, sonst hat dieselbe Zeichnung auf dem
/// Handy dickere Striche als im Ausdruck.
struct Linienstil: Equatable {

    /// Kurzform für die Werkzeugleiste. „Abgabe", nicht „Ballabgabe".
    let kurz: String
    /// Ausgeschrieben, für die Legende und den Vorleser.
    let lang: String
    /// Das Ende, mit dem eine neue Linie dieser Art anfängt. Ändern kann
    /// man es danach an jeder einzelnen Linie.
    let standardEnde: Zeichnung.Linie.Ende
    /// Strichmuster in Bildeinheiten, `nil` heißt durchgezogen.
    let strich: [Double]?
    /// Strichstärke in Bildeinheiten.
    let breite: Double
    /// Ob eine Linie dieser Art OHNE Spieler anfangen darf (R58).
    ///
    /// **Kommt vom Server und steht nicht mehr in Swift.** Bis zum
    /// 06.09.2026 stand die Regel als `self == .zone` in
    /// `Zeichnung.Linie.Art` -- und im Browser gar nicht. Zwei
    /// Fassungen derselben Regel, von denen eine fehlte: Der Editor am
    /// Schreibtisch liess Wege ohne Läufer weiterhin zu, ein halbes
    /// Jahr lang unbemerkt.
    let frei: Bool
    /// Ob diese Linie der Weg des BALLS ist und nicht der eines
    /// Spielers (R88).
    ///
    /// **Kommt vom Server**, wie `frei` daneben. Der Ablauf hatte die
    /// Liste bis zum 09.09.2026 ein zweites Mal getippt
    /// (`Laufplan.ballArten`), und der Editor kannte sie gar nicht --
    /// deshalb ersetzte ein Snap die Route desselben Spielers.
    let ball: Bool
    /// Die Farbe im Ausdruck, als Hexwert. Papier hat kein dunkles Thema.
    let druckfarbe: String
    /// Die Rolle der Bildschirmfarbe. Welcher Wert dahintersteht,
    /// entscheidet die Palette der App.
    let farbe: Rolle

    enum Rolle: String, Equatable {
        case text, still, gold, petrol
    }
}

extension Zeichnung.Linie.Art {

    /// Die Reihenfolge der Werkzeugleiste, dieselbe wie im Browser.
    static let reihenfolge: [Zeichnung.Linie.Art] = [
        .route,
        .motion,
        .block,
        .handoff,
        .pass,
        .zone,
        .option,
    ]

    var stil: Linienstil { Linienstil.alle[self] ?? Linienstil.alle[.route]! }

    /// Was in der WERKZEUGLEISTE steht (R83). Zwei Werkzeuge, nicht
    /// zehn: ein Weg und ein Raum.
    static let inDerLeiste: [Zeichnung.Linie.Art] = [.route, .zone]

    /// Welche Arten sich an einer ausgewählten Linie umstellen lassen.
    /// Man zeichnet erst und entscheidet dann, was es ist.
    static let umstellbar: [Zeichnung.Linie.Art] = [.route, .motion, .block, .handoff, .pass, .option]

    /// Welche Linien einander an EINER Position ersetzen (R88).
    ///
    /// Niklas am 09.09.2026: „Wenn ich einen Spieler eine Abgabe bzw.
    /// snap Linie gebe, kann ich ihm keine normale Route mehr geben."
    /// Ein Center snappt und läuft danach seine Route -- zwei Wege
    /// derselben Figur, aber nicht dasselbe: der eine ist der Ball, der
    /// andere der Mensch. Die Regel „eine Linie je Position" gilt
    /// seitdem JE SORTE.
    var sorte: Sorte {
        if self == .option { return .option }
        return stil.ball ? .ball : .weg
    }

    enum Sorte: Equatable {
        /// Der Weg des Spielers: Route, Motion, Abschirmen.
        case weg
        /// Der Weg des Balls: Snap und Passweg.
        case ball
        /// Der zweite Ast einer Gabelung.
        case option
    }
}

extension Linienstil {

    static let alle: [Zeichnung.Linie.Art: Linienstil] = [
        .route: Linienstil(
            kurz: String(localized: "Route"),
            lang: String(localized: "Route"),
            standardEnde: .arrow,
            strich: nil,
            breite: 2.6,
            frei: false,
            ball: false,
            druckfarbe: "#131A22",
            farbe: .text),
        .motion: Linienstil(
            kurz: String(localized: "Motion"),
            lang: String(localized: "Motion vor dem Snap"),
            standardEnde: .arrow,
            strich: [10.0, 7.0],
            breite: 2.2,
            frei: false,
            ball: false,
            druckfarbe: "#6B7684",
            farbe: .still),
        .block: Linienstil(
            kurz: String(localized: "Block"),
            lang: String(localized: "Abschirmen"),
            standardEnde: .tee,
            strich: nil,
            breite: 2.6,
            frei: false,
            ball: false,
            druckfarbe: "#131A22",
            farbe: .text),
        .handoff: Linienstil(
            kurz: String(localized: "Snap"),
            lang: String(localized: "Ballabgabe"),
            standardEnde: .arrow,
            strich: nil,
            breite: 2.6,
            frei: false,
            ball: true,
            druckfarbe: "#9C6310",
            farbe: .gold),
        .pass: Linienstil(
            kurz: String(localized: "Pass"),
            lang: String(localized: "Passweg"),
            standardEnde: .arrow,
            strich: [2.0, 8.0],
            breite: 2.2,
            frei: false,
            ball: true,
            druckfarbe: "#9C6310",
            farbe: .gold),
        .zone: Linienstil(
            kurz: String(localized: "Zone"),
            lang: String(localized: "Zonenverantwortung"),
            standardEnde: .none,
            strich: [14.0, 6.0],
            breite: 2.2,
            frei: true,
            ball: false,
            druckfarbe: "#1A5364",
            farbe: .petrol),
        .option: Linienstil(
            kurz: String(localized: "Option"),
            lang: String(localized: "Option Route"),
            standardEnde: .arrow,
            strich: [6.0, 5.0],
            breite: 2.4,
            frei: false,
            ball: false,
            druckfarbe: "#131A22",
            farbe: .text),
    ]
}
