// Das Feld, auf dem der Finger arbeitet.
//
// WARUM ES DAS ALS EIGENE ANSICHT GIBT (R46). Bis zum 02.09.2026 stand
// die ganze Fingerbehandlung im `EditorAnsicht`: eine Geste, die einen
// Spieler zieht, einen Stützpunkt zieht oder einen Punkt setzt, und
// dazu vier Zustandswerte, die sich merken, was gerade am Finger hängt.
//
// Für den Formationen-Builder (R46) wird genau dasselbe gebraucht --
// Figuren schieben, sonst nichts. Ihn danebenzuschreiben hiesse, die
// heikelste Stelle der App ein zweites Mal zu haben: Wer den Fang
// ändert, den Griffvorrang oder die Seitenregel, ändert dann eine von
// zwei Fassungen, und welche der Trainer gerade sieht, hängt davon ab,
// welchen Bildschirm er offen hat.
//
// DER CODE IST UMGEZOGEN, NICHT NEU GESCHRIEBEN. Er steht hier Zeile
// für Zeile so, wie er im Editor stand, samt seiner Begründungen. Ein
// Umzug lässt sich nachlesen, eine Neufassung muss man glauben.
//
// WAS HIER NICHT ENTSCHIEDEN WIRD: was ein Tipp bedeutet. Das steht in
// `Zeichenblock` und ist dort gemessen, ohne dass ein Mac dafür nötig
// wäre.

import SwiftUI

struct Zeichenfeld: View {

    @Binding var block: Zeichenblock
    /// Wie gross die Fläche ist -- nach draussen gemeldet.
    ///
    /// **Warum das hinaus muss.** Wer den Block AUSTAUSCHT (nach dem
    /// Laden, nach dem Übernehmen einer fremden Fassung), muss ihm die
    /// Grösse neu geben: Die Fläche selbst hat sich dabei nicht
    /// geändert, also meldet sich `onChange` nicht mehr, und das Feld
    /// sässe wieder klein in der Mitte. Genau diese Zeile steht im
    /// Editor an zwei Stellen, und ohne diese Bindung wüsste er die
    /// Zahl nicht mehr.
    @Binding var flaeche: CGSize
    /// Ob der Finger überhaupt etwas bewirkt. Am gesperrten Play (R6)
    /// und in der Zuschauerrolle nicht.
    let darfZeichnen: Bool
    /// Ob die Routennamen an den Linien stehen (R25).
    var zeigeNamen: Bool = true
    /// Der laufende Ablauf, falls einer läuft. Während des Abspielens
    /// wird nicht gezeichnet: Ein Fingertipp mitten hinein setzte einen
    /// Punkt an eine Stelle, an der gerade eine Figur vorbeiläuft.
    var ablauf: Ablauf?

    // Was gerade am Finger hängt. Vier Werte, weil ein Zug entweder
    // eine Figur ODER einen Stützpunkt bewegt und beide ihren
    // Ausgangspunkt brauchen.
    @State private var angefasst: String?
    @State private var beginn: (x: Double, y: Double)?
    @State private var griffAngefasst: Zeichenblock.Griffstelle?
    @State private var griffBeginn: (x: Double, y: Double)?
    /// Die Zonenflaeche unter dem Finger, solange er liegt.
    @State private var flaecheAngefasst: Int?
    /// Der Zoom, als das Kneifen anfing (R110.6). SwiftUI meldet den
    /// Faktor seit dem Beginn der Geste, nicht seit dem letzten Bild.
    @State private var zoomBeimAnfassen: Double?
    /// Wie weit der Zweifingerzug bisher lief. Gerechnet wird der
    /// Zuwachs -- sonst springt das Bild bei jedem Bild um die gesamte
    /// bisherige Strecke weiter.
    @State private var schiebeStand: CGSize?

    var body: some View {
        GeometryReader { rahmen in
            Feldansicht(zeichnung: block.zeichnung,
                        projektion: block.projektion,
                        hervorgehoben: angefasst
                            ?? block.ausgewaehlterSpieler?.id,
                        entwurf: block.entwurf,
                        zeiger: block.zeiger,
                        ausgewaehlt: block.ausgewaehlteStelle,
                        zeigeNamen: zeigeNamen,
                        // Die Griffe der ausgewählten Linie (R11). Beim
                        // Abspielen keine: Wer zusieht, zieht nichts,
                        // und fünf Kreise auf der Route wären dann nur
                        // im Weg.
                        griffe: ablauf == nil ? block.griffe : [],
                        griffAnker: ablauf == nil && !block.istGriff(0),
                        griffAmFinger: griffAngefasst?.punkt,
                        marken: ablauf?.marken ?? [],
                        laufende: ablauf?.plan.laufendeSpieler ?? [])
                .contentShape(Rectangle())
                // DER FINGER ZEICHNET NUR, WENN ER DARF (R6/R46).
                //
                // **Bis R110.6 hing das an `.allowsHitTesting`**, und
                // seit es Zoom gibt, geht das nicht mehr: Die Flaeche
                // muss auch beim Abspielen und ohne Zeichenrecht auf
                // Finger reagieren, sonst kommt ein Zuschauer nicht
                // mehr nah an eine Route heran. `allowsHitTesting`
                // haette BEIDE Gesten abgeschaltet -- und `true` (so
                // stand es zwischenzeitlich hier) schaltete am
                // gesperrten Play das Zeichnen wieder an.
                //
                // Die Maske trennt beides: DIESE Geste ist aus, die
                // Ausschnittgeste unten bleibt.
                .gesture(finger(in: rahmen.size),
                         including: ablauf == nil && darfZeichnen
                             ? .all : .subviews)
                // ZOOM UND AUSSCHNITT (R110.6).
                //
                // `simultaneousGesture` und nicht `.gesture`: Sonst
                // streiten sich Kneifen und Zeichnen um denselben
                // Finger, und SwiftUI entscheidet das nicht
                // zuverlaessig zugunsten der gemeinten. Nebeneinander
                // ist es eindeutig -- ein Finger zeichnet, zwei
                // schieben das Bild.
                //
                // AUCH BEIM ABSPIELEN UND OHNE ZEICHENRECHT. Wer
                // zusieht, will genauso nah heran -- und wer nur den
                // Ausschnitt verstellt, aendert nichts am Play.
                .simultaneousGesture(ausschnittgeste(in: rahmen.size))
                // DAS FELD FÜLLT DIE FLÄCHE (Niklas, 01.09.2026). Der
                // Block bekommt die Größe, nicht die Ansicht: Nur so
                // meinen Zeichnung und Finger denselben Ausschnitt.
                .onChange(of: rahmen.size, initial: true) { _, neu in
                    flaeche = neu
                    block.flaecheSetzen(neu)
                }
        }
    }

    // MARK: - Der Ausschnitt (R110.6)

    /// Kneifen und Schieben.
    ///
    /// **Zwei Finger, nicht einer.** Ein Finger gehört dem Zeichnen;
    /// ihn hier mitzunehmen hiesse, dass jeder Strich auch das Bild
    /// verschiebt. Zwei Finger sind auf einem Telefon die Geste, die
    /// jeder für „näher heran" hält.
    ///
    /// **Und es gibt einen sichtbaren Weg zurück** (B1): Der Knopf in
    /// der Leiste setzt den Ausschnitt zurück. Eine Geste, die man nur
    /// mit einer Geste rückgängig machen kann, ist eine Sackgasse für
    /// jeden, der die zweite nicht kennt.
    private func ausschnittgeste(in groesse: CGSize) -> some Gesture {
        SimultaneousGesture(
            // `MagnifyGesture` und nicht `MagnificationGesture`: Nur
            // sie nennt die STELLE, an der gekniffen wird
            // (`startLocation`). Ohne die zoomt das Bild um seine
            // Mitte, und wer auf eine Ecke zoomt, schiebt sie damit aus
            // dem Bild -- und sucht sie danach wieder. Seit iOS 17 da,
            // und dorthin geht diese App ohnehin (`deploymentTarget`).
            MagnifyGesture()
                .onChanged { wert in
                    let vorher = zoomBeimAnfassen ?? block.projektion.zoom
                    if zoomBeimAnfassen == nil { zoomBeimAnfassen = vorher }
                    block.zoomSetzen(vorher * Double(wert.magnification),
                                     um: wert.startLocation,
                                     groesse: groesse)
                }
                .onEnded { _ in zoomBeimAnfassen = nil },
            DragGesture(minimumDistance: 8)
                .onChanged { bewegung in
                    // GEMESSEN WIRD DER ZUWACHS und nicht der ganze
                    // Weg: Sonst springt das Bild bei jedem Bild um die
                    // gesamte bisherige Strecke weiter.
                    let vorher = schiebeStand ?? .zero
                    block.verschieben(
                        um: CGSize(
                            width: bewegung.translation.width - vorher.width,
                            height: bewegung.translation.height - vorher.height),
                        groesse: groesse)
                    schiebeStand = bewegung.translation
                }
                .onEnded { _ in schiebeStand = nil })
    }

    // MARK: - Der Finger

    /// EINE Geste für beides.
    ///
    /// Im Auswahl-Werkzeug zieht sie einen Spieler, mit einem
    /// Zeichenwerkzeug setzt sie beim Loslassen einen Punkt und zeigt
    /// vorher, wohin er fällt. Zwei getrennte Gesten würden sich um
    /// denselben Finger streiten, und SwiftUI entscheidet das nicht
    /// zuverlässig zugunsten der gemeinten.
    private func finger(in groesse: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { bewegung in
                switch block.werkzeug {
                case .auswahl:
                    ziehen(bewegung, in: groesse)
                case .linie:
                    // ZIEHEN AUF EINER FIGUR VERSCHIEBT SIE (R93), auch
                    // wenn das Zeichenwerkzeug an ist.
                    //
                    // Niklas am 09.09.2026: „Wenn man innerhalb des
                    // Kreises des Spielers drückt und schiebt obwohl man
                    // auf Route ist das man den verschieben kann nur
                    // wenn man außerhalb des spielerkreises tippt wird
                    // ne Route gemacht, checkst du?"
                    //
                    // Er hat recht, und es ist die Bewegung, die man
                    // beim Zeichnen dauernd braucht: Aufstellung
                    // hinschieben, Weg ziehen, nächste Figur. Vorher
                    // hiess das dreimal Werkzeug wechseln.
                    //
                    // TIPPEN BLEIBT ZEICHNEN. Erst ab einer knappen
                    // Fingerbreite Weg gilt es als Zug; darunter ist es
                    // ein Tipp, und der beginnt wie bisher die Linie
                    // bei dieser Figur.
                    if angefasst != nil || istFigurenzug(bewegung, in: groesse) {
                        ziehen(bewegung, in: groesse, nurFiguren: true)
                    } else {
                        block.zeigen(bewegung.location, groesse: groesse)
                    }
                }
            }
            .onEnded { bewegung in
                switch block.werkzeug {
                case .auswahl:
                    if angefasst == nil && griffAngefasst == nil
                        && flaecheAngefasst == nil {
                        // Nicht gezogen, sondern getippt: Das wählt aus.
                        spur("editor", "feld_tipp")
                        block.tippen(bewegung.startLocation, groesse: groesse)
                    }
                    // Der Zug ist zu Ende. Der nächste ist ein neuer
                    // Schritt im Verlauf und nicht die Fortsetzung
                    // dieses einen.
                    block.loslassen()
                    angefasst = nil
                    beginn = nil
                    griffAngefasst = nil
                    griffBeginn = nil
                    flaecheAngefasst = nil
                case .linie:
                    // War es ein Zug auf einer Figur, ist er hier zu
                    // Ende -- und es entsteht KEIN Punkt. Sonst läge am
                    // Ende jedes Verschiebens ein Wegpunkt.
                    if angefasst != nil {
                        block.loslassen()
                        angefasst = nil
                        beginn = nil
                        return
                    }
                    spur("editor", "punkt", block.werkzeug.spurname)
                    block.tippen(bewegung.location, groesse: groesse)
                }
            }
    }

    /// Ab wie viel Weg ein Zug ein Zug ist und kein Tipp.
    ///
    /// Zehn Punkte sind knapp unter der Fingerbreite, mit der Apple
    /// rechnet (44 Punkte Trefferfläche). Weniger, und ein Tipp mit
    /// leicht wackelnder Hand verschöbe die Figur um einen halben Yard;
    /// mehr, und das Verschieben fühlt sich klebrig an.
    private static let zugAb: CGFloat = 10

    /// Fasst dieser Zug eine Figur an, obwohl ein Zeichenwerkzeug an
    /// ist? (R93)
    ///
    /// **Nicht, solange eine Linie im Entstehen ist.** Wer mitten im
    /// Zeichnen die Figur verschöbe, an der die Linie hängt, bekäme
    /// einen ersten Punkt, der neben ihr liegt -- die angefangene Linie
    /// steht noch nicht in der Zeichnung und wird deshalb nicht
    /// mitgenommen.
    private func istFigurenzug(_ bewegung: DragGesture.Value,
                               in groesse: CGSize) -> Bool {
        guard block.entwurf == nil else { return false }
        let dx = bewegung.translation.width
        let dy = bewegung.translation.height
        guard dx * dx + dy * dy > Zeichenfeld.zugAb * Zeichenfeld.zugAb else {
            return false
        }
        return block.spielerBei(bewegung.startLocation,
                                groesse: groesse) != nil
    }

    /// ``nurFiguren`` lässt Stützpunkte und Zonenflächen aus. Mit einem
    /// Zeichenwerkzeug in der Hand meint ein Zug auf einer Figur genau
    /// sie -- ein Griff, der zufällig darunter liegt, wäre eine
    /// Überraschung.
    private func ziehen(_ bewegung: DragGesture.Value, in groesse: CGSize,
                        nurFiguren: Bool = false) {
        // ZUERST DER STÜTZPUNKT (R11), dann die Figur. Ein Griff liegt
        // oft dicht neben der Figur, an der seine Linie hängt; käme die
        // Figur zuerst, ließe sich der erste Knick einer Route nie
        // anfassen -- man verschöbe statt dessen den Spieler.
        if !nurFiguren, angefasst == nil, griffAngefasst == nil,
           let treffer = block.griffBei(bewegung.startLocation,
                                        groesse: groesse) {
            let punkt = block.zeichnung.linien[treffer.linie]
                .punkte[treffer.punkt]
            griffAngefasst = treffer
            griffBeginn = (punkt.x, punkt.y)
            block.griffAnfassen(treffer)
        }
        if let stelle = griffAngefasst, let start = griffBeginn {
            let (von, nach) = wegInYards(bewegung, in: groesse)
            // OHNE SEITENREGEL: Eine Route DARF über die Line of
            // Scrimmage -- dafür ist sie da. Nur Figuren bleiben auf
            // ihrer Seite (R1).
            let gefangen = block.fangen(x: start.x + (nach.x - von.x),
                                        y: start.y + (nach.y - von.y))
            block.griffVerschieben(stelle, x: gefangen.x, y: gefangen.y)
            return
        }

        // DANN DIE ZONENFLAECHE, und zwar VOR der Figur. Wer in eine
        // Zone hineinfasst, meint die Zone -- auch wenn zufaellig ein
        // Verteidiger darin steht. Die Figur bleibt ueber ihren eigenen
        // Treffer erreichbar, solange sie nicht in einer Flaeche liegt.
        if !nurFiguren, angefasst == nil, flaecheAngefasst == nil,
           let stelle = block.zonenflaecheBei(bewegung.startLocation,
                                              groesse: groesse) {
            flaecheAngefasst = stelle
            block.zugBeginnen()
        }
        if let stelle = flaecheAngefasst {
            let (von, nach) = wegInYards(bewegung, in: groesse)
            block.linieVerschieben(stelle, dx: nach.x - von.x,
                                   dy: nach.y - von.y)
            return
        }

        if angefasst == nil {
            guard let treffer = block.spielerBei(bewegung.startLocation,
                                                 groesse: groesse) else {
                return
            }
            angefasst = treffer.id
            beginn = (treffer.x, treffer.y)
            block.anfassen(treffer.id)
        }
        guard let kennung = angefasst, let start = beginn else { return }

        let (von, nach) = wegInYards(bewegung, in: groesse)
        // MIT SEITE: Ein Spieler bleibt auf seiner Seite der LOS. Bis
        // zum 25.08.2026 begrenzte der Fang nur auf das Feld, und man
        // konnte einen Receiver quer durch die Verteidigung ziehen.
        let seite = block.zeichnung.spieler
            .first { $0.id == kennung }?.seite ?? .offense
        // ÜBER DEN BLOCK und nicht über die Projektion: Seit R5 lässt
        // sich der Fang abschalten, und das muss auch für die Figuren
        // gelten. Ginge es hier direkt an `Projektion.fangen`, rastete
        // die Aufstellung weiter ein, während der Knopf „aus" sagt.
        let gefangen = block.fangen(x: start.x + (nach.x - von.x),
                                    y: start.y + (nach.y - von.y),
                                    seite: seite)
        block.verschiebe(kennung, x: gefangen.x, y: gefangen.y)
    }

    /// Anfang und Ende eines Zuges in Yards.
    ///
    /// Gerechnet wird die VERSCHIEBUNG und nicht die Fingerposition:
    /// Sonst springt das Angefasste beim Aufsetzen unter den Finger, und
    /// wer es am Rand greift, kann es nicht mehr genau setzen. Gilt für
    /// Figuren wie für Stützpunkte, deshalb steht es einmal hier.
    private func wegInYards(_ bewegung: DragGesture.Value, in groesse: CGSize)
        -> (von: (x: Double, y: Double), nach: (x: Double, y: Double)) {
        (block.projektion.vomBildschirm(bewegung.startLocation,
                                        groesse: groesse),
         block.projektion.vomBildschirm(bewegung.location, groesse: groesse))
    }
}
