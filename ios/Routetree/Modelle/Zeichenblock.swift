// Der Zeichenblock: was passiert, wenn ein Finger das Feld berührt.
//
// WARUM DAS NICHT IN DER ANSICHT STEHT. Es gibt keinen Mac. Jede
// Swift-Zeile wird auf einem Läufer übersetzt, und eine Rückmeldung
// dauert eine halbe Stunde -- eine Regel, die nur in einer SwiftUI-Ansicht
// steht, lässt sich in dieser Zeit nicht messen, sondern nur behaupten.
// Hier steht deshalb alles, was entscheidet: Treffererkennung, Fang,
// wann eine Linie fertig ist, welche sie ersetzt. Die Ansicht zeichnet
// nur noch, was hier herauskommt, und `ZeichenblockTests` misst es.
//
// DAS VORBILD IST `editor.js`, und zwar bis in die Ausnahmen: Ein Tipp
// auf einen ANDEREN Spieler schließt die angefangene Linie ab und beginnt
// eine neue bei ihm (sonst laufen Linien quer durch die Aufstellung).
// Jede Position hat genau EINE Linie, eine neue ersetzt die alte. Zonen
// brauchen drei Punkte, alles andere zwei. Wer eines davon hier ändert,
// muss es dort mitändern -- sonst zeichnet dieselbe Geste auf dem Handy
// etwas anderes als im Browser.

import CoreGraphics
import Foundation

/// Zeichnung, Werkzeug und die angefangene Linie -- ein Wert, kein Objekt.
struct Zeichenblock: Equatable {

    /// Was der nächste Fingertipp bedeutet.
    enum Werkzeug: Equatable {
        /// Anfassen und verschieben, nichts entsteht.
        case auswahl
        /// Eine Linie dieser Art zeichnen.
        case linie(Zeichnung.Linie.Art)

        /// Wie das Werkzeug in der Bedienspur heisst (R86). Kurz und
        /// unveränderlich -- eine Auswertung über zwei Wochen ist
        /// wertlos, wenn das Wort dazwischen ein anderes wurde.
        var spurname: String {
            switch self {
            case .auswahl: return "auswahl"
            case .linie(let art): return art.rawValue
            }
        }
    }

    /// Was gerade angetippt ist. Ein Spieler zeigt seine Position, eine
    /// Linie ihr Ende zur Auswahl.
    enum Auswahl: Equatable {
        case spieler(String)
        /// Die Stelle in `zeichnung.linien`. Sie wandert, wenn eine Linie
        /// wegfällt -- deshalb wird sie überall geprüft, bevor sie
        /// benutzt wird.
        case linie(Int)
    }

    var zeichnung: Zeichnung
    /// Für den Fang und die Treffererkennung. Beides braucht das Feld und
    /// die Blickrichtung, sonst rechnet die App an der LOS vorbei.
    var projektion: Projektion
    /// Die beiden Stapel hinter „Rückgängig" und „Wiederholen".
    private(set) var verlauf = Verlauf()
    /// Der Stand, mit dem der laufende Zug angefangen hat, und ob er
    /// schon einen Schritt im Verlauf hat. Siehe `anfassen`.
    private var zugStand: Verlauf.Stand?

    /// Name, Nummer, Seite, Kategorie, Situationen, Hinweise (R110.7).
    ///
    /// **Sie wohnen hier, seit sie in den Verlauf gehoeren.** Vorher
    /// lagen sie als `@State` in `EditorAnsicht`; der Verlauf liegt
    /// aber im Block, und ein Rueckgaengig, das die Zeichnung
    /// zuruecknimmt und die Umbenennung stehen laesst, ist genau das
    /// halbe Rueckgaengig, gegen das `Verlauf.swift` seit dem ersten
    /// Tag anschreibt.
    var angaben = Playangabenstand()
    private var zugGemerkt = false
    private(set) var werkzeug: Werkzeug = .auswahl

    /// Welche FORM eine neue Zone bekommt (R48).
    ///
    /// Nach demselben Muster wie `kurve` daneben und aus demselben
    /// Grund: Es ist eine Einstellung für die nächste Linie und keine
    /// eigene Art. Der Server kennt eine Art `zone` mit einer Form, und
    /// ein zweites Werkzeug je Form hiesse, die Aufzählung `Werkzeug` an
    /// jeder Stelle im Block aufzubohren, an der sie gemustert wird.
    ///
    /// Gilt nur beim Zeichnen einer Zone. Bei jeder anderen Art bleibt
    /// die Form `.linie` -- eine Route mit einer Fläche wäre eine
    /// Behauptung über etwas, das keine Fläche ist.
    private(set) var zonenform: Zeichnung.Linie.Zonenform = .linie

    /// Stellt die Form für neue Zonen um.
    ///
    /// AUCH DIE ANGEFANGENE LINIE, wie beim Rundungsschalter: Wer eine
    /// Zone anfängt und dann sieht, dass sie rund werden soll, bekäme
    /// sonst erst bei der nächsten etwas zu sehen.
    mutating func zonenformSetzen(_ neu: Zeichnung.Linie.Zonenform) {
        spur("editor", "zonenform", neu.rawValue)
        zonenform = neu
        if entwurf?.art == .zone {
            entwurf?.zonenform = neu
            // Kreis und Rechteck stehen mit zwei Punkten fest. Wer von
            // einem angefangenen Vieleck umschaltet, behält die ersten
            // beiden -- der Rest wäre bedeutungslos und stünde nur im
            // Weg, wenn er später zurückschaltet.
            if neu != .linie, let viele = entwurf?.punkte, viele.count > 2 {
                entwurf?.punkte = Array(viele.prefix(2))
            }
        }
    }
    /// Ob NEUE Linien weich gerundet werden.
    ///
    /// Gemeldet als R7 (Cyell) und R12 (Niklas): „wie ist das wenn man
    /// eine wheel route machen will das geht auch nicht". Eine Wheel
    /// läuft flach nach außen und dann in einem BOGEN nach oben -- mit
    /// eckigen Segmenten wird daraus ein Out mit angesetztem Go, und das
    /// läuft ein Spieler anders.
    ///
    /// Der Browser hat diesen Schalter seit jeher (`kurve` in
    /// `editor.js`, Taste K). Die App hatte ihn nicht: `gebogen` kam
    /// bisher nur aus dem Browser, anlegen konnte die App es nicht.
    private(set) var kurve = false
    /// Die Linie im Entstehen. Sie liegt NICHT in der Zeichnung: Ein
    /// halber Weg, der schon gespeichert werden kann, ist ein halber Weg
    /// im Playbook.
    private(set) var entwurf: Zeichnung.Linie?
    /// Ob der Zeichenfang greift: halbe Yards und 45-Grad-Schritte.
    ///
    /// Gemeldet als R5 (Cyell, 25.08.2026): „man kann nicht frei
    /// eingeben. Sie werden oft zu einem Punkt gezogen, wo man ihn nicht
    /// hin haben möchte." Der Fang ist Absicht -- ohne ihn steht eine von
    /// Hand gezogene Aufstellung auf krummen Zehntelyards, und im
    /// Ausdruck sieht man jede schiefe Linie. Nur war er bis dahin ohne
    /// Ausweg: Der Browser hat seit jeher einen Knopf (Taste F) und die
    /// Umschalttaste, die ihn kurz aufhebt; die App hatte NICHTS.
    /// `Projektion.fangen` lief unbedingt, an jeder Stelle.
    ///
    /// Am Telefon gibt es keine Umschalttaste. Deshalb hier ein
    /// Schalter, und deshalb sagt die Fußzeile, welcher Stand gilt --
    /// wer nicht weiß, dass es einen Fang gibt, hält das Wandern des
    /// Punktes für einen Fehler.
    private(set) var fang = true
    /// Der Punkt unter dem Finger, solange er aufliegt. Nur Vorschau.
    private(set) var zeiger: Zeichnung.Punkt?
    private(set) var auswahl: Auswahl?
    /// Wie oft die Zeichnung sich geändert hat.
    ///
    /// WARUM GEZÄHLT WIRD UND NICHT NUR JA/NEIN VERMERKT. Gemeldet am
    /// 25.08.2026 von Cyell: „Routen werden manchmal nicht gespeichert."
    /// Nachgemessen im Browser mit `scripts/_probe_r4.py`, und die App
    /// hatte dieselbe Stelle: Wer während einer laufenden Speicheranfrage
    /// weiterzeichnet, bekam hinterher „Gesichert" zu lesen -- die
    /// Antwort galt aber dem Stand, der losgeschickt worden war, und von
    /// dem, was inzwischen dazugekommen ist, weiß der Server nichts.
    ///
    /// Ein `Bool` kann das nicht auseinanderhalten. Eine Nummer schon:
    /// Beim Absenden merken, beim Eintreffen vergleichen. Nur wenn sie
    /// gleich ist, liegt genau das am Server, was auf dem Schirm steht.
    ///
    /// Am Schreibtisch fällt das nie auf; im Mobilfunk am Platz dauert
    /// eine Anfrage über eine Sekunde, und genau dort wird gezeichnet.
    private(set) var stand = 0
    /// Der Stand, der nachweislich am Server liegt.
    private var gesichertBis = 0
    /// Ungesicherte Änderungen. Ohne diese Angabe wüsste niemand, ob das
    /// Verlassen der Seite etwas kostet.
    var geaendert: Bool { stand != gesichertBis }
    /// Ein Satz für die Fußzeile, wenn etwas passiert ist, das man sonst
    /// nicht sieht -- etwa dass eine bestehende Linie ersetzt wurde.
    ///
    /// **Sie geht von selbst wieder weg (R75).** Bis zum 06.09.2026
    /// blieb sie stehen, bis zufällig etwas anderes passierte -- und
    /// seit R62 bricht sie um, steht also auf einem Telefon über drei
    /// Zeilen. Das sind bis zu vierundfünfzig Punkte, die dem Feld
    /// dauerhaft fehlen, für eine Auskunft, die einmal galt.
    ///
    /// Weggeräumt wird sie NICHT hier: Der Block kennt keine Zeit, und
    /// ein Wecker in einer `struct` wäre einer je Kopie. Die Ansicht
    /// hängt eine Aufgabe an `meldungsstand` und ruft `melden(nil)`.
    ///
    /// **`didSet` UND NICHT EIN ZÄHLER IN `melden`.** Der Block setzt
    /// diesen Satz an fünfzehn Stellen direkt zu -- „Diese Linie hat
    /// genug Ecken.", „Mehr Linien nimmt ein Play nicht auf." und so
    /// fort. Zählte nur `melden` mit, blieben genau diese fünfzehn
    /// stehen, und zwar unbemerkt: Die Meldung erscheint ja, sie geht
    /// nur nie wieder weg. Am `didSet` hängt jede Zuweisung.
    private(set) var meldung: String? {
        didSet { if meldung != nil { meldungsstand &+= 1 } }
    }

    /// Zählt bei jeder NEUEN Meldung hoch.
    ///
    /// **Warum nicht einfach auf `meldung` gewartet wird:** Zwei
    /// gleiche Sätze hintereinander („Diese Linie hat genug Ecken.")
    /// sind für SwiftUI derselbe Wert -- die Aufgabe liefe nicht neu
    /// an, und die zweite Meldung verschwände zusammen mit der ersten,
    /// also womöglich sofort.
    private(set) var meldungsstand = 0

    /// Griffweite um einen Spieler, in Bildschirmpunkten. Apples Mindestmaß
    /// für eine Zielfläche ist 44; der Kreis ist kleiner, also wird der
    /// Griff größer gemacht als das Bild.
    static let griff: Double = 26
    /// Dasselbe für eine Linie. Enger als beim Spieler, weil sonst jede
    /// Linie den Spieler überdeckt, an dem sie hängt.
    static let linienGriff: Double = 18

    // MARK: - Der Fang

    /// Schaltet den Fang um. Gilt für alles, was danach gesetzt oder
    /// gezogen wird -- er ist eine Gewohnheit, keine Eigenschaft des
    /// Plays, und wird deshalb auch nicht mitgespeichert.
    ///
    /// **Kurz, und trotzdem nicht falsch (R67).** Niklas am 03.09.2026:
    /// „Kurze prägnante Beschreibung, halbe Yards + 45 grad Winkel."
    /// Dastand ein Satz über zwei Zeilen, für eine Anzeige, die nur
    /// sagt, was gerade gilt.
    ///
    /// **Das Wort „rasten" trägt dabei die ganze Last.** Der Fang ist
    /// magnetisch (`Projektion.fangen`, dieselbe Regel wie `fang.py`
    /// auf dem Server): Nur was knapp an einer Marke sitzt, rastet ein,
    /// alles andere bleibt liegen. Die ganz alte Meldung hiess „halbe
    /// Yards und 45-Grad-Schritte" und klang wie ein Zwang -- wer sie
    /// las und dann 3,2 Yards zeichnete, hielt das Ergebnis für einen
    /// Fehler. „Rasten ein" sagt in zwei Wörtern, dass es ein Angebot
    /// ist und keine Vorschrift.
    mutating func fangUmschalten() {
        spur("editor", "fang", fang ? "aus" : "an")
        fang = !fang
        meldung = fang
            // EIN Literal, nicht zwei zusammengesetzte. `appsprache.py`
            // liest den Text aus dem Quelltext; ein `"a" + "b"` ist für
            // den Extraktor kein Satz, und die Meldung bliebe in jeder
            // Sprache deutsch -- ohne dass irgendwo ein Fehler stünde.
            ? String(localized: "Fang an: halbe Yards und 45 Grad rasten ein.")
            : String(localized: "Fang aus: Punkte bleiben, wo der Finger war.")
    }

    /// Rastet einen Punkt -- oder eben nicht.
    ///
    /// **Ins Feld gehalten wird IMMER**, auch bei ausgeschaltetem Fang.
    /// Das ist kein Fang, sondern eine Grenze: Der Server nimmt nichts
    /// außerhalb des Feldes an (`Field.clamp`), und ein Punkt, der beim
    /// Speichern von selbst zurückspringt, ist schlimmer als einer, der
    /// gar nicht erst hinauskommt.
    func fangen(x: Double, y: Double) -> (x: Double, y: Double) {
        fang ? projektion.fangen(x: x, y: y) : projektion.feld.begrenzen(x: x, y: y)
    }

    /// Dasselbe für eine Figur: zusätzlich auf ihrer Seite der LOS.
    ///
    /// Die Seitenregel gilt AUCH ohne Fang. Sie ist Spielregel und nicht
    /// Zeichenhilfe -- ein Play, in dem die Offense vor der Linie steht,
    /// ist auf dem Platz eine Strafe (R1).
    func fangen(x: Double, y: Double,
                seite: Zeichnung.Spieler.Seite) -> (x: Double, y: Double) {
        guard fang else {
            let imFeld = projektion.feld.begrenzen(x: x, y: y)
            return (projektion.aufEigenerSeite(imFeld.x, seite: seite),
                    imFeld.y)
        }
        return projektion.fangen(x: x, y: y, seite: seite)
    }

    /// Der Ausschnitt, BEVOR ein Bildschirm ihn geweitet hat.
    ///
    /// Ohne ihn dehnte jede Größenänderung den schon gedehnten Ausschnitt
    /// weiter, und das Feld liefe bei jeder Drehung des Telefons aus dem
    /// Bild.
    private var grundProjektion: Projektion

    init(zeichnung: Zeichnung, projektion: Projektion) {
        self.zeichnung = zeichnung
        self.projektion = projektion
        self.grundProjektion = projektion
    }

    /// Sagt dem Block, wie groß die Zeichenfläche ist.
    ///
    /// **Hier und nirgends sonst**, damit Zeichnen und Tippen denselben
    /// Ausschnitt meinen. Dehnte nur die Ansicht, läge die Figur woanders
    /// als der Finger sie sucht -- und zwar umso weiter daneben, je
    /// größer der schwarze Rand war.
    mutating func flaecheSetzen(_ groesse: CGSize) {
        let neu = grundProjektion.gedehnt(auf: groesse)
        if neu != projektion { projektion = neu }
    }

    // MARK: - Werkzeug

    /// Wechselt das Werkzeug.
    ///
    /// Eine angefangene Linie wird ÜBERNOMMEN und nicht weggeworfen: Wer
    /// mitten im Zeichnen merkt, dass es eine Motion und keine Route ist,
    /// soll umschalten können, ohne von vorn anzufangen.
    ///
    /// **Und der Weg zur Auswahl SCHLIESST sie ab, statt sie zu
    /// verwerfen (R92).** Niklas am 09.09.2026: „wenn man z.b. 2 punkte
    /// zeichnet und denn auf auswahl geht das es denn automatisch
    /// gespeichert wird weißt du?"
    ///
    /// Er hat recht, und vorher stand hier `entwurf = nil`: Zwei
    /// gesetzte Punkte, ein Tipp auf „Auswahl", und der Weg war
    /// kommentarlos weg. Das ist dieselbe Falle wie in R4 („meine Route
    /// wurde nicht gespeichert"), nur an einer anderen Stelle.
    ///
    /// `abschliessen()` entscheidet, was damit passiert: Ein
    /// vollständiger Weg wird übernommen, ein unvollständiger sagt,
    /// warum nicht. Beides ist besser als stilles Verschwinden.
    mutating func werkzeugSetzen(_ neu: Werkzeug) {
        spur("editor", "werkzeug", neu.spurname)
        werkzeug = neu
        meldung = nil
        switch neu {
        case .auswahl:
            if entwurf != nil { abschliessen() }
            entwurf = nil
            zeiger = nil
        case .linie(let art):
            if entwurf == nil, let spieler = ausgewaehlterSpieler {
                // WER AUSGEWÄHLT IST, HAT DEN WEG SCHON ANGEFANGEN.
                //
                // Niklas am 01.09.2026: „wnen man auf den spieler tippt
                // und denn auf route das die route dann automatisch bei
                // dem spieler auch beginnt und man nicht einfach mitten
                // irgendwo im feld anfängt."
                //
                // Vorher war der Tipp auf die Figur folgenlos: Das
                // Werkzeug fing erst beim NÄCHSTEN Tipp an, und der lag
                // dann irgendwo im Feld. Der Weg begann im Nichts, und
                // der Spieler lief aus dem Stand woanders los.
                beginnen(art: art, bei: spieler)
            } else {
                entwurf?.art = art
                entwurf?.ende = art.stil.standardEnde
            }
        }
    }

    // MARK: - Rückgängig und Wiederholen

    var kannRueckgaengig: Bool { verlauf.kannZurueck }
    var kannWiederherstellen: Bool { verlauf.kannVorwaerts }

    /// Legt den jetzigen Stand ab, BEVOR er sich ändert.
    ///
    /// Aufgerufen wird das an jeder Stelle, die die Zeichnung anfasst,
    /// und zwar erst hinter allen Prüfungen: Ein Schritt im Verlauf für
    /// eine Änderung, die gar nicht stattgefunden hat, ist ein
    /// Der ganze Arbeitsstand -- Zeichnung UND Lage des Balls
    /// (R110.3/R110.7).
    ///
    /// An einer Stelle und nicht an jeder Aufrufstelle zusammengesetzt:
    /// Kommt ein Feld dazu, kommt es hier dazu, und keine der elf
    /// Stellen, die `merken()` rufen, kann es vergessen.
    var jetzigerStand: Verlauf.Stand {
        Verlauf.Stand(zeichnung: zeichnung,
                      los: projektion.los,
                      richtung: projektion.richtung,
                      angaben: angaben)
    }

    /// Und zurück. Die Gegenrichtung gehört daneben: Wer eine Hälfte
    /// hinzufügt und die andere vergisst, baut genau das Rückgängig,
    /// das nur die Hälfte zurücknimmt.
    private mutating func standSetzen(_ neu: Verlauf.Stand) {
        zeichnung = neu.zeichnung
        projektion.los = neu.los
        projektion.richtung = neu.richtung
        angaben = neu.angaben
    }

    /// Einen geretteten Entwurf uebernehmen (R110.4).
    ///
    /// **EIN Schritt im Verlauf.** Wer sich vertut und den falschen
    /// Stand zurueckholt, kommt mit einem Druck wieder heraus -- eine
    /// Wiederherstellung, die sich nicht zuruecknehmen laesst, ist
    /// dieselbe Sackgasse wie ein Loeschen ohne Rueckfrage.
    ///
    /// Der Entwurf traegt ALLES, was der Verlauf traegt; er wird
    /// deshalb ueber `standSetzen` eingespielt und nicht Feld fuer
    /// Feld -- so kann keins vergessen werden.
    mutating func entwurfUebernehmen(zeichnung neu: Zeichnung, los: Double,
                                     richtung: Int,
                                     angaben neueAngaben: Playangabenstand) {
        spur("editor", "entwurf_zurueck")
        merken()
        standSetzen(Verlauf.Stand(zeichnung: neu, los: los,
                                  richtung: richtung,
                                  angaben: neueAngaben))
        stand += 1
        auswahl = nil
        melden(String(localized: "Der ungesicherte Stand ist zurück."))
    }

    /// Die Playangaben in den Verlauf aufnehmen (R110.7).
    ///
    /// **EIN Schritt je Bearbeitung und nicht je Tastendruck.** Das
    /// Blatt schreibt laufend in `angaben`; ein Verlauf, der jeden
    /// Buchstaben aufnimmt, ist beim Zurueckgehen nutzlos -- man
    /// drueckt zwanzigmal und ist beim ersten Buchstaben des Namens.
    /// Der Editor ruft das deshalb beim SCHLIESSEN des Blattes, mit
    /// dem Stand von vorher.
    ///
    /// Hat sich nichts geaendert, passiert nichts: Ein Schritt, der
    /// nichts zurueckzunehmen hat, ist einer, den man umsonst
    /// drueckt.
    mutating func angabenGemerkt(vorher: Playangabenstand) {
        guard vorher != angaben else { return }
        var alt = jetzigerStand
        alt.angaben = vorher
        verlauf.merken(alt)
        stand += 1
    }

    /// Rückgängig, das nichts tut. Zweimal gedrückt käme dann die
    /// vorletzte Änderung zurück, und niemand versteht, warum.
    private mutating func merken() {
        verlauf.merken(jetzigerStand)
    }

    /// Einen Arbeitsschritt zurück.
    mutating func rueckgaengig() {
        spur("editor", "zurueck")
        guard let alt = verlauf.zurueckgehen(von: jetzigerStand)
        else { return }
        standSetzen(alt)
        nachDemSprung()
    }

    /// Den zurückgenommenen Schritt wieder her.
    mutating func wiederherstellen() {
        spur("editor", "wieder")
        guard let neu = verlauf.vorgehen(von: jetzigerStand) else { return }
        standSetzen(neu)
        nachDemSprung()
    }

    /// Aufräumen nach einem Sprung im Verlauf.
    ///
    /// Die Auswahl geht, und das ist kein Aufräumen um des Aufräumens
    /// willen: Sie zeigt auf eine STELLE in der Linienliste, und die
    /// Liste ist gerade eine andere geworden. Ein anschließendes Löschen
    /// erwischte sonst eine Linie, die niemand angetippt hat.
    ///
    /// Der Entwurf geht aus demselben Grund: Er hängt an einem Spieler,
    /// der eben noch woanders stand.
    ///
    /// „Ungesichert" bleibt stehen, auch wenn der Sprung zufällig genau
    /// den gespeicherten Stand trifft. Lieber einmal zu viel sichern als
    /// einmal zu wenig.
    private mutating func nachDemSprung() {
        entwurf = nil
        zeiger = nil
        auswahl = nil
        zugStand = nil
        zugGemerkt = false
        meldung = nil
        stand += 1
    }

    // MARK: - Spiegeln

    /// Spiegelt die Zeichnung an der Längsachse: links wird rechts.
    ///
    // MARK: - Der Ausschnitt (R110.6)
    //
    // Am Platz steht der Trainer mit dem Telefon in der Sonne und will
    // eine Ecke des Feldes gross sehen. Der Browser kann das seit
    // Langem, die App nicht.
    //
    // NICHT IM VERLAUF. Zoom und Verschiebung sind keine Aenderung am
    // Play -- sie stehen in keinem Ausdruck und in keiner Datei. Ein
    // „Rueckgaengig", das erst den Ausschnitt zurueckdreht, bevor es an
    // die Zeichnung geht, waere ein Knopf, den man dreimal druecken
    // muss, um einmal etwas zu erreichen. Deshalb auch kein `stand +=
    // 1`: Der Play gilt danach nicht als geaendert, und der Autosave
    // bleibt still.

    /// Naeher heran oder weiter weg, um den Punkt unter dem Finger.
    ///
    /// **Um den Finger und nicht um die Mitte.** Wer auf eine Ecke
    /// zoomt, meint diese Ecke; ein Zoom auf die Bildmitte schiebt sie
    /// aus dem Bild, und man sucht sie danach wieder.
    mutating func zoomSetzen(_ neu: Double, um punkt: CGPoint? = nil,
                             groesse: CGSize) {
        let gestutzt = max(Projektion.zoomMin,
                           min(Projektion.zoomMax, neu))
        guard abs(gestutzt - projektion.zoom) > 0.0001 else { return }
        guard let punkt, groesse.width > 0, groesse.height > 0 else {
            projektion.zoom = gestutzt
            ausschnittStutzen(groesse: groesse)
            return
        }
        // WELCHER FELDPUNKT LIEGT JETZT UNTER DEM FINGER -- gelesen
        // VOR der Aenderung. Danach waere es ein anderer, und der Zoom
        // liefe von der falschen Stelle weg.
        let feldpunkt = projektion.vomBildschirm(punkt, groesse: groesse)
        projektion.zoom = gestutzt
        // Und wo laege er danach? Die Differenz ist die Verschiebung.
        let danach = projektion.aufBildschirm(x: feldpunkt.x, y: feldpunkt.y,
                                              groesse: groesse)
        projektion.versatz = CGPoint(
            x: Double(projektion.versatz.x) + Double(punkt.x) - Double(danach.x),
            y: Double(projektion.versatz.y) + Double(punkt.y) - Double(danach.y))
        ausschnittStutzen(groesse: groesse)
    }

    /// Den Ausschnitt verschieben.
    mutating func verschieben(um weg: CGSize, groesse: CGSize) {
        projektion.versatz = CGPoint(
            x: Double(projektion.versatz.x) + Double(weg.width),
            y: Double(projektion.versatz.y) + Double(weg.height))
        ausschnittStutzen(groesse: groesse)
    }

    /// Zurueck auf das ganze Feld.
    ///
    /// **Ein sichtbarer Weg zurueck gehoert dazu.** Wer sich verzoomt
    /// hat, soll nicht herausfinden muessen, wie viele Kneifbewegungen
    /// es zurueck sind (B1: keine Handlung nur als Geste).
    mutating func ausschnittZuruecksetzen() {
        projektion.zoom = 1
        projektion.versatz = .zero
    }

    /// Ob es ueberhaupt etwas zurueckzusetzen gibt.
    var ausschnittVerstellt: Bool {
        abs(projektion.zoom - 1) > 0.0001
            || abs(Double(projektion.versatz.x)) > 0.5
            || abs(Double(projektion.versatz.y)) > 0.5
    }

    /// Den Versatz auf das Erlaubte stutzen.
    ///
    /// Wer weiter schieben darf, hat irgendwann eine schwarze Flaeche
    /// vor sich und weiss nicht, wo das Feld geblieben ist.
    private mutating func ausschnittStutzen(groesse: CGSize) {
        guard groesse.width > 0, groesse.height > 0 else { return }
        let (faktor, _) = projektion.aufFlaeche(groesse)
        projektion.versatz = projektion.geklemmterVersatz(faktor: faktor,
                                                          groesse: groesse)
    }

    // MARK: - Wo der Ball liegt (R110.3)
    //
    // DIE APP KONNTE ES BIS ZUM 10.09.2026 GAR NICHT. Ein Play, der
    // nicht an der Mittellinie beginnt, liess sich am Telefon nicht
    // anlegen -- und die Mittellinie ist die Ausnahme, nicht die Regel:
    // Ein Call Sheet gliedert sich nach 3rd & lang, Red Zone und
    // No-Run-Zone, also nach der LAGE des Balls.
    //
    // DIE LOS VERSCHIEBT DIE ZEICHNUNG NICHT. Sie ist der Bezugspunkt
    // der Projektion; die Punkte der Spieler und Linien stehen in
    // absoluten Yards auf dem Feld. Der Browser macht es seit jeher
    // genauso (`zustand.los` in `editor.js`) -- eine App, die dabei
    // mitschoebe, zeigte dieselbe Zeichnung anders als der Ausdruck.

    /// Wohin die LOS darf: zwischen die beiden Torlinien.
    ///
    /// Nicht bis an den Feldrand: Hinter der Torlinie gibt es keinen
    /// Snap, und ein Regler, der dorthin reicht, bietet eine Lage an,
    /// die es im Spiel nicht gibt.
    var losBereich: ClosedRange<Double> {
        projektion.feld.torlinieLinks...projektion.feld.torlinieRechts
    }

    /// Die LOS setzen. Ausserhalb des Bereichs wird geklemmt statt
    /// abgelehnt: Ein Regler, der am Ende haengt, ist verstaendlicher
    /// als einer, der zurueckspringt.
    mutating func losSetzen(_ yard: Double, merkt: Bool = true) {
        let neu = min(max(yard, losBereich.lowerBound), losBereich.upperBound)
        guard abs(neu - projektion.los) > 0.001 else { return }
        if merkt { merken() }
        projektion.los = neu
        stand += 1
    }

    /// Die Angriffsrichtung umdrehen.
    ///
    /// **Nicht dasselbe wie Spiegeln.** Spiegeln tauscht links und
    /// rechts und laesst die Richtung stehen; hier bleibt die Zeichnung,
    /// und der Play greift die andere Endzone an. Wer beides
    /// verwechselt, bekommt eine Formation, die falsch herum steht.
    mutating func richtungWechseln() {
        spur("editor", "richtung")
        merken()
        projektion.richtung = projektion.richtung > 0 ? -1 : 1
        stand += 1
        melden(projektion.richtung > 0
               ? String(localized: "Ihr greift die rechte Endzone an.")
               : String(localized: "Ihr greift die linke Endzone an."))
    }

    /// Die Angriffsrichtung bleibt. Gerechnet wird in `Spiegelung.swift`,
    /// gemessen gegen den Server.
    mutating func spiegeln() {
        spur("editor", "spiegeln")
        guard !zeichnung.spieler.isEmpty || !zeichnung.linien.isEmpty else {
            meldung = String(localized:
                "Auf dem Feld steht nichts, was sich spiegeln ließe.")
            return
        }
        merken()
        entwurf = nil
        zeiger = nil
        auswahl = nil
        zeichnung = zeichnung.gespiegelt(breite: Double(projektion.feld.breite))
        stand += 1
        meldung = String(localized: """
            Gespiegelt. Links ist jetzt rechts, die Angriffsrichtung ist \
            geblieben.
            """)
    }

    // MARK: - Formation anwenden

    /// Eine eingebaute Vorlage anwenden (R110.5).
    ///
    /// **Geht durch `formationAnwenden`** und nicht daran vorbei: Dort
    /// steht, was mit den LINIEN passiert, wenn Figuren verschwinden
    /// oder dazukommen -- und das ist die Stelle, an der eine zweite
    /// Fassung Wege an Spieler hängen würde, die es nicht mehr gibt.
    @discardableResult
    mutating func vorlageAnwenden(_ vorlage: Modell.Vorlage,
                                  seite: Zeichnung.Spieler.Seite) -> Bool {
        let neue = seite == .defense
            ? Vorlagenblock.mitDefense(vorlage, in: zeichnung,
                                       los: projektion.los,
                                       richtung: projektion.richtung,
                                       feld: projektion.feld)
            : Vorlagenblock.mitOffense(vorlage, in: zeichnung,
                                       los: projektion.los,
                                       richtung: projektion.richtung,
                                       feld: projektion.feld)
        return formationAnwenden(neue, name: vorlage.name)
    }

    /// Die Verteidigung vom Feld nehmen (R110.5).
    ///
    /// **Der Browser hat den Knopf seit jeher.** Ohne ihn musste man
    /// fünf Figuren einzeln auswählen und löschen -- und wer eine
    /// vergisst, hat einen Play mit vier Verteidigern, was auf dem
    /// Ausdruck aussieht wie Absicht.
    @discardableResult
    mutating func defenseEntfernen() -> Bool {
        guard Vorlagenblock.hatDefense(zeichnung) else {
            meldung = String(localized: "Es steht keine Defense auf dem Feld.")
            return false
        }
        return formationAnwenden(Vorlagenblock.ohneDefense(zeichnung),
                                 name: String(localized: "ohne Defense"))
    }

    /// Übernimmt die Aufstellung einer gespeicherten Formation (B7).
    ///
    /// **DIE LINIEN GEHEN MIT (R26).** Hier stand das Gegenteil, mit
    /// Begründung: „Wer eine Formation anwendet, will denselben Play aus
    /// einer anderen Aufstellung laufen lassen." Das klingt einleuchtend
    /// und ist falsch, und Niklas hat es am 27.08.2026 gemeldet: „bei
    /// offense aufstellen eine andere Aufstellung nimmt bleiben die
    /// Routen wie sie sind nur die Kreise Wandern, die sollten aber
    /// mitwandern die Routen".
    ///
    /// Eine Linie beginnt BEIM Spieler. Bleibt sie liegen, während er
    /// geht, beginnt sie bei niemandem -- das ist kein Play aus einer
    /// anderen Aufstellung, sondern ein kaputter. Verschoben wird die
    /// ganze Linie um dieselbe Strecke: Form, Länge und Winkel bleiben,
    /// damit aus einem Slant kein Post wird.
    ///
    /// Dieselbe Regel wie im Browser (`aufstellungUebernehmen` in
    /// `editor.js`), gemessen von `test_linien_mitnehmen.py`.
    ///
    /// **Ein Schritt im Verlauf, nicht keiner und nicht fünf.** Eine
    /// Formation setzt zehn Figuren auf einmal; wer sich vertut, drückt
    /// einmal Rückgängig und hat seine alte Aufstellung zurück.
    ///
    /// Zurück kommt, ob etwas passiert ist. Eine leere Formation ändert
    /// nichts und kostet deshalb auch keinen Schritt -- sonst täte
    /// Rückgängig beim ersten Drücken nichts.
    @discardableResult
    mutating func formationAnwenden(_ aufstellung: [Zeichnung.Spieler],
                                    name: String) -> Bool {
        guard !aufstellung.isEmpty else {
            meldung = String(localized: "Diese Aufstellung ist leer.")
            return false
        }
        merken()
        entwurf = nil
        zeiger = nil
        // Die Auswahl geht, und zwar aus demselben Grund wie nach einem
        // Sprung im Verlauf: Sie zeigt auf einen Spieler, den es gerade
        // nicht mehr gibt.
        auswahl = nil
        zugStand = nil
        zugGemerkt = false

        // Zugeordnet wird über die `id`. Wen es vorher nicht gab, hat
        // keine Linie; wen die neue Aufstellung nicht mehr enthält, den
        // gibt es danach nicht mehr, und seine Linie gehört niemandem.
        var vorher: [String: (x: Double, y: Double)] = [:]
        for s in zeichnung.spieler { vorher[s.id] = (s.x, s.y) }

        // WER DABEI VERSCHWINDET, UND OB ER ETWAS LIEF (R47).
        //
        // Niklas: „Sowie dann ein Play auf andere Formationen zu
        // übertragen." Die Roadmap nennt die Bedingung dazu: „und wenn
        // die neue Formation keinen X hat, gehört das gesagt."
        //
        // Bis hierher stand darüber nur der Kommentar oben -- die
        // Linie gehörte danach niemandem, und die Meldung sagte
        // trotzdem nur „Aufstellung übernommen". Ein Trainer, der eine
        // Formation ausprobiert, verlor eine Route und erfuhr es
        // nicht.
        //
        // Gezählt werden nur die mit einer Linie: Eine Figur ohne Weg
        // ist ein Platz, der neu besetzt wird, und darüber muss
        // niemand benachrichtigt werden.
        let neueKennungen = Set(aufstellung.map(\.id))
        let verwaist = zeichnung.spieler
            .filter { !neueKennungen.contains($0.id) }
            .filter { s in zeichnung.linien.contains { $0.spieler == s.id } }
            .map { $0.rolle.isEmpty ? $0.kuerzel : $0.rolle }

        zeichnung.spieler = aufstellung
        for s in aufstellung {
            guard let alt = vorher[s.id] else { continue }
            linienMitnehmen(s.id, dx: s.x - alt.x, dy: s.y - alt.y)
        }
        stand += 1
        // EIN GANZER SATZ JE FALL (R22): „1 Weg" und „2 Wege" gehen in
        // anderen Sprachen nicht durch dieselbe Fuge, und die
        // Aufzählung der Positionen erst recht nicht.
        if verwaist.isEmpty {
            meldung = String(localized:
                "Aufstellung „\(name)“ übernommen.")
        } else if verwaist.count == 1 {
            let wer = verwaist[0]
            meldung = String(localized:
                "Aufstellung „\(name)“ übernommen. \(wer) gibt es dort nicht mehr, sein Weg hängt jetzt frei.")
        } else {
            let wer = verwaist.joined(separator: ", ")
            meldung = String(localized:
                "Aufstellung „\(name)“ übernommen. \(wer) gibt es dort nicht mehr, ihre Wege hängen jetzt frei.")
        }
        return true
    }

    /// Ein Satz für die Fußzeile, den nicht der Block ausgelöst hat.
    ///
    /// Die Ansicht hat auch Dinge zu sagen („dieser Play hat noch keine
    /// Linien zum Abspielen"), und zwei Meldungszeilen übereinander wären
    /// eine zu viel.
    mutating func melden(_ text: String?) {
        meldung = text
    }

    /// Wie lange ein Satz stehen bleibt, in Sekunden.
    ///
    /// **Nach Länge und nicht pauschal.** „Diese Aufstellung ist leer."
    /// liest man in zwei Sekunden, „Route beginnt bei einem Spieler.
    /// Tipp zuerst auf die Figur, die den Weg läuft." braucht das
    /// Dreifache. Gerechnet mit zwölf Zeichen je Sekunde -- das ist die
    /// vorsichtige Seite von dem, was für stilles Lesen gemessen wird
    /// (Brysbaert 2019 nennt 238 Wörter je Minute für Sachtexte, also
    /// rund 24 Zeichen je Sekunde; die Hälfte davon lässt Zeit, den
    /// Blick überhaupt erst dorthin zu wenden).
    ///
    /// Mindestens vier Sekunden, höchstens zehn -- dieselben Grenzen,
    /// die Material Design für seine Einblendungen nennt. Darunter
    /// liest niemand mit, darüber steht es im Weg.
    static func lesedauer(_ text: String) -> Double {
        min(10.0, max(4.0, Double(text.count) / 12.0))
    }

    // MARK: - Treffer

    /// Der nächste Spieler innerhalb der Grifffläche.
    ///
    /// Nicht der erste getroffene: Bei eng stehenden Spielern hinge sonst
    /// die Reihenfolge in der Liste darüber, wen man erwischt.
    func spielerBei(_ punkt: CGPoint, groesse: CGSize) -> Zeichnung.Spieler? {
        var bester: (Zeichnung.Spieler, Double)?
        for spieler in zeichnung.spieler {
            let mitte = projektion.aufBildschirm(x: spieler.x, y: spieler.y,
                                                 groesse: groesse)
            let abstand = Zeichenblock.abstand(punkt, mitte)
            guard abstand <= Zeichenblock.griff else { continue }
            if bester == nil || abstand < bester!.1 { bester = (spieler, abstand) }
        }
        return bester?.0
    }

    /// Die nächste Linie innerhalb der Grifffläche, als Stelle in der
    /// Liste. Gemessen wird der Abstand zu den STRECKEN, nicht zu den
    /// Stützpunkten: Eine gerade Route hat zwei Punkte und dazwischen
    /// zwanzig Yards, die man sonst nicht treffen könnte.
    func linieBei(_ punkt: CGPoint, groesse: CGSize) -> Int? {
        var beste: (Int, Double)?
        for (stelle, linie) in zeichnung.linien.enumerated() {
            let punkte = linie.punkte.map {
                projektion.aufBildschirm(x: $0.x, y: $0.y, groesse: groesse)
            }
            guard punkte.count >= 2 else { continue }
            var naechster = Double.infinity
            for i in 1..<punkte.count {
                naechster = min(naechster,
                                Zeichenblock.abstandZurStrecke(
                                    punkt, von: punkte[i - 1], nach: punkte[i]))
            }
            // Eine Zone ist geschlossen gezeichnet, also gehört die
            // Rückstrecke dazu -- sonst greift man ins Leere, wo eine
            // Linie zu sehen ist.
            if linie.art == .zone, linie.zonenform == .linie,
               let erster = punkte.first, let letzter = punkte.last {
                naechster = min(naechster,
                                Zeichenblock.abstandZurStrecke(
                                    punkt, von: letzter, nach: erster))
            }
            guard naechster <= Zeichenblock.linienGriff else { continue }
            if beste == nil || naechster < beste!.1 { beste = (stelle, naechster) }
        }
        return beste?.0
    }

    private static func abstand(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = Double(a.x - b.x), dy = Double(a.y - b.y)
        return (dx * dx + dy * dy).squareRoot()
    }

    private static func abstandZurStrecke(_ punkt: CGPoint, von: CGPoint,
                                          nach: CGPoint) -> Double {
        let dx = Double(nach.x - von.x), dy = Double(nach.y - von.y)
        let laengeQuadrat = dx * dx + dy * dy
        guard laengeQuadrat > 0.0001 else { return abstand(punkt, von) }
        let t = ((Double(punkt.x - von.x) * dx + Double(punkt.y - von.y) * dy)
                 / laengeQuadrat)
        let geklemmt = min(max(t, 0), 1)
        return abstand(punkt, CGPoint(x: Double(von.x) + geklemmt * dx,
                                      y: Double(von.y) + geklemmt * dy))
    }

    // MARK: - Tippen

    /// Ein Fingertipp auf die Fläche.
    ///
    /// Im Auswahl-Werkzeug wählt er aus, mit einem Zeichenwerkzeug setzt
    /// er Punkte. Das ist dieselbe Aufteilung wie im Browser, wo
    /// `pointerdown` genau diese beiden Fälle unterscheidet.
    mutating func tippen(_ punkt: CGPoint, groesse: CGSize) {
        meldung = nil
        zeiger = nil
        let getroffen = spielerBei(punkt, groesse: groesse)

        switch werkzeug {
        case .auswahl:
            if let spieler = getroffen {
                auswahl = .spieler(spieler.id)
            } else if let stelle = linieBei(punkt, groesse: groesse) {
                auswahl = .linie(stelle)
            } else {
                auswahl = nil
            }

        case .linie(let art):
            let feldpunkt = projektion.vomBildschirm(punkt, groesse: groesse)

            // Ein Tipp auf einen ANDEREN Spieler schließt die angefangene
            // Linie ab und beginnt die nächste bei ihm. Vorher wurde
            // daraus ein Wegpunkt, und die Linie lief quer durch die
            // Aufstellung.
            if let laufend = entwurf, let spieler = getroffen,
               spieler.id != laufend.spieler {
                abschliessen()
                beginnen(art: art, bei: spieler)
                return
            }

            guard entwurf != nil else {
                if let spieler = getroffen {
                    beginnen(art: art, bei: spieler)
                } else if art.darfFreiAnfangen {
                    let gefangen = fangen(x: feldpunkt.x, y: feldpunkt.y)
                    // Der Kurvenschalter gilt auch hier -- eine Zone
                    // fängt fast immer auf freier Fläche an und nicht auf
                    // einer Figur. Ohne ihn gälte er ausgerechnet für die
                    // Linien nicht, für die man ihn am ehesten will.
                    entwurf = Zeichnung.Linie(
                        spieler: nil, art: art, ende: art.stil.standardEnde,
                        gebogen: kurve,
                        punkte: [Zeichnung.Punkt(x: gefangen.x, y: gefangen.y)])
                    entwurf?.zonenform = art == .zone ? zonenform : .linie
                } else {
                    // EIN WEG OHNE LÄUFER IST KEINE ANWEISUNG (R58).
                    //
                    // Niklas am 02.09.2026, mit einem Bildschirmfoto, auf
                    // dem ein Weg neben dem Feld schwebt: „Man kann immer
                    // noch wild routen irgendwo machen? Verstehe nicht
                    // warum soll das wegen Option Route sein?"
                    //
                    // Er hat recht, und die Begründung im Code war zu
                    // breit geraten: Sie nennt die ZONE, und für die
                    // stimmt sie. Eine Route, eine Motion, ein Block,
                    // eine Ballabgabe und ein Passweg gehören immer
                    // einem Spieler. Ohne ihn bewegt sich im Ablauf
                    // nichts daran, im Ausdruck steht ein Strich ohne
                    // Zuordnung, und „zeig mir nur meinen Weg" findet
                    // ihn nie.
                    //
                    // GESAGT UND NICHT NUR VERHINDERT. Ein Tipp, der
                    // nichts tut, sieht aus wie ein Programm, das
                    // klemmt.
                    // UND DIE AUSWAHL FAELLT (R83, 09.09.2026).
                    //
                    // Entschieden: „Ein Tipp ins Leere hebt immer die
                    // Auswahl auf." Vorher tat er je nach Werkzeug vier
                    // verschiedene Dinge -- auswaehlen, eine Linie
                    // beginnen, einen Punkt anhaengen, oder nur eine
                    // Meldung zeigen. Der vierte Fall liess die alte
                    // Auswahl stehen, und dann blieb eine fremde Linie
                    // hervorgehoben, waehrend die Meldung von einer
                    // anderen sprach.
                    //
                    // Die Zone bleibt ausgenommen und muss es: Sie
                    // gehoert keinem Spieler und faengt zwangslaeufig
                    // auf freier Flaeche an. Ein Tipp ins Leere ist bei
                    // ihr die einzige Art, sie zu zeichnen.
                    auswahl = nil
                    melden(String(localized: """
                        \(art.stil.kurz) beginnt bei einem Spieler. \
                        Tipp zuerst auf die Figur, die den Weg läuft.
                        """))
                }
                return
            }
            punktAnhaengen(feldpunkt)

            // EINE FERTIGE FORM SCHLIESST SICH SELBST (Niklas, 09.09.2026).
            //
            // „wenn ich auf den Punkt tippe um es grösser zu ziehen,
            // denn erstelle ich nur super viele andere Punkte die gar
            // keinen Sinn ergeben ich check das nicht das ist nicht
            // intuitiv."
            //
            // Er hat recht, und der Grund stand hier: Kreis und
            // Rechteck stehen nach dem ZWEITEN Tipp fest, das Werkzeug
            // hängte aber weiter Punkte an. Wer danach die Ecke
            // anfassen wollte, setzte einen dritten, vierten, fünften
            // Punkt -- unsichtbar, weil der Server sie beim Speichern
            // ohnehin abschneidet.
            //
            // UND DANACH DAS AUSWAHL-WERKZEUG. Griffe gibt es nur dort
            // (siehe `griffe`), und ohne sie ist die eben gezeichnete
            // Form weder zu verschieben noch zu vergrössern. Wer eine
            // Form fertig hat, will sie als Nächstes anfassen -- nicht
            // die nächste zeichnen.
            if entwurf?.istGeschlosseneForm == true {
                abschliessen()
                werkzeug = .auswahl
                if !zeichnung.linien.isEmpty {
                    auswahl = .linie(zeichnung.linien.count - 1)
                }
            }
        }
    }

    /// Der Punkt unter dem aufliegenden Finger. Nur Vorschau, er landet
    /// erst beim Loslassen in der Linie.
    ///
    /// Ohne ihn zeichnet man auf einem Handy blind: Es gibt keinen
    /// Mauszeiger, der vorher zeigt, wo der Fang den Punkt hinlegt.
    mutating func zeigen(_ punkt: CGPoint, groesse: CGSize) {
        guard entwurf != nil else { return }
        let feldpunkt = projektion.vomBildschirm(punkt, groesse: groesse)
        let ziel = gefangen(feldpunkt)
        zeiger = Zeichnung.Punkt(x: ziel.x, y: ziel.y)
    }

    mutating func zeigerLoesen() { zeiger = nil }

    private mutating func beginnen(art: Zeichnung.Linie.Art,
                                   bei spieler: Zeichnung.Spieler) {
        // Der erste Punkt ist die Position des Spielers, ungefangen: Wo er
        // steht, fängt sein Weg an. Ein gefangener Anfang risse die Linie
        // sichtbar von der Figur ab.
        entwurf = Zeichnung.Linie(
            spieler: spieler.id, art: art, ende: art.stil.standardEnde,
            gebogen: kurve,
            punkte: [Zeichnung.Punkt(x: spieler.x, y: spieler.y)])
        entwurf?.zonenform = art == .zone ? zonenform : .linie
        auswahl = .spieler(spieler.id)
    }

    /// Fängt einen Punkt so, wie es der nächste Schritt verlangt: den
    /// ersten aufs Raster, jeden weiteren auf Winkel UND Raster.
    ///
    /// Ist der Fang aus (R5), bleibt der Punkt, wo der Finger war -- ins
    /// Feld gehalten wird er trotzdem.
    private func gefangen(_ punkt: (x: Double, y: Double))
        -> (x: Double, y: Double) {
        guard fang else {
            return projektion.feld.begrenzen(x: punkt.x, y: punkt.y)
        }
        guard let letzter = entwurf?.punkte.last else {
            return projektion.fangen(x: punkt.x, y: punkt.y)
        }
        return projektion.fangenAufWinkel(von: (x: letzter.x, y: letzter.y),
                                          nach: punkt)
    }

    private mutating func punktAnhaengen(_ punkt: (x: Double, y: Double)) {
        guard var laufend = entwurf, let letzter = laufend.punkte.last else {
            return
        }
        guard laufend.punkte.count < Zeichnung.maxPunkteJeLinie else {
            meldung = String(localized: "Diese Linie hat genug Ecken.")
            return
        }
        // Kreis und Rechteck nehmen keinen dritten Punkt an.
        guard !laufend.istGeschlosseneForm else { return }
        let ziel = gefangen(punkt)
        // Ein Punkt auf seinem Vorgänger ist keine Strecke, sondern eine
        // Stelle, an der der Pfeil später keine Richtung mehr hat. Im
        // Browser fällt das nicht auf, weil ein Mauszeiger genauer trifft
        // als ein Finger.
        guard abs(ziel.x - letzter.x) > 0.001
                || abs(ziel.y - letzter.y) > 0.001 else { return }
        laufend.punkte.append(Zeichnung.Punkt(x: ziel.x, y: ziel.y))
        entwurf = laufend
    }

    // MARK: - Die angefangene Linie

    /// Wie viele Punkte der Entwurf noch braucht. 0 heißt fertig.
    var fehlendePunkte: Int {
        guard let laufend = entwurf else { return 0 }
        return max(0, laufend.mindestensPunkte - laufend.punkte.count)
    }

    /// Nimmt den letzten Punkt zurück. Mit dem letzten geht der Entwurf.
    ///
    /// Das ist NICHT das Rückgängig aus B5, das ganze Arbeitsschritte
    /// zurücknimmt -- es gilt nur, solange gezeichnet wird. Auf einem
    /// Handy braucht es das trotzdem: Ein Finger trifft daneben, und ohne
    /// diesen Knopf müsste man die ganze Linie wegwerfen.
    mutating func punktZurueck() {
        spur("editor", "punkt_zurueck")
        guard var laufend = entwurf else { return }
        zeiger = nil
        laufend.punkte.removeLast()
        entwurf = laufend.punkte.isEmpty ? nil : laufend
    }

    /// Wirft die angefangene Linie weg.
    mutating func abbrechen() {
        spur("editor", "abbrechen")
        entwurf = nil
        zeiger = nil
        meldung = nil
    }

    /// Legt die angefangene Linie in die Zeichnung.
    ///
    /// Zu kurz heißt: verworfen. Eine Linie mit einem Punkt ist keine
    /// Anweisung, und der Server nähme sie ohnehin nicht an.
    @discardableResult
    mutating func abschliessen() -> Bool {
        spur("editor", "linie_fertig", entwurf?.art.rawValue ?? "")
        guard let laufend = entwurf else { return false }
        entwurf = nil
        zeiger = nil
        guard laufend.istVollstaendig else {
            // NICHT STILL WEGWERFEN. „Fertig" ist bei zu wenigen Punkten
            // gesperrt, der Wechsel auf einen anderen Spieler ging aber
            // daran vorbei: Erst antippen, dann den nächsten antippen --
            // und die angefangene Linie war kommentarlos weg. Genau so
            // entsteht „meine Route wurde nicht gespeichert" (R4).
            // Derselbe Satz steht in `editor.js`.
            meldung = laufend.art == .zone && laufend.zonenform == .linie
                ? String(localized: """
                    Eine Zone braucht mindestens drei Ecken. Nichts angelegt.
                    """)
                : laufend.art == .zone
                ? String(localized: """
                    Diese Zone braucht einen zweiten Punkt. Nichts angelegt.
                    """)
                : String(localized:
                    "Eine Linie braucht einen zweiten Punkt. Nichts angelegt.")
            auswahl = nil
            return false
        }
        // Jede Position hat genau EINEN Weg. Eine neue Linie ersetzt die
        // alte, statt sich mit ihr zu überlagern -- sonst häuft sich im
        // Diagramm Unrat an, den niemand mehr auseinanderhält.
        //
        // **AUSSER DER OPTION (Niklas, 08.09.2026).** „wenn die app
        // nicht abstürzt denn wird immer editor nur noch die option
        // route angezeigt aber nicht mehr die normale route."
        //
        // Er hat recht, und die Ursache stand genau hier: Eine
        // Option-Route gehört DEMSELBEN Spieler wie die Route, an der
        // sie ansetzt -- das ist ihr ganzer Sinn (R68). Die Regel oben
        // sah darin die „bisherige Linie dieser Position" und löschte
        // die Originalroute, sobald die Option fertig war. Aus einer
        // Gabelung wurde ein einzelner Ast.
        //
        // Deshalb wird nicht mehr nach dem Spieler allein gefragt,
        // sondern nach Spieler UND Sorte: Eine Option ersetzt nur eine
        // Option, alles andere ersetzt alles andere.
        //
        // **Und die Option bleibt stehen, wenn die Hauptroute neu
        // gezeichnet wird.** Der Gedanke, sie mitzunehmen, liegt nahe
        // -- sie setzt ja an einem Punkt an, den es dann nicht mehr
        // gibt. Er ist trotzdem falsch: Wer eine Route um einen halben
        // Yard nachzieht, verlöre dabei stillschweigend den zweiten
        // Ast. Was sichtbar dasteht, kann man wegnehmen; was von selbst
        // verschwindet, sucht man.
        //
        // **UND SEIT DEM 09.09.2026 AUCH NICHT MEHR DEN BALLWEG (R88).**
        // Niklas: „Wenn ich einen Spieler eine Abgabe bzw. snap Linie
        // gebe, kann ich ihm keine normale Route mehr geben, es geht nur
        // eine Sache." Der Center snappt und läuft danach seine Route,
        // der Quarterback wirft und läuft: zwei Wege derselben Figur,
        // aber nicht dasselbe. Der eine ist der Ball, der andere der
        // Mensch.
        //
        // Die Sorte kommt aus `render.py` und nicht aus einer Liste hier
        // (`Art.sorte`). Zwei Fassungen dieser Zuordnung sind genau der
        // Fehler, an dem R58 schon einmal ein halbes Jahr hing.
        let betroffen: (Zeichnung.Linie) -> Bool = { alt in
            alt.spieler == laufend.spieler && alt.art.sorte == laufend.art.sorte
        }
        let ersetzt = laufend.spieler != nil
            && zeichnung.linien.contains(where: betroffen)
        // Gefragt wird VOR dem Ersetzen, ob noch Platz ist: Sonst wäre
        // die alte Linie weg und die neue abgelehnt, und der Play hätte
        // an dieser Position gar keinen Weg mehr.
        guard ersetzt || zeichnung.linien.count < Zeichnung.maxLinien else {
            meldung = String(localized: "Mehr Linien nimmt ein Play nicht auf.")
            return false
        }
        // Ab hier ändert sich wirklich etwas, also gehört der bisherige
        // Stand in den Verlauf -- einmal, vor dem Ersetzen UND dem
        // Anhängen. Zwei Schritte für eine Linie hieße: zweimal
        // Rückgängig drücken, und nach dem ersten Mal steht der Play mit
        // gar keiner Linie an dieser Position da.
        merken()
        if ersetzt {
            zeichnung.linien.removeAll(where: betroffen)
            meldung = laufend.art == .option
                ? String(localized:
                    "Die bisherige Option dieser Position wurde ersetzt.")
                : String(localized:
                    "Die bisherige Linie dieser Position wurde ersetzt.")
        }
        zeichnung.linien.append(laufend)
        // Ausgewählt ist die eben fertige Linie, nicht nichts: Direkt
        // danach will man ihr Ende einstellen, und ein Griff daneben
        // erwischte sonst eine andere.
        auswahl = .linie(zeichnung.linien.count - 1)
        stand += 1
        return true
    }

    // MARK: - Eine bestehende Linie

    /// Die ausgewählte Linie, falls eine ausgewählt ist.
    var ausgewaehlteLinie: Zeichnung.Linie? {
        guard case .linie(let stelle) = auswahl,
              zeichnung.linien.indices.contains(stelle) else { return nil }
        return zeichnung.linien[stelle]
    }

    /// Die Stelle der ausgewählten Linie, für die Ansicht.
    var ausgewaehlteStelle: Int? {
        guard case .linie(let stelle) = auswahl,
              zeichnung.linien.indices.contains(stelle) else { return nil }
        return stelle
    }

    // MARK: - Die Option an einer bestehenden Route (R68)

    /// An welchen Punkten der ausgewählten Linie eine Option ansetzen
    /// darf.
    ///
    /// **Nicht am ersten.** Dort steht die Figur, und eine Linie, die
    /// bei ihr beginnt, ist keine Option, sondern eine zweite Route --
    /// die gibt es über den gewöhnlichen Weg schon.
    ///
    /// **Und nicht an einer Zone.** Eine Zone ist eine Fläche; „ab
    /// welchem Punkt" hat dort keine Bedeutung.
    var optionstellen: [Int] {
        guard let linie = ausgewaehlteLinie, linie.art != .zone,
              linie.punkte.count >= 2 else { return [] }
        return Array(1..<linie.punkte.count)
    }

    /// Setzt eine Option-Route an einem Punkt der ausgewählten an (R68).
    ///
    /// Niklas am 03.09.2026: „Wenn man eine original Route anwählt sieht
    /// man ja die Punkte. Man sollte die Möglichkeit haben an der
    /// Original Route anzusetzen und einen Punkt wählen zur Option
    /// Route. Also angenommen eine Route geht gerade nach oben denkt
    /// kommt ein Punkt und die Route geht 45 grad nach links hoch, also
    /// ein Corner. Aber optional kann sie auch nach rechts hoch weisst
    /// du?"
    ///
    /// **Das Modell konnte das schon.** Eine Option ist eine gewöhnliche
    /// Linie der Art `option`, die demselben Spieler gehört; der Server
    /// nimmt beliebig viele Linien je Spieler an. Was fehlte, war der
    /// ANSATZ: Eine Linie begann immer bei der Figur, also lief jede
    /// Option quer über das halbe Feld zurück zum Knick.
    ///
    /// **Und sie beginnt als ENTWURF und nicht als fertige Linie.** Wo
    /// sie hingeht, weiss nur der Trainer -- eine automatisch gesetzte
    /// zweite Hälfte wäre geraten, und man müsste sie erst wieder
    /// verschieben.
    mutating func optionAnsetzen(ab stelle: Int) {
        guard let linie = ausgewaehlteLinie,
              optionstellen.contains(stelle) else { return }
        let ansatz = linie.punkte[stelle]
        entwurf = Zeichnung.Linie(
            spieler: linie.spieler, art: .option,
            ende: Zeichnung.Linie.Art.option.stil.standardEnde,
            gebogen: kurve, punkte: [ansatz])
        werkzeug = .linie(.option)
        // DIE AUSWAHL FÄLLT WEG. Die Fußzeile zeigt entweder den Entwurf
        // ODER die ausgewählte Linie; bliebe die Auswahl stehen, stünde
        // die Leiste der Originalroute über einer Option, an der man
        // gerade zeichnet.
        auswahl = nil
        melden(String(localized: """
            Option angesetzt. Tipp jetzt, wohin sie stattdessen läuft.
            """))
    }

    /// Setzt das Ende -- an der angefangenen Linie, sonst an der
    /// ausgewählten. Beides ist „die Linie, an der ich gerade arbeite".
    mutating func endeSetzen(_ ende: Zeichnung.Linie.Ende) {
        spur("editor", "linienende", ende.rawValue)
        if entwurf != nil {
            entwurf?.ende = ende
            return
        }
        guard let stelle = ausgewaehlteStelle else { return }
        guard zeichnung.linien[stelle].ende != ende else { return }
        merken()
        zeichnung.linien[stelle].ende = ende
        stand += 1
    }

    /// Schaltet die Rundung um -- für neue Linien, den Entwurf und die
    /// ausgewählte Linie.
    ///
    /// **Warum alle drei und nicht nur die neuen.** Der Browser schaltet
    /// nur den Vorrat für neue Linien um; wer dort eine eckige Route
    /// runden will, muss sie neu zeichnen. Genau darüber geht R11
    /// („das Werkzeug lässt mich nicht mehr an das heran, was ich gerade
    /// gemacht habe"). Am Telefon wiegt das schwerer als am Schreibtisch:
    /// Eine Wheel mit dem Finger noch einmal zu ziehen, weil der Bogen
    /// fehlt, ist die Arbeit, die R12 gemeldet hat.
    ///
    /// Läuft ein Entwurf, gilt die Rundung sofort für ihn -- sonst
    /// zeichnet die Vorschau etwas anderes als der Knopf sagt.
    /// Umgeschaltet wird gegen das, was der Knopf ANZEIGT (`kurveAktiv`),
    /// nicht gegen den Vorrat. Sonst passiert beim ersten Druck nichts:
    /// Ist eine gerundete Linie ausgewählt, während der Vorrat auf eckig
    /// steht, setzt ein Umschalten des Vorrats sie auf denselben Wert,
    /// den sie schon hat.
    mutating func kurveUmschalten() {
        spur("editor", "kurve")
        let neu = !kurveAktiv
        kurve = neu
        if entwurf != nil {
            entwurf?.gebogen = neu
            return
        }
        guard let stelle = ausgewaehlteStelle,
              zeichnung.linien[stelle].gebogen != neu else { return }
        merken()
        zeichnung.linien[stelle].gebogen = neu
        stand += 1
    }

    /// Ob der Kurvenknopf gedrückt aussieht: Es zählt, woran gerade
    /// gearbeitet wird, nicht der Vorrat für die nächste Linie.
    var kurveAktiv: Bool {
        if let laufend = entwurf { return laufend.gebogen }
        if let linie = ausgewaehlteLinie { return linie.gebogen }
        return kurve
    }

    /// Löscht die ausgewählte Linie.
    mutating func ausgewaehlteLinieLoeschen() {
        spur("editor", "linie_weg")
        guard let stelle = ausgewaehlteStelle else { return }
        merken()
        zeichnung.linien.remove(at: stelle)
        auswahl = nil
        stand += 1
    }

    /// Die Beschriftung der ausgewählten Linie -- „Go", „Out 7", „Flat".
    ///
    /// **Das ist die zweite Hälfte von R25.** Die erste war, sie überhaupt
    /// zu ZEIGEN; damit ließ sie sich nur im Browser eintippen. Wer am
    /// Spielfeldrand merkt, dass die Route falsch heißt, musste bis an den
    /// Schreibtisch. Die Beschriftung ist aber genau das, was der Trainer
    /// ruft -- und wer sie ruft, ist draußen und nicht drinnen.
    ///
    /// **Nur die ausgewählte Linie, nicht der Entwurf** -- anders als bei
    /// `endeSetzen` und `kurveUmschalten`. Die beiden schalten etwas um,
    /// das sich mit einem Griff sagen lässt, während die Linie entsteht.
    /// Ein Name ist Tipparbeit: Wer mitten im Zeichnen die Tastatur
    /// aufzieht, verliert die halbe Fläche und den Faden. Benannt wird,
    /// was fertig ist.
    ///
    /// **Kein Schritt im Verlauf je Tastendruck**, dieselbe Entscheidung
    /// wie bei `rolleSetzen` (R9): Nach „Comeback" wäre Rückgängig achtmal
    /// zu drücken, und der neunte Druck nähme den Zug davor mit.
    mutating func beschriftungSetzen(_ neu: String) {
        guard let stelle = ausgewaehlteStelle else { return }
        let kurz = String(neu.prefix(Zeichnung.Linie.maxBeschriftung))
        // Derselbe Wert ist keine Änderung. SwiftUI ruft den Setzer einer
        // Bindung auch dann auf, wenn sich nichts geändert hat; ohne diese
        // Bremse zählte `stand` beim bloßen Antippen hoch, und die Fußzeile
        // sagte „Ungesichert", ohne dass jemand etwas getan hat -- genau
        // die Anzeige, an der seit R4 die Rückfrage beim Zurückgehen hängt.
        guard zeichnung.linien[stelle].beschriftung != kurz else { return }
        zeichnung.linien[stelle].beschriftung = kurz
        stand += 1
    }

    // MARK: - Wer da steht (R9)

    /// Die Grenzen des Servers, hier noch einmal.
    ///
    /// `schema.validate_play_data` schneidet die Rolle auf sechs und das
    /// Kürzel auf drei Zeichen ab. Wer mehr eintippen darf, als ankommt,
    /// bekommt seine Eingabe beim Speichern gekürzt und erfährt es nicht
    /// -- deshalb greift die Grenze schon hier. Eine Prüfung hält die
    /// Zahlen gegen `schema.py` (`test_umbenennen.py`), damit sie nicht
    /// leise auseinanderlaufen.
    static let maxRolle = 6
    static let maxKuerzel = 3
    /// Dieselbe Grenze wie `schema.MAX_SPIELERNOTIZ` (R41). Auch sie
    /// wird nachgehalten, damit sie nicht leise auseinanderläuft.
    static let maxSpielernotiz = 120

    /// Der ausgewählte Spieler, falls einer ausgewählt ist.
    ///
    /// Das Gegenstück zu `ausgewaehlteLinie`. Bis R9 gab es das nicht:
    /// Die Fußzeile kannte eine Leiste für eine ausgewählte LINIE, aber
    /// keine für eine ausgewählte Figur -- und damit keinen Weg, an
    /// Rolle oder Kürzel heranzukommen.
    var ausgewaehlterSpieler: Zeichnung.Spieler? {
        guard let stelle = ausgewaehlteSpielerstelle else { return nil }
        return zeichnung.spieler[stelle]
    }

    private var ausgewaehlteSpielerstelle: Int? {
        guard case .spieler(let kennung) = auswahl else { return nil }
        return zeichnung.spieler.firstIndex { $0.id == kennung }
    }

    // MARK: - Spieler dazustellen und wegnehmen (08.09.2026)
    //
    // **Die App konnte es bis hierher gar nicht.** Nachgezählt: kein
    // `spieler.append`, kein `spieler.remove`, keine Funktion, die die
    // Länge der Aufstellung ändert. Die Figuren kamen fertig vom
    // Server -- als Startaufstellung beim Anlegen oder aus einer
    // gespeicherten Formation -- und ließen sich danach nur schieben,
    // umbenennen und einfärben.
    //
    // Das fiel nicht auf, solange jede Mannschaft fünf Leute hatte. Mit
    // Tackle fällt es sofort auf: Wer eine Mannschaft von Elfer auf
    // Neuner umstellt, behält in vorhandenen Plays elf Figuren und wird
    // zwei davon in der App nicht los.
    //
    // **Dieselben Regeln wie im Browser** (`editor.js`,
    // `spielerHinzufuegen`/`spielerEntfernen`), und zwar bewusst
    // Zeile für Zeile: die Grenze aus der Spielform, die freie Rolle
    // aus ihrer Liste, der Platz mit dem größten Abstand zum nächsten
    // Mitspieler, und beim Entfernen gehen die Linien mit. Eine Route
    // ohne Spieler wäre ein Waisenkind, das der Server ohnehin
    // zurückweist.

    /// Wie viele auf dieser Seite stehen.
    func anzahl(_ seite: Zeichnung.Spieler.Seite) -> Int {
        zeichnung.spieler.filter { $0.seite == seite }.count
    }

    /// Höchstens so viele je Seite -- aus der Spielform.
    ///
    /// **Nicht `Zeichnung.maxJeSeite`.** Die Konstante ist der Rückfall
    /// des Servers für den Fall, dass niemand eine Form nennt; hier ist
    /// eine genannt.
    var hoechstensJeSeite: Int { projektion.form.spieler }

    /// Die erste Rolle dieser Form, die noch niemand trägt.
    ///
    /// `nil` heißt: alle vergeben. Dann bekommt der neue Spieler „O"
    /// oder „D" -- so wie im Browser, und das ist ehrlicher als eine
    /// Rolle zu erfinden, die es in dieser Form nicht gibt.
    private func freieRolle(_ seite: Zeichnung.Spieler.Seite) -> String? {
        let rollen = seite == .defense ? projektion.form.rollenDefense
                                       : projektion.form.rollenOffense
        let belegt = Set(zeichnung.spieler
            .filter { $0.seite == seite }
            .map(\.rolle))
        return rollen.first { !belegt.contains($0) }
    }

    /// Eine Kennung, die es noch nicht gibt.
    private func freieKennung(_ vorschlag: String) -> String? {
        let vorhanden = Set(zeichnung.spieler.map(\.id))
        if !vorhanden.contains(vorschlag) { return vorschlag }
        for zaehler in 2...20 {
            let versuch = "\(vorschlag)\(zaehler)"
            if !vorhanden.contains(versuch) { return versuch }
        }
        return nil
    }

    /// Wo ein neuer Spieler landet.
    ///
    /// Fünf Kandidaten quer über das Feld; es gewinnt der mit dem
    /// größten Abstand zum nächsten Mitspieler derselben Seite. Wer
    /// einen dazustellt, will ihn sehen und nicht suchen.
    ///
    /// **Die Tiefe der Defense hängt an der Rushlinie -- wo es eine
    /// gibt.** Im Tackle ist `rush` null, und ohne diese Unterscheidung
    /// landete ein neuer Verteidiger GENAU auf der Line of Scrimmage,
    /// also mitten in der Offensive Line. Derselbe Fall wie im Browser.
    private func freierPlatz(_ seite: Zeichnung.Spieler.Seite)
        -> (x: Double, y: Double) {
        let feld = projektion.feld
        let abstand = feld.rush > 0 ? feld.rush : 1.2
        let x = seite == .defense
            ? projektion.los + abstand * Double(projektion.richtung)
            : projektion.los
        let eigene = zeichnung.spieler.filter { $0.seite == seite }
        var beste = 0.5 * feld.breite
        var besterAbstand = -1.0
        for anteil in [0.12, 0.28, 0.5, 0.72, 0.88] {
            let y = anteil * feld.breite
            let naechster = eigene.map { abs($0.y - y) }.min() ?? .infinity
            if naechster > besterAbstand {
                besterAbstand = naechster
                beste = y
            }
        }
        return feld.begrenzen(x: x, y: beste)
    }

    /// Einen Spieler dazustellen.
    @discardableResult
    mutating func spielerDazu(_ seite: Zeichnung.Spieler.Seite) -> Bool {
        spur("editor", "spieler_dazu", seite.rawValue)
        guard anzahl(seite) < hoechstensJeSeite else {
            meldung = String(localized:
                "Mehr als \(hoechstensJeSeite) Spieler je Seite gibt diese Spielform nicht her.")
            return false
        }
        let rolle = freieRolle(seite)
        let kuerzel = rolle ?? (seite == .defense ? "D" : "O")
        let stamm = (seite == .defense ? "d_" : "o_") + kuerzel.lowercased()
        guard let kennung = freieKennung(stamm) else {
            meldung = String(localized: "Keine freie Kennung mehr.")
            return false
        }
        let platz = freierPlatz(seite)
        merken()
        zeichnung.spieler.append(Zeichnung.Spieler(
            id: kennung, seite: seite, rolle: kuerzel,
            kuerzel: String(kuerzel.prefix(Zeichenblock.maxKuerzel)),
            x: (platz.x * 100).rounded() / 100,
            y: (platz.y * 100).rounded() / 100))
        auswahl = .spieler(kennung)
        stand += 1
        meldung = String(localized: "\(kuerzel) dazugestellt.")
        return true
    }

    /// Einen Spieler wegnehmen -- mit seinen Linien.
    @discardableResult
    mutating func spielerWeg(_ kennung: String) -> Bool {
        spur("editor", "spieler_weg")
        guard let spieler = zeichnung.spieler.first(where: {
            $0.id == kennung
        }) else { return false }
        merken()
        zeichnung.spieler.removeAll { $0.id == kennung }
        // SEINE LINIEN GEHEN MIT. Eine Route ohne Spieler ist ein
        // Waisenkind, das der Server zurückweist -- und dann liesse
        // sich der Play nicht mehr sichern.
        zeichnung.linien.removeAll { $0.spieler == kennung }
        if case .spieler(let gewaehlt) = auswahl, gewaehlt == kennung {
            auswahl = nil
        }
        stand += 1
        let wer = spieler.rolle.isEmpty ? spieler.kuerzel : spieler.rolle
        meldung = String(localized: "\(wer) entfernt.")
        return true
    }

    /// Die Rolle: WER da steht -- „QB", „X", „C1".
    ///
    /// **Das ist die Hälfte, nach der Cyells Meldung fragt.** „wenn man
    /// doch mal einen anderen Spieler haben möchte" heißt, aus dem X ein
    /// Z zu machen. Das Kürzel im Kreis tut das nicht: Die Rolle steht
    /// über den Linien dieses Spielers, in der Überschrift der Spalte
    /// und in der Vorlesehilfe des Symbols. Wer nur das Kürzel ändert,
    /// hat einen Spieler, der „Z" heißt und „X" ist.
    ///
    /// **Kein Schritt im Verlauf je Tastendruck.** Nach „Cornerback"
    /// wäre Rückgängig zehnmal zu drücken, und der elfte Druck nähme
    /// dann den Zug davor mit -- man hätte den Spieler verschoben, statt
    /// den Namen zurückzunehmen. Der Browser hält es genauso.
    mutating func rolleSetzen(_ neu: String) {
        guard let stelle = ausgewaehlteSpielerstelle else { return }
        let kurz = String(neu.prefix(Zeichenblock.maxRolle))
        guard zeichnung.spieler[stelle].rolle != kurz else { return }
        zeichnung.spieler[stelle].rolle = kurz
        stand += 1
    }

    /// Das Kürzel: was IM KREIS steht, höchstens drei Zeichen.
    ///
    /// Drei, weil mehr nicht in den Kreis passt -- weder hier noch im
    /// Ausdruck. Meistens ist es dasselbe wie die Rolle, und genau
    /// deshalb reicht es allein nicht: Cyells Fall ist der andere.
    mutating func kuerzelSetzen(_ neu: String) {
        guard let stelle = ausgewaehlteSpielerstelle else { return }
        let kurz = String(neu.prefix(Zeichenblock.maxKuerzel))
        guard zeichnung.spieler[stelle].kuerzel != kurz else { return }
        zeichnung.spieler[stelle].kuerzel = kurz
        stand += 1
    }

    /// Wie weit die Linie eine Motion ist (R45).
    ///
    /// Cyell am 01.09.2026: „Route in Segmente einteilen das man eine
    /// Motion haben kann + normale Route." `0` nimmt den Vorlauf weg.
    ///
    /// **Geprüft wird hier, nicht nur beim Server.** Ein Wert ausserhalb
    /// von `1 ... punkte.count - 2` liesse der Server still auf 0 fallen
    /// -- die App zeigte dann einen Vorlauf, der beim nächsten Laden
    /// weg wäre.
    mutating func motionSetzen(_ bis: Int) {
        guard let stelle = ausgewaehlteStelle else { return }
        let linie = zeichnung.linien[stelle]
        let sauber = (1...max(1, linie.punkte.count - 2)).contains(bis)
            && linie.art != .zone && linie.punkte.count >= 3 ? bis : 0
        guard linie.motionBis != sauber else { return }
        verlauf.merken(jetzigerStand)
        zeichnung.linien[stelle].motionBis = sauber
        stand += 1
    }

    /// Die Farbe einer Figur (R43).
    ///
    /// Niklas am 01.09.2026: „Farben der Spieler noch änderbar machen."
    /// Das Modell trägt sie längst durch (`Zeichnung.Spieler.farbe`),
    /// gezeichnet wird sie auch -- es gab nur kein Bedienelement.
    ///
    /// **Ein Schritt im Verlauf, kein Zug.** Anders als beim Ziehen
    /// entsteht hier genau eine Änderung; sie darf sich einzeln
    /// zurücknehmen lassen.
    ///
    /// Leer heißt „Standard" und nicht „farblos": Ohne Farbe zeichnet
    /// die Ansicht die Farbe der SEITE, und das ist eine Farbe.
    mutating func farbeSetzen(_ neu: String) {
        guard let stelle = ausgewaehlteSpielerstelle else { return }
        let jetzt = zeichnung.spieler[stelle].farbe ?? ""
        guard jetzt != neu else { return }
        verlauf.merken(jetzigerStand)
        // Leer wird zu `nil`: Der Server unterscheidet beides nicht
        // (`_check_color` gibt `""` zurück), aber ein `nil` schreibt
        // den Schlüssel gar nicht erst in die Zeichnung -- und dann
        // steht in zwei Programmen dasselbe.
        zeichnung.spieler[stelle].farbe = neu.isEmpty ? nil : neu
        stand += 1
    }

    /// Die Notiz an einer Figur (R41).
    ///
    /// Cyell am 01.09.2026: „sowie Player Notizen zu jedem Spieler
    /// (Route etc.)." Sie sagt, worauf es bei DIESEM Spieler ankommt --
    /// die Beschriftung an der Linie sagt nur, wie der Weg heisst.
    ///
    /// Gekürzt auf dasselbe Mass wie der Server (`MAX_SPIELERNOTIZ`).
    /// Wer mehr eintippen darf, als ankommt, bekommt seine Eingabe beim
    /// Speichern gekürzt und erfährt es nicht -- dieselbe Falle wie bei
    /// `maxRolle`, `maxKuerzel` und der Beschriftung.
    mutating func notizSetzen(_ neu: String) {
        guard let stelle = ausgewaehlteSpielerstelle else { return }
        let kurz = String(neu.prefix(Zeichenblock.maxSpielernotiz))
        guard zeichnung.spieler[stelle].notiz != kurz else { return }
        zeichnung.spieler[stelle].notiz = kurz
        stand += 1
    }

    // MARK: - Spieler verschieben

    /// Ein Finger liegt auf einer Figur.
    ///
    /// Das wählt sie aus und hebt damit die Auswahl einer Linie auf. Ohne
    /// diesen Schritt zeigt die Fußzeile weiter den Papierkorb der Linie,
    /// die vorhin angetippt war, während der Finger auf einem Spieler
    /// liegt -- und ein Griff daneben löscht dann etwas, das niemand mehr
    /// gemeint hat.
    mutating func anfassen(_ kennung: String) {
        spur("editor", "spieler_anfassen")
        meldung = nil
        auswahl = .spieler(kennung)
        // Der Stand vor dem Zug, noch NICHT im Verlauf: EIN Zug ist ein
        // Schritt und nicht dreißig. Ein Finger, der eine Figur über das
        // Feld schiebt, löst dutzendweise `verschiebe` aus; wer danach
        // Rückgängig drückt, will die Figur dort haben, wo sie vor dem
        // Anfassen stand, und nicht einen Millimeter weiter links.
        //
        // Abgelegt wird erst, wenn sich wirklich etwas bewegt hat --
        // sonst bekäme jedes Antippen einen leeren Schritt.
        zugStand = jetzigerStand
        zugGemerkt = false
    }

    /// Der Finger ist weg. Der nächste Zug ist ein neuer Schritt.
    mutating func loslassen() {
        zugStand = nil
        zugGemerkt = false
    }

    /// Setzt einen Spieler auf eine gefangene Position.
    ///
    /// Die Linien der Position gehen MIT. Wer die Figur verschiebt und den
    /// Weg stehen lässt, hat eine Linie, die im Nichts beginnt. Der
    /// Browser verschiebt sie mit, und die App muss dasselbe tun -- sonst
    /// sieht derselbe Play in beiden Programmen anders aus.
    mutating func verschiebe(_ kennung: String, x: Double, y: Double) {
        guard let stelle = zeichnung.spieler.firstIndex(where: {
            $0.id == kennung
        }) else { return }
        let alt = zeichnung.spieler[stelle]
        guard alt.x != x || alt.y != y else { return }

        if let anfang = zugStand {
            if !zugGemerkt {
                verlauf.merken(anfang)
                zugGemerkt = true
            }
        } else {
            // Verschoben ohne Anfassen: Dann ist es kein Zug, sondern
            // ein einzelner Schritt.
            merken()
        }

        zeichnung.spieler[stelle].x = x
        zeichnung.spieler[stelle].y = y
        linienMitnehmen(kennung, dx: x - alt.x, dy: y - alt.y)
        stand += 1
    }

    /// Jede Linie dieses Spielers um dieselbe Strecke mitnehmen (R26).
    ///
    /// Stand bis zum 28.08.2026 mitten in `verschiebe` und galt deshalb
    /// nur fürs Ziehen. `formationAnwenden` daneben ersetzte die Spieler
    /// und ließ die Linien liegen -- genau der Fehler, den Niklas
    /// gemeldet hat. Als eigene Regel gilt sie jetzt an beiden Stellen.
    ///
    /// **Ins Feld gehalten wird dabei**, wie beim Ziehen: Eine Linie,
    /// die halb neben dem Platz endet, nimmt der Server ohnehin nicht
    /// an, und sie im Ausdruck abgeschnitten zu sehen wäre die
    /// schlechtere Rückmeldung.
    private mutating func linienMitnehmen(_ kennung: String,
                                          dx: Double, dy: Double) {
        guard dx != 0 || dy != 0 else { return }
        for (i, linie) in zeichnung.linien.enumerated()
        where linie.spieler == kennung {
            zeichnung.linien[i].punkte = linie.punkte.map {
                let gefangen = projektion.feld.begrenzen(x: $0.x + dx,
                                                         y: $0.y + dy)
                return Zeichnung.Punkt(x: gefangen.x, y: gefangen.y)
            }
        }
    }

    // MARK: - Stützpunkte verschieben (R11)

    /// Ein einzelner Stützpunkt einer fertigen Linie.
    struct Griffstelle: Equatable {
        var linie: Int
        var punkt: Int
    }

    /// Gehört diese Linie einer Position? Dann ist ihr erster Punkt der
    /// Anfang ihres Weges und kein Griff -- er liegt auf der Figur.
    private func istVerankert(_ stelle: Int) -> Bool {
        guard zeichnung.linien.indices.contains(stelle) else { return false }
        return zeichnung.linien[stelle].spieler != nil
    }

    /// Die Stützpunkte, die die Ansicht als Griffe zeichnen soll.
    ///
    /// Nur an der AUSGEWÄHLTEN Linie, und nur im Auswahl-Werkzeug.
    ///
    /// Alle Punkte aller Linien wären auf einem Handy ein Feld voller
    /// Kreise, und jeder Finger träfe einen fremden. Und wer gerade
    /// zeichnet, kann ohnehin nichts ziehen -- sichtbare Griffe wären
    /// dann ein Versprechen, das die Geste nicht hält. Der Browser
    /// entscheidet an derselben Stelle genauso
    /// (`gewaehlteLinieFuerGriffe` in `editor.js`).
    var griffe: [Zeichnung.Punkt] {
        guard werkzeug == .auswahl else { return [] }
        // Gezeichnet werden weiterhin nur die Griffe der ausgewaehlten
        // Linie -- alle Punkte aller Linien waeren auf einem Handy ein
        // Feld voller Kreise. Angefasst werden darf seit R83 trotzdem
        // jeder (siehe `griffBei`): Das eine ist die Anzeige, das andere
        // die Reichweite des Fingers, und die darf groesser sein.
        return ausgewaehlteLinie?.punkte ?? []
    }

    /// Ob der Punkt an dieser Stelle angefasst werden darf.
    func istGriff(_ stelle: Int) -> Bool {
        guard werkzeug == .auswahl, let linie = ausgewaehlteStelle else {
            return false
        }
        return Griffe.istGriff(stelle, von: zeichnung.linien[linie].punkte.count,
                               verankert: istVerankert(linie))
    }

    /// Welcher Stützpunkt liegt unter dem Finger?
    ///
    /// Gemessen wird auf dem BILDSCHIRM und nicht in Yards: Ein Griff
    /// soll überall gleich groß zu treffen sein. Die Auswahl trifft
    /// `Griffe.naechster` -- dieselbe Regel wie im Browser
    /// (`griffe.js`), und `GriffeTests` misst sie gegen dieselben Proben.
    func griffBei(_ punkt: CGPoint, groesse: CGSize) -> Griffstelle? {
        guard werkzeug == .auswahl else { return nil }

        // JEDE LINIE, NICHT NUR DIE AUSGEWAEHLTE (R83, entschieden am
        // 09.09.2026: „Griffe immer, aber nur nah am Finger").
        //
        // Vorher musste man erst die Linie antippen und DANN ihren Punkt
        // ziehen -- zwei Schritte vor dem eigentlichen. Gemessen kostete
        // „einen Knick verschieben" damit drei Schritte, obwohl es einer
        // ist: hinfassen und ziehen.
        //
        // „Nur nah am Finger" ist dabei keine Einschraenkung, sondern
        // der Grund, warum es geht: Gesucht wird im Umkreis von
        // `Griffe.weite`, und was weiter weg liegt, stoert nicht. Alle
        // Punkte aller Linien SICHTBAR zu machen waere ein Feld voller
        // Kreise -- deshalb aendert sich nur die Trefferpruefung, nicht
        // das Zeichnen.
        //
        // Die AUSGEWAEHLTE Linie zuerst: Wer sie gerade bearbeitet, will
        // ihren Punkt und nicht den einer fremden, die zufaellig
        // daneben liegt.
        var reihenfolge = Array(zeichnung.linien.indices)
        if let gewaehlt = ausgewaehlteStelle {
            reihenfolge.removeAll { $0 == gewaehlt }
            reihenfolge.insert(gewaehlt, at: 0)
        }
        for stelle in reihenfolge {
            let punkte = zeichnung.linien[stelle].punkte.map {
                projektion.aufBildschirm(x: $0.x, y: $0.y, groesse: groesse)
            }
            if let treffer = Griffe.naechster(punkte, zu: punkt,
                                              weite: Griffe.weite,
                                              verankert: istVerankert(stelle)) {
                return Griffstelle(linie: stelle, punkt: treffer)
            }
        }
        return nil
    }

    /// Ein Finger liegt auf einem Griff. Wie `anfassen` bei einer Figur:
    /// Der Stand vor dem Zug wird gemerkt, aber noch nicht abgelegt.
    mutating func griffAnfassen(_ stelle: Griffstelle) {
        spur("editor", "griff_anfassen")
        meldung = nil
        auswahl = .linie(stelle.linie)
        zugStand = jetzigerStand
        zugGemerkt = false
    }

    /// Ein Finger liegt auf einer Zonenflaeche. Wie `griffAnfassen`,
    /// nur ohne einzelnen Punkt.
    mutating func zugBeginnen() {
        spur("editor", "flaeche_anfassen")
        meldung = nil
        zugStand = jetzigerStand
        zugGemerkt = false
    }

    /// Setzt einen Stützpunkt auf eine neue Stelle.
    ///
    /// **Der Spieler bleibt, wo er ist.** Beim Verschieben einer FIGUR
    /// gehen ihre Linien mit -- hier nicht: Wer einen Knick zwei Yards
    /// versetzt, will genau den Knick versetzen. Das ist die Meldung
    /// (Niklas, 25.08.2026): „ich würde es cool finden wenn man einzelne
    /// punkte bei zone oder route auch nochmal verschieben könnte."
    ///
    /// **Kein Winkelfang.** Beim Zeichnen rastet die Richtung zum
    /// Vorgänger ein; das beschreibt eine Route. Ein fertiger Knick hat
    /// aber auch einen Nachfolger, und ihn auf einen Winkel zum
    /// Vorgänger zu zwingen verbiegt die Strecke dahinter. Genau das ist
    /// die Beschwerde aus R5.
    mutating func griffVerschieben(_ stelle: Griffstelle,
                                   x: Double, y: Double) {
        guard zeichnung.linien.indices.contains(stelle.linie) else { return }
        var linie = zeichnung.linien[stelle.linie]
        guard linie.punkte.indices.contains(stelle.punkt) else { return }
        guard Griffe.istGriff(stelle.punkt, von: linie.punkte.count,
                              verankert: linie.spieler != nil) else { return }
        let alt = linie.punkte[stelle.punkt]
        guard alt.x != x || alt.y != y else { return }

        // EIN ZUG IST EIN SCHRITT. Derselbe Gedanke wie bei `verschiebe`:
        // Ein Finger, der einen Punkt über das Feld schiebt, löst
        // dutzendweise Aufrufe aus. Wer danach Rückgängig drückt, will
        // den Punkt dort haben, wo er vor dem Anfassen lag.
        if let anfang = zugStand {
            if !zugGemerkt {
                verlauf.merken(anfang)
                zugGemerkt = true
            }
        } else {
            merken()
        }

        linie.punkte[stelle.punkt] = Zeichnung.Punkt(x: x, y: y)
        zeichnung.linien[stelle.linie] = linie
        stand += 1
    }

    /// Liegt dieser Punkt INNERHALB einer Zonenflaeche?
    ///
    /// Gefragt wird nur nach Flaechen, und nur im Auswahl-Werkzeug: Eine
    /// Route ist ein Strich, den man an ihren Griffen anfasst; eine
    /// Flaeche hat ein Inneres, und wer dort hineinfasst, meint sie als
    /// Ganzes.
    func zonenflaecheBei(_ punkt: CGPoint, groesse: CGSize) -> Int? {
        guard werkzeug == .auswahl else { return nil }
        let feld = projektion.vomBildschirm(punkt, groesse: groesse)
        for (stelle, linie) in zeichnung.linien.enumerated().reversed()
        where linie.istFlaeche {
            if Zeichenblock.liegtIn(linie, x: feld.x, y: feld.y) { return stelle }
        }
        return nil
    }

    /// Punkt-in-Flaeche, je nach Form.
    static func liegtIn(_ linie: Zeichnung.Linie, x: Double, y: Double) -> Bool {
        let p = linie.punkte
        switch linie.zonenform {
        case .kreis:
            guard p.count >= 2 else { return false }
            let r = (p[0].x - p[1].x) * (p[0].x - p[1].x)
                  + (p[0].y - p[1].y) * (p[0].y - p[1].y)
            let d = (p[0].x - x) * (p[0].x - x) + (p[0].y - y) * (p[0].y - y)
            return d <= r
        case .rechteck:
            guard p.count >= 2 else { return false }
            return x >= min(p[0].x, p[1].x) && x <= max(p[0].x, p[1].x)
                && y >= min(p[0].y, p[1].y) && y <= max(p[0].y, p[1].y)
        case .linie:
            // Strahlensatz, wie ueberall. Ein Vieleck ist selten konvex.
            guard p.count >= 3 else { return false }
            var drin = false
            var j = p.count - 1
            for i in 0..<p.count {
                if (p[i].y > y) != (p[j].y > y),
                   x < (p[j].x - p[i].x) * (y - p[i].y)
                       / (p[j].y - p[i].y) + p[i].x {
                    drin.toggle()
                }
                j = i
            }
            return drin
        }
    }

    /// Verschiebt eine ganze Linie um `dx`, `dy` -- alle Punkte zugleich.
    ///
    /// **Warum das fehlte und warum es weh tat** (Niklas, 09.09.2026):
    /// „ich finde das viel zu kompliziert das zu verschieben". Es gab
    /// nur `griffVerschieben`, also EINEN Punkt je Zug. Eine Zone drei
    /// Yards nach links zu setzen hiess: jeden Punkt einzeln anfassen
    /// und dabei die Form nicht verlieren. Bei einem Kreis waren das
    /// zwei Zuege, bei einem Vieleck fuenf -- und beim kleinsten
    /// Danebengreifen war die Form verzogen.
    mutating func linieVerschieben(_ stelle: Int, dx: Double, dy: Double) {
        guard zeichnung.linien.indices.contains(stelle) else { return }
        var linie = zeichnung.linien[stelle]
        guard !linie.punkte.isEmpty else { return }

        // EIN ZUG IST EIN SCHRITT, wie bei Figur und Griff.
        if let anfang = zugStand {
            if !zugGemerkt {
                verlauf.merken(anfang)
                zugGemerkt = true
            }
        } else {
            merken()
        }

        // ALLE PUNKTE UM DENSELBEN BETRAG, und die Begrenzung aufs Feld
        // gilt fuer die ganze Form: Wer einen einzelnen Punkt am Rand
        // klemmen liesse, verzoege die Form beim Anstossen.
        let feld = projektion.feld
        var wirklichX = dx
        var wirklichY = dy
        for punkt in linie.punkte {
            let (gx, gy) = feld.begrenzen(x: punkt.x + dx, y: punkt.y + dy)
            wirklichX = dx < 0 ? max(wirklichX, gx - punkt.x)
                               : min(wirklichX, gx - punkt.x)
            wirklichY = dy < 0 ? max(wirklichY, gy - punkt.y)
                               : min(wirklichY, gy - punkt.y)
        }
        linie.punkte = linie.punkte.map {
            Zeichnung.Punkt(x: $0.x + wirklichX, y: $0.y + wirklichY)
        }
        zeichnung.linien[stelle] = linie
        stand += 1
    }

    /// Stellt die Art der AUSGEWAEHLTEN Linie um (R83).
    ///
    /// Entschieden am 09.09.2026: drei Werkzeuge statt zehn. Auswahl,
    /// Route und Zone stehen in der Leiste; welche Art eine Linie ist,
    /// wird danach an ihr umgestellt. So macht es auch Playmaker X, und
    /// es nimmt sechs Knoepfe aus einer Leiste, die auf dem Telefon
    /// ohnehin seitlich scrollen musste.
    ///
    /// **Die Zone ist nicht dabei, und das mit Absicht.** Sie ist keine
    /// andere Art derselben Sache, sondern eine Flaeche: Sie braucht
    /// drei Punkte statt zwei, gehoert keinem Spieler und hat kein
    /// Ende. Eine Route in eine Zone zu verwandeln hiesse, aus einem
    /// Strich einen Raum zu machen -- das ist keine Umstellung, das ist
    /// eine neue Linie.
    mutating func artSetzen(_ art: Zeichnung.Linie.Art) {
        spur("editor", "linienart", art.rawValue)
        guard let stelle = ausgewaehlteStelle else { return }
        var linie = zeichnung.linien[stelle]
        guard linie.art != .zone, art != .zone, linie.art != art else { return }
        merken()
        linie.art = art
        // Das Ende gehoert zur Art: Eine Route endet im Pfeil, ein
        // Abschirmen im Querstrich. Wer die Art aendert und das Ende
        // stehen liesse, bekaeme einen Block mit Pfeil.
        linie.ende = art.stil.standardEnde
        zeichnung.linien[stelle] = linie
        stand += 1
    }

    // MARK: - Gesichert

    /// Nach dem Speichern. Die Zeichnung bleibt, der Vermerk geht -- aber
    /// nur für den Stand, der wirklich beim Server war.
    ///
    /// `bis` ist der Wert von `stand`, der VOR dem Absenden gelesen wurde,
    /// und nicht der von jetzt. Wer währenddessen weitergezeichnet hat,
    /// bleibt „Ungesichert" -- sonst behauptet die Fußzeile etwas, das der
    /// Server nicht hat, und beim Zurückgehen ist die Linie weg.
    mutating func gesichert(bis: Int) {
        gesichertBis = bis
    }
}
