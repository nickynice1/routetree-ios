// Das Datenformat einer Zeichnung, in Swift.
//
// Die Quelle ist backend/designer/schema.py. Anders als Feld.swift wird
// diese Datei NICHT erzeugt: Ein Schema ist keine Liste von Zahlen,
// sondern eine Menge von Regeln, und ein Erzeuger dafuer waere mehr Code
// als die Datei selbst. Stattdessen beweist ein Hin-und-Rueck-Vergleich
// gegen echte Server-Plays, dass beide Seiten dasselbe meinen
// (RoutetreeTests/ZeichnungTests.swift).
//
// WAS DABEI ZAEHLT: Was hier hineingeht, muss zeichengleich wieder
// herauskommen. Ein Feld, das Swift nicht kennt, faellt beim Speichern
// still weg -- und dann verliert die App beim Verschieben eines Spielers
// die Verzoegerung einer Route, die jemand im Browser gesetzt hat.

import Foundation

/// Eine Zeichnung: Spieler und Linien, alle Koordinaten in Yards.
///
/// `x` laeuft in Feldrichtung (0 bis `gesamtLaenge`), `y` quer
/// (0 bis `breite`). Die Line of Scrimmage haengt am Play, nicht hier.
struct Zeichnung: Codable, Equatable {
    var spieler: [Spieler] = []
    var linien: [Linie] = []

    /// Jede Yard-Linie, auf der in diesem Play etwas steht.
    ///
    /// Dieselbe Aufzählung wie `_alle_yardwerte` in `render.py`, und
    /// gebraucht für dasselbe: `Projektion.passendFuer` weitet damit
    /// den Ausschnitt, bis der ganze Play hineinpasst. Ohne sie liefe
    /// eine Go-Route über dreissig Yards aus dem Bild -- und das fällt
    /// niemandem auf, weil das Bild an der Kante einfach aufhört.
    ///
    /// Nur `x`: Es geht um die LÄNGE. Quer gibt es `querwerte`.
    var yardwerte: [Double] {
        spieler.map(\.x) + linien.flatMap { $0.punkte.map(\.x) }
    }

    /// Jede Querlage, auf der in diesem Play etwas steht.
    ///
    /// Dieselbe Aufzählung wie `render._alle_querwerte` -- Spieler UND
    /// Wegpunkte. Nur die Spieler zu nehmen wäre der nächste Fehler:
    /// Eine Out-Route endet an der Seitenlinie, und der Ausschnitt
    /// schnitte sie ab.
    ///
    /// Gebraucht seit dem 08.09.2026 für `querPassendFuer`: Der
    /// Ausschnitt wird längs geweitet UND quer verengt.
    var querwerte: [Double] {
        spieler.map(\.y) + linien.flatMap { $0.punkte.map(\.y) }
    }

    enum CodingKeys: String, CodingKey {
        case spieler = "players"
        case linien = "routes"
    }

    /// Ein leerer Play hat keine Zeichnung, und die JSON-Antwort dazu ist
    /// `{}` -- ohne beide Schluessel. Ohne diese beiden Zeilen waere das
    /// ein Dekodierfehler, und die App zeigte statt eines leeren Feldes
    /// eine Fehlermeldung.
    init(from decoder: Decoder) throws {
        let behaelter = try decoder.container(keyedBy: CodingKeys.self)
        spieler = try behaelter.decodeIfPresent([Spieler].self,
                                                forKey: .spieler) ?? []
        linien = try behaelter.decodeIfPresent([Linie].self,
                                               forKey: .linien) ?? []
    }

    init(spieler: [Spieler] = [], linien: [Linie] = []) {
        self.spieler = spieler
        self.linien = linien
    }

    /// Hoechstens so viele je Seite, WENN NIEMAND EINE SPIELFORM NENNT.
    ///
    /// **Der Satz, der hier stand, war seit T4 falsch**: „Das Format
    /// ist 5 gegen 5, und der Server weist mehr zurueck." Der Server
    /// nimmt die Grenze seit T4 aus der Spielform
    /// (`schema.validate_play_data`), der Browser aus der Antwort
    /// (`editor.js`, `MAX_JE_SEITE`). Nur Swift stand fest auf fuenf --
    /// und behauptete dazu eine Sportart.
    ///
    /// Entschaerft war es nur dadurch, dass die Konstante nirgends
    /// gelesen wird. Das ist kein Zustand, auf den man sich verlassen
    /// soll: Beim ersten „Spieler hinzufuegen" in der App wird sie
    /// scharf. Wer sie benutzt, nimmt `Spielform.spieler`.
    ///
    /// Der Wert bleibt fuenf, weil er der Rueckfall des Servers ist
    /// (`schema.MAX_PLAYERS_PER_SIDE`) -- also das, was gilt, wenn
    /// niemand eine Form nennt.
    static let maxJeSeite = 5
    static let maxLinien = 40
    static let maxPunkteJeLinie = 40

    func anzahl(_ seite: Spieler.Seite) -> Int {
        spieler.filter { $0.seite == seite }.count
    }

    /// Die Linie eines Spielers, falls er eine hat.
    ///
    /// Seit R88 kann er zwei haben: seinen Weg und den des Balls (Snap,
    /// Pass). Gefragt ist hier der Weg des MENSCHEN -- der Ballweg
    /// beschreibt den Ball und nicht, was diese Position tut.
    func linie(von spielerId: String) -> Linie? {
        let seine = linien.filter { $0.spieler == spielerId }
        return seine.first { $0.art.sorte == .weg } ?? seine.first
    }
}

extension Zeichnung {

    /// Ein Spieler auf dem Feld.
    struct Spieler: Codable, Equatable, Identifiable {
        /// Die Kennung aus der Zeichnung (`o_qb`, `d_c1`, ...), nicht die
        /// Zeilennummer einer Datenbank. Sie verbindet Spieler und Linie.
        var id: String
        var seite: Seite
        /// Die Position im Fachjargon (`QB`, `X`, `C1`). Darf leer sein.
        var rolle: String
        /// Was im Kreis steht. Hoechstens drei Zeichen, sonst passt es
        /// nicht in den Kreis -- weder hier noch im Ausdruck.
        var kuerzel: String
        var farbe: String?
        /// Was dieser Spieler tun soll -- in Worten (R41).
        ///
        /// Cyell am 01.09.2026: „sowie Player Notizen zu jedem Spieler
        /// (Route etc.)." Die Beschriftung an der LINIE sagt, wie der
        /// Weg heisst („Go", „Out"); diese Notiz sagt, worauf es
        /// ankommt: „gegen Zone kurz sitzen".
        ///
        /// Leer und nicht `nil`: Anders als bei der Farbe gibt es
        /// keinen Unterschied zwischen „keine Notiz" und „leere
        /// Notiz", und ein `Optional` zwaenge jede Stelle zu einem
        /// `?? ""`.
        var notiz: String = ""
        var x: Double
        var y: Double

        enum Seite: String, Codable, Equatable {
            case offense = "off"
            case defense = "def"
        }

        enum CodingKeys: String, CodingKey {
            case id, side, role, label, color, x, y
            case notiz = "note"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(String.self, forKey: .id)
            seite = try b.decodeIfPresent(Seite.self, forKey: .side) ?? .offense
            rolle = try b.decodeIfPresent(String.self, forKey: .role) ?? ""
            kuerzel = try b.decodeIfPresent(String.self, forKey: .label) ?? "?"
            farbe = try b.decodeIfPresent(String.self, forKey: .color)
            // Leer als Rückfall: Eine ältere Zeichnung hat den
            // Schlüssel nicht, und das ist keine Notiz, sondern keine.
            notiz = try b.decodeIfPresent(String.self, forKey: .notiz) ?? ""
            x = try b.decode(Double.self, forKey: .x)
            y = try b.decode(Double.self, forKey: .y)
        }

        func encode(to encoder: Encoder) throws {
            var b = encoder.container(keyedBy: CodingKeys.self)
            try b.encode(id, forKey: .id)
            try b.encode(seite, forKey: .side)
            try b.encode(rolle, forKey: .role)
            try b.encode(kuerzel, forKey: .label)
            // `color` ist beim Server optional und wird dort aus der
            // Position abgeleitet, wenn nichts kommt. Ein `null` waere
            // etwas anderes als „nicht gesetzt": Der Server nimmt beides,
            // aber wer die Antwort spaeter vergleicht, sieht einen
            // Unterschied, den niemand gemacht hat.
            try b.encodeIfPresent(farbe, forKey: .color)
            // IMMER MITSCHICKEN, auch leer: Der Server nimmt `note`
            // entgegen und schneidet ab; ein weggelassener Schlüssel
            // liesse eine gelöschte Notiz stehen -- man löscht sie,
            // speichert, und beim nächsten Laden steht sie wieder da.
            try b.encode(notiz, forKey: .notiz)
            try b.encode(x, forKey: .x)
            try b.encode(y, forKey: .y)
        }

        init(id: String, seite: Seite, rolle: String = "", kuerzel: String,
             farbe: String? = nil, notiz: String = "",
             x: Double, y: Double) {
            self.id = id
            self.seite = seite
            self.notiz = notiz
            self.rolle = rolle
            self.kuerzel = kuerzel
            self.farbe = farbe
            self.x = x
            self.y = y
        }
    }

    /// Eine Linie in ihre Stücke, mit der Art je Stück (R45).
    ///
    /// Cyell am 01.09.2026: „Route in Segmente einteilen das man eine
    /// Motion haben kann + normale Route." Ohne Vorlauf ist es genau
    /// ein Stück -- also alles wie vorher.
    ///
    /// **Die beiden Stücke teilen sich den Grenzpunkt**, sonst klaffte
    /// dort eine Lücke von einem Segment. Bei einer gerundeten Linie
    /// bekommt sie an dieser Stelle eine Ecke, und das ist richtig:
    /// Dort hört die Motion auf und die Route fängt an.
    ///
    /// **Dieselbe Aufteilung steht dreimal** -- hier, in
    /// `render._abschnitte` und in `editor.js`. Sie muss überall
    /// dieselbe sein; deshalb steht sie in jedem Programm an genau
    /// EINER Stelle und nicht in jedem Zeichner noch einmal.
    struct Abschnitt {
        let punkte: [Punkt]
        let art: Linie.Art
    }

    /// Ein Punkt einer Linie, in Yards.
    struct Punkt: Codable, Equatable {
        var x: Double
        var y: Double
    }

    /// Eine Linie: Route, Block, Motion, Abgabe, Pass oder Zone.
    struct Linie: Codable, Equatable {
        /// Zu wem sie gehoert. `nil` gibt es: eine freie Linie, die an
        /// keinem Spieler haengt.
        var spieler: String?
        var art: Art
        var ende: Ende
        /// Gebogen statt eckig gezeichnet.
        var gebogen: Bool
        /// Beschriftung an der Linie, hoechstens `maxBeschriftung` Zeichen.
        var beschriftung: String
        /// Sekunden, die dieser Spieler beim Abspielen wartet.
        var verzoegerung: Double
        /// Tempo beim Abspielen, 0,5 bis 2,0.
        var tempo: Double
        var punkte: [Punkt]
        /// Wie eine Zone gezeichnet wird (R48).
        ///
        /// Die Arten aus `schema.ZONENFORMEN`. Wer hier etwas hinzufügt,
        /// muss es dort auch tun -- sonst weist der Server es zurück.
        ///
        /// `linie` ist der Bestand: ein Vieleck aus mindestens drei
        /// Punkten. `kreis` und `rechteck` stehen mit ZWEI Punkten fest,
        /// beim Kreis Mittelpunkt und ein Punkt auf dem Rand, beim
        /// Rechteck zwei gegenüberliegende Ecken.
        ///
        /// Gilt nur für ``Art/zone``. Eine Route mit einer Form wäre
        /// eine Behauptung über etwas, das keine Fläche ist.
        enum Zonenform: String, Codable, Equatable, CaseIterable {
            case linie
            case kreis
            case rechteck
        }

        var zonenform: Zonenform = .linie

        /// Ist diese Linie eine Fläche und kein Strich?
        ///
        /// Die Zahl steht hier und nicht an jeder Zeichenstelle: Beim
        /// Vieleck sind drei Punkte nötig, bei Kreis und Rechteck zwei.
        var istFlaeche: Bool {
            guard art == .zone else { return false }
            return zonenform == .linie ? punkte.count >= 3 : punkte.count >= 2
        }

        /// Bis zu welchem Stützpunkt diese Linie eine MOTION ist (R45).
        ///
        /// Cyell am 01.09.2026: „Route in Segmente einteilen das man
        /// eine Motion haben kann + normale Route." Bis dahin war die
        /// Art eine Eigenschaft der GANZEN Linie; ein Receiver, der vor
        /// dem Snap läuft und danach seine Route, brauchte zwei Linien,
        /// und die hingen nur im Kopf des Trainers zusammen.
        ///
        /// `0` heißt „kein Vorlauf" und ist der Normalfall: eine Linie,
        /// ein Stil. Gültig ist `1 ... punkte.count - 2` -- auf jeder
        /// Seite muss mindestens ein Abschnitt bleiben.
        var motionBis: Int = 0

        /// Die Grenze des Servers, hier noch einmal (R25).
        ///
        /// `schema.validate_play_data` schneidet die Beschriftung beim
        /// Speichern auf vierzehn Zeichen ab, und `render.py` setzt beim
        /// Zeichnen ebenfalls nur die ersten vierzehn. Wer in der App mehr
        /// eintippen darf, als ankommt, bekommt seine Eingabe beim
        /// Speichern gekuerzt und erfaehrt es nicht -- dieselbe Falle wie
        /// bei `maxRolle` und `maxKuerzel` aus R9.
        ///
        /// **Warum sie hier steht und nicht am `Zeichenblock`**, wo die
        /// beiden anderen liegen: Die Zahl wird an ZWEI Stellen gebraucht,
        /// beim Eintippen und beim Zeichnen. `Feldansicht` ist keine
        /// Editoransicht und hat mit dem Block nichts zu tun; sie zeichnet
        /// auch Zeichnungen, die nie durch einen Editor gelaufen sind. Die
        /// Grenze gehoert also an die Linie selbst.
        static let maxBeschriftung = 14

        /// Die Arten aus `schema.LINE_KINDS`. Wer hier etwas hinzufuegt,
        /// muss es dort auch tun -- sonst weist der Server es zurueck.
        enum Art: String, Codable, Equatable, CaseIterable {
            case route
            case block
            case motion
            case handoff
            case pass
            case zone
            /// Der zweite Ast einer Gabelung (R20).
            ///
            /// **Sie hat hier gefehlt, und das war kein Schoenheitsfehler.**
            /// `schema.LINE_KINDS` kennt sie seit R20, das ERZEUGTE
            /// `Linienstil.swift` benutzt `.option` -- und diese
            /// Aufzaehlung hatte den Fall nicht. Zweierlei folgte
            /// daraus, und beides faellt ohne Mac erst auf dem Laeufer
            /// auf: Die App uebersetzte gar nicht mehr, und selbst wenn
            /// sie es taete, waere ein Play mit einer Option Route beim
            /// Dekodieren umgefallen -- `decodeIfPresent` gibt bei einem
            /// unbekannten `rawValue` nicht `nil` zurueck, sondern
            /// wirft. Ein einziger Play haette die ganze Liste
            /// unlesbar gemacht.
            case option

            /// Darf diese Art auf freier Fläche anfangen, ohne Spieler?
            ///
            /// **Nur die Zone.** Sie beschreibt einen RAUM, den jemand
            /// deckt, und den zeichnet man um eine Stelle des Feldes,
            /// nicht um eine Figur. Alles andere ist ein WEG, und ein
            /// Weg gehört dem, der ihn läuft.
            ///
            /// Niklas am 02.09.2026, mit einem Bildschirmfoto, auf dem
            /// ein Weg neben dem Feld schwebte: „Man kann immer noch
            /// wild routen irgendwo machen? Verstehe nicht warum soll
            /// das wegen Option Route sein?"
            ///
            /// Er hatte recht, und die Begründung im `Zeichenblock` war
            /// zu breit geraten: Sie nannte die Zone, und für die
            /// stimmt sie. Ein Weg ohne Läufer bewegt sich im Ablauf
            /// nicht, steht im Ausdruck ohne Zuordnung, und „zeig mir
            /// nur meinen Weg" in der Spieleransicht findet ihn nie.
            ///
            /// **Die Option Route gehört auch einem Spieler**, obwohl
            /// sie an einem Punkt einer anderen Linie ansetzt: Es ist
            /// derselbe Receiver, der sich entscheidet.
            /// **Seit dem 06.09.2026 kommt die Antwort vom SERVER**
            /// (`Linienstil.frei`, erzeugt aus `render.LINE_STYLES`).
            /// Vorher stand hier `self == .zone` -- und im Browser stand
            /// die Regel gar nicht. Zwei Fassungen, von denen eine
            /// fehlte: Am Schreibtisch liessen sich weiterhin Wege ohne
            /// Läufer zeichnen, obwohl die App es seit R58 verhindert.
            var darfFreiAnfangen: Bool { stil.frei }
        }

        /// Die Enden aus `schema.LINE_ENDS`.
        ///
        /// Die Namen sind die des Servers, auch wo ein deutscher näher
        /// läge: Sie stehen so im JSON, und ein `rawValue`, der von der
        /// Schreibweise abweicht, ist eine Fehlerquelle ohne Gewinn.
        enum Ende: String, Codable, Equatable, CaseIterable {
            /// Pfeil: Laufweg oder Route, der Regelfall.
            case arrow
            /// Querstrich: Sitzroute oder Blockpunkt.
            case tee
            /// Offen: die Linie geht weiter, das Ende ist nicht der Punkt.
            case none
        }

        enum CodingKeys: String, CodingKey {
            case player, kind, end, curve, label, delay, speed, points
            case motionBis = "motion_bis"
            case zonenform
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            spieler = try b.decodeIfPresent(String.self, forKey: .player)
            art = try b.decodeIfPresent(Art.self, forKey: .kind) ?? .route
            ende = try b.decodeIfPresent(Ende.self, forKey: .end) ?? .arrow
            gebogen = try b.decodeIfPresent(Bool.self, forKey: .curve) ?? false
            beschriftung = try b.decodeIfPresent(String.self,
                                                 forKey: .label) ?? ""
            verzoegerung = try b.decodeIfPresent(Double.self,
                                                 forKey: .delay) ?? 0
            tempo = try b.decodeIfPresent(Double.self, forKey: .speed) ?? 1
            punkte = try b.decodeIfPresent([Punkt].self, forKey: .points) ?? []
            // Fehlt der Schlüssel, gibt es keinen Vorlauf -- eine
            // ältere Zeichnung ist eine Linie in einem Stil (R45).
            motionBis = try b.decodeIfPresent(Int.self,
                                              forKey: .motionBis) ?? 0
            // Fehlt der Schlüssel, ist die Zone ein Vieleck -- so war es
            // vor R48, und so sind alle vorhandenen Zeichnungen abgelegt.
            zonenform = try b.decodeIfPresent(Zonenform.self,
                                              forKey: .zonenform) ?? .linie
        }

        func encode(to encoder: Encoder) throws {
            var b = encoder.container(keyedBy: CodingKeys.self)
            try b.encode(spieler, forKey: .player)
            try b.encode(art, forKey: .kind)
            try b.encode(ende, forKey: .end)
            try b.encode(gebogen, forKey: .curve)
            try b.encode(beschriftung, forKey: .label)
            try b.encode(verzoegerung, forKey: .delay)
            try b.encode(tempo, forKey: .speed)
            try b.encode(punkte, forKey: .points)
            // IMMER MITSCHICKEN, auch die 0: Ein weggelassener
            // Schlüssel liesse einen gelöschten Vorlauf stehen -- man
            // nimmt ihn weg, speichert, und beim nächsten Laden ist
            // er wieder da.
            try b.encode(motionBis, forKey: .motionBis)
            // IMMER MITSCHICKEN, aus demselben Grund wie der Vorlauf:
            // Ein weggelassener Schlüssel liesse eine Form stehen, die
            // gerade zurückgestellt wurde.
            try b.encode(zonenform, forKey: .zonenform)
        }

        /// Die Stücke dieser Linie, mit der Art je Stück (R45).
        ///
        /// Ohne Vorlauf genau eines. Siehe ``Zeichnung/Abschnitt``.
        var abschnitte: [Abschnitt] {
            guard punkte.count >= 2 else { return [] }
            // ZWEI VERGLEICHE UND KEIN BEREICH (Absturz vom 08.09.2026).
            //
            // Hier stand `1...(punkte.count - 2) ~= motionBis`. Bei
            // einer Linie mit GENAU ZWEI Punkten -- einer geraden Route,
            // dem häufigsten Fall überhaupt -- ist das `1...0`, und ein
            // Bereich, dessen Ende vor seinem Anfang liegt, ist in Swift
            // kein leerer Bereich, sondern ein Programmabbruch:
            //
            //     Swift runtime failure: Range requires lowerBound
            //     <= upperBound
            //     Zeichnung.Linie.abschnitte.getter (Zeichnung.swift:352)
            //     Feldansicht.zeichneLinien(_:auf:faktor:)
            //
            // Das ist der Absturzbericht, den Niklas am 08.09. um 04:26
            // aus TestFlight geschickt hat („Abgestürzt"). Aufgefallen
            // ist er beim Zeichnen einer Option-Route: Die hat nach dem
            // ersten Tipp genau zwei Punkte.
            //
            // Ein Bereich taugt nur dort, wo er nicht leer werden kann.
            // Zwei Vergleiche können es nicht.
            guard art != .zone,
                  motionBis >= 1, motionBis <= punkte.count - 2 else {
                return [Abschnitt(punkte: punkte, art: art)]
            }
            return [
                Abschnitt(punkte: Array(punkte[0...motionBis]), art: .motion),
                Abschnitt(punkte: Array(punkte[motionBis...]), art: art),
            ]
        }

        /// Wie viele Stellen es gibt, an denen sich teilen lässt.
        ///
        /// Null heißt: keine. Bei zwei Punkten gibt es nichts zu
        /// teilen, und eine Zone hat keine Richtung.
        var teilstellen: Int {
            art == .zone ? 0 : max(0, punkte.count - 2)
        }

        init(spieler: String?, art: Art = .route, ende: Ende = .arrow,
             gebogen: Bool = false, beschriftung: String = "",
             verzoegerung: Double = 0, tempo: Double = 1,
             motionBis: Int = 0, punkte: [Punkt]) {
            self.spieler = spieler
            self.art = art
            self.ende = ende
            self.gebogen = gebogen
            self.motionBis = motionBis
            self.beschriftung = beschriftung
            self.verzoegerung = verzoegerung
            self.tempo = tempo
            self.punkte = punkte
        }

        /// Eine Zone braucht drei Punkte, alles andere zwei. Dieselbe
        /// Regel wie in `schema.validate_play_data`.
        var mindestensPunkte: Int {
            art == .zone && zonenform == .linie ? 3 : 2
        }

        /// Wie viele Punkte diese Linie HÖCHSTENS trägt, oder `nil`.
        ///
        /// Kreis und Rechteck stehen mit genau zwei Punkten fest: beim
        /// Kreis Mitte und Rand, beim Rechteck zwei gegenüberliegende
        /// Ecken. Ein dritter Punkt hat dort keine Bedeutung.
        ///
        /// **Und genau daran ist die Bedienung gescheitert** (Niklas,
        /// 09.09.2026): „wenn ich auf den Punkt tippe um es grösser zu
        /// ziehen, denn erstelle ich nur super viele andere Punkte die
        /// gar keinen Sinn ergeben." Das Zeichenwerkzeug hängte bei
        /// jedem weiteren Tipp einen Punkt an, weil ihm niemand gesagt
        /// hatte, dass die Form längst vollständig ist.
        var hoechstensPunkte: Int? {
            art == .zone && zonenform != .linie ? 2 : nil
        }

        /// Ist diese Form fertig und nimmt keinen Punkt mehr an?
        var istGeschlosseneForm: Bool {
            guard let grenze = hoechstensPunkte else { return false }
            return punkte.count >= grenze
        }
        var istVollstaendig: Bool { punkte.count >= mindestensPunkte }
    }
}
