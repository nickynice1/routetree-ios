// Ein Play am Handgelenk (R140).
//
// **Das ist bewusst NICHT `Feldansicht`.** Die zeichnet Torlinien,
// Fünf-Yard-Linien, Yardzahlen, Hashmarks, No-Run-Zonen, Rushlinie,
// Line to Gain, Griffe, Entwürfe und Auswahl. Auf einem Bildschirm von
// vier Zentimetern ist davon nichts lesbar -- es ist Grau, das die
// Routen verdeckt.
//
// Ein Wristcoach braucht das Gegenteil: die Figuren, die Wege, und eine
// Linie, an der es losgeht. Sonst nichts.
//
// **Dieselben Yards, dieselbe Projektion.** Das ist der Punkt, an dem
// dieses Projekt hängt: Server, Browser, Telefon und Ausdruck rechnen
// aus `Projektion` und `Feld`. Die Uhr tut es auch -- sie zeichnet nur
// weniger davon. Eine eigene Rechnung wäre eine fünfte Wahrheit über
// dieselbe Sache, und die liefe auseinander.

import SwiftUI

/// Wie viel dicker eine Linie auf der Uhr ist als auf dem Telefon.
///
/// Klein, und das ist gemessen an einem Handgelenk: Aus 2,2 bis 2,6
/// Punkten werden 2,5 bis 2,9. Bei 1,2 -- dem ersten Versuch -- lagen
/// drei Routen nebeneinander wie ein Balken.
private let AUFSCHLAG: CGFloat = 0.3

/// Wie lang eine Pfeilspitze im Verhältnis zur Linienbreite ist.
///
/// Das Dreifache ist die Faustregel, ab der ein Pfeil als Pfeil
/// gelesen wird und nicht als Verdickung.
private let SPITZE_JE_BREITE: CGFloat = 3.2

/// Und nach unten begrenzt, damit auch die dünnste Art eine Spitze hat.
private let SPITZE_MINDESTENS: CGFloat = 10

/// Zeichnet einen Play so groß, wie die Uhr ihn hergibt.
struct Uhrfeld: View {

    let play: Uhrpaket.Play
    let feld: Feld
    let spielform: String

    /// Ob die Namen an den Routen stehen.
    ///
    /// Auf der Uhr **aus** als Vorgabe: „Go" neben einer Linie kostet
    /// ein Viertel der Breite, und wer den Play am Handgelenk ansieht,
    /// erkennt ihn an der Form. Wer den Namen braucht, schaltet ihn im
    /// Play-Blatt dazu.
    var zeigeNamen: Bool = false

    private var projektion: Projektion {
        Projektion.fuerDieApp(feld: feld, los: play.los,
                              richtung: play.richtung,
                              spielform: spielform)
            .passendFuer(play.zeichnung)
    }

    var body: some View {
        GeometryReader { raum in
            let p = projektion
            let (faktor, _) = p.aufFlaeche(raum.size)
            Canvas { zeichner, groesse in
                grundlinie(zeichner, p, groesse)
                for linie in play.zeichnung.linien {
                    zeichne(linie, zeichner, p, groesse)
                }
                for spieler in play.zeichnung.spieler {
                    zeichne(spieler, zeichner, p, groesse, faktor: faktor)
                }
            }
        }
        .background(Uhrfarben.rasen)
    }

    // MARK: - Die Linie, an der es losgeht

    /// Die Line of Scrimmage, und nur sie.
    ///
    /// Sie bleibt, wo die anderen Markierungen wegfallen, weil sie die
    /// einzige ist, die man zum LESEN eines Plays braucht: Ohne sie
    /// steht die Aufstellung im Nichts, und ob eine Route fünf Yards
    /// tief läuft oder fünfzehn, lässt sich nicht abschätzen.
    private func grundlinie(_ z: GraphicsContext, _ p: Projektion,
                            _ groesse: CGSize) {
        var weg = Path()
        weg.move(to: p.aufBildschirm(x: play.los, y: 0, groesse: groesse))
        weg.addLine(to: p.aufBildschirm(x: play.los, y: feld.breite,
                                        groesse: groesse))
        z.stroke(weg, with: .color(Uhrfarben.grundlinie),
                 style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
    }

    // MARK: - Wege

    private func zeichne(_ linie: Zeichnung.Linie, _ z: GraphicsContext,
                         _ p: Projektion, _ groesse: CGSize) {
        let punkte = linie.punkte.map {
            p.aufBildschirm(x: $0.x, y: $0.y, groesse: groesse)
        }
        guard punkte.count >= 2 else { return }

        let stil = linie.art.stil
        let farbe = Uhrfarben.fuer(stil.farbe)

        // ETWAS dicker als auf dem Telefon, nicht viel.
        //
        // **Der Aufschlag war 1,2 und ist jetzt 0,3** (Niklas am
        // 25.09.2026, nach dem ersten Blick auf die Uhr: „die linien
        // sind zu dick"). Aus 2,2 bis 2,6 Punkten wurden damit 3,4 bis
        // 3,8 -- und auf vier Zentimetern liegen drei solche Linien
        // nebeneinander wie ein Balken.
        //
        // Das Verhältnis der Arten zueinander bleibt unangetastet:
        // `stil.breite` gibt es vor, die Uhr legt nur einen festen
        // Aufschlag darauf.
        let breite = CGFloat(stil.breite) + AUFSCHLAG

        // **DIE LINIE ENDET AM FUSS DER SPITZE, nicht in ihr.**
        //
        // Sie wird mit rundem Abschluss gezeichnet; läuft sie bis zur
        // Spitze durch, beult der Rundkopf den Pfeil von innen aus --
        // und aus einem Dreieck wird ein Tropfen. Das ist der dritte
        // Grund, aus dem die Pfeile am 25.09.2026 „schwer zu erkennen"
        // waren, und der am schwersten zu sehende.
        //
        // Gekürzt wird nur der letzte Abschnitt und nur bei einem
        // Pfeil: Ein stumpfes Ende und ein Querstrich sollen die ganze
        // Linie behalten.
        let gezeichnet = linie.ende == .arrow
            ? gekuerzt(punkte, um: max(SPITZE_MINDESTENS,
                                       breite * SPITZE_JE_BREITE) * 0.8)
            : punkte
        let weg = Kurve.pfad(gezeichnet, weich: linie.gebogen,
                             geschlossen: linie.istFlaeche)

        if linie.istFlaeche {
            z.fill(weg, with: .color(farbe.opacity(0.22)))
        }
        z.stroke(weg, with: .color(farbe),
                 style: StrokeStyle(lineWidth: breite,
                                    lineCap: .round, lineJoin: .round,
                                    // `map(CGFloat.init)` waere
                                    // mehrdeutig: `CGFloat` hat ein
                                    // Dutzend Initialisierer, und der
                                    // Compiler weiss nicht, welchen.
                                    dash: (stil.strich ?? [])
                                        .map { CGFloat($0) }))

        if let letzter = punkte.last, let vorletzter = punkte.dropLast().last {
            ende(linie, von: vorletzter, nach: letzter, farbe: farbe,
                 breite: breite, z)
        }
        if zeigeNamen, !linie.beschriftung.isEmpty, let letzter = punkte.last {
            z.draw(Text(linie.beschriftung)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Uhrfarben.schrift),
                   at: CGPoint(x: letzter.x, y: letzter.y - 9))
        }
    }

    /// Denselben Weg, aber hinten um `um` Punkte kürzer.
    ///
    /// **Nur der letzte Abschnitt wird angefasst.** Wer den ganzen Weg
    /// skalierte, verschöbe jede Ecke -- und eine Route lebt von ihren
    /// Ecken. Ist der letzte Abschnitt kürzer als der Abzug, bleibt er
    /// wie er ist: Eine Linie, die rückwärts zeigt, wäre schlimmer als
    /// eine ausgebeulte Spitze.
    private func gekuerzt(_ punkte: [CGPoint], um: CGFloat) -> [CGPoint] {
        guard let letzter = punkte.last,
              let vorletzter = punkte.dropLast().last else { return punkte }
        let dx = letzter.x - vorletzter.x
        let dy = letzter.y - vorletzter.y
        let laenge = (dx * dx + dy * dy).squareRoot()
        guard laenge > um else { return punkte }
        let anteil = (laenge - um) / laenge
        return punkte.dropLast() + [CGPoint(x: vorletzter.x + dx * anteil,
                                            y: vorletzter.y + dy * anteil)]
    }

    /// Das Ende eines Weges: Pfeil, Querstrich oder offen.
    ///
    /// Der Unterschied trägt Bedeutung -- ein Block endet stumpf, eine
    /// Route mit einer Spitze, eine Sitzroute mit einem Querstrich. Wer
    /// ihn weglässt, macht aus drei Dingen eins.
    private func ende(_ linie: Zeichnung.Linie, von: CGPoint, nach: CGPoint,
                      farbe: Color, breite: CGFloat, _ z: GraphicsContext) {
        // **DIE SPITZE WÄCHST MIT DER LINIE, sie ist nicht fest.**
        //
        // Hier stand `laenge: CGFloat = 7`. Bei einer Linie von 3,8
        // Punkten ist eine 7 Punkte lange Spitze kaum breiter als die
        // Linie selbst -- dann sieht sie nicht wie ein Pfeil aus,
        // sondern wie ein Klecks am Ende. Niklas am 25.09.2026: „mir
        // werden die pfeile nicht richtig angezeigt. schwer zu
        // erkennen."
        //
        // Das Dreifache der Linienbreite ist die Faustregel, die ein
        // Pfeil braucht, um als Pfeil gelesen zu werden. Die
        // Untergrenze sorgt dafür, dass auch die dünnste Linienart
        // eine sichtbare Spitze bekommt.
        let laenge = max(SPITZE_MINDESTENS, breite * SPITZE_JE_BREITE)
        let winkel = atan2(nach.y - von.y, nach.x - von.x)

        switch linie.ende {
        case .arrow:
            var spitze = Path()
            spitze.move(to: nach)
            spitze.addLine(to: CGPoint(
                x: nach.x - laenge * cos(winkel - .pi / 7),
                y: nach.y - laenge * sin(winkel - .pi / 7)))
            spitze.addLine(to: CGPoint(
                x: nach.x - laenge * cos(winkel + .pi / 7),
                y: nach.y - laenge * sin(winkel + .pi / 7)))
            spitze.closeSubpath()
            z.fill(spitze, with: .color(farbe))
        case .tee:
            let quer = winkel + .pi / 2
            var strich = Path()
            // Genauso lang wie die Pfeilspitze breit ist -- sonst
            // liest sich ein Querstrich neben einem Pfeil wie eine
            // Verdickung und nicht wie ein anderes Ende.
            let halb = laenge * 0.6
            strich.move(to: CGPoint(x: nach.x + halb * cos(quer),
                                    y: nach.y + halb * sin(quer)))
            strich.addLine(to: CGPoint(x: nach.x - halb * cos(quer),
                                       y: nach.y - halb * sin(quer)))
            z.stroke(strich, with: .color(farbe),
                     style: StrokeStyle(lineWidth: breite, lineCap: .round))
        case .none:
            break
        }
    }

    // MARK: - Figuren

    private func zeichne(_ spieler: Zeichnung.Spieler, _ z: GraphicsContext,
                         _ p: Projektion, _ groesse: CGSize,
                         faktor: Double) {
        let mitte = p.aufBildschirm(x: spieler.x, y: spieler.y,
                                    groesse: groesse)
        // DER RADIUS KOMMT AUS DER SPIELFORM, IN YARDS. Sonst stehen im
        // Tackle zwei Kreise ineinander (zwei Linemen stehen 1,33 Yards
        // auseinander) und im Flag sind sie zu klein -- dieselbe Zahl
        // wie auf dem Server. Nach unten begrenzt, weil auf der Uhr
        // sonst ein Punkt übrig bliebe.
        let radius = max(6, Spielform.zu(spielform).figurradius * faktor)
        let kreis = CGRect(x: mitte.x - radius, y: mitte.y - radius,
                           width: radius * 2, height: radius * 2)
        let farbe = Uhrfarben.fuerSpieler(spieler)

        if spieler.seite == .defense {
            // Die Verteidigung ist ein Kreuz, kein Kreis -- dieselbe
            // Unterscheidung wie im Ausdruck.
            var kreuz = Path()
            let r = radius * 0.8
            kreuz.move(to: CGPoint(x: mitte.x - r, y: mitte.y - r))
            kreuz.addLine(to: CGPoint(x: mitte.x + r, y: mitte.y + r))
            kreuz.move(to: CGPoint(x: mitte.x + r, y: mitte.y - r))
            kreuz.addLine(to: CGPoint(x: mitte.x - r, y: mitte.y + r))
            z.stroke(kreuz, with: .color(farbe),
                     style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            return
        }

        z.fill(Path(ellipseIn: kreis), with: .color(farbe))
        z.stroke(Path(ellipseIn: kreis), with: .color(Uhrfarben.rand),
                 lineWidth: 1)
        if !spieler.kuerzel.isEmpty {
            z.draw(Text(spieler.kuerzel)
                    .font(.system(size: max(7, radius), weight: .bold))
                    .foregroundStyle(Uhrfarben.aufFigur),
                   at: mitte)
        }
    }
}
