// ERZEUGT VON scripts/druck_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/druck.py -- dieselben Zahlen, mit denen
// der Server die Seite setzt. Was hier steht, hat der SERVER geliefert
// und niemand abgeschrieben.
//
// Warum das erzeugt wird: Ein Armband ist 125 Millimeter breit und nicht
// 127, und wer sich hier vertippt, merkt es erst, wenn zwölf
// ausgeschnittene Einlagen nicht ins Fenster passen. Dasselbe gilt für
// die Grenzen: Ein Regler, der bis zwanzig geht, während der Server auf
// zwölf klemmt, druckt acht Einlagen weniger als bestellt und sagt nichts.
//
// Neu erzeugen:  ./scripts/druck_swift.py
// Geprüft von:   backend/designer/test_druck_swift.py

import Foundation

/// Eine Ausgabe, die sich drucken oder teilen lässt.
struct Ausgabe: Identifiable, Hashable {
    let art: String
    let titel: String
    let text: String
    /// Die Dateiendung ohne Punkt.
    let endung: String
    /// Der Inhaltstyp, den der Server schickt.
    let typ: String
    /// Ob sich das an einen Drucker schicken lässt. Ein Archiv voller
    /// SVG lässt sich teilen, aber nicht drucken, und ein Druckknopf
    /// daneben wäre ein toter Knopf.
    let druckbar: Bool
    /// Welche Einstellungen zu dieser Ausgabe gehören.
    let felder: [String]
    /// Das Bild neben der Ausgabe, ohne Endung.
    ///
    /// Die Zeichnung liegt als SVG im Server
    /// (`static/designer/drucksymbole/`) und kommt hier als PDF im
    /// Bildkatalog an -- erzeugt von `scripts/drucksymbole.py`, damit
    /// beide Seiten dasselbe Bild zeigen. Ein PDF und kein PNG: Es
    /// bleibt in jeder Grösse scharf, und Xcode behält die Vektoren.
    let zeichen: String
    /// Wie viele verschiedene Gestalten diese Ausgabe annehmen kann
    /// (R56).
    ///
    /// **Vom Server gerechnet** (`druck.varianten`), nicht hier: Die
    /// Druckseite im Browser zeigt dieselbe Zahl, und zwei Rechnungen
    /// für dieselbe Frage geben irgendwann zwei Antworten.
    ///
    /// Gezählt wird, was die Ausgabe anders AUSSEHEN lässt -- Karten je
    /// Seite, Spalten, Armbandgröße, Bauart, Bildbreite. Nicht gezählt
    /// werden Logo und Schwarzweiß (Schalter am selben Bogen), die Zahl
    /// der Kopien (eine Menge) und die Seitenwahl (ein Filter auf den
    /// Inhalt).
    let varianten: Int

    var id: String { art }
}

/// Ein Wert mit Beschriftung, für ein Auswahlfeld.
struct Wahl: Identifiable, Hashable {
    let wert: String
    let label: String
    var id: String { wert }
}

/// Eine Armbandgröße, in Millimetern.
struct Groesse: Identifiable, Hashable {
    let wert: String
    let label: String
    let breite: Double
    let hoehe: Double
    let hinweis: String
    var id: String { wert }
}

/// Eine Ausgabebreite für Bilder, in Millimetern.
struct Bildbreite: Identifiable, Hashable {
    let wert: Double
    let label: String
    var id: Double { wert }
}

enum Druckwahl {

    /// Was sich an einem Playbook drucken lässt.
    static let ausgaben: [Ausgabe] = [
        Ausgabe(art: "playcards",
                titel: String(localized: "Playcards"),
                text: String(localized: "Alle Plays als Karten auf A4, zum Ausschneiden oder Abheften."),
                endung: "pdf", typ: "application/pdf",
                druckbar: true, felder: ["pro_seite", "kartenfuss", "zoom", "zeichenstil", "logo", "sw", "seite"],
                zeichen: "playcards",
                varianten: 135),
        Ausgabe(art: "callsheet",
                titel: String(localized: "Call Sheet"),
                text: String(localized: "A4 quer, gegliedert nach den Situationen am Play. Ein Play steht in jedem Block, zu dem er passt."),
                endung: "pdf", typ: "application/pdf",
                druckbar: true, felder: ["spalten", "je_block", "diagramme", "zoom", "zeichenstil", "logo", "sw", "seite"],
                zeichen: "call-sheet",
                varianten: 270),
        Ausgabe(art: "wristband",
                titel: String(localized: "Wristcoach-Einlagen"),
                text: String(localized: "Einlagen fürs Armband, mit Schnittzone und Marken an den Ecken."),
                endung: "pdf", typ: "application/pdf",
                druckbar: true, felder: ["groesse", "je_einlage", "anordnung", "kopien", "stil", "zoom", "zeichenstil", "logo", "sw", "seite"],
                zeichen: "wristcoach",
                varianten: 1152),
        Ausgabe(art: "bilder",
                titel: String(localized: "Bilder zum Weiterverwenden"),
                text: String(localized: "Jeder Play als SVG, alle zusammen in einem Archiv. Ein Vektorbild bleibt in jeder Größe scharf."),
                endung: "zip", typ: "application/zip",
                druckbar: false, felder: ["bildbreite", "zoom", "zeichenstil", "sw", "seite"],
                zeichen: "svg-export",
                varianten: 27),
    ]

    /// Und was an einem einzelnen Play.
    static let playAusgaben: [Ausgabe] = [
        Ausgabe(art: "blatt",
                titel: String(localized: "Play-Blatt"),
                text: String(localized: "Ein Play groß auf A4, mit den Hinweisen darunter."),
                endung: "pdf", typ: "application/pdf",
                druckbar: true, felder: ["zoom", "zeichenstil", "logo", "sw"],
                zeichen: "playbook",
                varianten: 9),
        Ausgabe(art: "bild",
                titel: String(localized: "Als Bild"),
                text: String(localized: "Der Play als SVG, zum Einfügen in eine Präsentation."),
                endung: "svg", typ: "image/svg+xml",
                druckbar: false, felder: ["bildbreite", "zoom", "zeichenstil", "sw"],
                zeichen: "svg-export",
                varianten: 27),
    ]

    /// Die Beschreibung zu einer Art, aus beiden Listen.
    static func ausgabe(_ art: String) -> Ausgabe? {
        (ausgaben + playAusgaben).first { $0.art == art }
    }

    // --- Playcards --------------------------------------------------------

    static let kartenZahlen: [Int] = [1, 2, 4, 6, 9]
    /// Wie viele Diagramme NEBENEINANDER stehen, je Anzahl pro Seite.
    ///
    /// Die Tafel ist `druck.SPALTEN`. Sie in Swift zu tippen hiesse,
    /// eine Anordnung zweimal zu behaupten -- und die Vorschau (R55)
    /// zeigte dann ein Blatt, das der Ausdruck nicht ergibt.
    static let kartenSpalten: [Int: Int] = [1: 1, 2: 1, 4: 2, 6: 2, 9: 3]
    static let kartenStandard = 4

    /// Was UNTER dem Diagramm einer Karte steht (R74).
    static let kartenfuesse: [Wahl] = [
        Wahl(wert: "situationen", label: String(localized: "Spielsituationen")),
        Wahl(wert: "notizen", label: String(localized: "Hinweise zum Play")),
        Wahl(wert: "nichts", label: String(localized: "Nur das Diagramm")),
    ]
    static let kartenfussStandard = "situationen"

    // --- Call Sheet -------------------------------------------------------

    static let spaltenZahlen: [Int] = [2, 3, 4]
    static let spaltenStandard = 3

    /// Wie viele Plays je Situationsblock aufs Blatt kommen (R74). Die
    /// Null heißt „alle" -- ein Block „Red Zone" mit dreiundzwanzig
    /// Einträgen ist am Spielfeldrand aber keine Hilfe.
    static let jeBlockZahlen: [Int] = [0, 3, 5, 8, 12]
    static let jeBlockStandard = 0

    // --- Was JEDE Ausgabe fragt (R74) -------------------------------------

    /// Wie viel vom Feld im Bild steht.
    static let zooms: [Wahl] = [
        Wahl(wert: "eng", label: String(localized: "Eng am Play")),
        Wahl(wert: "normal", label: String(localized: "Normal")),
        Wahl(wert: "weit", label: String(localized: "Weit, mit viel Feld")),
    ]
    static let zoomStandard = "normal"

    /// Wie kräftig gezeichnet wird. EINE Einstellung und nicht drei:
    /// Strich, Schrift und Symbolgröße sind auf einer Einlage von 125
    /// Millimetern keine unabhängigen Größen.
    static let zeichenstile: [Wahl] = [
        Wahl(wert: "fein", label: String(localized: "Fein")),
        Wahl(wert: "normal", label: String(localized: "Normal")),
        Wahl(wert: "kraeftig", label: String(localized: "Kräftig")),
    ]
    static let zeichenstilStandard = "normal"

    // --- Wristcoach -------------------------------------------------------

    static let groessen: [Groesse] = [
        Groesse(wert: "jugend",
                label: String(localized: "Jugend (Fenster 95 × 57 mm)"),
                breite: 95.0, hoehe: 60.0,
                hinweis: String(localized: "Cutters Youth, Champro Youth")),
        Groesse(wert: "standard",
                label: String(localized: "Standard (Fenster 127 × 70 mm)"),
                breite: 125.0, hoehe: 75.0,
                hinweis: String(localized: "die üblichen Dreifenster-Armbänder")),
        Groesse(wert: "gross",
                label: String(localized: "Groß (Fenster 133 × 83 mm)"),
                breite: 133.0, hoehe: 83.0,
                hinweis: String(localized: "Varsity und Erwachsene")),
    ]
    static let groesseStandard = "standard"
    /// Der Wert für „ich messe selbst". Ausdrücklich keine Größe.
    static let groesseFrei = "frei"
    static let freiLabel = String(localized: "Eigenes Maß")

    static let breiteMin = 40.0
    static let breiteMax = 190.0
    static let hoeheMin = 30.0
    static let hoeheMax = 260.0

    static let kopienMin = 1
    static let kopienMax = 12
    static let kopienStandard = 4

    static let stile: [Wahl] = [
        Wahl(wert: "text", label: String(localized: "Liste mit Nummern und Namen")),
        Wahl(wert: "diagramm", label: String(localized: "Kleine Diagramme")),
    ]
    static let stilStandard = "diagramm"

    /// Wie viele Plays auf EINE Einlage kommen (R74). Die Null heißt
    /// „alle auf eine" -- das ist der Stand, den die App bis zum
    /// 03.09.2026 als einzigen kannte.
    static let jeEinlageZahlen: [Int] = [0, 1, 2, 3, 4, 6, 8, 15]
    static let jeEinlageStandard = 8

    /// Wie die Plays IN der Einlage stehen: im Raster oder untereinander.
    static let anordnungen: [Wahl] = [
        Wahl(wert: "raster", label: String(localized: "Im Raster")),
        Wahl(wert: "spalte", label: String(localized: "Untereinander")),
    ]
    static let anordnungStandard = "raster"

    /// Wie fein die freie Maßeingabe rastet, in Millimetern. Ein Feld,
    /// in das man 126,3 tippen kann, verspricht eine Genauigkeit, die
    /// weder die Schere noch der Drucker einhält.
    static let massSchrittMm = 5.0

    /// Ein Zoll in Millimetern. Armbänder werden in Zoll verkauft, der
    /// Bogen wird in Millimetern gesetzt -- wer beides nebeneinander
    /// liest, muss nicht rechnen.
    static let zollMm = 25.4

    /// Die Schnittzone rundherum, in Millimetern. Steht auf der Seite,
    /// damit niemand die gestrichelte Linie für die Sollkante hält.
    static let schnittZugabeMm = 3.0

    // --- Bilder -----------------------------------------------------------

    static let bildBreiten: [Bildbreite] = [
        Bildbreite(wert: 120.0, label: String(localized: "Klein (12 cm)")),
        Bildbreite(wert: 180.0, label: String(localized: "Mittel (18 cm)")),
        Bildbreite(wert: 300.0, label: String(localized: "Groß (30 cm)")),
    ]
    static let bildBreiteStandard = 180.0
    static let bildBreiteMin = 40.0
    static let bildBreiteMax = 1000.0
}
