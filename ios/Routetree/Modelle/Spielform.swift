// ERZEUGT VON scripts/spielformen_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/spielformen.py. Wer hier etwas
// ändert, ändert es nur in der App -- und dann spielt das Handy eine
// andere Sportart als der Ausdruck.
//
// Neu erzeugen:  ./scripts/spielformen_swift.py
// Geprüft von:   backend/designer/test_spielformen_swift.py

import Foundation

/// Was eine Mannschaft spielt.
///
/// Flag oder Tackle, und mit wie vielen Leuten. Bestimmt Feldmaße,
/// Aufstellung und die Regelhinweise.
struct Spielform: Equatable, Identifiable {

    let schluessel: String
    /// Mit Spielerzahl im Namen, weil „9er" ohne sie mehrdeutig ist.
    let name: String
    /// Ein Satz zu dem, was diese Form besonders macht.
    let hinweis: String
    let spieler: Int
    /// Vollkontakt oder Flag.
    let kontakt: Bool
    /// Reicht das Überqueren der Feldmitte für neue Versuche?
    ///
    /// Im Flag ja, im 5er-Tackle auch. Sonst läuft eine Kette, und dann
    /// ist die Mittellinie einfach die 50.
    let mitteIstLineToGain: Bool
    /// Wie viele mindestens an der Scrimmage Line stehen müssen.
    let linieMindestens: Int
    /// Davon mit einer Trikotnummer von 50 bis 79.
    let nummernMindestens: Int
    /// Wie viele höchstens im Backfield stehen dürfen. 0 heißt: egal.
    let hoechstensBacks: Int
    /// Wie viele Backfield-Spieler zwischen den aeusseren Linemen
    /// stehen muessen. Null heisst: Diese Form kennt die Regel nicht.
    let backsImRahmen: Int
    /// Wie gross eine Figur gezeichnet wird, in YARDS.
    ///
    /// **Der Wert hat bis zum 07.09.2026 gefehlt**, und die App hat
    /// deshalb jeden Spieler gleich gross gezeichnet: 0,65 Yards, den
    /// alten Flagwert. Im Tackle stossen zwei Kreise damit aneinander
    /// (zwei Linemen stehen 1,33 Yards auseinander), im Flag sind sie
    /// zu klein -- der Server nimmt dort 1,05.
    ///
    /// Server (`render.build_play`) und Browser (`editor.js`) rechnen
    /// seit T11 damit. Die App konnte es nicht, weil der Erzeuger das
    /// Feld nicht mit hinausgeschrieben hat.
    let figurradius: Double
    /// Wie viele Yards eine Kette misst -- null, wo keine laeuft.
    ///
    /// Im Flag und im 5er-Tackle reicht die Feldmitte fuer neue
    /// Versuche, dort gibt es keine wandernde Linie. In jeder anderen
    /// Form ist sie das, wonach ein Trainer die Tiefe seiner Routen
    /// aussucht -- und im bayerischen Sechser liegt sie bei fuenfzehn
    /// Yards, nicht bei zehn.
    let kette: Double
    /// Die Positionen dieser Form, als Kuerzel.
    ///
    /// **Zum VORSCHLAGEN und nicht zum Erzwingen.** Das Rollenfeld ist
    /// freier Text -- wer seine Position anders nennt, darf das. Ohne
    /// die Liste muss man im Elfer aber LT, LG, RG, RT, TE, RB und SL
    /// von Hand tippen, und der Browser bietet sie seit dem 07.09.2026
    /// an. Die App tat es nicht.
    let rollenOffense: [String]
    let rollenDefense: [String]
    let feld: Feld

    var id: String { schluessel }

    /// Alle Formen, in der Reihenfolge der Quelldatei: Flag zuerst,
    /// dann Tackle von groß nach klein.
    static let alle: [Spielform] = [
        Spielform(
            schluessel: "flag5",
            name: String(localized: #"Flag Football, 5 gegen 5"#),
            hinweis: String(localized: #"DFFL und Landesligen. Kein Kontakt, Rushlinie 7 Yards, die Mitte ist die Line to Gain."#),
            spieler: 5,
            kontakt: false,
            mitteIstLineToGain: true,
            linieMindestens: 0,
            nummernMindestens: 0,
            hoechstensBacks: 0,
            backsImRahmen: 0,
            figurradius: 1.05,
            kette: 0,
            rollenOffense: ["C", "QB", "X", "Y", "Z"],
            rollenDefense: ["R", "C1", "C2", "S1", "S2"],
            feld: Feld(spielLaenge: 50.0, endzone: 10.0, breite: 25.0,
                       keinLauf: 5.0, rush: 7.0, hashAbstand: nil)),
        Spielform(
            schluessel: "tackle11",
            name: String(localized: #"Tackle Football, 11 gegen 11"#),
            hinweis: String(localized: #"GFL, Regionalliga und die Jugendbundesliga. Volles Feld, höchstens vier Backs, fünf Nummern von 50 bis 79 an der Linie."#),
            spieler: 11,
            kontakt: true,
            mitteIstLineToGain: false,
            linieMindestens: 7,
            nummernMindestens: 5,
            hoechstensBacks: 4,
            backsImRahmen: 0,
            figurradius: 0.6,
            kette: 10.0,
            rollenOffense: ["LT", "LG", "C", "RG", "RT", "TE", "X", "QB", "RB", "SL", "Z"],
            rollenDefense: ["DE1", "DT1", "DT2", "DE2", "LB1", "LB2", "LB3", "CB1", "CB2", "FS", "SS"],
            feld: Feld(spielLaenge: 100.0, endzone: 10.0, breite: 53.33,
                       keinLauf: 0.0, rush: 0.0, hashAbstand: 20.0)),
        Spielform(
            schluessel: "tackle9",
            name: String(localized: #"Tackle Football, 9 gegen 9"#),
            hinweis: String(localized: #"In Deutschland auf dem vollen Feld (NRW, Bayern, Baden-Württemberg, Hessen) und bei den Frauen in der GFLW2. Kein Kickoff, drei Nummern von 50 bis 79 an der Linie."#),
            spieler: 9,
            kontakt: true,
            mitteIstLineToGain: false,
            linieMindestens: 5,
            nummernMindestens: 3,
            hoechstensBacks: 4,
            backsImRahmen: 0,
            figurradius: 0.6,
            kette: 10.0,
            rollenOffense: ["LT", "LG", "C", "RG", "RT", "X", "QB", "RB", "Z"],
            rollenDefense: ["DE1", "NT", "DE2", "LB1", "LB2", "LB3", "CB1", "CB2", "FS"],
            feld: Feld(spielLaenge: 100.0, endzone: 10.0, breite: 53.33,
                       keinLauf: 0.0, rush: 0.0, hashAbstand: 20.0)),
        Spielform(
            schluessel: "tackle9_eu",
            name: String(localized: #"Tackle Football, 9 gegen 9, schmales Feld"#),
            hinweis: String(localized: #"So spielt der Rest Europas: Italien 45 Yards breit, Österreich und die Schweiz 43⅓. Deutschland ist beim Feld die Ausnahme."#),
            spieler: 9,
            kontakt: true,
            mitteIstLineToGain: false,
            linieMindestens: 5,
            nummernMindestens: 3,
            hoechstensBacks: 4,
            backsImRahmen: 0,
            figurradius: 0.6,
            kette: 10.0,
            rollenOffense: ["LT", "LG", "C", "RG", "RT", "X", "QB", "RB", "Z"],
            rollenDefense: ["DE1", "NT", "DE2", "LB1", "LB2", "LB3", "CB1", "CB2", "FS"],
            feld: Feld(spielLaenge: 100.0, endzone: 10.0, breite: 45.0,
                       keinLauf: 0.0, rush: 0.0, hashAbstand: 16.875)),
        Spielform(
            schluessel: "tackle7",
            name: String(localized: #"Tackle Football, 7 gegen 7"#),
            hinweis: String(localized: #"Spielverbund Hessen, Rheinland-Pfalz und Saar sowie Baden-Württemberg. Feld 32 Meter breit, vier an der Linie. Bis U16 darf sofort nach dem Snap nur einer aus dem Backfield vorstoßen, und nur durch die Mitte. Bei den Damen verlangt Hessen fünf an der Linie, Baden-Württemberg vier."#),
            spieler: 7,
            kontakt: true,
            mitteIstLineToGain: false,
            linieMindestens: 4,
            nummernMindestens: 3,
            hoechstensBacks: 3,
            backsImRahmen: 2,
            figurradius: 0.6,
            kette: 10.0,
            rollenOffense: ["LG", "C", "RG", "X", "Z", "QB", "RB"],
            rollenDefense: ["DE1", "NT", "DE2", "LB1", "LB2", "CB1", "CB2"],
            feld: Feld(spielLaenge: 100.0, endzone: 10.0, breite: 35.0,
                       keinLauf: 0.0, rush: 0.0, hashAbstand: nil)),
        Spielform(
            schluessel: "tackle6",
            name: String(localized: #"Tackle Football, 6 gegen 6"#),
            hinweis: String(localized: #"Nur in Bayern, nach dem amerikanischen Six-Man-Football. Feld 80 mal 40 Yards, First Down nach 15 statt 10, und der Ball muss einmal übergeben werden, bevor er die neutrale Zone überqueren darf."#),
            spieler: 6,
            kontakt: true,
            mitteIstLineToGain: false,
            linieMindestens: 3,
            nummernMindestens: 0,
            hoechstensBacks: 3,
            backsImRahmen: 0,
            figurradius: 0.6,
            kette: 15,
            rollenOffense: ["LE", "C", "RE", "QB", "LB", "RB"],
            rollenDefense: ["DE1", "NT", "DE2", "LB1", "CB1", "CB2"],
            feld: Feld(spielLaenge: 80.0, endzone: 10.0, breite: 40.0,
                       keinLauf: 0.0, rush: 0.0, hashAbstand: 12.0)),
        Spielform(
            schluessel: "tackle5",
            name: String(localized: #"Tackle Football, 5 gegen 5"#),
            hinweis: String(localized: #"NRW, bis hinunter zu U10. Näher am Flag als am Tackle: ein einziger Rusher, sieben Sekunden zum Werfen, No-Run-Zone, keine Kette."#),
            spieler: 5,
            kontakt: true,
            mitteIstLineToGain: true,
            linieMindestens: 0,
            nummernMindestens: 0,
            hoechstensBacks: 0,
            backsImRahmen: 0,
            figurradius: 1.05,
            kette: 0,
            rollenOffense: ["C", "X", "Y", "Z", "QB"],
            rollenDefense: ["R", "CB1", "CB2", "LB1", "FS"],
            feld: Feld(spielLaenge: 87.49, endzone: 10.94, breite: 27.34,
                       keinLauf: 5.47, rush: 0.0, hashAbstand: nil)),
    ]

    /// Was eine Mannschaft bekommt, die nichts wählt.
    ///
    /// Flag bleibt die Voreinstellung: Alles Bestehende ist Flag, und
    /// eine App, die einem Playbook eine andere Form unterschöbe,
    /// verschöbe die Feldmaße unter fertigen Ausdrucken.
    static let standard = "flag5"

    /// Die Form zu einem Schlüssel, sonst die Voreinstellung.
    ///
    /// Fällt zurück statt `nil` zu liefern: Der Schlüssel kommt vom
    /// Server, und eine App, die ein Playbook wegen eines unbekannten
    /// Wortes nicht öffnet, ist die teuerste denkbare Antwort auf einen
    /// Tippfehler.
    static func zu(_ schluessel: String?) -> Spielform {
        alle.first { $0.schluessel == schluessel }
            ?? alle.first { $0.schluessel == standard }!
    }

    /// Die Formen nach Flag und Tackle getrennt, für die Auswahl.
    static var flag: [Spielform] { alle.filter { !$0.kontakt } }
    static var tackle: [Spielform] { alle.filter { $0.kontakt } }
}
