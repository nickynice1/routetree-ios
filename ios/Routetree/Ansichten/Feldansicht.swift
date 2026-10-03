// Das Spielfeld, nativ gezeichnet.
//
// KEIN WEBVIEW. Was der Browser als SVG ausgibt, entsteht hier mit
// `Canvas` -- aus denselben Yards, über dieselbe Projektion. Der Grund
// ist nicht Sturheit: Ein WebView kennt keine Fingergesten, die man
// einzeln abfangen kann, kein Rückgängig und kein Offline. Der Editor
// wäre damit eine Webseite in einem Rahmen, und genau das war die
// Beschwerde.
//
// Die Markierungen folgen `render.build_field` in Python: Torlinien,
// Fünf-Yard-Linien, Yardzahlen, Hashmarks, die Line of Scrimmage -- und,
// WO ES SIE GIBT, die No-Run-Zonen, die Rushlinie und die Line to Gain.
//
// Der Zusatz „wo es sie gibt" stand hier bis zum 07.09.2026 nicht, und
// „die Rushlinie sieben Yards davor" auch nicht: Sieben Yards gelten
// nur im Flag, No-Run-Zonen gibt es in fünf von sieben Formen nicht,
// und die Mitte ist nur dort die Line to Gain, wo keine Kette läuft.
// Ein Kommentar, der eine Flagregel als die Regel ausgibt, ist die
// Anleitung für den nächsten Fehler.

import SwiftUI

/// Zeichnet Feldmarkierungen, Spieler und Linien einer Zeichnung.
///
/// Nur Darstellung: Was angefasst wird, entscheidet der Editor. Diese
/// Ansicht bekommt fertige Daten und gibt nichts zurück -- so lässt sie
/// sich auch dort verwenden, wo niemand zeichnen darf (Spieleransicht,
/// Übungsmodus).
struct Feldansicht: View {

    let zeichnung: Zeichnung
    let projektion: Projektion
    /// Der gerade angefasste Spieler, damit der Editor ihn hervorheben
    /// kann. `nil` heißt: keiner.
    var hervorgehoben: String?
    /// Die angefangene Linie. Sie gehört nicht zur Zeichnung und wird
    /// deshalb auch anders gezeichnet: mit sichtbaren Ecken, damit man
    /// sieht, was man gesetzt hat.
    var entwurf: Zeichnung.Linie?
    /// Wo der Punkt landet, wenn der Finger jetzt losließe.
    var zeiger: Zeichnung.Punkt?
    /// Die ausgewählte Linie, als Stelle in `zeichnung.linien`.
    var ausgewaehlt: Int?
    /// Ob die Routennamen an den Linien stehen (R25).
    ///
    /// Niklas am 26.08.2026: „ich finde man sollte togglen können ob
    /// der routenname mit angezeigt wird." Vorgabe `true`, damit jede
    /// Ansicht, die nichts dazu sagt, sie zeigt -- der Ausdruck tut es
    /// ohnehin, und zwei Voreinstellungen über dieselbe Sache wären
    /// eine zu viel.
    var zeigeNamen: Bool = true
    /// Die Stützpunkte der ausgewählten Linie, als anfassbare Griffe
    /// (R11). Leer heißt: keine -- etwa beim Abspielen oder in der
    /// Spieleransicht, wo niemand zeichnen darf.
    var griffe: [Zeichnung.Punkt] = []
    /// Ob der erste Griff ein ANKER ist: Der Anfang einer Positionslinie
    /// liegt auf der Figur und lässt sich nicht einzeln ziehen. Er wird
    /// deshalb anders gezeichnet -- ein Punkt, an dem man zieht und der
    /// sich nie bewegt, lässt das ganze Werkzeug kaputt aussehen.
    var griffAnker: Bool = false
    /// Welcher Griff gerade am Finger hängt. Er wird größer gezeichnet:
    /// Unter einer Fingerkuppe sieht man den Punkt selbst nicht.
    var griffAmFinger: Int?
    /// Plays, die der Spieler aufbekommen hat, markiert der Editor
    /// woanders -- hier geht es nur um die Zeichnung.
    var zeigeZonen: Bool = true
    /// Die mitlaufenden Figuren beim Abspielen (B5). Leer heißt: Standbild.
    var marken: [Laufplan.Marke] = []
    /// Wer gerade mitläuft. Sein Standbild tritt zurück, sonst stünde
    /// dieselbe Figur zweimal auf dem Feld.
    var laufende: Set<String> = []

    var body: some View {
        Canvas { grund, groesse in
            let (faktor, versatz) = projektion.aufFlaeche(groesse)
            let auf = { (x: Double, y: Double) -> CGPoint in
                let p = projektion.zuBild(x: x, y: y)
                return CGPoint(x: Double(p.x) * faktor + Double(versatz.x),
                               y: Double(p.y) * faktor + Double(versatz.y))
            }
            zeichneFeld(grund, auf: auf, faktor: faktor)
            zeichneLinien(grund, auf: auf, faktor: faktor)
            zeichneEntwurf(grund, auf: auf, faktor: faktor)
            zeichneSpieler(grund, auf: auf, faktor: faktor)
            // NACH den Figuren: Ein Griff liegt oft auf einer Figur, und
            // wer ihn treffen soll, muss ihn sehen.
            zeichneGriffe(grund, auf: auf)
            zeichneMarken(grund, auf: auf, faktor: faktor)
        }
        // FLACH, und das mit Absicht. Ueberall sonst liegt seit dem
        // 27.08.2026 `Grundflaeche()` mit den drei Lichtquellen aus
        // `app.css` -- hier nicht: Hinter einem Spielfeld hat kein
        // Farbverlauf etwas zu suchen. Die Linien sind eine Zeichnung,
        // und eine Zeichnung braucht einen ruhigen Grund. Im Web ist es
        // genauso: Die Lichtquellen liegen unter der Seite, nicht unter
        // der Zeichenflaeche.
        .background(Farben.flaeche)
        .accessibilityLabel(beschreibung)
    }

    /// Für den Vorleser. Ein Feld aus Strichen ist für ihn sonst nichts.
    private var beschreibung: String {
        let offense = zeichnung.anzahl(.offense)
        let defense = zeichnung.anzahl(.defense)
        var text = String(localized: "Spielfeld, \(offense) in der Offense")
        if defense > 0 {
            text += String(localized: ", \(defense) in der Defense")
        }
        let mitWeg = zeichnung.linien.filter { $0.spieler != nil }.count
        if mitWeg > 0 {
            text += String(localized: ", \(mitWeg) Laufwege")
        }
        if let entwurf {
            text += String(localized: """
                , angefangen: \(entwurf.art.stil.lang) mit \
                \(entwurf.punkte.count) Punkten
                """)
        }
        return text
    }

    // MARK: - Die Markierungen

    private func zeichneFeld(_ grund: GraphicsContext,
                             auf: (Double, Double) -> CGPoint,
                             faktor: Double) {
        let feld = projektion.feld
        let links = auf(projektion.los, feld.breite)
        let rechts = auf(projektion.los, 0)
        let breiteX = min(links.x, rechts.x)
        let breite = abs(rechts.x - links.x)

        // Der Rasen. Sehr ruhig, damit die Zeichnung trägt.
        let obenY = Double(projektion.vorwaerts(projektion.vorne)) * faktor
                    + rand(auf: auf)
        let untenY = Double(projektion.vorwaerts(-projektion.hinten)) * faktor
                     + rand(auf: auf)
        let rasen = CGRect(x: breiteX, y: obenY,
                           width: breite, height: untenY - obenY)
        grund.fill(Path(rasen), with: .color(Farben.flaechePanel))

        // No-Run-Zonen zuerst: Sie liegen unter den Linien.
        if zeigeZonen {
            for (vonYard, bisYard) in [
                (feld.torlinieLinks, feld.keinLaufLinks),
                (feld.keinLaufRechts, feld.torlinieRechts),
            ] {
                let a = auf(vonYard, 0).y
                let b = auf(bisYard, 0).y
                let kasten = CGRect(x: breiteX, y: min(a, b),
                                    width: breite, height: abs(b - a))
                    .intersection(rasen)
                guard !kasten.isNull, kasten.height > 0.5 else { continue }
                grund.fill(Path(kasten), with: .color(Zeichen.tief.opacity(0.55)))
            }
        }

        // Yard-Linien. Gerechnet in echten Feldkoordinaten, nicht relativ
        // zur LOS: Sonst wanderten sie mit, und die Zeichnung stünde auf
        // einem Feld, das es nicht gibt.
        // DIE SPANNE GILT NUR FÜR RICHTUNG +1, und deshalb stand hier
        // ein Fehler. Bei Richtung -1 liegt das sichtbare Fenster auf
        // der anderen Seite der Line of Scrimmage; die Schleife suchte
        // an der falschen Stelle, und von den Linien 10, 15 und 20
        // Yards VOR ihr wurde keine gezeichnet. Genau der Bereich, in
        // den die Routen laufen.
        //
        // Ein Feld mit weniger Linien sieht immer noch aus wie ein
        // Feld; man merkt es erst beim Zählen. Aufgefallen ist es beim
        // Umbau für Tackle (T6), in `render.py`, `editor.js` und hier.
        //
        // DIE STELLEN WERDEN GERECHNET, NICHT ABGEZÄHLT. Vorher lief
        // hier eine Schleife über ganze Yards, und die konnte auf einem
        // in Metern gesteckten Feld (5er-Tackle: Torlinie bei 10,94
        // Yards) weder die Torlinie noch die Mitte treffen -- dieses
        // Feld hätte beides gar nicht gehabt.
        //
        // Gefiltert wird über das FENSTER und nicht über die
        // Schleifengrenze. Auch das war ein Fehler: Bei Richtung -1
        // liegt das sichtbare Fenster auf der anderen Seite der Line of
        // Scrimmage, und von den Linien 10, 15 und 20 Yards VOR ihr
        // wurde keine gezeichnet. Genau der Bereich, in den die Routen
        // laufen. Dieselbe Rechnung wie in `render.py` und `editor.js`.
        var stellen: [Double] = [feld.torlinieLinks, feld.torlinieRechts,
                                 feld.mitte]
        var schritt = 0.0
        while schritt <= feld.spielLaenge {
            stellen.append(feld.torlinieLinks + schritt)
            schritt += 5
        }
        for yard in stellen.sorted() {
            let vorwaerts = (yard - projektion.los)
                            * Double(projektion.richtung)
            guard vorwaerts >= -projektion.hinten,
                  vorwaerts <= projektion.vorne else { continue }

            let istTor = abs(yard - feld.torlinieLinks) < 0.01
                         || abs(yard - feld.torlinieRechts) < 0.01
            let istMitte = abs(yard - feld.mitte) < 0.01
            // IN DER ENDZONE STEHT KEINE YARD-LINIE (R35). Cyell am
            // 01.09.2026: „wieso hat die end Zone eine yard Markierung".
            // Auf einem echten Platz ist die Endzone leer.
            let inEndzone = yard < feld.torlinieLinks - 0.01
                            || yard > feld.torlinieRechts + 0.01
            guard istTor || istMitte || !inEndzone else { continue }

            let y = auf(yard, 0).y
            var pfad = Path()
            pfad.move(to: CGPoint(x: breiteX, y: y))
            pfad.addLine(to: CGPoint(x: breiteX + breite, y: y))
            // DIE MITTE IST NICHT ÜBERALL DIE LINE TO GAIN (Audit
            // 07.09.2026). In fünf von sieben Formen läuft eine Kette,
            // und die Mittellinie ist dann einfach die 50 -- ein Strich
            // wie jeder andere. Die App hob sie trotzdem in der
            // Akzentfarbe und 60 Prozent dicker hervor: eine Aussage
            // über eine Regel, die dort nicht gilt.
            let mitteZaehlt = istMitte && projektion.form.mitteIstLineToGain
            let farbe = istTor ? Farben.inkStill
                : (mitteZaehlt ? Farben.akzent.opacity(0.7) : Farben.linie)
            grund.stroke(pfad, with: .color(farbe),
                         lineWidth: istTor || mitteZaehlt ? 1.6 : 1)
        }

        // HASHMARKS (T8). Zwei Reihen kurzer Striche an jeder Yardlinie.
        // Ohne sie gibt es keinen Ort für den Ball außer der Mitte, und
        // der halbe Sinn einer Formation (Feldseite gegen Randseite)
        // fällt weg.
        if let links = feld.hashLinks, let rechts = feld.hashRechts {
            let laenge = 0.6 * faktor * Projektion.einheitenJeYard
            var hs = 0.0
            while hs <= feld.spielLaenge {
                let yard = feld.torlinieLinks + hs
                hs += 1
                let vorwaerts = (yard - projektion.los)
                                * Double(projektion.richtung)
                guard vorwaerts >= -projektion.hinten,
                      vorwaerts <= projektion.vorne else { continue }
                let y = auf(yard, 0).y
                for quer in [links, rechts] {
                    // Ausdrücklich als CGFloat: In diesem Ausdruck
                    // treffen `CGPoint.x` und eine gerechnete Länge
                    // aufeinander, und ein gemischter Ausdruck hängt
                    // davon ab, dass CGFloat und Double sich stillschweigend
                    // ineinander umwandeln lassen. Das tun sie auf
                    // 64 Bit, aber „hängt davon ab" ist kein guter Grund.
                    let x = auf(yard, quer).x
                    let halbe = CGFloat(laenge) / 2
                    var pfad = Path()
                    pfad.move(to: CGPoint(x: x - halbe, y: y))
                    pfad.addLine(to: CGPoint(x: x + halbe, y: y))
                    grund.stroke(pfad, with: .color(Farben.linie),
                                 lineWidth: 1)
                }
            }
        }

        // YARDZAHLEN (Audit 07.09.2026). Sie fehlten der App ganz --
        // und ausgerechnet dort, wo sie gebraucht werden: „Auf hundert
        // Yards Laenge sieht ein Strich aus wie der naechste; auf
        // fuenfzig ging es ohne", steht seit T6 im Server. Auf dem
        // Ausdruck stand, wo man ist, auf dem Telefon nicht -- und am
        // Spielfeldrand hat man das Telefon.
        //
        // Dieselben drei Bedingungen wie in `render.build_field`, samt
        // der wichtigsten: Auf dem in Metern gesteckten 5er-Feld liegt
        // kein Zehn-Yard-Raster, und eine „9" an der Torlinie stünde
        // auf keinem Platz.
        let zahlenZeichnen = feld.spielLaenge > 60
            && feld.spielLaenge == feld.spielLaenge.rounded()
            && feld.torlinieLinks == feld.torlinieLinks.rounded()
            && feld.breite > 3 * Feldansicht.zahlenVomRand
        if zahlenZeichnen {
            var schritt = 10.0
            while schritt < feld.spielLaenge {
                let yard = feld.torlinieLinks + schritt
                let vorwaerts = (yard - projektion.los)
                                * Double(projektion.richtung)
                let zahl = Int(min(schritt, feld.spielLaenge - schritt))
                schritt += 10
                guard zahl > 0,
                      vorwaerts >= -projektion.hinten,
                      vorwaerts <= projektion.vorne else { continue }
                // GRÖSSE AUS DEM MASSSTAB, wie alles andere hier: Eine
                // feste Punktzahl wäre in einer Vorschaukachel ein
                // Balken quer über dem Play.
                let hoehe = 1.1 * faktor * Projektion.einheitenJeYard
                guard hoehe >= 5 else { continue }
                for quer in [Feldansicht.zahlenVomRand,
                             feld.breite - Feldansicht.zahlenVomRand] {
                    grund.draw(
                        Text(String(zahl))
                            .font(.system(size: hoehe, weight: .bold))
                            .foregroundColor(Farben.linie),
                        at: auf(yard, quer))
                }
            }
        }

        // Line of Scrimmage: die eine Linie, auf die es ankommt.
        let losY = auf(projektion.los, 0).y
        var los = Path()
        los.move(to: CGPoint(x: breiteX, y: losY))
        los.addLine(to: CGPoint(x: breiteX + breite, y: losY))
        grund.stroke(los, with: .color(Farben.ink), lineWidth: 2)

        // Rushlinie, so weit dahinter, wie die Spielform sagt.
        // Gestrichelt: Sie ist eine Regel, keine Markierung auf dem
        // Rasen. („Sieben Yards" stand hier fest -- das gilt nur im
        // Flag.)
        // NUR WO ES EINE GIBT. Im Tackle ist `rush` null, und die alte
        // Bedingung war damit immer wahr: Es entstand eine zweite Linie
        // genau auf der Line of Scrimmage. Dieselbe Stelle wie in
        // `render.py` und `editor.js`.
        let rush = Double(feld.rush)
        if rush > 0, rush <= projektion.vorne {
            let y = Double(projektion.vorwaerts(rush)) * faktor
                    + rand(auf: auf)
            var pfad = Path()
            pfad.move(to: CGPoint(x: breiteX, y: y))
            pfad.addLine(to: CGPoint(x: breiteX + breite, y: y))
            grund.stroke(pfad, with: .color(Farben.fehler.opacity(0.75)),
                         style: StrokeStyle(lineWidth: 1.4,
                                            dash: [6, 5]))
        }

        // DIE KETTE (08.09.2026). Wo eine läuft, ist sie die Linie, auf
        // die es ankommt: Der Play muss sie erreichen, sonst war er
        // umsonst. Sie fehlte in allen drei Zeichnern -- im Flag gibt
        // es keine, und solange es nur Flag gab, ist niemandem
        // aufgefallen, dass ein Zeichner ohne Kette auskommt.
        //
        // Gold statt Rot, damit sie sich von der Rushlinie
        // unterscheidet. Beide zusammen gibt es nie: Wo gerusht wird,
        // läuft keine Kette.
        //
        // Ohne Beschriftung, und das ist keine Auslassung: Diese
        // Ansicht schreibt überhaupt keine Feldtexte (siehe
        // `Projektion.fuerDieApp` -- der Streifen dafür ist bewusst
        // weg). Die Zahl steht im Editor über der Werkzeugleiste.
        let kette = projektion.form.kette
        if kette > 0, kette <= projektion.vorne {
            let y = Double(projektion.vorwaerts(kette)) * faktor
                    + rand(auf: auf)
            var pfad = Path()
            pfad.move(to: CGPoint(x: breiteX, y: y))
            pfad.addLine(to: CGPoint(x: breiteX + breite, y: y))
            grund.stroke(pfad, with: .color(Farben.akzent.opacity(0.8)),
                         style: StrokeStyle(lineWidth: 1.4, dash: [7, 5]))
        }

        // Seitenlinien.
        grund.stroke(Path(rasen), with: .color(Farben.linie), lineWidth: 1.4)
    }

    /// Die y-Verschiebung, die `aufFlaeche` liefert. `auf(los, 0).y` ist
    /// genau sie, weil die LOS in Bildkoordinaten auf null liegt.
    private func rand(auf: (Double, Double) -> CGPoint) -> Double {
        Double(auf(projektion.los, 0).y)
    }

    // MARK: - Die Zeichnung

    /// Wie viel breiter der Saum unter einem Weg ist als der Weg selbst.
    ///
    /// Dieselbe Zahl wie `SAUM_BREITE` in `backend/designer/render.py`,
    /// und `backend/designer/test_saum.py` hält beide gleich. Wären
    /// sie verschieden, sähe die Zeichnung am Gerät anders aus als
    /// auf dem Blatt, das
    /// daneben liegt -- und das ist genau der Unterschied, den Niklas
    /// gemeldet hat.
    static let saumBreite: Double = 2.2

    private func zeichneLinien(_ grund: GraphicsContext,
                               auf: (Double, Double) -> CGPoint,
                               faktor: Double) {
        // ERST ALLE SÄUME, DANN ALLE WEGE (R34).
        //
        // Niklas am 01.09.2026 über das Server-SVG: „man sieht sie nicht
        // unterschieden von der seitenlinie." Hier ist es dieselbe Falle
        // in anderer Farbe: Die Wege sind hell, die Line of Scrimmage
        // und die Seitenlinien sind es auch. Eine Out, die an der
        // Seitenlinie endet, und ein Block, der auf der LOS liegt,
        // verschwinden darin.
        //
        // Unter jeden Weg kommt deshalb ein breiterer Strich in der
        // Farbe des Rasens -- dieselbe Antwort wie in `render.py`, nur
        // mit dem dunklen Grund dieser App statt dem hellen des Papiers.
        //
        // Und alle Säume VOR allen Wegen: Paarweise gezeichnet schnitte
        // der Saum der zweiten Route ein Loch in die erste, genau da, wo
        // zwei Receiver sich kreuzen.
        for linie in zeichnung.linien where linie.punkte.count >= 2 {
            // Eine Zone ist eine Fläche und liegt flach auf dem Rasen;
            // ein Saum um sie herum wäre ein heller Ring um nichts.
            guard linie.art != .zone else { continue }
            // JE ABSCHNITT (R45). Eine Linie mit Motion-Vorlauf besteht
            // aus zwei Stücken verschiedener Breite; ein Saum in der
            // Breite des einen träfe für das andere nicht.
            for teil in linie.abschnitte {
                let weg = pfad(teil.punkte.map { auf($0.x, $0.y) },
                               linie: linie)
                grund.stroke(weg, with: .color(Farben.flaechePanel),
                             style: StrokeStyle(
                                lineWidth: (teil.art.stil.breite
                                            + Feldansicht.saumBreite) * faktor,
                                lineCap: .round, lineJoin: .round))
            }
        }

        for (stelle, linie) in zeichnung.linien.enumerated()
        where linie.punkte.count >= 2 {
            let punkte = linie.punkte.map { auf($0.x, $0.y) }
            // `weg` und nicht `pfad`: Eine lokale Angabe, die so heißt wie
            // die Funktion daneben, ist eine Übersetzung, die entweder
            // durchgeht oder nicht -- und ohne Mac merkt man das erst eine
            // halbe Stunde später auf dem Läufer.
            let weg = self.pfad(punkte, linie: linie)

            // Die ausgewählte Linie bekommt einen Schein darunter. Ein
            // Farbwechsel wäre falsch: Die Farbe SAGT hier etwas (wessen
            // Weg das ist), und was sie sagt, gilt auch beim Anfassen.
            if stelle == ausgewaehlt {
                grund.stroke(weg, with: .color(Farben.ink.opacity(0.35)),
                             style: StrokeStyle(
                                lineWidth: (linie.art.stil.breite + 4) * faktor,
                                lineCap: .round, lineJoin: .round))
            }

            // EINE ZONE IST EINE FLÄCHE (R8, 26.08.2026). Der Browser und
            // der Ausdruck füllen sie seit jeher leicht ein
            // (`fill-opacity="0.14"` in `render.py`), die App hat sie nur
            // umrandet. Auf dem Papier war der Deckungsraum ein Raum, auf
            // dem Handy ein Strichgebilde -- dieselbe Zeichnung, zwei
            // Aussagen.
            if linie.istFlaeche {
                grund.fill(weg, with: .color(farbe(fuer: linie).opacity(0.14)))
            }

            // JE ABSCHNITT (R45): bis `motionBis` als Motion, danach in
            // der eigenen Art. Ohne Vorlauf ist es genau ein Stück, und
            // dann ist es Zeichen für Zeichen dasselbe wie vorher.
            for teil in linie.abschnitte {
                let teilweg = self.pfad(teil.punkte.map { auf($0.x, $0.y) },
                                        linie: linie)
                grund.stroke(teilweg, with: .color(farbe(fuer: linie)),
                             style: strich(teil.art, faktor: faktor))
            }

            // Eine Zone hat kein Ende -- sie ist geschlossen. `render.py`
            // und `editor.js` steigen für sie aus, bevor der Marker an
            // die Reihe kommt; ein Pfeil an einem Ring zeigt ins Nichts.
            if linie.ende != .none && linie.art != .zone {
                zeichneEnde(grund, linie: linie, faktor: faktor,
                            vorletzter: punkte[punkte.count - 2],
                            letzter: punkte[punkte.count - 1])
            }

            // DIE BESCHRIFTUNG (R25, 26.08.2026). Sie ist das, was der
            // Trainer RUFT -- Go, Out 7, Flat. Der Browser und der
            // Ausdruck zeigen sie seit jeher; die App hat sie
            // gespeichert, durchgereicht und nie gezeigt. Wer sie
            // eintippt, sah sie auf dem Papier und nicht auf dem
            // Gerät, mit dem er am Spielfeldrand steht.
            zeichneBeschriftung(grund, linie: linie, punkte: punkte,
                                faktor: faktor)
        }
    }

    /// Die Beschriftung an ihre Stelle, in der Farbe der Linie.
    ///
    /// **Die Stelle rechnet `Beschriftungsstelle`, und zwar mit
    /// derselben Formel wie `render.py`.** Stünde sie hier woanders,
    /// wäre die Frage, welche Stelle stimmt -- und am Spielfeldrand
    /// liegen Ausdruck und Gerät nebeneinander.
    private func zeichneBeschriftung(_ grund: GraphicsContext,
                                     linie: Zeichnung.Linie,
                                     punkte: [CGPoint],
                                     faktor: Double) {
        guard zeigeNamen else { return }
        // ABGESCHNITTEN WIE IM AUSDRUCK. `render.py` setzt nur die ersten
        // vierzehn Zeichen, und `schema.py` kürzt beim Speichern auf
        // dieselbe Zahl. Wer hier den vollen Text zeichnete, zeigte am
        // Spielfeldrand etwas anderes, als auf dem Blatt steht -- und
        // zwar genau bei den langen Namen, bei denen es auffällt.
        let text = String(
            linie.beschriftung
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(Zeichnung.Linie.maxBeschriftung))
        guard !text.isEmpty else { return }

        // Eine Zone hat kein Ende, also auch keine Spitze: Dort steht
        // der Name in der Mitte der Fläche.
        // Beim Kreis ist die Mitte der ERSTE Punkt und nicht der
        // Schwerpunkt beider: Der zweite liegt auf dem Rand, und der
        // Name stünde sonst auf halber Strecke nach draussen.
        let stelle: CGPoint?
        if linie.art == .zone, linie.zonenform == .kreis, punkte.count >= 1 {
            stelle = punkte[0]
        } else if linie.art == .zone, linie.zonenform == .rechteck,
                  punkte.count >= 2 {
            stelle = CGPoint(x: (punkte[0].x + punkte[1].x) / 2,
                             y: (punkte[0].y + punkte[1].y) / 2)
        } else if linie.art == .zone {
            stelle = Beschriftungsstelle.mitte(punkte)
        } else {
            stelle = Beschriftungsstelle.fuer(punkte, faktor: faktor)
        }
        guard let wo = stelle else { return }

        // Die Grösse skaliert mit, sonst wächst die Schrift beim
        // Hineinzoomen nicht mit dem Feld und steht irgendwann quer
        // über der Zeichnung.
        var beschriftet = grund.resolve(
            Text(text)
                .font(.system(size: 7 * faktor, weight: .bold))
                .foregroundColor(farbe(fuer: linie)))
        beschriftet.shading = .color(farbe(fuer: linie))
        grund.draw(beschriftet, at: wo, anchor: .center)
    }

    /// Der Weg einer Linie, gebogen oder eckig, bei einer Zone geschlossen.
    ///
    /// Die Rechnung steht in `Kurve.swift` und ist dieselbe wie in
    /// `render.py`. **Hier stand bis R7 eine eigene, einfachere:** eine
    /// Kette quadratischer Bögen durch die Mittelpunkte. Sie ging durch
    /// dieselben Stützpunkte, lief aber DAZWISCHEN anders -- und
    /// dazwischen liegt bei einer Wheel Route die Route.
    private func pfad(_ punkte: [CGPoint], linie: Zeichnung.Linie) -> Path {
        // KREIS UND RECHTECK (R48). Eine Zone konnte bisher nur ein
        // Vieleck aus einzeln gesetzten Ecken sein. Für ein
        // Defense-Playbook ist das die falsche Bedienung: Eine Zone wird
        // ständig verschoben und in der Grösse geändert.
        //
        // Beide Formen stehen mit ZWEI Punkten fest, und weil die
        // Umrechnung `auf(x, y)` in beiden Achsen denselben Massstab hat,
        // bleibt ein Kreis in Yards auch im Bild ein Kreis.
        //
        // Hier und nicht an zwei Stellen: Füllung, Strich und Saum gehen
        // alle durch diese Funktion, und eine Form, die nur gefüllt und
        // nicht umrandet wäre, sähe nach einem Fehler aus.
        if linie.art == .zone, linie.zonenform != .linie, punkte.count >= 2 {
            let a = punkte[0], b = punkte[1]
            if linie.zonenform == .kreis {
                let r = max(hypot(b.x - a.x, b.y - a.y), 1)
                return Path(ellipseIn: CGRect(x: a.x - r, y: a.y - r,
                                              width: r * 2, height: r * 2))
            }
            let ecke = CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                              width: max(abs(b.x - a.x), 1),
                              height: max(abs(b.y - a.y), 1))
            return Path(roundedRect: ecke, cornerRadius: 2)
        }
        // Geschlossen erst ab drei Ecken. Solange eine Zone noch
        // entsteht und zwei Punkte hat, ist sie eine Strecke -- der
        // Browser zeichnet sie in diesem Zustand ebenfalls offen, und
        // eine Zone, die beim zweiten Tipp verschwindet, sähe nach einem
        // Fehler aus.
        // `return` AUSGESCHRIEBEN, und das ist kein Schoenheitsmass.
        //
        // Bis R48 war diese Funktion ein einziger Ausdruck, und Swift
        // gibt den stillschweigend zurueck. Mit dem Zweig darueber ist
        // sie es nicht mehr -- dann ist dieselbe Zeile kein Rueckgabe-
        // wert, sondern ein Ausdruck ins Leere:
        //
        //     Feldansicht.swift:558: result of call to
        //     'pfad(_:weich:geschlossen:)' is unused
        //
        // Ohne Mac faellt das erst auf dem Laeufer auf, eine halbe
        // Stunde spaeter. Genau so ist der Bau am 09.09.2026 um 04:48
        // rot geworden.
        return Kurve.pfad(punkte, weich: linie.gebogen,
                          geschlossen: linie.art == .zone
                                       && punkte.count >= 3)
    }

    /// Strichstärke und Muster einer Linienart.
    ///
    /// Die Zahlen kommen aus `Linienstil.swift` und damit aus `render.py`
    /// -- dieselben, mit denen der Ausdruck entsteht. Sie stehen in
    /// Bildeinheiten und werden mit demselben Faktor gestreckt wie die
    /// Punkte; sonst hätte dieselbe Zeichnung auf dem Handy dickere
    /// Striche als auf dem Papier.
    private func strich(_ art: Zeichnung.Linie.Art,
                        faktor: Double) -> StrokeStyle {
        let stil = art.stil
        return StrokeStyle(lineWidth: stil.breite * faktor,
                           lineCap: stil.strich == nil ? .round : .butt,
                           lineJoin: .round,
                           dash: (stil.strich ?? []).map { $0 * faktor })
    }

    private func farbe(fuer linie: Zeichnung.Linie) -> Color {
        // Hat die Position eine eigene Farbe, gewinnt sie -- so sieht man
        // auf einen Blick, wessen Weg das ist. Sonst gilt die Farbe der
        // Linienart. Dieselbe Regel wie in `editor.js` und im Renderer.
        if let kennung = linie.spieler,
           let spieler = zeichnung.spieler.first(where: { $0.id == kennung }),
           let hex = spieler.farbe, !hex.isEmpty,
           let eigene = Color(hex: hex) {
            return eigene
        }
        return Feldansicht.farbe(fuer: linie.art.stil.farbe)
    }

    /// Die Rolle aus `Linienstil` in eine Farbe dieser App.
    ///
    /// Der Browser hat dafür CSS-Variablen, die im Dunkeln andere Werte
    /// tragen als im Ausdruck. Die App hat ihre Palette, und `test_marke`
    /// hält sie mit der Website zusammen.
    static func farbe(fuer rolle: Linienstil.Rolle) -> Color {
        switch rolle {
        case .text: return Farben.ink
        case .still: return Farben.inkStill
        case .gold: return Farben.gold
        case .petrol: return Farben.akzent
        }
    }

    /// Pfeil oder Querstrich am Ende.
    ///
    /// Die Maße folgen den SVG-Markern in `editor.js`: Ein Marker skaliert
    /// dort mit der Strichstärke (`markerUnits` steht auf `strokeWidth`),
    /// der Pfeil ist 4,6 Strichstärken lang, der Querstrich 5 breit. Feste
    /// Punktmaße sähen bei einer dünnen Linie plump aus und bei einer
    /// dicken verloren.
    private func zeichneEnde(_ grund: GraphicsContext,
                             linie: Zeichnung.Linie, faktor: Double,
                             vorletzter: CGPoint, letzter: CGPoint) {
        let dx = Double(letzter.x - vorletzter.x)
        let dy = Double(letzter.y - vorletzter.y)
        let laenge = (dx * dx + dy * dy).squareRoot()
        guard laenge > 0.01 else { return }
        let ex = dx / laenge, ey = dy / laenge
        let farbe = self.farbe(fuer: linie)
        let breite = linie.art.stil.breite * faktor

        switch linie.ende {
        case .arrow:
            let groesse = 4.6 * breite
            var spitze = Path()
            spitze.move(to: letzter)
            spitze.addLine(to: CGPoint(
                x: Double(letzter.x) - ex * groesse - ey * groesse * 0.45,
                y: Double(letzter.y) - ey * groesse + ex * groesse * 0.45))
            spitze.addLine(to: CGPoint(
                x: Double(letzter.x) - ex * groesse + ey * groesse * 0.45,
                y: Double(letzter.y) - ey * groesse - ex * groesse * 0.45))
            spitze.closeSubpath()
            grund.fill(spitze, with: .color(farbe))
        case .tee:
            // Querstrich: Sitzroute oder Blockpunkt.
            let halb = 2.5 * breite
            var strich = Path()
            strich.move(to: CGPoint(x: Double(letzter.x) - ey * halb,
                                    y: Double(letzter.y) + ex * halb))
            strich.addLine(to: CGPoint(x: Double(letzter.x) + ey * halb,
                                       y: Double(letzter.y) - ex * halb))
            grund.stroke(strich, with: .color(farbe), lineWidth: breite)
        case .none:
            break
        }
    }

    // MARK: - Die angefangene Linie

    /// Die Linie, die gerade entsteht.
    ///
    /// Sie sieht ABSICHTLICH anders aus als eine fertige: mit sichtbaren
    /// Ecken und einer blassen Strecke bis unter den Finger. Auf einem
    /// Handy gibt es keinen Mauszeiger, der vorher zeigt, wo der Fang den
    /// nächsten Punkt hinlegt -- ohne diese Vorschau zeichnet man blind.
    private func zeichneEntwurf(_ grund: GraphicsContext,
                                auf: (Double, Double) -> CGPoint,
                                faktor: Double) {
        guard let entwurf, let letzter = entwurf.punkte.last else { return }
        let punkte = entwurf.punkte.map { auf($0.x, $0.y) }
        let farbe = self.farbe(fuer: entwurf)

        if punkte.count >= 2 {
            grund.stroke(pfad(punkte, linie: entwurf), with: .color(farbe),
                         style: strich(entwurf.art, faktor: faktor))
            if entwurf.ende != .none {
                zeichneEnde(grund, linie: entwurf, faktor: faktor,
                            vorletzter: punkte[punkte.count - 2],
                            letzter: punkte[punkte.count - 1])
            }
        }

        // Die Strecke bis unter den Finger. Blass und gestrichelt, weil
        // sie noch nichts ist.
        if let zeiger, zeiger.x != letzter.x || zeiger.y != letzter.y {
            var vorschau = Path()
            vorschau.move(to: punkte[punkte.count - 1])
            vorschau.addLine(to: auf(zeiger.x, zeiger.y))
            grund.stroke(vorschau, with: .color(farbe.opacity(0.5)),
                         style: StrokeStyle(lineWidth: 1.6 * faktor,
                                            dash: [4 * faktor, 4 * faktor]))
        }

        // Die gesetzten Ecken. Sie sind der Unterschied zwischen „ich habe
        // hier getippt" und „hier ist etwas passiert".
        for (i, punkt) in punkte.enumerated() {
            let radius = (i == punkte.count - 1 ? 4.5 : 3.0) * faktor
            let kasten = CGRect(x: Double(punkt.x) - radius,
                                y: Double(punkt.y) - radius,
                                width: radius * 2, height: radius * 2)
            grund.fill(Path(ellipseIn: kasten), with: .color(Farben.flaeche))
            grund.stroke(Path(ellipseIn: kasten), with: .color(farbe),
                         lineWidth: 1.6 * faktor)
        }
    }

    // MARK: - Die Griffe (R11)

    /// Die Stützpunkte der ausgewählten Linie.
    ///
    /// **Nicht mit dem Faktor skaliert**, anders als alles andere hier:
    /// Ein Griff ist kein Teil der Zeichnung, sondern eine Bedienstelle.
    /// Er muss so groß sein, wie ein Finger ihn trifft -- und das ist
    /// eine Zahl in Bildschirmpunkten, keine in Yards. Zöge er mit dem
    /// Maßstab mit, wäre er auf einem kleinen Feld ein Fleck und auf
    /// einem großen unauffindbar.
    private func zeichneGriffe(_ grund: GraphicsContext,
                               auf: (Double, Double) -> CGPoint) {
        guard !griffe.isEmpty else { return }
        for (stelle, punkt) in griffe.enumerated() {
            let mitte = auf(punkt.x, punkt.y)
            let anker = griffAnker && stelle == 0
            let amFinger = griffAmFinger == stelle
            let radius = anker ? 3.5 : (amFinger ? 9.0 : 6.0)
            let kasten = CGRect(x: Double(mitte.x) - radius,
                                y: Double(mitte.y) - radius,
                                width: radius * 2, height: radius * 2)
            let kreis = Path(ellipseIn: kasten)
            if anker {
                // Nur ein Ring, und in der stillen Farbe: Er sagt „hier
                // fängt der Weg an", nicht „zieh mich".
                grund.stroke(kreis, with: .color(Farben.inkStill),
                             lineWidth: 1.4)
                continue
            }
            grund.fill(kreis, with: .color(Farben.flaeche))
            grund.stroke(kreis, with: .color(Farben.akzent),
                         lineWidth: amFinger ? 3 : 2)
        }
    }

    private func zeichneSpieler(_ grund: GraphicsContext,
                                auf: (Double, Double) -> CGPoint,
                                faktor: Double) {
        for spieler in zeichnung.spieler {
            zeichneFigur(grund, spieler: spieler,
                         mitte: auf(spieler.x, spieler.y),
                         faktor: faktor,
                         // Wer mitläuft, tritt im Standbild zurück.
                         // Dieselben 22 Prozent wie im Browser
                         // (`.sp.laeuft` in editor.css).
                         deckkraft: laufende.contains(spieler.id) ? 0.22 : 1)
        }
    }

    /// Die Umrisslinie einer Figur: Kreis für die Offense, Viereck für
    /// die Defense.
    ///
    /// **DIE DEFENSE IST EIN VIERECK, seit dem 09.09.2026.** Niklas beim
    /// Zeichnen seines ersten Defense-Playbooks: „das wenn man Defense
    /// Spieler addet das dass nicht so X sind sondern vielleicht
    /// Vierecke und genauso wie bei den Spielern". Ein Kreuz hat keine
    /// Innenfläche, also stand das Kürzel daneben -- in einer Cover 2
    /// sind das sechs lose Textstücke im Feld statt sechs beschrifteter
    /// Figuren.
    ///
    /// Rund gegen eckig bleibt auch im Schwarzweissdruck
    /// unterscheidbar; zwei Kreise in zwei Farben wären es bei
    /// schlechtem Licht nicht.
    ///
    /// **Warum das eine eigene Funktion ist.** Die Hilfe zeigt dieselben
    /// beiden Figuren als Legende (`Spielerprobe`). Sie dort ein
    /// zweites Mal zu zeichnen wäre eine zweite Notation -- und wenn
    /// sich die echte wieder ändert, erklärt die Legende danach die
    /// alte.
    ///
    /// `0.886` ist keine gegriffene Zahl: Ein Quadrat dieser Kantenlänge
    /// hat dieselbe FLÄCHE wie der Kreis mit demselben Radius
    /// (√(π)/2 = 0,886). Ohne das wirkt das Viereck neben dem Kreis
    /// klobig, obwohl beide „gleich gross" sind.
    static func figurform(seite: Zeichnung.Spieler.Seite,
                          mitte: CGPoint, radius: Double) -> Path {
        if seite == .offense {
            return Path(ellipseIn: CGRect(
                x: Double(mitte.x) - radius, y: Double(mitte.y) - radius,
                width: radius * 2, height: radius * 2))
        }
        let kante = radius * 0.886
        return Path(roundedRect: CGRect(
            x: Double(mitte.x) - kante, y: Double(mitte.y) - kante,
            width: kante * 2, height: kante * 2),
            cornerSize: CGSize(width: radius * 0.14,
                               height: radius * 0.14))
    }

    /// Wie gross eine Figur gezeichnet wird, in Bildschirmpunkten.
    ///
    /// **DAS WAR EINE FESTE 13, UND DAS WAR EIN RECHENFEHLER (R73).**
    /// Niklas am 03.09.2026 zu den Vorschaukacheln: „Hier sind die
    /// Spieler viel zu gross" -- „Viel zu grosse Spieler. Allgemein die
    /// Vorschau bekommst du viel viel professioneller hin."
    ///
    /// Er hat recht, und es ist kein Geschmack: Alles andere auf dem
    /// Feld wird mit `faktor` skaliert -- die Linien, ihre Strichelung,
    /// die Beschriftung. Nur die Figuren nicht. Auf dem grossen Feld
    /// fällt das nicht auf; in einer Kachel von zwei Zentimetern ist
    /// eine Figur so gross wie fünf Yards und verdeckt den Play, den
    /// sie zeigen soll.
    ///
    /// **In Yards gerechnet und dann skaliert**, wie der Rest. Ein
    /// Spieler ist knapp einen Yard breit; der Kreis ist etwas grösser,
    /// weil das Kürzel hineinpassen muss. Der Wert ist derselbe, den
    /// die feste 13 auf einem vollen Bildschirm ergab -- die grosse
    /// Ansicht sieht also aus wie vorher.
    ///
    /// **Mit einer Untergrenze**, und die ist keine Bequemlichkeit: Ein
    /// Kreis unter drei Punkten ist ein Fleck, und eine Vorschau aus
    /// Flecken sagt weniger als eine ohne Figuren.
    static func figurradius(faktor: Double,
                            form: Spielform = Spielform.zu(nil)) -> Double {
        max(Feldansicht.figurMindestens,
            form.figurradius * Projektion.einheitenJeYard * faktor)
    }

    /// Der Halbmesser einer Figur in YARDS.
    ///
    /// **DIE ERSTE FASSUNG WAR UM DEN FAKTOR ZEHN DANEBEN, UND MAN SAH
    /// ES SOFORT.** Niklas am 03.09.2026, fünf Stunden nach dem Bau:
    /// „Das ist doch kacke jetzt. Jetzt sieht man im Editor die Punkte
    /// viel zu klein." Auf seinem Bild sind die Figuren blaue Tupfer
    /// von sechs Punkten, ohne Kürzel darin.
    ///
    /// Die Ursache: `faktor` rechnet EINHEITEN in Bildpunkte, nicht
    /// Yards -- die Projektion legt zehn Einheiten auf einen Yard
    /// (`Projektion.einheitenJeYard`). Mit `figurYards * faktor` kam
    /// ein Zehntel heraus, und die Untergrenze von drei Punkten fing
    /// alles ab. Genau deshalb fiel es nicht als Absturz auf, sondern
    /// als „zu klein": Der Riegel, der Flecken verhindern soll, war die
    /// einzige Zahl, die noch wirkte.
    ///
    /// **Nachgerechnet.** Auf einem iPhone im Hochformat misst der
    /// Ausschnitt 29 Yards in der Breite, also 290 Einheiten, und
    /// bekommt rund 580 Punkte -- der Faktor ist etwa 2. Der alte feste
    /// Radius von 13 Punkten entspricht damit 6,5 Einheiten oder 0,65
    /// Yards. So gross bleibt die Figur auf dem vollen Bildschirm, und
    /// in einer Kachel schrumpft sie mit.
    ///
    /// Ein Spieler ist gut einen Yard breit; der Kreis ist etwas
    /// grösser, weil das Kürzel hineinpassen muss.
    ///
    /// **DIESE ZAHL IST NICHT MEHR DIE ANTWORT** (Audit 07.09.2026).
    /// Sie stand hier fest, für jede Spielform dieselbe -- und das war
    /// richtig, solange es nur ein Feld gab. Der Server rechnet seit
    /// T11 mit `Spielform.figurradius`: 1,05 Yards im Flag, 0,6 im
    /// Tackle, weil zwei Linemen nur 1,33 Yards auseinanderstehen. Mit
    /// festen 0,65 stiessen die Kreise im Tackle aneinander und waren
    /// im Flag zu klein.
    ///
    /// Der Wert bleibt als BELEG stehen: Er ist der, den die alte feste
    /// 13 auf einem vollen Bildschirm ergab, und er erklärt, warum die
    /// Flagansicht sich dabei ändert (1,05 statt 0,65 -- die App war
    /// dort immer etwas zu klein gegenüber dem Ausdruck).
    static let figurYards = 0.65

    /// **Mit einer Untergrenze**, und die ist keine Bequemlichkeit: Ein
    /// Kreis unter drei Punkten ist ein Fleck, und eine Vorschau aus
    /// Flecken sagt weniger als eine ohne Figuren.
    ///
    /// Sie steht seit dem 06.09.2026 als eigener Wert da, weil sie beim
    /// Rechenfehler oben die einzige wirksame Zahl war. Was einen
    /// Fehler verdeckt hat, gehört benannt.
    static let figurMindestens = 3.0

    /// Ab welchem Radius ein Kürzel in die Figur geschrieben wird.
    ///
    /// **Am Radius gemessen und nicht an der Schriftgrösse**, weil die
    /// Frage lautet: Passt ein Buchstabe in diesen Kreis?
    ///
    /// **VIER UND NICHT VIERFÜNF, UND DIE ZAHL IST GERECHNET.** Auf
    /// einem iPhone im Hochformat (rund 390 Punkte) misst ein
    /// Elfer-Feld von 53,33 Yards plus Saum 573 Einheiten; der
    /// Massstab ist damit 0,68, und eine Tackle-Figur von 0,6 Yards
    /// kommt auf 4,08 Punkte. Bei 4,5 traegt in einem Elfer-Playbook
    /// auf dem Telefon KEINE Figur mehr ihr Kürzel -- genau der Fehler,
    /// den der Audit gefunden hat. Nachgerechnet in
    /// `test_figurgroesse.test_das_kuerzel_passt_bei_tackle_noch_hinein`.
    ///
    /// Bei vier Punkten Radius sind es rund 3,4 Punkte Schrift. Klein,
    /// aber da -- und mehr Auskunft als elf gleiche Punkte. Darunter
    /// (Vorschaukacheln) bleibt es beim Kreis.
    static let kuerzelAb = 4.0

    /// Wie weit die Yardzahlen von der Seitenlinie stehen, in Yards.
    ///
    /// Dieselben neun wie im Server (`render.ZAHLEN_VOM_RAND`): NCAA
    /// und NFHS setzen sie neun Yards von der Seitenlinie, die NFL
    /// zwölf. Eine zweite Zahl hier hiesse, dass Ausdruck und
    /// Bildschirm sie an verschiedene Stellen schreiben.
    static let zahlenVomRand = 9.0

    /// Welche Farbe eine Figur trägt.
    ///
    /// **Eine Stelle, seit es die Farbwahl gibt (R43).** Der Tupfer
    /// neben dem Menü im Editor und die Figur auf dem Feld müssen
    /// dasselbe zeigen; stünde die Regel zweimal da, zeigte der Tupfer
    /// irgendwann Petrol und die Figur Gold.
    ///
    /// Ohne eigene Farbe kommt die der SEITE -- und das ist keine
    /// Notlösung: Was ohne Angabe gezeichnet wird, ist nicht farblos,
    /// sondern normal.
    static func figurfarbe(_ spieler: Zeichnung.Spieler) -> Color {
        figurfarbe(wert: spieler.farbe, seite: spieler.seite)
    }

    /// Dieselbe Regel, aber für einen Wert, den noch niemand trägt.
    ///
    /// Das Farbmenü zeigt seit R66 neben jedem Eintrag den Punkt, der
    /// herauskäme. Dafür braucht es die Farbe zu einem Hexwert, der
    /// noch an keiner Figur steht -- und „Standard" hängt dabei an der
    /// Seite, sonst zeigte der Eintrag der Defense Petrol.
    static func figurfarbe(wert: String?,
                           seite: Zeichnung.Spieler.Seite) -> Color {
        if let eigen = wert.flatMap({ Color(hex: $0) }) {
            return eigen
        }
        return seite == .offense ? Farben.petrol : Farben.inkStill
    }

    /// Eine Figur an einer Stelle. Getrennt vom Durchlauf über die
    /// Aufstellung, weil beim Abspielen dieselbe Figur ein zweites Mal
    /// gezeichnet wird -- unterwegs, an einer anderen Stelle.
    private func zeichneFigur(_ grund: GraphicsContext,
                              spieler: Zeichnung.Spieler,
                              mitte: CGPoint,
                              faktor: Double,
                              deckkraft: Double) {
        let radius = Feldansicht.figurradius(faktor: faktor,
                                             form: projektion.form)
        let angefasst = spieler.id == hervorgehoben && deckkraft == 1
        // Der Kasten steckt jetzt in `figurform` -- er wurde hier
        // stehengelassen, als die beiden Umrisse herausgezogen wurden,
        // und der Läufer hat ihn gefunden: Warnungen sind hier Fehler.
        let form = Feldansicht.figurform(seite: spieler.seite,
                                         mitte: mitte, radius: radius)
        grund.fill(form,
                   with: .color(Feldansicht.figurfarbe(spieler)
                                    .opacity(deckkraft)))
        grund.stroke(form,
                     with: .color((angefasst ? Farben.ink
                                   : Farben.flaeche).opacity(deckkraft)),
                     // Mit dem Kreis (R73): Ein Rand von 1,6 Punkten um
                     // einen Kreis von vier ist fast der halbe Kreis.
                     lineWidth: (angefasst ? 3 : 1.6) * radius / 13.0)

        // DAS KÜRZEL WÄCHST MIT DEM KREIS (R73). Vorher stand es
        // fest auf 13 Punkten -- in einer Vorschaukachel ragte es
        // rechts und links aus der Figur heraus.
        //
        // UND UNTER EINER SCHWELLE GAR NICHT MEHR: Zwei Buchstaben in
        // fünf Punkten sind kein Text, sondern ein Fleck auf einem
        // Kreis. Ohne sie bleibt der Kreis, und der sagt in einer
        // Vorschau genug.
        //
        // **DIE SCHWELLE WAR EIN FLAGWERT** (Audit 07.09.2026). Sie
        // stand auf sieben Punkten und wurde gegen `radius * 1.0`
        // geprüft. Auf 25 Yards Feldbreite ist der Radius rund zehn --
        // auf 53,33 Yards sind es 4,8, und damit trug in einem
        // Elfer-, Neuner- oder Sechser-Playbook auf dem Telefon
        // **keine einzige Figur mehr ihr Kürzel**. Elf gleich
        // aussehende Punkte, und wer LT von RT unterscheiden will,
        // kann es nicht.
        //
        // Zwei Änderungen: Die Schrift folgt jetzt demselben Verhältnis
        // wie im Server (`render.py`: Schrift 9 in einem Kreis von 21,
        // also 0,857 des Radius mal zwei geteilt durch zwei), und die
        // Schwelle liegt am RADIUS statt an der Schriftgrösse. Ein
        // Kreis, der gross genug für einen Buchstaben ist, bekommt
        // einen.
        // SEIT DEM 09.09.2026 AUCH FÜR DIE DEFENSE. Sie trägt ihr
        // Kürzel jetzt IN der Figur, weil sie eine Innenfläche hat.
        let schrift = radius * 0.857
        if !spieler.kuerzel.isEmpty,
           radius >= Feldansicht.kuerzelAb {
            grund.draw(
                Text(spieler.kuerzel)
                    .font(.system(size: schrift, weight: .bold))
                    .foregroundColor(Farben.flaeche.opacity(deckkraft)),
                at: mitte)
        }
    }

    // MARK: - Der Ablauf

    /// Die mitlaufenden Figuren beim Abspielen.
    ///
    /// Zuletzt und über allem: Sie sind das, worauf gerade jeder sieht.
    /// Wo sie stehen, hat `Laufplan` ausgerechnet -- diese Ansicht
    /// entscheidet nichts davon, sie zeichnet nur.
    private func zeichneMarken(_ grund: GraphicsContext,
                               auf: (Double, Double) -> CGPoint,
                               faktor: Double) {
        for marke in marken {
            let mitte = auf(marke.x, marke.y)
            switch marke.traeger {
            case .spieler(let kennung):
                if let spieler = zeichnung.spieler.first(where: {
                    $0.id == kennung
                }) {
                    zeichneFigur(grund, spieler: spieler, mitte: mitte,
                                 faktor: faktor, deckkraft: 1)
                    continue
                }
                zeichnePunkt(grund, mitte: mitte, marke: marke)
            case .ball:
                // Der Ball ist ein Ei und kein Kreis: Beim Abspielen
                // laufen fünf Figuren gleichzeitig, und wer den Ball
                // sucht, soll ihn an der Form finden und nicht an der
                // Farbe -- die trägt schon eine andere Bedeutung.
                // MIT DEM MASSSTAB (R73), wie die Figuren daneben:
                // Ein Ei von elf Punkten neben einer Figur von vier
                // wäre grösser als der Werfer.
                let breit = 0.95 * Feldansicht.figurradius(
                    faktor: faktor, form: projektion.form) * 2
                let hoch = breit * 7 / 11
                // NAHT, SCHNÜRUNG UND FLUGRICHTUNG (R89).
                //
                // Niklas am 09.09.2026: „Denn Football mehr nach
                // Football texturieren, und vorallem in Flugrichtung
                // drehen." Ein gelbes Ei, das beim Pass nach vorn quer
                // in der Luft steht, liest sich als liegender Ball --
                // und der Browser hatte Naht und Schnürung längst
                // (`ballSymbol` in `editor.js`), die App nicht.
                //
                // Gezeichnet wird um den Nullpunkt und danach gedreht
                // und geschoben: Sonst müsste jede Linie der Schnürung
                // einzeln mitgerechnet werden.
                var ebene = grund
                ebene.translateBy(x: Double(mitte.x), y: Double(mitte.y))
                ebene.rotate(by: .radians(marke.winkel))
                let kasten = CGRect(x: -breit / 2, y: -hoch / 2,
                                    width: breit, height: hoch)
                let ei = Path(ellipseIn: kasten)
                ebene.fill(ei, with: .color(Farben.gold))
                ebene.stroke(ei, with: .color(Farben.flaeche), lineWidth: 1.2)
                var naht = Path()
                naht.move(to: CGPoint(x: -breit * 0.24, y: 0))
                naht.addLine(to: CGPoint(x: breit * 0.24, y: 0))
                for i in -2...2 {
                    let x = Double(i) * breit * 0.105
                    naht.move(to: CGPoint(x: x, y: -hoch * 0.2))
                    naht.addLine(to: CGPoint(x: x, y: hoch * 0.2))
                }
                ebene.stroke(naht, with: .color(Farben.flaeche),
                             style: StrokeStyle(lineWidth: 1.1,
                                                lineCap: .round))
            case .punkt:
                zeichnePunkt(grund, mitte: mitte, marke: marke)
            }
        }
    }

    private func zeichnePunkt(_ grund: GraphicsContext, mitte: CGPoint,
                              marke: Laufplan.Marke) {
        let radius = 4.5
        let kasten = CGRect(x: Double(mitte.x) - radius,
                            y: Double(mitte.y) - radius,
                            width: radius * 2, height: radius * 2)
        grund.fill(Path(ellipseIn: kasten),
                   with: .color(Feldansicht.farbe(fuer: marke.art.stil.farbe)))
    }
}

// MARK: - Hexfarben

extension Color {
    /// `#1A5364` in eine Farbe. `nil`, wenn es kein Hexwert ist.
    ///
    /// Der Server schreibt Farben als Hex und akzeptiert nur genau diese
    /// Form (`schema._HEX`). Was er nicht schickt, muss hier auch nicht
    /// geraten werden.
    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let wert = UInt32(text, radix: 16) else {
            return nil
        }
        self.init(red: Double((wert >> 16) & 0xFF) / 255,
                  green: Double((wert >> 8) & 0xFF) / 255,
                  blue: Double(wert & 0xFF) / 255)
    }
}
