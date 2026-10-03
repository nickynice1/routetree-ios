// ERZEUGT VON scripts/gestaltung_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quellen sind backend/static/designer/app.css (die Oberfläche) und
// scripts/marke.mjs (das Zeichen). Wer hier eine Farbe ändert, ändert sie
// nur in der App -- und dann sehen Website und App aus wie zwei Produkte,
// die derselbe Verein aus zwei Quellen bezogen hat.
//
// Neu erzeugen:  ./scripts/gestaltung_swift.py
// Geprüft von:   backend/designer/test_gestaltung_swift.py

import SwiftUI

/// Eine Farbe des Systems: die Zahlen und die Farbe daraus.
///
/// Warum die Zahlen daneben stehenbleiben: Aus einem `Color` bekommt man
/// sie nur über UIKit wieder heraus, und dann misst eine Prüfung den
/// Umweg mit. So misst `GestaltungTests` das, was hier steht.
struct Ton: Equatable {
    let r: Double
    let g: Double
    let b: Double

    /// SwiftUIs `Color(red:green:blue:)` rechnet in sRGB -- derselbe
    /// Farbraum, in dem der Browser die Seite zeigt. Stünde hier
    /// `Color(.displayP3, ...)`, wären dieselben Zahlen ein anderer Ton,
    /// und zwar ein sattererer. Das sähe nicht falsch aus, nur anders.
    var farbe: Color { Color(red: r, green: g, blue: b) }

    /// Für die Prüfung und für Fehlermeldungen. „#75BCD2" liest sich,
    /// „0.4588235294" nicht.
    var hex: String {
        String(format: "#%02X%02X%02X",
               Int((r * 255).rounded()),
               Int((g * 255).rounded()),
               Int((b * 255).rounded()))
    }
}

/// Die Farben der OBERFLÄCHE, aus `app.css`.
///
/// Die Namen sind die des Webs. Das ist Absicht: Solange dieselbe Farbe
/// hier anders heißt als dort, redet niemand über dieselbe Sache. Bis
/// B13 hieß `flaeche-panel` in der App `flaeche` und `flaeche` hieß
/// `grund` -- zwei Namen, die sich überkreuzen, sind schlimmer als zwei
/// fremde.
enum Farben {
    /// Der Grund, auf dem alles liegt. Im Web `body`.
    static let flaecheTon = Ton(r: 0x0C/255, g: 0x11/255, b: 0x15/255)
    static let flaeche = flaecheTon.farbe
    /// Eine Karte, eine Zeile, ein Blatt darüber.
    static let flaechePanelTon = Ton(r: 0x14/255, g: 0x1A/255, b: 0x1F/255)
    static let flaechePanel = flaechePanelTon.farbe
    /// Was angefasst wird: Knopf, Feld, Auswahl.
    static let flaecheHochTon = Ton(r: 0x1C/255, g: 0x23/255, b: 0x28/255)
    static let flaecheHoch = flaecheHochTon.farbe
    /// Was zurücktritt: Beispielkasten, gedrückter Knopf.
    static let flaecheTiefTon = Ton(r: 0x07/255, g: 0x0B/255, b: 0x0F/255)
    static let flaecheTief = flaecheTiefTon.farbe
    /// Fließtext und Überschrift.
    static let inkTon = Ton(r: 0xE9/255, g: 0xED/255, b: 0xF0/255)
    static let ink = inkTon.farbe
    /// Zweite Zeile, Beschriftung.
    static let inkLeiseTon = Ton(r: 0xB7/255, g: 0xBD/255, b: 0xC2/255)
    static let inkLeise = inkLeiseTon.farbe
    /// Was da sein muss, aber nicht gelesen wird.
    static let inkStillTon = Ton(r: 0x8A/255, g: 0x92/255, b: 0x97/255)
    static let inkStill = inkStillTon.farbe
    static let linieTon = Ton(r: 0x29/255, g: 0x30/255, b: 0x36/255)
    static let linie = linieTon.farbe
    static let linieStarkTon = Ton(r: 0x41/255, g: 0x4A/255, b: 0x51/255)
    static let linieStark = linieStarkTon.farbe
    /// Die Marke IN DER OBERFLÄCHE -- hell, für dunklen Grund. Nicht zu
    /// verwechseln mit `Zeichen.petrol`, das ist das dunkle Petrol des
    /// Logos für hellen Grund.
    static let petrolTon = Ton(r: 0x75/255, g: 0xBC/255, b: 0xD2/255)
    static let petrol = petrolTon.farbe
    /// Dasselbe wie `petrol`. Im Web ein zweiter Name dafür.
    static let akzentTon = Ton(r: 0x75/255, g: 0xBC/255, b: 0xD2/255)
    static let akzent = akzentTon.farbe
    static let petrolTiefTon = Ton(r: 0x92/255, g: 0xD1/255, b: 0xE5/255)
    static let petrolTief = petrolTiefTon.farbe
    /// Die einzige Schriftfarbe, die auf `petrol` gehört.
    static let aufPetrolTon = Ton(r: 0x09/255, g: 0x0E/255, b: 0x12/255)
    static let aufPetrol = aufPetrolTon.farbe
    static let petrolHellTon = Ton(r: 0x14/255, g: 0x2E/255, b: 0x37/255)
    static let petrolHell = petrolHellTon.farbe
    static let petrolRandTon = Ton(r: 0x27/255, g: 0x4F/255, b: 0x5C/255)
    static let petrolRand = petrolRandTon.farbe
    /// WARNUNG -- und im Diagramm der Weg des Balls.
    static let goldTon = Ton(r: 0xE0/255, g: 0xB2/255, b: 0x6A/255)
    static let gold = goldTon.farbe
    static let goldHellTon = Ton(r: 0x37/255, g: 0x26/255, b: 0x13/255)
    static let goldHell = goldHellTon.farbe
    /// Die Defense im Diagramm.
    static let ziegelTon = Ton(r: 0xE1/255, g: 0x87/255, b: 0x75/255)
    static let ziegel = ziegelTon.farbe
    static let ziegelHellTon = Ton(r: 0x3B/255, g: 0x1F/255, b: 0x19/255)
    static let ziegelHell = ziegelHellTon.farbe
    /// Erledigt, sitzt, grün.
    static let gutTon = Ton(r: 0x69/255, g: 0xBF/255, b: 0x89/255)
    static let gut = gutTon.farbe
    static let warnungTon = Ton(r: 0xE0/255, g: 0xB2/255, b: 0x6A/255)
    static let warnung = warnungTon.farbe
    /// Abgelehnt, kaputt.
    static let fehlerTon = Ton(r: 0xEF/255, g: 0x7F/255, b: 0x74/255)
    static let fehler = fehlerTon.farbe
    static let fehlerHellTon = Ton(r: 0x3D/255, g: 0x1B/255, b: 0x17/255)
    static let fehlerHell = fehlerHellTon.farbe

    /// Alle Töne mit ihrem Namen aus der Quelle -- für die
    /// Prüfung, nicht für den Alltag.
    static let alle: [(name: String, ton: Ton)] = [
        ("flaeche", flaecheTon),
        ("flaeche-panel", flaechePanelTon),
        ("flaeche-hoch", flaecheHochTon),
        ("flaeche-tief", flaecheTiefTon),
        ("ink", inkTon),
        ("ink-leise", inkLeiseTon),
        ("ink-still", inkStillTon),
        ("linie", linieTon),
        ("linie-stark", linieStarkTon),
        ("petrol", petrolTon),
        ("akzent", akzentTon),
        ("petrol-tief", petrolTiefTon),
        ("auf-petrol", aufPetrolTon),
        ("petrol-hell", petrolHellTon),
        ("petrol-rand", petrolRandTon),
        ("gold", goldTon),
        ("gold-hell", goldHellTon),
        ("ziegel", ziegelTon),
        ("ziegel-hell", ziegelHellTon),
        ("gut", gutTon),
        ("warnung", warnungTon),
        ("fehler", fehlerTon),
        ("fehler-hell", fehlerHellTon),
    ]
}

/// Die Farben des ZEICHENS, aus `marke.mjs`.
///
/// Getrennt von `Farben`, weil `petrol` und `gold` in beiden Sätzen
/// vorkommen und verschiedene Werte haben. Ein Satz mit beiden darin
/// hätte einen der beiden umbenennen müssen, und der umbenannte wäre der
/// gewesen, den jemand als nächstes falsch benutzt.
enum Zeichen {
    /// Der Grund des Logos. In der App der Schatten der No-Run-Zone.
    static let tiefTon = Ton(r: 0x0E/255, g: 0x2A/255, b: 0x33/255)
    static let tief = tiefTon.farbe
    /// Das Zeichen auf HELLEM Grund. Nicht die Oberfläche.
    static let petrolTon = Ton(r: 0x14/255, g: 0x60/255, b: 0x6F/255)
    static let petrol = petrolTon.farbe
    /// Das Zeichen auf DUNKLEM Grund.
    static let klarTon = Ton(r: 0x3E/255, g: 0x9D/255, b: 0xB8/255)
    static let klar = klarTon.farbe
    /// Der Punkt des Zeichens.
    static let kreideTon = Ton(r: 0xE8/255, g: 0xF1/255, b: 0xF2/255)
    static let kreide = kreideTon.farbe
    /// Nur im Ausdruck.
    static let papierTon = Ton(r: 0xFB/255, g: 0xFB/255, b: 0xF9/255)
    static let papier = papierTon.farbe
    /// Nur im Ausdruck.
    static let tinteTon = Ton(r: 0x0F/255, g: 0x14/255, b: 0x1A/255)
    static let tinte = tinteTon.farbe
    /// Die Warnfarbe der Marke. Die Oberfläche hat ihre eigene.
    static let goldTon = Ton(r: 0xC8/255, g: 0x87/255, b: 0x1F/255)
    static let gold = goldTon.farbe

    /// Alle Töne mit ihrem Namen aus der Quelle -- für die
    /// Prüfung, nicht für den Alltag.
    static let alle: [(name: String, ton: Ton)] = [
        ("tief", tiefTon),
        ("petrol", petrolTon),
        ("klar", klarTon),
        ("kreide", kreideTon),
        ("papier", papierTon),
        ("tinte", tinteTon),
        ("gold", goldTon),
    ]
}

/// Schrift auf Fläche -- so, wie das Web es setzt.
///
/// **Wozu das gut ist.** Im CSS stehen Schriftfarbe und Fläche in
/// EINER Regel; in SwiftUI sind es zwei Griffe, und der zweite steht
/// drei Zeilen später. Genau da geht eine Paarung verloren: Wer
/// `.background(Farben.petrol)` schreibt und danach die Schriftfarbe
/// vergisst, bekommt Weiß auf Hellpetrol. Das ist ein Kontrast von 1,9
/// zu 1 -- unlesbar, aber es sieht nach einem Knopf aus.
///
/// Jede Paarung hier ist im Browser nachweislich so gesetzt, und jede
/// hält den Fließtextwert 4,5:1 ein. Gemessen in
/// `backend/designer/test_gestaltung.py` und in `GestaltungTests`.
enum Paare {
    struct Paar: Equatable {
        let schrift: Ton
        let grund: Ton
    }

    /// Im Web: `body`
    static let body = Paar(schrift: Farben.inkTon, grund: Farben.flaecheTon)
    /// Im Web: `.knopf`
    static let knopf = Paar(schrift: Farben.inkTon, grund: Farben.flaecheHochTon)
    /// Im Web: `.knopf.haupt`
    static let knopfHaupt = Paar(schrift: Farben.aufPetrolTon, grund: Farben.petrolTon)
    /// Im Web: `.chip`
    static let chip = Paar(schrift: Farben.inkLeiseTon, grund: Farben.flaecheHochTon)
    /// Im Web: `.chip.warn`
    static let chipWarn = Paar(schrift: Farben.goldTon, grund: Farben.goldHellTon)
    /// Im Web: `.meldung.fehler`
    static let meldungFehler = Paar(schrift: Farben.fehlerTon, grund: Farben.fehlerHellTon)
    /// Im Web: `.beispiel`
    static let beispiel = Paar(schrift: Farben.inkLeiseTon, grund: Farben.flaecheTiefTon)
    /// Im Web: `.aufgabenmarke`
    static let aufgabenmarke = Paar(schrift: Farben.petrolTiefTon, grund: Farben.petrolHellTon)
    /// Im Web: `.kontoblock .sprachfeld select`
    static let kontoblockSprachfeldSelect = Paar(schrift: Farben.inkTon, grund: Farben.flaechePanelTon)
    /// Im Web: `.anderesprache`
    static let anderesprache = Paar(schrift: Farben.inkLeiseTon, grund: Farben.flaechePanelTon)
    /// Im Web: `.wissen-nummer span`
    static let wissenNummerSpan = Paar(schrift: Farben.petrolTiefTon, grund: Farben.flaecheHochTon)

    /// Alle Paarungen -- für die Prüfung, nicht für den Alltag.
    static let alle: [(name: String, paar: Paar)] = [
        ("body", body),
        ("knopf", knopf),
        ("knopfHaupt", knopfHaupt),
        ("chip", chip),
        ("chipWarn", chipWarn),
        ("meldungFehler", meldungFehler),
        ("beispiel", beispiel),
        ("aufgabenmarke", aufgabenmarke),
        ("kontoblockSprachfeldSelect", kontoblockSprachfeldSelect),
        ("anderesprache", anderesprache),
        ("wissenNummerSpan", wissenNummerSpan),
    ]
}

extension View {

    /// Setzt Schrift und Fläche einer Paarung in EINEM Griff.
    ///
    /// Ohne diesen Weg gäbe es die Paarungen zwar, aber jede
    /// Verwendungsstelle dürfte sie wieder auseinandernehmen -- und das
    /// tut sie dann auch.
    func paarung<F: Shape>(_ paar: Paare.Paar, in form: F) -> some View {
        self.foregroundStyle(paar.schrift.farbe)
            .background(paar.grund.farbe, in: form)
    }

    /// Dasselbe mit der üblichen Ecke. Die Rundung kommt aus `Masse`,
    /// damit hier keine Zahl steht.
    func paarung(_ paar: Paare.Paar, ecke: CGFloat = Masse.r2) -> some View {
        self.paarung(paar, in: RoundedRectangle(cornerRadius: ecke))
    }
}

/// Die Eckenrundungen, aus `--r1` bis `--r4`.
///
/// **Vier und nicht sechs.** Vor B13 rundete die App an sechs Maßen (8,
/// 10, 12, 13, 14, 16), das Web an vier. Sechs Rundungen sind keine
/// feinere Abstufung, sondern vier plus zwei Versehen: Niemand sieht
/// einer Ecke an, ob sie 13 oder 14 Punkte hat, und deshalb merkt auch
/// niemand, wenn zwei Karten nebeneinander verschieden gerundet sind.
///
/// `--rund: 999px` kommt bewusst NICHT mit. Das ist kein Maß, sondern
/// das Wort „ganz rund", und in SwiftUI heißt es `Capsule()`.
enum Masse {
    static let r1: CGFloat = 8
    static let r2: CGFloat = 12
    static let r3: CGFloat = 18
    static let r4: CGFloat = 26
}

/// Wie sich etwas bewegt, aus `--tempo` und `--kurve`.
///
/// Eine App, die schneller oder langsamer einblendet als die Website,
/// fühlt sich anders an, ohne dass jemand sagen könnte warum.
enum Bewegung {
    static let dauer: Double = 0.18
    static let kurve = Animation.timingCurve(0.22, 1.0, 0.36, 1.0,
                                             duration: dauer)
}

/// Eine der Lichtquellen hinter der Oberfläche, aus `body::before`.
///
/// **Wozu.** Die Kacheln sind Glas, und Glas braucht etwas zum Brechen.
/// Ohne die Lichtquellen ist der Weichzeichner reine Behauptung, und
/// dieselben Kacheln sehen auf flachem Grund aus wie Kästen mit einem
/// Filter darüber. Das steht so in `app.css` und gilt hier genauso.
///
/// **Die Maße sind ANTEILE der Fläche, keine Punkte.** Im CSS stehen
/// die Kegel in `rem`: 58 rem sind 928 px, auf einem Laptop knapp zwei
/// Drittel der Breite. Auf einem Telefon wären dieselben 928 Punkte das
/// Zweieinhalbfache des Schirms, und aus dem Schein in der Ecke würde
/// ein Farbschleier über allem. Was den Entwurf ausmacht, ist das
/// Verhältnis von Kegel zu Fläche.
struct Lichtquelle {
    /// Mittelpunkt, als Anteil der Fläche. 0.12 = 12 % von links.
    let x: Double
    let y: Double
    /// HALBMESSER, als Anteil der Fläche. Im CSS sind `58rem 40rem`
    /// die beiden Halbmesser des Kegels, nicht seine Kantenlängen.
    let breiteAnteil: Double
    let hoeheAnteil: Double
    let ton: Ton
    let deckkraft: Double
    /// Wo der Kegel ganz durchsichtig ist, als Anteil des Halbmessers.
    let ende: Double
}

/// Der Grund, auf dem alles liegt -- Farbe UND Licht.
///
/// Im Web macht das `body` plus `body::before`. In der App war es bis
/// zum 27.08.2026 nur die Farbe: flach, ohne Verlauf. Gemeldet von
/// Niklas: „da ist so ein farbverlauf im web."
///
/// **Die Zahlen sind ERZEUGT**, nicht getippt. Wer den Verlauf im Web
/// ändert und die App vergisst, sieht zwei Produkte -- und genau dagegen
/// ist dieses ganze Modul geschrieben.
enum Grund {
    static let lichtquellen: [Lichtquelle] = [
        Lichtquelle(
            x: 0.12, y: -0.08,
            breiteAnteil: 0.6444,
            hoeheAnteil: 0.7111,
            ton: Ton(r: 0x75/255, g: 0xBC/255, b: 0xD2/255),
            deckkraft: 0.16, ende: 0.62),
        Lichtquelle(
            x: 0.96, y: 0.04,
            breiteAnteil: 0.5111,
            hoeheAnteil: 0.6044,
            ton: Ton(r: 0xE0/255, g: 0xB2/255, b: 0x6A/255),
            deckkraft: 0.1, ende: 0.6),
        Lichtquelle(
            x: 0.5, y: 1.18,
            breiteAnteil: 0.7778,
            hoeheAnteil: 0.8889,
            ton: Ton(r: 0xE1/255, g: 0x87/255, b: 0x75/255),
            deckkraft: 0.07, ende: 0.64),
    ]
}

/// Die Grundfläche als Sicht: Farbe, darüber die Lichtquellen.
///
/// **`.ignoresSafeArea()` gehört an den Aufrufer**, nicht hierher: Eine
/// Sicht, die von sich aus über die Kanten läuft, lässt sich nicht mehr
/// in eine Karte legen.
struct Grundflaeche: View {
    var body: some View {
        GeometryReader { raum in
            ZStack {
                Farben.flaeche
                ForEach(Array(Grund.lichtquellen.enumerated()), id: \.offset) {
                    _, quelle in
                    // Der waagerechte Halbmesser gibt den Kreis vor, der
                    // senkrechte staucht ihn. SwiftUI kennt keinen
                    // elliptischen Verlauf -- ein runder wäre an der
                    // einen Achse zu kurz und an der anderen zu lang.
                    let halb = raum.size.width * quelle.breiteAnteil
                    let hoch = raum.size.height * quelle.hoeheAnteil
                    RadialGradient(
                        colors: [quelle.ton.farbe.opacity(quelle.deckkraft),
                                 quelle.ton.farbe.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: halb * quelle.ende)
                        .frame(width: halb * 2, height: halb * 2)
                        .scaleEffect(x: 1, y: hoch / max(halb, 1))
                        .position(x: raum.size.width * quelle.x,
                                  y: raum.size.height * quelle.y)
                }
            }
        }
    }
}
