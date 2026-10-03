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

/// Ein Spielfeld in Yards. Standard ist die AFVD-Norm.
///
/// Alle Maße in Yards, x läuft in Angriffsrichtung, y quer.
///
/// **`Codable` seit R140**, und zwar für die Apple Watch. Das Paket,
/// das das Telefon hinüberschickt, trägt die Maße des Hefts mit --
/// anders kann die Uhr nicht dieselbe Projektion rechnen wie Telefon
/// und Ausdruck, und genau darauf beruht hier alles.
///
/// Die naheliegende Abkürzung wäre gewesen, nur die Kennung des
/// Formats zu schicken (`afvd`, `afvd_klein`) und die Uhr in
/// `voreinstellungen` nachschlagen zu lassen. Sie ist falsch: Was ein
/// Play an Maßen benutzt, entscheidet der SERVER beim Speichern, und
/// ein Heft mit eigenen Maßen steht in keiner Voreinstellung. Die Uhr
/// zeichnete dann ein anderes Feld als das Telefon -- und das fiele
/// erst am Platz auf.
struct Feld: Codable, Equatable {

    // --- Normmaße, aus geometry.py -----------------------------------

    /// Spielfeld OHNE Endzonen.
    static let normSpielLaenge = 50.0
    /// Je Endzone.
    static let normEndzone = 10.0
    static let normBreite = 25.0
    /// Vor jeder Torlinie.
    static let normKeinLauf = 5.0
    /// Hinter der Line of Scrimmage.
    static let normRush = 7.0

    /// Rasterweite des Zeichenfangs. Ein halbes Yard ist die Genauigkeit,
    /// in der ein Trainer eine Aufstellung überhaupt denkt: feiner fängt
    /// man Zittern ein, gröber verliert man die Splitbreite.
    static let fangYards = 0.5
    /// Wie nah an einer Marke es einrastet. Darueber hinaus bleibt der
    /// Punkt, wo getippt wurde (Niklas, 27.08.2026).
    static let fangMagnetYards = 0.12
    /// Winkelschritt des Fangs. 45 Grad deckt die Richtungen ab, in denen
    /// Routen beschrieben werden: Go, Out, Slant, Post.
    static let fangGrad = 45.0
    /// Dasselbe fuer Winkel. Enger als beim Raster: Ein schiefer Winkel
    /// faellt auf, eine schiefe Position nicht.
    static let fangMagnetGrad = 6.0

    /// Vom Regelwerk erlaubte Abweichung.
    static let minLaenge = 40.0
    static let maxLaenge = 60.0
    static let minBreite = 20.0
    static let maxBreite = 30.0

    var spielLaenge = normSpielLaenge
    var endzone = normEndzone
    var breite = normBreite
    var keinLauf = normKeinLauf
    var rush = normRush
    /// Abstand der Hashmarks von der Seitenlinie, oder `nil`.
    ///
    /// Bei den gespeicherten Eigenschaften und nicht bei den
    /// abgeleiteten, weil der erzeugte Initialisierer der Reihenfolge
    /// hier folgt. `Optional` bekommt dabei `nil` als Vorgabe, also
    /// bleibt `Feld(spielLaenge:breite:)` unveraendert gueltig.
    var hashAbstand: Double?

    static let afvd = Feld()

    /// Die Auswahl im Editor.
    static let voreinstellungen: [String: Feld] = [
        "afvd": Feld(spielLaenge: 50.0, breite: 25.0),
        "afvd_klein": Feld(spielLaenge: 40.0, breite: 20.0),
        "afvd_gross": Feld(spielLaenge: 60.0, breite: 30.0),
    ]

    // --- Abgeleitete Linien, alle auf der x-Achse --------------------

    /// Gesamtlänge inklusive beider Endzonen.
    var gesamtLaenge: Double { spielLaenge + 2 * endzone }
    var torlinieLinks: Double { endzone }
    var torlinieRechts: Double { endzone + spielLaenge }
    /// Mittellinie, im Flag Football zugleich die Line to Gain.
    var mitte: Double { endzone + spielLaenge / 2 }
    /// Grenze der linken No-Run-Zone.
    var keinLaufLinks: Double { torlinieLinks + keinLauf }
    var keinLaufRechts: Double { torlinieRechts - keinLauf }

    /// Ob dieses Feld Hashmarks hat, und wo sie liegen.
    ///
    /// `nil` heißt: keine. Im Flag gibt es keine, im 7er-Tackle sind
    /// keine belegt -- und erfundene Striche wären schlimmer als keine,
    /// weil ein Trainer einen Ball darauf legen würde, den es dort
    /// nicht gibt.
    var hatHashmarks: Bool { hashAbstand != nil }
    var hashLinks: Double? { hashAbstand }
    var hashRechts: Double? { hashAbstand.map { breite - $0 } }

    // --- Umrechnungen -------------------------------------------------

    /// Die übliche Yard-Linien-Zählung.
    ///
    /// Im Football zählen die Linien von beiden Torlinien zur Mitte hoch,
    /// die Mittellinie ist die höchste. Bei einem 50-Yard-Feld also 0 an
    /// den Torlinien und 25 in der Mitte.
    /// ACHTUNG, RUNDUNG: `.toNearestOrEven` und nicht `.rounded()`.
    ///
    /// Python rundet mit `round()` kaufmaennisch zur geraden Zahl: 4,5
    /// wird 4, nicht 5. Swifts `.rounded()` rundet von der Null weg und
    /// macht daraus 5. Auf halben Yards liegen aber genau die
    /// Aufstellungen, die ein Trainer wirklich zeichnet, weil der
    /// Zeichenfang auf halbe Yards rastet. Ohne diese Zeile stuende auf
    /// dem Handy eine andere Yard-Linie als auf dem Ausdruck.
    ///
    /// Gemessen, nicht vermutet: `FeldProben.yardLinie` enthaelt die
    /// halben Werte, und die erwarteten Ergebnisse kommen aus Python.
    func yardLinie(_ x: Double) -> Int {
        let vonLinks = x - torlinieLinks
        let vonRechts = torlinieRechts - x
        return Int((min(vonLinks, vonRechts)).rounded(.toNearestOrEven))
    }

    /// Muss von dieser Position aus zwingend gepasst werden?
    func inKeinLaufZone(_ x: Double) -> Bool {
        x < keinLaufLinks || x > keinLaufRechts
    }

    /// Hält einen Punkt im Feld, Endzonen eingeschlossen.
    func begrenzen(x: Double, y: Double) -> (x: Double, y: Double) {
        (min(max(x, 0), gesamtLaenge), min(max(y, 0), breite))
    }

    /// Die Rushlinie zu einer Line of Scrimmage.
    ///
    /// `richtung` ist +1, wenn die Offense nach rechts angreift, sonst -1.
    /// Die Rushlinie liegt immer auf der Verteidigerseite.
    func rushLinie(los: Double, richtung: Int) -> Double {
        los + Double(richtung) * Double(rush)
    }

    /// Liegt das Feld im vom Regelwerk erlaubten Rahmen?
    var istGueltig: Bool {
        (Feld.minLaenge...Feld.maxLaenge).contains(spielLaenge)
            && (Feld.minBreite...Feld.maxBreite).contains(breite)
    }
}

/// Ein Feldformat mit seinem Anzeigenamen -- für die Auswahl beim
/// Anlegen eines Playbooks (B6).
///
/// Die Namen stehen hier und nicht in der Ansicht, weil sie erzeugt
/// werden: Sie kommen aus `geometry.FIELD_PRESETS`, also aus derselben
/// Quelle wie die Maße. Ein abgeschriebener Name liefe beim nächsten
/// Regelwerk auseinander -- im Browser stünde „Verkleinert — 40 × 20 yd
/// (Regelminimum)" und in der App „Klein".
struct Feldformat: Hashable, Identifiable {
    let kennung: String
    let name: String

    var id: String { kennung }

    /// Alle Formate, in der Reihenfolge von `geometry.py`.
    static let alle: [Feldformat] = [
        Feldformat(kennung: "afvd",
                   name: String(localized: #"IFAF 5v5, 50 × 25 yd"#)),
        Feldformat(kennung: "afvd_klein",
                   name: String(localized: #"Verkleinert: 40 × 20 yd (Regelminimum)"#)),
        Feldformat(kennung: "afvd_gross",
                   name: String(localized: #"Vergrößert: 60 × 30 yd (Regelmaximum)"#)),
    ]

    /// Das erste ist die Vorgabe -- dieselbe wie im Modell des Servers.
    static let vorgabe = alle[0]

    /// Der Anzeigename zu einer Kennung. Unbekanntes bleibt stehen, wie
    /// es kam: Eine Kennung, die die App nicht kennt, ist ehrlicher als
    /// ein erfundener Name.
    ///
    /// Heißt `anzeigename` und nicht `name`: Ein statisches `name(_:)`
    /// neben einem Feld `name` liest sich beim Überfliegen wie dasselbe.
    static func anzeigename(fuer kennung: String) -> String {
        alle.first { $0.kennung == kennung }?.name ?? kennung
    }
}
