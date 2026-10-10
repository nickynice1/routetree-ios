// Wie das Ergebnis aussehen wird (R55).
//
// Niklas am 02.09.2026 zum Druckbildschirm von Playmaker X: „Das ist von
// playmaker X das finde ich auch sehr schön vielleicht können wir das
// auch so umsetzen." Auf dem Bild steht an jeder Kachel ein
// Vorschaubild des Ergebnisses.
//
// WAS DARAN WIRKLICH GUT IST, ist nicht die Schrägstellung: Man sieht,
// was herauskommt, BEVOR man es erzeugt. Unsere Druckseite war eine
// Liste aus Namen und Erklärungen -- wer „Wristcoach-Einlage" noch nie
// gesehen hat, wusste nach dem Lesen so viel wie vorher.
//
// WARUM DIE APP NICHT DAS SERVER-SVG HOLT. Sie hat kein WebKit mehr
// (B3); ein SVG liesse sich nicht anzeigen, ohne es wieder
// hereinzuholen. Und sie hat etwas Besseres: denselben Zeichner, der
// auch den Editor malt. Die Anordnung kommt aus denselben Zahlen wie
// auf dem Server (`Druckwahl`), das Diagramm aus `Feldansicht`.
//
// WAS HIER NICHT ENTSCHIEDEN WIRD: wie viele Karten auf eine Seite
// gehen. Das steht in `druck.py` und kommt über `scripts/druck_swift.py`
// herüber. Eine zweite Zahl hier wäre eine Vorschau, die etwas anderes
// verspricht als der Bogen.

import SwiftUI

/// Ein Blatt Papier mit der Anordnung darauf.
struct Druckvorschau: View {
    let art: String
    /// Was auf dem Blatt gezeigt wird. Leer heisst: leeres Heft, und
    /// dann bleibt das Blatt leer -- das ist die ehrliche Auskunft.
    let plays: [Modell.PlayVoll]
    /// Die gewählte Einstellung. Sie ändert die Anordnung, und genau
    /// deshalb gibt es die Vorschau.
    let wahl: Druckwunsch

    /// A4 hoch, sonst quer. Das Verhältnis ist das von A4 (1:1,414).
    private var quer: Bool { art == "callsheet" }

    var body: some View {
        blatt
            .aspectRatio(quer ? 1.414 : 1 / 1.414, contentMode: .fit)
            // IN DER FARBE DER APP UND NICHT WEISS.
            //
            // Auf Papier ist der Bogen hell, im Browser zeigt die
            // Vorschau deshalb ein weisses Blatt. Die App hat EINEN
            // Feldzeichner, und der zeichnet dunkel; ein zweiter in
            // hell wäre eine zweite Wahrheit über dasselbe Feld --
            // genau das, was `Feldansicht` seit B3 vermeidet.
            //
            // Die Vorschau beantwortet ohnehin eine andere Frage: WIE
            // VIELE stehen nebeneinander, und liegt das Blatt hoch
            // oder quer. Dafür ist die Farbe gleichgültig.
            .background(Farben.flaechePanel)
            .overlay(RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Farben.linie, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel(Text("Vorschau: wie die Seite aussehen wird"))
    }

    @ViewBuilder
    private var blatt: some View {
        switch art {
        case "playcards": karten
        case "callsheet": spalten
        case "wristband": einlagen
        default: einzelbild
        }
    }

    // MARK: - Playcards

    /// Karten in einem Raster, so viele wie eingestellt.
    ///
    /// Die Spaltenzahl rechnet `Druckblock.spaltenZahl` aus derselben
    /// Tafel wie der Server (`druck.SPALTEN`).
    private var karten: some View {
        let proSeite = Druckblock.kartenZahl(wahl.proSeite)
        let spaltenzahl = Druckblock.kartenSpalten(proSeite)
        return GeometryReader { rahmen in
            let luft = rahmen.size.width * 0.03
            let breite = (rahmen.size.width - luft * CGFloat(spaltenzahl + 1))
                / CGFloat(spaltenzahl)
            let zeilen = Int((Double(proSeite) / Double(spaltenzahl)).rounded(.up))
            VStack(spacing: luft) {
                ForEach(0..<zeilen, id: \.self) { zeile in
                    HStack(spacing: luft) {
                        ForEach(0..<spaltenzahl, id: \.self) { spalte in
                            let nummer = zeile * spaltenzahl + spalte
                            if nummer < proSeite {
                                kaertchen(nummer).frame(width: breite)
                            } else {
                                Color.clear.frame(width: breite)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(luft)
        }
    }

    private func kaertchen(_ nummer: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(Farben.linie.opacity(0.6), lineWidth: 0.8)
            if nummer < plays.count {
                feld(plays[nummer]).padding(2)
            }
        }
        .aspectRatio(0.9, contentMode: .fit)
    }

    // MARK: - Call Sheet

    /// Ein Call Sheet ist eine LISTE, kein Diagrammbogen.
    ///
    /// Die Striche sind die Zeilen: So sieht man auf einen Blick, dass
    /// dort Namen stehen und keine Bilder. Ein Bogen voller Diagramme
    /// wäre die falsche Erwartung.
    private var spalten: some View {
        let anzahl = Druckblock.spaltenZahl(wahl.spalten)
        return GeometryReader { rahmen in
            HStack(spacing: rahmen.size.width * 0.02) {
                ForEach(0..<anzahl, id: \.self) { _ in
                    VStack(spacing: rahmen.size.height * 0.055) {
                        ForEach(0..<8, id: \.self) { _ in
                            Rectangle()
                                .fill(Farben.linie.opacity(0.55))
                                .frame(height: 1.4)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(rahmen.size.width * 0.015)
                    .overlay(RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Farben.linie.opacity(0.6),
                                      lineWidth: 0.8))
                }
            }
            .padding(rahmen.size.width * 0.03)
        }
    }

    // MARK: - Wristcoach

    /// Die Einlagen im echten Verhältnis, gestrichelt wie die
    /// Schnittkante.
    ///
    /// **JEDE EINSTELLUNG ÄNDERT DAS BILD (R124).** Bis zum 15.09.2026
    /// zeigte diese Vorschau drei feste Striche, ganz gleich was
    /// eingestellt war -- „8 Plays je Einlage" sah aus wie eins, und
    /// „Kleine Diagramme" sah aus wie „Liste". Niklas am 11.09.2026:
    /// „Wenn man unten was verändert sollte sich auch jeweils die
    /// Vorschau Detail getreu mitöndern."
    ///
    /// Das war nicht bloss unschön: Der Kopf dieser Datei sagt, wofür
    /// sie da ist -- man soll sehen, was herauskommt, BEVOR man es
    /// erzeugt. Eine Vorschau, die sich bei drei von fünf Reglern
    /// nicht rührt, beantwortet die Frage nicht, sondern täuscht eine
    /// Antwort vor.
    ///
    /// **Die Reihenfolge ist die des Bogens**: erst alle Abzüge der
    /// ersten Einlage, dann die der zweiten (`printing`: der
    /// Schnittrahmen wird mal `kopien` genommen, Einlage für Einlage).
    private var einlagen: some View {
        let masse = wahl.einlage
        let kopien = Druckblock.kopien(wahl.kopien)
        let teile = Druckblock.einlagenTeilen(plays, jeEinlage: wahl.jeEinlage)
        // Wie viele Zeilen EINE Einlage trägt: die Einstellung, nicht
        // die Zahl der Beispielplays. Sonst zeigte ein Vorrat von neun
        // Plays acht Zeilen nur deshalb, weil es neun sind.
        let proEinlage = Druckblock.jeEinlage(wahl.jeEinlage)
        return GeometryReader { rahmen in
            // 186 Millimeter nutzbare Breite auf A4 -- dieselbe Zahl
            // wie in `printing.playcards_html`.
            let faktor = rahmen.size.width / 186.0
            let breite = masse.breite * faktor
            let hoehe = masse.hoehe * faktor
            let jeZeile = max(1, Int(rahmen.size.width / max(breite + 3, 1)))
            // Alle Abzüge aller Einlagen, in der Reihenfolge des Bogens.
            let abzuege = teile.count * kopien
            let zeilen = Int((Double(abzuege) / Double(jeZeile)).rounded(.up))
            VStack(alignment: .leading, spacing: 3) {
                ForEach(0..<zeilen, id: \.self) { zeile in
                    HStack(spacing: 3) {
                        ForEach(0..<jeZeile, id: \.self) { spalte in
                            let nummer = zeile * jeZeile + spalte
                            if nummer < abzuege {
                                einlage(teile[nummer / kopien],
                                        posten: proEinlage,
                                        breite: breite, hoehe: hoehe)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(6)
        }
    }

    /// Eine Einlage mit dem, was darauf steht.
    ///
    /// ``posten`` ist die EINGESTELLTE Zahl je Einlage; ``teil`` sind
    /// die Beispielplays, die es dafür gibt. Sind es weniger, bleiben
    /// die restlichen Zeilen leer -- die Einlage trägt trotzdem so
    /// viele, wie eingestellt ist, und genau das soll man sehen.
    private func einlage(_ teil: [Modell.PlayVoll], posten: Int,
                         breite: CGFloat, hoehe: CGFloat) -> some View {
        // Null heisst „alle auf eine". Dann steht da, was da ist.
        let zeilen = posten > 0 ? posten : max(teil.count, 1)
        let spalten = Druckblock.einlagenSpalten(
            posten: zeilen, anordnung: wahl.anordnung)
        let jeSpalte = max(1, Int((Double(zeilen) / Double(spalten)).rounded(.up)))
        let diagramme = Druckblock.stil(wahl.stil) == "diagramm"
        return HStack(alignment: .top, spacing: 3) {
            ForEach(0..<spalten, id: \.self) { spalte in
                VStack(spacing: max(1.5, hoehe / CGFloat(jeSpalte * 4))) {
                    ForEach(0..<jeSpalte, id: \.self) { reihe in
                        let nummer = spalte * jeSpalte + reihe
                        if nummer < zeilen {
                            eintrag(teil, nummer: nummer,
                                    diagramm: diagramme,
                                    hoehe: hoehe / CGFloat(jeSpalte))
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(3)
        .frame(width: breite, height: hoehe)
        .overlay(Rectangle()
            .strokeBorder(style: StrokeStyle(lineWidth: 0.8, dash: [3, 2]))
            .foregroundStyle(Farben.linie.opacity(0.7)))
    }

    /// Ein Eintrag auf der Einlage: ein Strich oder ein kleines Feld.
    ///
    /// **Das kleine Feld ist derselbe Zeichner wie im Editor**
    /// (`feld(_:)`). Ein nachgemaltes Kästchen verspräche wieder etwas
    /// anderes als das Ergebnis.
    /// **`eintrag` und nicht `posten`**: `posten` heisst schon die
    /// ZAHL je Einlage, und ein Parameter dieses Namens steht in
    /// `einlage` im Weg. Swift nimmt dann den Parameter, und der
    /// Aufruf liest sich als „rufe die Zahl auf" -- der Bau brach mit
    /// „cannot call value of non-function type 'Int'".
    @ViewBuilder
    private func eintrag(_ teil: [Modell.PlayVoll], nummer: Int,
                         diagramm: Bool, hoehe: CGFloat) -> some View {
        if diagramm {
            if nummer < teil.count {
                feld(teil[nummer])
                    .frame(maxWidth: .infinity)
                    .frame(height: max(4, hoehe * 0.8))
            } else {
                // Ein leerer Platz sieht anders aus als ein Diagramm --
                // sonst liest sich eine halbvolle Einlage wie eine
                // volle.
                Rectangle()
                    .strokeBorder(Farben.linie.opacity(0.35), lineWidth: 0.6)
                    .frame(height: max(4, hoehe * 0.8))
            }
        } else {
            Rectangle()
                .fill(Farben.linie.opacity(nummer < teil.count ? 0.55 : 0.25))
                .frame(height: 1.2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Ein einzelnes Bild

    private var einzelbild: some View {
        Group {
            if let erster = plays.first {
                feld(erster).padding(10)
            } else {
                Color.clear
            }
        }
    }

    /// Ein Play, gezeichnet wie im Editor.
    ///
    /// **Derselbe Zeichner und kein zweiter.** Ein nachgemaltes Bild
    /// verspräche etwas anderes als das Ergebnis -- genau dagegen ist
    /// R55 gerichtet.
    private func feld(_ play: Modell.PlayVoll) -> some View {
        Feldansicht(
            zeichnung: play.zeichnung,
            projektion: Projektion
                .fuerDieApp(feld: play.feld, los: play.los,
                            richtung: play.richtung,
                            spielform: play.spielform)
                .passendFuer(play.zeichnung)
                // DERSELBE AUSSCHNITT WIE AUF DEM PAPIER. Der Ausdruck
                // schneidet quer seit T9 (`querfenster_fuer`); eine
                // Vorschau, die es nicht tut, zeigt etwas anderes als
                // das Ergebnis -- und genau das verspricht sie nicht.
                .querPassendFuer(play.zeichnung),
            // KEINE GRIFFE, KEINE NAMEN: Eine Vorschau zeigt die
            // ANORDNUNG. Routennamen in einer Kachel von zwei
            // Zentimetern wären ein Fleck.
            zeigeNamen: false)
    }
}
