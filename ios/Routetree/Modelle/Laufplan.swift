// Der Ablauf: wann wer losläuft, und wo er dann steht.
//
// Ein Play läuft nicht in einem Rutsch. Erst die Motion vor dem Snap,
// dann der Snap, dann die Routen. Wer alles gleichzeitig startet, zeigt
// eine Bewegung, die es auf dem Feld nie gibt -- ein Mesh-Konzept oder
// ein Motion-Sweep wird dabei unlesbar.
//
// DIE QUELLE IST `static/designer/laufplan.js`. Dieselbe Rechnung, und
// deshalb dieselbe Prüfung: `scripts/laufplan_swift.py` lässt das
// JavaScript unter Node über ein Dutzend Fälle laufen und schreibt seine
// Ergebnisse nach `LaufplanProben.swift`. `LaufplanTests` rechnet sie in
// Swift nach. Ohne das wäre „die App spielt ab wie das Web" eine
// Behauptung; es gibt hier keinen Mac, auf dem man beides nebeneinander
// ansehen könnte.
//
// WAS DIE ANSICHT NICHT ENTSCHEIDET: nichts davon. Der Weg entlang einer
// Linie, die Beschleunigung, das Anhalten am Ende und der Text auf dem
// Knopf stehen hier und werden gemessen. Die Ansicht zeichnet Punkte an
// Stellen, die sie sich hat ausrechnen lassen.

import Foundation

/// Die Zeitachse eines Plays und die Wege dazu.
struct Laufplan: Equatable {

    /// Die vier Spannen in Millisekunden, wie in `laufplan.js`.
    struct Zeiten: Equatable {
        /// Bewegung vor dem Snap.
        var motion: Double = 900
        /// Kurzes Innehalten beim Snap.
        var snap: Double = 260
        /// Die eigentlichen Laufwege.
        var routen: Double = 1900
        /// Endbild stehen lassen.
        var nachlauf: Double = 550

        init(motion: Double = 900, snap: Double = 260,
             routen: Double = 1900, nachlauf: Double = 550) {
            self.motion = motion
            self.snap = snap
            self.routen = routen
            self.nachlauf = nachlauf
        }
    }

    /// Was zum Ball gehört und nicht zu einem Menschen. Ein Snap und
    /// ein Pass hängen zwar an einem Spieler -- dort fangen sie an --,
    /// aber unterwegs ist der Ball, nicht er.
    ///
    /// **Die Liste stand hier getippt und steht seit dem 09.09.2026 in
    /// `render.py`** (R88). Sie war die zweite Fassung derselben
    /// Zuordnung, und der Editor hatte gar keine -- deshalb ersetzte
    /// ein Snap die Route desselben Spielers.
    static func istBallweg(_ art: Zeichnung.Linie.Art) -> Bool {
        art.stil.ball
    }

    /// Eine Linie auf der Zeitachse, ohne ihren Weg.
    ///
    /// Getrennt vom `Laeufer`, weil genau das die Rechnung ist, die auch
    /// `laufplan.js` macht: Aus ihr entstehen die Proben, die beide
    /// Seiten vergleichbar machen.
    struct Eintrag: Equatable {
        var linie: Zeichnung.Linie
        var vorSnap: Bool
        var start: Double
        var ende: Double
    }

    /// Die reine Zeitachse: Reihenfolge und Dauer, ohne Geometrie.
    struct Achse: Equatable {
        var eintraege: [Eintrag]
        var hatMotion: Bool
        var snapZeit: Double
        var routenStart: Double
        var gesamt: Double
        var nachlauf: Double
    }

    /// Eine Linie mit ihrem Weg, bereit zum Abfahren.
    struct Laeufer: Equatable {
        var linie: Zeichnung.Linie
        var vorSnap: Bool
        var start: Double
        var ende: Double
        /// Die Stützpunkte in Yards.
        var punkte: [Zeichnung.Punkt]
        /// Der bis zu jedem Punkt zurückgelegte Weg. `laengen[0]` ist 0.
        var laengen: [Double]

        var laenge: Double { laengen.last ?? 0 }

        /// Der Punkt nach `anteil` der Strecke (0 bis 1).
        ///
        /// Gerechnet wird ÜBER DIE STRECKE und nicht über die Punkte:
        /// Eine Route mit einem kurzen Haken und einem langen Go hätte
        /// sonst für beide Stücke gleich viel Zeit, und der Läufer
        /// schliche über die ersten drei Yards und schösse die letzten
        /// achtzehn hinunter.
        func punkt(bei anteil: Double) -> Zeichnung.Punkt {
            guard let erster = punkte.first else {
                return Zeichnung.Punkt(x: 0, y: 0)
            }
            guard punkte.count >= 2, laenge > 0 else { return erster }
            let weg = min(max(anteil, 0), 1) * laenge
            for i in 1..<punkte.count {
                let bis = laengen[i]
                guard weg <= bis else { continue }
                let von = laengen[i - 1]
                let stueck = bis - von
                let t = stueck > 0 ? (weg - von) / stueck : 0
                let a = punkte[i - 1], b = punkte[i]
                return Zeichnung.Punkt(x: a.x + (b.x - a.x) * t,
                                       y: a.y + (b.y - a.y) * t)
            }
            return punkte[punkte.count - 1]
        }
    }

    /// Wo eine Figur zu einem Zeitpunkt steht.
    struct Marke: Equatable {
        /// Wer sich bewegt. Gehört die Linie zu einem Spieler, läuft SEIN
        /// Symbol mit -- ein wandernder Punkt zeigt zwar den Weg, aber
        /// nicht, wer ihn geht. Bei fünf Routen gleichzeitig ist das der
        /// Unterschied zwischen einem lesbaren Ablauf und fünf Punkten.
        enum Traeger: Equatable {
            case ball
            case spieler(String)
            /// Freie Linien haben keinen Träger. Dafür bleibt der Punkt.
            case punkt
        }

        var traeger: Traeger
        var art: Zeichnung.Linie.Art
        var vorSnap: Bool
        var x: Double
        var y: Double
        /// Wohin es gerade geht, im Bogenmass (R89).
        ///
        /// Niklas am 09.09.2026: „Denn Football mehr nach Football
        /// texturieren, und vorallem in Flugrichtung drehen." Gebraucht
        /// wird es nur vom Ball -- eine Figur ist ein Kreis und hat
        /// keine Blickrichtung -- aber die Marke traegt es fuer alle:
        /// Zwei Sorten Marke waeren zwei Wege durch dieselbe Schleife.
        var winkel: Double = 0
    }

    var laeufer: [Laeufer]
    var hatMotion: Bool
    var snapZeit: Double
    var routenStart: Double
    /// Nur über die Läufer, die es wirklich gibt: Eine Linie ohne Länge
    /// fällt heraus und darf den Ablauf nicht verlängern.
    var gesamt: Double
    var nachlauf: Double

    /// Wer mitläuft. Ihr Standbild tritt zurück, solange sie unterwegs
    /// sind -- sonst stünde jede Figur doppelt auf dem Feld.
    var laufendeSpieler: Set<String>

    var istLeer: Bool { laeufer.isEmpty }

    // MARK: - Bauen

    init(linien: [Zeichnung.Linie], zeiten: Zeiten = Zeiten()) {
        let achse = Laufplan.zeitachse(linien, zeiten: zeiten)
        var gebaut: [Laeufer] = []
        var laufende: Set<String> = []
        for eintrag in achse.eintraege {
            let punkte = eintrag.linie.punkte
            guard punkte.count >= 2 else { continue }
            var laengen: [Double] = [0]
            var summe: Double = 0
            for i in 1..<punkte.count {
                let dx = punkte[i].x - punkte[i - 1].x
                let dy = punkte[i].y - punkte[i - 1].y
                summe += (dx * dx + dy * dy).squareRoot()
                laengen.append(summe)
            }
            // Eine Linie ohne Länge hat keinen Weg. Der Browser lässt sie
            // aus demselben Grund weg: `getTotalLength()` ist dort null.
            guard summe > 0 else { continue }
            gebaut.append(Laeufer(linie: eintrag.linie, vorSnap: eintrag.vorSnap,
                                  start: eintrag.start, ende: eintrag.ende,
                                  punkte: punkte, laengen: laengen))
            if !Laufplan.istBallweg(eintrag.linie.art),
               let wer = eintrag.linie.spieler {
                laufende.insert(wer)
            }
        }
        laeufer = gebaut
        hatMotion = achse.hatMotion
        snapZeit = achse.snapZeit
        routenStart = achse.routenStart
        nachlauf = achse.nachlauf
        gesamt = gebaut.reduce(0) { max($0, $1.ende) }
        laufendeSpieler = laufende
    }

    /// Die Zeitachse zu einer Liste von Linien.
    ///
    /// Zeile für Zeile `laufplan.js`. Zonen gehören nicht dazu -- sie
    /// laufen nicht, sie stehen.
    static func zeitachse(_ linien: [Zeichnung.Linie],
                          zeiten: Zeiten = Zeiten()) -> Achse {
        let laufende = linien.filter { $0.art != .zone }
        let hatMotion = laufende.contains { vorDemSnap($0) }

        // Jede Linie bringt ihr eigenes Timing mit: eine Verzögerung in
        // Sekunden und ein Tempo als Faktor. Das ist es, was ein
        // Mesh-Konzept lesbar macht -- zwei Receiver kreuzen
        // nacheinander, nicht gleichzeitig.
        func verzug(_ linie: Zeichnung.Linie) -> Double {
            let wert = linie.verzoegerung
            return wert.isFinite && wert > 0 ? wert * 1000 : 0
        }
        func tempo(_ linie: Zeichnung.Linie) -> Double {
            let wert = linie.tempo
            return wert.isFinite && wert > 0 ? wert : 1
        }

        // Die Motion-Phase dauert, bis der LETZTE Motion-Läufer durch ist
        // -- sonst schneidet der Snap eine verzögerte Bewegung ab.
        var motionEnde: Double = 0
        for linie in laufende where vorDemSnap(linie) {
            motionEnde = max(motionEnde,
                             verzug(linie) + zeiten.motion / tempo(linie))
        }
        if !hatMotion { motionEnde = 0 }
        let routenStart = motionEnde + zeiten.snap

        let eintraege = laufende.map { linie -> Eintrag in
            let vor = vorDemSnap(linie)
            let start = (vor ? 0 : routenStart) + verzug(linie)
            let dauer = (vor ? zeiten.motion : zeiten.routen) / tempo(linie)
            return Eintrag(linie: linie, vorSnap: vor,
                           start: start, ende: start + dauer)
        }

        return Achse(eintraege: eintraege,
                     hatMotion: hatMotion,
                     snapZeit: motionEnde,
                     routenStart: routenStart,
                     gesamt: eintraege.reduce(0) { max($0, $1.ende) },
                     nachlauf: zeiten.nachlauf)
    }

    /// Was vor dem Snap läuft. Alles andere gehört dahinter.
    static func vorDemSnap(_ linie: Zeichnung.Linie) -> Bool {
        linie.art == .motion
    }

    // MARK: - Abfahren

    /// Wo alle Figuren zum Zeitpunkt `zeit` (in Millisekunden) stehen.
    func marken(bei zeit: Double) -> [Marke] {
        laeufer.map { laeufer in
            let spanne = laeufer.ende - laeufer.start
            let roh = spanne > 0 ? (zeit - laeufer.start) / spanne : 1
            let t = min(max(roh, 0), 1)
            let punkt = laeufer.punkt(bei: Laufplan.weich(t))
            let traeger: Marke.Traeger
            if Laufplan.istBallweg(laeufer.linie.art) {
                traeger = .ball
            } else if let wer = laeufer.linie.spieler {
                traeger = .spieler(wer)
            } else {
                traeger = .punkt
            }
            // Die Richtung aus dem Weg selbst: ein Stueck davor, ein
            // Stueck danach, die Steigung dazwischen. Am Anfang und am
            // Ende faellt einer der beiden auf den Punkt selbst zurueck
            // -- dann zeigt der Ball dorthin, wo er herkam.
            let s = Laufplan.weich(t)
            let davor = laeufer.punkt(bei: max(0, s - 0.02))
            let danach = laeufer.punkt(bei: min(1, s + 0.02))
            let winkel = atan2(danach.y - davor.y, danach.x - davor.x)
            return Marke(traeger: traeger, art: laeufer.linie.art,
                         vorSnap: laeufer.vorSnap, x: punkt.x, y: punkt.y,
                         winkel: winkel)
        }
    }

    /// Auslaufen statt Abbremsen: dieselbe Kurve wie im Browser
    /// (`ease-out-cubic`). Eine Bewegung mit gleichbleibendem Tempo sieht
    /// aus wie eine Schiebefigur, keine wie ein Spieler.
    static func weich(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }
}

// MARK: - Der laufende Ablauf

/// Kein Durchlauf, sondern ein Zustand.
///
/// Der Ablauf hält an, lässt sich spulen und im Tempo verstellen. Ein
/// Trainer will an der Stelle stehen bleiben, an der es klemmt; dafür
/// reicht ein einmaliges Durchlaufen nicht. Dieselbe Entscheidung wie im
/// Browser, und derselbe Grund.
///
/// **Ohne Uhr.** Diese Struktur fragt nie, wie spät es ist -- sie bekommt
/// die verstrichene Zeit gereicht. Nur so lässt sich das Anhalten am Ende
/// messen, ohne eine Sekunde zu warten.
struct Ablauf: Equatable {

    static let tempoMin: Double = 0.5
    static let tempoMax: Double = 2
    /// Die Stufen aus der Auswahl im Browser.
    static let tempoStufen: [Double] = [0.5, 0.75, 1, 1.5, 2]

    let plan: Laufplan
    private(set) var zeit: Double = 0
    private(set) var laeuft = false
    private(set) var tempo: Double = 1

    init(plan: Laufplan) {
        self.plan = plan
    }

    var amEnde: Bool { zeit >= plan.gesamt }

    /// Die Marken zum jetzigen Zeitpunkt, für die Ansicht.
    var marken: [Laufplan.Marke] { plan.marken(bei: zeit) }

    /// Was auf dem Hauptknopf steht. Am Ende „Nochmal" und nicht
    /// „Weiter": Weiter geht dort nichts mehr.
    var knopf: String { laeuft ? "Pause" : (amEnde ? "Nochmal" : "Weiter") }

    /// Das Zeichen auf dem Abspielknopf (R85).
    ///
    /// Niklas am 09.09.2026 mit einem Bildschirmfoto, auf dem der linke
    /// Bereich eingekringelt ist: „Play und Pause Button links, also
    /// wenn es abspielt Pause Button wenn es pausiert ist play".
    ///
    /// Das Wort allein reichte nicht. „Weiter" und „Nochmal" sagen zwar
    /// genauer, was passiert, aber sie sagen es in einem Bedienelement,
    /// das jeder Mensch seit vierzig Jahren am DREIECK erkennt -- und am
    /// Spielfeldrand liest niemand, er tippt. Das Zeichen führt, das
    /// Wort erklärt.
    var knopfzeichen: String { laeuft ? "pause.fill" : "play.fill" }

    /// Die Stelle im Ablauf, als Text. Deutsches Komma.
    var zeittext: String {
        String(format: "%.1f", zeit / 1000).replacingOccurrences(
            of: ".", with: ",") + " s"
    }

    /// Verstrichene Zeit einrechnen, in Millisekunden Wanduhr.
    ///
    /// Das Tempo streckt die Wanduhr, es verstellt NICHT die Zeitachse:
    /// Sonst sprängen die Läufer beim Umschalten, weil derselbe
    /// Zeitpunkt plötzlich eine andere Stelle im Play bezeichnete.
    mutating func schritt(_ millisekunden: Double) {
        guard laeuft, millisekunden > 0 else { return }
        zeit += millisekunden * tempo
        if zeit >= plan.gesamt {
            // Am Ende bleibt das Bild stehen, statt zu verschwinden: Der
            // letzte Zustand ist der, über den man redet.
            zeit = plan.gesamt
            laeuft = false
        }
    }

    /// Losspielen. Am Ende fängt es wieder von vorn an.
    mutating func weiter() {
        guard plan.gesamt > 0 else { return }
        if amEnde { zeit = 0 }
        laeuft = true
    }

    mutating func anhalten() {
        laeuft = false
    }

    /// Zurück an den Anfang. Läuft der Ablauf, läuft er weiter -- wer auf
    /// „Anfang" drückt, will es noch einmal sehen und nicht anhalten.
    mutating func anfang() {
        zeit = 0
    }

    /// Von Hand spulen. Das hält an: Wer am Regler zieht, sucht eine
    /// Stelle, und ein weiterlaufender Ablauf zöge ihm die Stelle unter
    /// dem Finger weg.
    mutating func spulen(zu neu: Double) {
        laeuft = false
        zeit = min(max(neu, 0), plan.gesamt)
    }

    mutating func tempoSetzen(_ neu: Double) {
        guard neu.isFinite else { return }
        tempo = min(max(neu, Ablauf.tempoMin), Ablauf.tempoMax)
    }
}
