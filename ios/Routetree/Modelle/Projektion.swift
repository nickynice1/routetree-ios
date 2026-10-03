// Von Yards in Bildpunkte, und zurück.
//
// Die Quelle ist `Projection` in backend/designer/render.py. Diese Datei
// wird nicht erzeugt -- es sind zwanzig Zeilen Arithmetik --, aber sie
// wird gemessen: `scripts/zeichnung_swift.py` schreibt Rechenproben, deren
// erwartete Werte aus Python stammen, und `ProjektionTests` rechnet sie
// nach.
//
// WARUM DAS GENAU STIMMEN MUSS. Wer im Editor einen Spieler anfasst,
// tippt auf Bildpunkte, und was gespeichert wird, sind Yards. Rechnet die
// App anders als der Server, steht der Spieler nach dem Speichern woanders
// als da, wo der Finger war -- und der Ausdruck zeigt wieder etwas
// anderes.

import CoreGraphics
import Foundation

/// Rechnet Feldkoordinaten (Yards) in Bildkoordinaten um.
///
/// **Die Offense greift immer nach oben an**, gleich in welche Richtung
/// sie auf dem echten Feld spielt. Ein Trainer zeichnet nach oben, und ein
/// Play, der beim Seitenwechsel plötzlich kopfsteht, wäre unlesbar.
///
/// Der Nullpunkt liegt auf der Line of Scrimmage in der Feldmitte: y = 0
/// ist die LOS, negative y liegen davor (in Angriffsrichtung).
struct Projektion: Equatable {

    /// Bildeinheiten je Yard. Dieselbe Zahl wie `UNITS_PER_YARD` im
    /// Server: Sie ist kein Zoom, sondern der Maßstab, in dem alle
    /// Strichstärken und Abstände beider Seiten ausgedrückt sind.
    static let einheitenJeYard: Double = 10

    var feld: Feld
    var los: Double
    /// +1, wenn die Offense auf dem echten Feld nach rechts angreift.
    var richtung: Int
    /// Sichtbar hinter der LOS, in Yards.
    var hinten: Double = 8
    /// Sichtbar vor der LOS, in Yards.
    var vorne: Double = 22
    /// Streifen neben dem Feld für die Linienbeschriftung.
    var rand: Double = 6
    /// Was hier gespielt wird -- als Schlüssel in `Spielform.alle`.
    ///
    /// **Warum an der Projektion und nicht an jeder Ansicht.** Wie groß
    /// eine Figur gezeichnet wird (`figurradius`) und ob die Mittellinie
    /// die Line to Gain ist, hängt an der Spielform und nicht am Feld.
    /// Bis zum 07.09.2026 kam beides in der App gar nicht an: Die
    /// Zeichenkette reichte nur `Feld` durch, und `Feldansicht` rechnete
    /// mit einem festen Flagwert. Auf einem Elfer-Feld trug danach keine
    /// Figur mehr ihr Kürzel.
    ///
    /// Die Projektion geht ohnehin durch jede zeichnende Ansicht. Ein
    /// zweiter Weg daneben wäre der, den man beim nächsten Umbau
    /// vergisst.
    ///
    /// Vorgabe ist Flag, wie überall sonst: Wer nichts sagt, bekommt
    /// den Bestand.
    var spielform: String = Spielform.standard
    /// Der sichtbare Streifen der FELDBREITE, in Yards.
    ///
    /// **Warum es das gibt** (08.09.2026): Auf 25 Yards Flagbreite ist
    /// nichts abzuschneiden, eine Aufstellung mit drei Empfängern
    /// benutzt sie ganz. Auf 53,33 Yards ist es der Unterschied
    /// zwischen lesbar und nicht: Auf einem iPhone im Hochformat
    /// (390 Punkte) misst ein Elfer-Feld 0,68 Punkte je Einheit, ein
    /// Spielerkreis kommt auf vier Punkte und das Kürzel auf drei.
    ///
    /// Der Server macht das seit T9 (`render.querfenster_fuer`) -- für
    /// Papier, wo dasselbe Problem in Millimetern auftritt. Die App
    /// hatte es nicht.
    ///
    /// **Es verschiebt keinen einzigen Punkt.** Wie `zuBild` einen
    /// Feldpunkt abbildet, hängt nicht davon ab; nur der sichtbare
    /// Kasten wird enger. Genau so steht es im Server: Der
    /// Querausschnitt betrifft `view_box` und `aspect`, und `to_svg`
    /// bleibt unberührt. Deshalb stimmt auch der Finger weiter -- er
    /// rechnet über `aufFlaeche` zurück, und die liest den Kasten.
    var querVon: Double
    var querBis: Double

    // MARK: - Der Ausschnitt am Bildschirm (R110.6)
    //
    // Am Platz steht der Trainer mit dem Telefon in der Sonne und will
    // eine Ecke des Feldes gross sehen. Der Browser kann das seit
    // Langem, die App nicht -- und Playmaker-X-Nutzer vermissen beides.
    //
    // GERECHNET WIRD AUSSCHLIESSLICH IN `aufFlaeche`, also an der EINEN
    // Stelle, an der die Projektion den Bildschirm trifft. Damit
    // stimmen Zeichnen UND Finger von selbst: `aufBildschirm` und
    // `vomBildschirm` gehen beide dort durch. Der Browser macht es
    // genauso -- dort ueber die `viewBox`, und die Zeichnung bleibt
    // unangetastet.
    //
    // WAS HIER NICHT PASSIERT: Die Zeichnung aendert sich nicht. Ein
    // gezoomter Play ist derselbe Play; im Ausdruck ist davon nichts
    // zu sehen, und das ist richtig so.

    /// Wie stark vergroessert. 1 heisst „ganzes Sichtfenster".
    var zoom: Double = 1
    /// Wohin verschoben, in BILDSCHIRMPUNKTEN -- also in derselben
    /// Einheit wie der Finger. `.zero` heisst mittig.
    var versatz: CGPoint = .zero

    static let zoomMin = 1.0
    static let zoomMax = 5.0

    init(feld: Feld, los: Double, richtung: Int,
         hinten: Double = 8, vorne: Double = 22, rand: Double = 6,
         spielform: String = Spielform.standard,
         querVon: Double? = nil, querBis: Double? = nil) {
        self.feld = feld
        self.los = los
        self.richtung = richtung >= 0 ? 1 : -1
        self.hinten = hinten
        self.vorne = vorne
        self.rand = rand
        self.spielform = spielform
        // OHNE ANGABE DAS GANZE FELD. Der Bestand zeichnet damit
        // Einheit für Einheit wie vorher.
        self.querVon = querVon ?? 0
        self.querBis = querBis ?? Double(feld.breite)
    }

    /// Wie breit der sichtbare Streifen ist.
    var querBreite: Double { max(1, querBis - querVon) }

    /// Die Form als Ganzes, nachgeschlagen.
    var form: Spielform { Spielform.zu(spielform) }

    /// Der Ausschnitt für die APP: derselbe wie auf dem Papier, aber
    /// ohne den Beschriftungsstreifen.
    ///
    /// **Warum es den Streifen auf dem Papier gibt.** Im Server-SVG
    /// stehen links neben dem Feld „No-Run-Zone", „Rush 7 yd" und „Line
    /// to Gain". Sie liegen NEBEN der Zeichnung und nicht darin, damit
    /// sie nie einen Laufweg überdecken -- auch dann nicht, wenn die
    /// Line of Scrimmage genau auf einer markierten Linie liegt.
    ///
    /// **Warum ihn die App nicht braucht.** `Feldansicht` schreibt dort
    /// nichts hinein; nachgezählt sind es null Textausgaben. Der
    /// Streifen war damit 12 von 37 Yards Breite -- **ein Drittel des
    /// Bildschirms für nichts.**
    ///
    /// Niklas am 02.09.2026, 02:15 und 02:16, mit Kringeln an beiden
    /// Seiten: „Immernoch Ränder" -- „Hier auch immer noch Ränder".
    /// `gedehnt(auf:)` hatte am Tag zuvor nur die Balken oben und unten
    /// beseitigt.
    ///
    /// **Die Vorgabe bleibt bei 6**, denn sie ist die des Servers, und
    /// `ProjektionTests` rechnet gegen dessen Zahlen. Wer den Rand nicht
    /// braucht, sagt es hier -- statt eine gemeinsame Vorgabe zu
    /// verbiegen.
    static func fuerDieApp(feld: Feld, los: Double, richtung: Int,
                           spielform: String = Spielform.standard)
        -> Projektion {
        Projektion(feld: feld, los: los, richtung: richtung,
                   hinten: Projektion.appHinten, vorne: Projektion.appVorne,
                   rand: 0, spielform: spielform)
    }

    /// Wie viel Feld hinter der Line of Scrimmage die App mindestens
    /// zeigt (R48).
    ///
    /// Cyell am 01.09.2026: „bei der Detail Ansicht würde ich nur 10 yrs
    /// hinter der los sowie 20 nach der los anzeigen." Vorher waren es
    /// 8 und 22 -- die Zahlen des AUSDRUCKS, und dort sind sie richtig:
    /// Auf A4 ist Platz, und eine Go-Route soll ganz drauf.
    ///
    /// **Auf einem Telefon ist der Play kleiner, je mehr Feld darum
    /// steht.** Zwei Yards weniger nach vorn und zwei mehr nach hinten
    /// rücken die Aufstellung dorthin, wo man sie liest.
    ///
    /// **MINDESTMASS, KEIN FESTMASS**, und das ist die Auflösung des
    /// Widerspruchs zu R34: Dort wurde der Ausschnitt gerade GEWEITET,
    /// damit kein schwarzer Balken bleibt. `gedehnt(auf:)` füllt von
    /// hier aus weiter, und `passendFuer(_:)` weitet, wenn ein Weg sonst
    /// aus dem Bild liefe.
    static let appHinten = 10.0
    static let appVorne = 20.0

    /// Derselbe Ausschnitt, aber weit genug für DIESE Zeichnung.
    ///
    /// **Die Lücke, die dabei auffiel.** Auf dem Server weitet
    /// `fenster_fuer` das Fenster, bis der ganze Play hineinpasst -- mit
    /// der Begründung, eine Go-Route über dreissig Yards liege bei
    /// `ahead=22` acht Yards draussen und das falle niemandem auf, weil
    /// das Bild an der Kante einfach aufhört. Genau diese Rechnung gab
    /// es in der App NICHT. Sie zeichnet seit B3 selbst, und ein Weg,
    /// der über den Ausschnitt hinausgeht, wurde dort schlicht
    /// abgeschnitten.
    ///
    /// Dieselbe Regel wie auf dem Server, samt Sicherheitssaum: nie
    /// enger als die Vorgabe, nie weiter als das Feld hergibt.
    func passendFuer(_ zeichnung: Zeichnung) -> Projektion {
        var neuHinten = hinten
        var neuVorne = vorne
        for x in zeichnung.yardwerte {
            let vorwaerts = (x - los) * Double(richtung)
            if vorwaerts > 0 {
                neuVorne = max(neuVorne, vorwaerts + Projektion.appSaum)
            } else {
                neuHinten = max(neuHinten, -vorwaerts + Projektion.appSaum)
            }
        }
        let grenze = Double(feld.gesamtLaenge)
        var neu = Projektion(feld: feld, los: los, richtung: richtung,
                             hinten: min(neuHinten, grenze),
                             vorne: min(neuVorne, grenze), rand: rand,
                             spielform: spielform,
                             querVon: querVon, querBis: querBis)
        // DER AUSSCHNITT GEHT MIT (R110.6). Sonst springt das Bild auf
        // Anfang, sobald jemand eine lange Route zieht -- also genau
        // dann, wenn er hineingezoomt hat, um sie zu zeichnen.
        neu.zoom = zoom
        neu.versatz = versatz
        return neu
    }

    /// Luft zwischen dem äussersten Punkt und der Bildkante.
    ///
    /// Dieselben zwei Yards wie `fenster_fuer(rand=2.0)`. Ohne sie
    /// endete eine Route genau auf der Kante, und das sieht aus wie
    /// abgeschnitten -- auch wenn sie ganz da ist.
    static let appSaum = 2.0

    // MARK: - Hin und zurück

    /// Feldpunkt in Yards zu Bildpunkt in Einheiten.
    func zuBild(x: Double, y: Double) -> CGPoint {
        let vorwaerts = (x - los) * Double(richtung)
        let quer = richtung < 0 ? y : (Double(feld.breite) - y)
        return CGPoint(x: quer * Projektion.einheitenJeYard,
                       y: -vorwaerts * Projektion.einheitenJeYard)
    }

    /// Bildpunkt zurück in Yards. Das ist die Richtung, die der Editor
    /// braucht: Ein Finger liefert Bildpunkte.
    func zuFeld(_ punkt: CGPoint) -> (x: Double, y: Double) {
        let vorwaerts = -Double(punkt.y) / Projektion.einheitenJeYard
        let quer = Double(punkt.x) / Projektion.einheitenJeYard
        let x = los + vorwaerts * Double(richtung)
        let y = richtung < 0 ? quer : (Double(feld.breite) - quer)
        return (x, y)
    }

    /// Bild-y für eine Entfernung in Yards vor der LOS.
    func vorwaerts(_ yards: Double) -> Double {
        -yards * Projektion.einheitenJeYard
    }

    // MARK: - Der Ausschnitt

    /// Der sichtbare Bereich in Bildeinheiten, wie die `viewBox` des SVG.
    ///
    /// Der Beschriftungsstreifen liegt links, wird aber rechts in gleicher
    /// Breite ausgeglichen: Sonst säße das Feld sichtbar aus der Mitte.
    var ausschnitt: CGRect {
        // DIE QUERACHSE IST GEDREHT (siehe `zuBild`): Bei Richtung +1
        // liegt y = 0 rechts. Der Ausschnitt `querVon..querBis` in
        // Yards wird deshalb zu `breite - querBis .. breite - querVon`
        // in Einheiten. Wer das vergisst, schneidet die falsche Hälfte
        // weg -- und zwar so, dass es aussieht wie eine Aufstellung an
        // der anderen Seitenlinie. Dieselbe Rechnung wie in
        // `render.Projection.view_box`.
        let linksYd = richtung < 0 ? querVon : Double(feld.breite) - querBis
        return CGRect(x: (linksYd - rand) * Projektion.einheitenJeYard,
                      y: -vorne * Projektion.einheitenJeYard,
                      width: (querBreite + 2 * rand)
                             * Projektion.einheitenJeYard,
                      height: (vorne + hinten) * Projektion.einheitenJeYard)
    }

    /// Breite zu Höhe des Ausschnitts.
    var seitenverhaeltnis: Double {
        (querBreite + 2 * rand) / (vorne + hinten)
    }

    /// Derselbe Ausschnitt, aber quer nur so breit wie nötig.
    ///
    /// Dieselbe Regel wie `render.querfenster_fuer`, samt der
    /// wichtigsten Zeile darin: **Auf einem Flagfeld passiert hier
    /// nichts.** Nicht, weil es zufällig so herauskäme, sondern weil es
    /// ausdrücklich abgeschnitten wird -- sonst hätte ein Flag-Play,
    /// bei dem alle zwischen 5 und 20 Yards stehen, plötzlich einen
    /// anderen Ausschnitt als gestern.
    ///
    /// **Nicht im Editor benutzen.** Wer zeichnet, muss einen Spieler
    /// an die Seitenlinie ziehen können, und was nicht im Bild ist,
    /// erreicht kein Finger. Der Server hält es genauso: Der Ausdruck
    /// schneidet, der Editor nicht.
    func querPassendFuer(_ zeichnung: Zeichnung) -> Projektion {
        guard Double(feld.breite) > Feld.maxBreite else { return self }
        let werte = zeichnung.querwerte
        guard !werte.isEmpty else { return self }
        let von = max(0, werte.min()! - Projektion.querSaum)
        let bis = min(Double(feld.breite), werte.max()! + Projektion.querSaum)
        guard bis - von >= 1 else { return self }
        var neu = Projektion(feld: feld, los: los, richtung: richtung,
                             hinten: hinten, vorne: vorne, rand: rand,
                             spielform: spielform, querVon: von, querBis: bis)
        neu.zoom = zoom
        neu.versatz = versatz
        return neu
    }

    /// Luft neben dem äussersten Punkt, quer. Dieselben vier Yards wie
    /// `querfenster_fuer(rand=4.0)`.
    static let querSaum = 4.0

    /// Weitet den Ausschnitt, bis er die Fläche AUSFÜLLT.
    ///
    /// Niklas am 01.09.2026, mit einem magentafarbenen Kringel um den
    /// schwarzen Rand herum: „das feld an bildschirmränder angepasst
    /// werden sollte [...] da ist halt super viel platz."
    ///
    /// **Der Maßstab ändert sich dabei nicht.** Ein Yard bleibt so viele
    /// Bildpunkte wie vorher -- die Figuren werden nicht größer, es kommt
    /// mehr Rasen dazu. Genau das ist gemeint: Ein Telefon ist hochkant,
    /// der Ausschnitt von 30 Yards ist quer, und was dazwischen bleibt,
    /// war bisher schwarz. Ein Spielfeld, das am Bildschirmrand aufhört,
    /// sieht aus wie ein Spielfeld; eines mit Balken sieht aus wie ein
    /// Fehler.
    ///
    /// **Nur so weit, wie Feld da ist.** Hinter der Endzone ist nichts,
    /// was sich zeigen ließe; was dort nicht hingeht, wird der anderen
    /// Seite gegeben. Reicht das Feld nicht, bleibt ein Rest schwarz --
    /// das ist ehrlicher, als Linien zu erfinden.
    func gedehnt(auf groesse: CGSize) -> Projektion {
        guard groesse.width > 0, groesse.height > 0 else { return self }
        let quer = Double(feld.breite) + 2 * rand
        let laengs = vorne + hinten
        guard quer > 0, laengs > 0 else { return self }
        let gebraucht = quer * Double(groesse.height) / Double(groesse.width)
        guard gebraucht > laengs else { return self }

        // Wie viel Feld in jede Richtung überhaupt noch kommt. Die
        // Offense greift nach oben an, also liegt „vorne" bei Richtung +1
        // zum Feldende hin und bei -1 zum Nullpunkt.
        let vorPlatz = max(0, richtung >= 0
                           ? Double(feld.gesamtLaenge) - los : los)
        let hintenPlatz = max(0, richtung >= 0
                              ? los : Double(feld.gesamtLaenge) - los)
        let uebrig = gebraucht - laengs

        // Wie viel jede Seite ueberhaupt noch DAZUnehmen darf.
        //
        // Nicht zu verwechseln mit dem Platz: Liegt die LOS naeher als
        // 22 Yards vor dem Feldende, reicht der Ausschnitt schon
        // ungedehnt darueber hinaus -- das ist so, seit es das feste
        // Fenster gibt, und im Ausdruck genauso. Dann ist eben nichts
        // mehr dazuzunehmen.
        let vorErlaubt = max(0, vorPlatz - vorne)
        let hintenErlaubt = max(0, hintenPlatz - hinten)

        // Anteilig zum bisherigen Ausschnitt: Die LOS soll ungefähr da
        // bleiben, wo das Auge sie erwartet, statt in die Bildmitte zu
        // rutschen.
        var nachVorne = uebrig * vorne / laengs
        var nachHinten = uebrig - nachVorne

        // WEITERGEREICHT WIRD, WAS TATSAECHLICH ABGEZOGEN WURDE -- und
        // das ist der Fehler, den der Laeufer am 01.09.2026 gefunden
        // hat. Vorher stand hier die Ueberschreitung von `vorne`, also
        // ein Stueck, das nie in `nachVorne` steckte. Bei Richtung -1
        // dicht an der Torlinie wurde der Ausschnitt dadurch GROESSER
        // als gebraucht (91 statt 85,4 Yards), und dann begrenzt die
        // Hoehe den Massstab: Das Feld waere kleiner geworden statt
        // groesser. Genau umgekehrt zum Zweck der Sache.
        if nachVorne > vorErlaubt {
            nachHinten += nachVorne - vorErlaubt
            nachVorne = vorErlaubt
        }
        if nachHinten > hintenErlaubt {
            nachVorne = min(vorErlaubt,
                            nachVorne + (nachHinten - hintenErlaubt))
            nachHinten = hintenErlaubt
        }
        var neu = Projektion(feld: feld, los: los, richtung: richtung,
                             hinten: hinten + nachHinten,
                             vorne: vorne + nachVorne, rand: rand,
                             spielform: spielform,
                             querVon: querVon, querBis: querBis)
        neu.zoom = zoom
        neu.versatz = versatz
        return neu
    }

    // MARK: - Auf den Bildschirm

    /// Der Faktor, mit dem der Ausschnitt in eine Fläche passt, und die
    /// Verschiebung dazu.
    ///
    /// Getrennt von `zuBild`, weil beides verschiedene Fragen sind: Der
    /// Maßstab des Feldes ist fest, die Größe des Bildschirms nicht.
    /// Zusammengelegt wäre jede Zeichenfunktion von der Fenstergröße
    /// abhängig, und der Vergleich mit Python ginge nicht mehr.
    func aufFlaeche(_ groesse: CGSize) -> (faktor: Double, versatz: CGPoint) {
        let kasten = ausschnitt
        guard kasten.width > 0, kasten.height > 0,
              groesse.width > 0, groesse.height > 0 else {
            return (1, .zero)
        }
        // DER ZOOM SITZT HIER (R110.6), an der einen Stelle, an der
        // die Projektion den Bildschirm trifft. Damit stimmen Zeichnen
        // und Finger von selbst: `aufBildschirm` und `vomBildschirm`
        // gehen beide hier durch.
        let grund = min(Double(groesse.width) / Double(kasten.width),
                        Double(groesse.height) / Double(kasten.height))
        let faktor = grund * max(Projektion.zoomMin,
                                 min(Projektion.zoomMax, zoom))
        // Mittig: Was übrig bleibt, wird links und rechts gleich verteilt.
        let breite = Double(kasten.width) * faktor
        let hoehe = Double(kasten.height) * faktor
        let geklemmt = geklemmterVersatz(faktor: faktor, groesse: groesse)
        return (faktor,
                CGPoint(x: (Double(groesse.width) - breite) / 2
                           - Double(kasten.minX) * faktor
                           + Double(geklemmt.x),
                        y: (Double(groesse.height) - hoehe) / 2
                           - Double(kasten.minY) * faktor
                           + Double(geklemmt.y)))
    }

    /// Wie weit sich der Ausschnitt ueberhaupt schieben laesst (R110.6).
    ///
    /// **Nur so weit, wie ueber den Rand hinaus etwas da ist.** Wer
    /// weiter schieben darf, hat irgendwann eine schwarze Flaeche vor
    /// sich und weiss nicht, wo das Feld geblieben ist -- und der Weg
    /// zurueck ist dann Raten. Bei `zoom == 1` ist die Grenze null: Da
    /// passt ohnehin alles ins Bild.
    func versatzgrenze(faktor: Double, groesse: CGSize) -> CGPoint {
        let kasten = ausschnitt
        let breite = Double(kasten.width) * faktor
        let hoehe = Double(kasten.height) * faktor
        return CGPoint(x: max(0, (breite - Double(groesse.width)) / 2),
                       y: max(0, (hoehe - Double(groesse.height)) / 2))
    }

    /// Der Versatz, auf das Erlaubte gestutzt.
    func geklemmterVersatz(faktor: Double, groesse: CGSize) -> CGPoint {
        let grenze = versatzgrenze(faktor: faktor, groesse: groesse)
        return CGPoint(
            x: min(max(Double(versatz.x), -Double(grenze.x)),
                   Double(grenze.x)),
            y: min(max(Double(versatz.y), -Double(grenze.y)),
                   Double(grenze.y)))
    }

    /// Ein Feldpunkt direkt auf dem Bildschirm.
    func aufBildschirm(x: Double, y: Double, groesse: CGSize) -> CGPoint {
        let (faktor, versatz) = aufFlaeche(groesse)
        let punkt = zuBild(x: x, y: y)
        return CGPoint(x: Double(punkt.x) * faktor + Double(versatz.x),
                       y: Double(punkt.y) * faktor + Double(versatz.y))
    }

    /// Ein Bildschirmpunkt zurück in Yards. Der Weg des Fingers.
    func vomBildschirm(_ punkt: CGPoint, groesse: CGSize)
        -> (x: Double, y: Double) {
        let (faktor, versatz) = aufFlaeche(groesse)
        guard faktor > 0 else { return (los, Double(feld.breite) / 2) }
        return zuFeld(CGPoint(x: (Double(punkt.x) - Double(versatz.x)) / faktor,
                              y: (Double(punkt.y) - Double(versatz.y)) / faktor))
    }
}

// MARK: - Der Zeichenfang

extension Projektion {

    /// Rastet einen Punkt an halbe Yards -- **magnetisch, nicht rastend.**
    ///
    /// Niklas am 27.08.2026: „Punkte werden gesetzt, wo getippt wird,
    /// nicht im Raster." Vorher landete JEDER Punkt auf dem halben Yard;
    /// wer 3,2 wollte, bekam 3,0.
    ///
    /// Der alte Grund bleibt wahr, deshalb ist der Fang nicht ersatzlos
    /// weg: Ohne ihn fängt man Zittern ein, und im Ausdruck sieht man
    /// das. Knapp an einer Marke rastet es, weiter weg bleibt der Punkt
    /// liegen.
    ///
    /// **Warum kaufmännisch zur geraden Zahl** (`.toNearestOrEven`): Der
    /// Server rundet mit Pythons `round()`, und das rundet 4,5 auf 4, nicht
    /// auf 5. Wer hier anders rundet, verschiebt bei jedem Speichern
    /// Aufstellungen um einen halben Yard -- und zwar genau die
    /// Aufstellungen, die auf dem Raster liegen, also fast alle. Dieselbe
    /// Falle wie bei `Feld.yardLinie`.
    ///
    /// GENAU SO WIE IM BROWSER (`aufRaster` in `editor.js`). Wären die
    /// Magnetweiten hier andere, hätte dieselbe Geste im Browser eine
    /// gerade Route und in der App eine krumme.
    static func fangen(_ wert: Double) -> Double {
        let schritte = (wert / Feld.fangYards).rounded(.toNearestOrEven)
        let marke = schritte * Feld.fangYards
        return abs(wert - marke) <= Feld.fangMagnetYards ? marke : wert
    }

    /// Rastet einen Feldpunkt und hält ihn im Feld.
    func fangen(x: Double, y: Double) -> (x: Double, y: Double) {
        feld.begrenzen(x: Projektion.fangen(x), y: Projektion.fangen(y))
    }

    /// Hält einen Spieler auf SEINER Seite der Line of Scrimmage.
    ///
    /// **Die Regel.** Vor dem Snap steht die Offense hinter der Linie,
    /// die Defense davor. Niemand darf die neutrale Zone überqueren --
    /// das ist Grundregel, und ein Play, der sie verletzt, ist auf dem
    /// Platz eine Strafe.
    ///
    /// **AUF der Linie ist erlaubt.** Der Center steht am Ball.
    ///
    /// Dieselbe Rechnung wie `schema.eigene_seite` auf dem Server und
    /// `aufEigenerSeite` im Browser. Drei Stellen, eine Regel -- ein
    /// Test misst sie gegeneinander, sonst zieht das Telefon anders als
    /// der Browser und der Spieler springt beim Sichern.
    func aufEigenerSeite(_ x: Double,
                         seite: Zeichnung.Spieler.Seite) -> Double {
        let vor = (x - los) * Double(richtung)
        if seite == .defense { return vor >= 0 ? x : los }
        return vor <= 0 ? x : los
    }

    /// Rasten, im Feld halten UND auf der eigenen Seite lassen.
    ///
    /// Die Reihenfolge zählt: erst ins Feld, dann auf die Seite. Sonst
    /// schöbe das Feld einen Spieler wieder über die Linie, wenn die LOS
    /// nahe am Rand liegt.
    func fangen(x: Double, y: Double,
                seite: Zeichnung.Spieler.Seite) -> (x: Double, y: Double) {
        let imFeld = fangen(x: x, y: y)
        return (aufEigenerSeite(imFeld.x, seite: seite), imFeld.y)
    }

    /// Rastet eine Strecke an 45 Grad und an halbe Yards, magnetisch.
    ///
    /// **Erst die Richtung, dann die Länge**, und genau in dieser
    /// Reihenfolge: Andersherum zöge das Raster den Winkel wieder krumm.
    /// Go, Out, Slant und Post liegen genau auf diesen acht Richtungen,
    /// und eine Route über 12,5 Yards ist eine Ansage -- eine über
    /// 12,31 Yards ist ein Zittern.
    ///
    /// GENAU SO WIE IM BROWSER. `gefangeneRichtung` in `editor.js` rundet
    /// die Länge mit aufs Raster. Bliebe sie hier stehen, hätte dieselbe
    /// Geste im Browser eine gerade Route und in der App eine krumme --
    /// und der Unterschied fiele erst nebeneinander auf.
    func fangenAufWinkel(von: (x: Double, y: Double),
                         nach: (x: Double, y: Double))
        -> (x: Double, y: Double) {
        let dx = nach.x - von.x
        let dy = nach.y - von.y
        let laenge = (dx * dx + dy * dy).squareRoot()
        // Ohne Länge gibt es keine Richtung, die sich rasten ließe.
        guard laenge >= Feld.fangYards / 2 else { return von }

        // Derselbe Magnet für den Winkel, nur enger: Ein Slant läuft auf
        // 43 oder 47 Grad und soll dort bleiben dürfen -- wer aber 44,5
        // zieht, meinte 45. Ein schiefer Winkel fällt im Ausdruck auf,
        // eine schiefe Position nicht.
        let schritt = Feld.fangGrad * .pi / 180
        let roh = atan2(dy, dx)
        let marke = (roh / schritt).rounded() * schritt
        let abstand = abs(roh - marke) * 180 / .pi
        let winkel = abstand <= Feld.fangMagnetGrad ? marke : roh
        // Mindestens ein Rasterschritt: Sonst fiele eine kurze Strecke auf
        // die Länge null zurück, und der Punkt läge auf seinem Vorgänger.
        let weite = max(Feld.fangYards, Projektion.fangen(laenge))
        return feld.begrenzen(x: von.x + cos(winkel) * weite,
                              y: von.y + sin(winkel) * weite)
    }
}
