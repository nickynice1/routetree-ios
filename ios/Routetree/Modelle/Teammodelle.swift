import Foundation

// Was der Server über eine MANNSCHAFT schickt (B9).
//
// In einer eigenen Datei und nicht in `Modelle.swift`: Dort steht der
// Weg Playbook → Play, hier der Weg Mannschaft → Kader → Zugang. Beides
// in einer Datei wären neunhundert Zeilen mit zwei Themen, und beim
// Suchen fände man immer das falsche.
//
// WAS HIER NICHT ENTSCHIEDEN WIRD: ob jemand etwas darf. Das steht als
// `darfFuehren`, `darfAendern`, `darfName` und `letzterHead` in der
// Antwort -- gerechnet vom Server, aus denselben Funktionen, die auch
// die Webseite fragt. Ein Knopf, der beim Drücken 403 bekommt, ist ein
// toter Knopf (ADR-0007), und eine Rolle, die die App selbst auswertet,
// ist die Regel ein zweites Mal in Swift.

extension Modell {

    /// Ein Wert mit seiner deutschen Beschriftung -- Rollen, Bereiche.
    ///
    /// Vom Server und nicht in Swift getippt: „Head Coach",
    /// „Assistenz", „Nur Ansicht" stehen in `Membership.Role.choices`,
    /// und beim nächsten Umbenennen bliebe eine Fassung stehen.
    struct Auswahl: Decodable, Identifiable, Hashable {
        let wert: String
        let text: String

        var id: String { wert }
    }

    /// Der Verein über einer Mannschaft, so viel wie die App braucht.
    struct Vereinskopf: Decodable, Hashable {
        let id: Int
        let name: String
        /// Ob dieser Verein auf `demo` steht. Bestimmt, was die Grenzen
        /// bedeuten -- nicht, was die App verbietet.
        let demo: Bool
        /// Das Vereinswappen (R30), als vollständige Adresse.
        ///
        /// Der Server hat die Rückfallregel schon angewandt: Ist beim
        /// Verein selbst keines hinterlegt, steht hier das der ersten
        /// Mannschaft. `nil` heißt „nirgends eines" und ist kein
        /// Fehler.
        let logo: URL?
        /// Die Initialen des VEREINS, vom Server, aus derselben Regel
        /// wie die der Mannschaft (`models.initialen_aus`).
        let initialen: String

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(Int.self, forKey: .id)
            name = try b.decode(String.self, forKey: .name)
            demo = try b.decodeIfPresent(Bool.self, forKey: .demo) ?? false
            // `decodeIfPresent`, damit eine ältere Serverfassung ohne
            // diese Felder nicht die GANZE Antwort unlesbar macht --
            // dieselbe Lehre wie bei B9.
            logo = try b.decodeIfPresent(URL.self, forKey: .logo)
            initialen = try b.decodeIfPresent(String.self,
                                              forKey: .initialen) ?? ""
        }

        /// Der Bauweg fuer Tests und Vorschauen.
        ///
        /// **Er MUSS jedes gespeicherte Feld setzen**, auch die, die
        /// niemand mitgibt -- sonst „return from initializer without
        /// initializing all stored properties". Genau daran ist der Bau
        /// am 28.08.2026 gescheitert: Zwei neue Felder (R30) standen
        /// oben, hier fehlten sie, und der Compiler sagt es erst auf
        /// dem Laeufer.
        ///
        /// Vorgabewerte statt Pflichtangaben: Ein Test, der einen
        /// Verein baut, interessiert sich fuer Name und Zustand -- ein
        /// Wappen muesste er sonst erfinden.
        init(id: Int, name: String, demo: Bool = false,
             logo: URL? = nil, initialen: String = "") {
            self.id = id
            self.name = name
            self.demo = demo
            self.logo = logo
            self.initialen = initialen
        }

        enum CodingKeys: String, CodingKey {
            case id, name, demo, logo, initialen
        }
    }

    /// Eine Mannschaft -- in der Liste wie auf ihrer eigenen Seite.
    ///
    /// **Ein Typ für beides.** Die Liste lässt die schweren Felder weg
    /// (Kader, Teamcode, Einladungen, Schlüssel), und das sind genau die
    /// optionalen. Zwei Typen hätten dieselben zwölf Rechtefelder
    /// zweimal, und beim nächsten Feld bekäme einer davon es nicht.
    struct Mannschaft: Decodable, Identifiable, Hashable {
        let id: Int
        let name: String
        let farbe: String
        /// Das Logo, als vollständige Adresse. `nil` heißt „keins
        /// hochgeladen" -- das ist der Normalfall und kein Fehler.
        ///
        /// Vollständig und nicht `/medien/…`, weil `AsyncImage` keinen
        /// Serverstamm kennt: Ein Pfad wäre dort kein Bild, sondern
        /// nichts.
        let logo: URL?
        /// Die Initialen aus dem Namen, wenn kein Logo da ist -- **vom
        /// Server**.
        ///
        /// Sie stehen auf jedem Ausdruck (`printing._wappen`). Würde die
        /// App sie selbst rechnen, hieße dieselbe Mannschaft auf dem
        /// Blatt „RU" und im Telefon vielleicht „RO", und niemand
        /// könnte sagen, welche der beiden Regeln die richtige ist.
        let initialen: String
        let verein: Vereinskopf
        /// Die eigene Rolle. `nil` heißt „kein Mitglied" -- das gibt es
        /// wirklich: Ein Vereinsadmin sieht jede Mannschaft seines
        /// Vereins, ohne in einer davon zu stehen.
        let rolle: String?
        let rolleText: String?
        let istVereinsadmin: Bool
        /// Darf hier geschrieben werden (Head Coach, Assistenz,
        /// Vereinsadmin)? Daran hängt auch, wer Aufgaben verteilt.
        let darfAendern: Bool
        /// Führt diese Person die Mannschaft? Enger als `darfAendern`:
        /// Zugänge vergibt nur der Head Coach.
        let darfFuehren: Bool
        let mitglieder: Int
        let playbooks: Int

        // --- Nur auf der Mannschaftsseite -------------------------------

        /// Wie viele Plays die Mannschaft insgesamt hat. Ohne einen
        /// einzigen gibt es keinen Balken -- und dann soll auch nicht
        /// von einem die Rede sein.
        let plays: Int
        let kader: [Kadermitglied]
        let rollen: [Auswahl]
        /// Teamcode, Einladungen und Schlüssel kommen NUR mit, wenn
        /// diese Person die Mannschaft führt. `nil` heißt hier deshalb
        /// „geht dich nichts an" und nicht „gibt es nicht" --
        /// `darfFuehren` sagt, welches von beidem.
        let teamcode: Teamcodestand?
        let einladungen: [Einladung]?
        let schluessel: [Schluessel]?
        let haltbarkeiten: [Auswahl]?
        let standardHaltbarkeit: String?
        let einladungTage: [Int]?
        let standardTage: Int?
        /// Welche Rolle eine neue Einladung vorschlägt. Vom Server und
        /// nicht „der letzte Eintrag in `rollen`": Das stimmt nur,
        /// solange die Liste in dieser Reihenfolge steht, und wäre
        /// „Head Coach" vorgewählt, verschenkte ein Trainer die
        /// Mannschaft mit einem Knopfdruck.
        let standardRolle: String?
        let schluesselBereiche: [Auswahl]?
        let schluesselTage: [Int]?
        let standardSchluesselTage: Int?
        /// Was diese Mannschaft spielt: Flag oder Tackle, und mit wie
        /// vielen (T4).
        ///
        /// Gebraucht beim ANLEGEN eines Playbooks: Bei einer
        /// Tackle-Mannschaft hat die Feldformatwahl keine Bedeutung --
        /// die drei Formate sind Flagmaße.
        let spielform: String

        enum CodingKeys: String, CodingKey {
            case id, name, farbe, logo, initialen, verein, rolle, spielform
            case mitglieder, playbooks
            case plays, kader, rollen, teamcode, einladungen, schluessel
            case haltbarkeiten
            case rolleText = "rolle_text"
            case istVereinsadmin = "ist_vereinsadmin"
            case darfAendern = "darf_aendern"
            case darfFuehren = "darf_fuehren"
            case standardHaltbarkeit = "standard_haltbarkeit"
            case einladungTage = "einladung_tage"
            case standardTage = "standard_tage"
            case standardRolle = "standard_rolle"
            case schluesselBereiche = "schluessel_bereiche"
            case schluesselTage = "schluessel_tage"
            case standardSchluesselTage = "standard_schluessel_tage"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(Int.self, forKey: .id)
            name = try b.decode(String.self, forKey: .name)
            farbe = try b.decodeIfPresent(String.self, forKey: .farbe)
                ?? Farbwert.standard
            // ÜBER DEN UMWEG TEXT, nicht `decode(URL.self)`. Ein
            // JSONDecoder wirft bei einer Adresse, aus der er keine URL
            // machen kann -- und dann wäre nicht das Wappen weg, sondern
            // die ganze Mannschaftsliste. Ein Bild ist das eine, die
            // Liste das andere.
            if let quelle = try b.decodeIfPresent(String.self, forKey: .logo),
               !quelle.isEmpty {
                logo = URL(string: quelle)
            } else {
                logo = nil
            }
            // Leer heißt „der Server hat nicht mitgeschickt". Dann steht
            // ein Zeichen im Wappen und keine selbstgerechnete Abkürzung
            // (siehe `Kachelblock.wappen`).
            initialen = try b.decodeIfPresent(String.self,
                                              forKey: .initialen) ?? ""
            verein = try b.decode(Vereinskopf.self, forKey: .verein)
            // `decodeIfPresent`, damit eine ältere Serverfassung ohne
            // dieses Feld nicht die ganze Mannschaftsliste unlesbar
            // macht -- dieselbe Lehre wie bei B9.
            spielform = try b.decodeIfPresent(String.self,
                                              forKey: .spielform)
                        ?? Spielform.standard
            rolle = try b.decodeIfPresent(String.self, forKey: .rolle)
            rolleText = try b.decodeIfPresent(String.self, forKey: .rolleText)
            istVereinsadmin = try b.decodeIfPresent(
                Bool.self, forKey: .istVereinsadmin) ?? false
            // Fehlt der Schlüssel, wurde nicht gefragt. Dann lieber
            // keinen Knopf zeigen als einen, der mit 403 endet.
            darfAendern = try b.decodeIfPresent(
                Bool.self, forKey: .darfAendern) ?? false
            darfFuehren = try b.decodeIfPresent(
                Bool.self, forKey: .darfFuehren) ?? false
            mitglieder = try b.decodeIfPresent(Int.self,
                                               forKey: .mitglieder) ?? 0
            playbooks = try b.decodeIfPresent(Int.self,
                                              forKey: .playbooks) ?? 0
            plays = try b.decodeIfPresent(Int.self, forKey: .plays) ?? 0
            kader = try b.decodeIfPresent([Kadermitglied].self,
                                          forKey: .kader) ?? []
            rollen = try b.decodeIfPresent([Auswahl].self,
                                           forKey: .rollen) ?? []
            teamcode = try b.decodeIfPresent(Teamcodestand.self,
                                             forKey: .teamcode)
            einladungen = try b.decodeIfPresent([Einladung].self,
                                                forKey: .einladungen)
            schluessel = try b.decodeIfPresent([Schluessel].self,
                                               forKey: .schluessel)
            haltbarkeiten = try b.decodeIfPresent([Auswahl].self,
                                                  forKey: .haltbarkeiten)
            standardHaltbarkeit = try b.decodeIfPresent(
                String.self, forKey: .standardHaltbarkeit)
            einladungTage = try b.decodeIfPresent([Int].self,
                                                  forKey: .einladungTage)
            standardTage = try b.decodeIfPresent(Int.self,
                                                 forKey: .standardTage)
            standardRolle = try b.decodeIfPresent(String.self,
                                                  forKey: .standardRolle)
            schluesselBereiche = try b.decodeIfPresent(
                [Auswahl].self, forKey: .schluesselBereiche)
            schluesselTage = try b.decodeIfPresent([Int].self,
                                                   forKey: .schluesselTage)
            standardSchluesselTage = try b.decodeIfPresent(
                Int.self, forKey: .standardSchluesselTage)
        }
    }

    struct MannschaftsListe: Decodable {
        let teams: [Mannschaft]
    }

    /// Eine Zeile im Kader (A6): Name, seit wann, Rolle, wie viel sitzt.
    struct Kadermitglied: Decodable, Identifiable, Hashable {
        /// Die Kennung der MITGLIEDSCHAFT, nicht die des Kontos. Ein
        /// Kader gehört der Mannschaft (A5).
        let id: Int
        let name: String
        let rolle: String
        let rolleText: String
        /// `nil` heißt „vor A6 beigetreten und nicht aufgeschrieben" --
        /// NICHT „heute". Ein erfundener Tag sähe aus wie gemessen.
        let seit: Date?
        /// Ob das die anrufende Person selbst ist.
        let ich: Bool
        /// Der einzige Head Coach. An ihm ändert niemand etwas, auch er
        /// selbst nicht -- sonst stünde die Mannschaft ohne jemanden da,
        /// der sie verwalten kann.
        let letzterHead: Bool
        /// Ob DIESE Person DIESEN Namen berichtigen darf: der Head Coach
        /// bei jedem, jeder andere bei sich selbst.
        let darfName: Bool
        /// Wie viel sitzt. `nil` heißt „geht dich nichts an" -- für
        /// Unbeteiligte rechnet der Server es gar nicht erst aus.
        let fortschritt: Fortschritt?

        enum CodingKeys: String, CodingKey {
            case id, name, rolle, seit, ich, fortschritt
            case rolleText = "rolle_text"
            case letzterHead = "letzter_head"
            case darfName = "darf_name"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(Int.self, forKey: .id)
            name = try b.decode(String.self, forKey: .name)
            rolle = try b.decodeIfPresent(String.self, forKey: .rolle) ?? ""
            rolleText = try b.decodeIfPresent(String.self,
                                              forKey: .rolleText) ?? ""
            seit = try b.decodeIfPresent(Date.self, forKey: .seit)
            ich = try b.decodeIfPresent(Bool.self, forKey: .ich) ?? false
            letzterHead = try b.decodeIfPresent(
                Bool.self, forKey: .letzterHead) ?? false
            darfName = try b.decodeIfPresent(Bool.self,
                                             forKey: .darfName) ?? false
            fortschritt = try b.decodeIfPresent(Fortschritt.self,
                                                forKey: .fortschritt)
        }

        /// Nur für Tests und Vorschauen.
        init(id: Int, name: String, rolle: String = "viewer",
             rolleText: String = String(localized: "Nur Ansicht"),
             seit: Date? = nil,
             ich: Bool = false, letzterHead: Bool = false,
             darfName: Bool = false, fortschritt: Fortschritt? = nil) {
            self.id = id
            self.name = name
            self.rolle = rolle
            self.rolleText = rolleText
            self.seit = seit
            self.ich = ich
            self.letzterHead = letzterHead
            self.darfName = darfName
            self.fortschritt = fortschritt
        }
    }

    /// Der eine Code, mit dem eine Mannschaft beitritt (A4).
    struct Teamcodestand: Decodable, Hashable {
        let code: String
        /// In Vierergruppen, zum Vorlesen. **Vom Server gruppiert** --
        /// `Teamcode.lesbar`, damit die App nicht irgendwann Dreier
        /// zeigt.
        let lesbar: String
        /// Der Link zum Verschicken.
        let link: String
        /// `nil` heißt unbegrenzt.
        let gueltigBis: Date?
        let unbegrenzt: Bool
        let abgelaufen: Bool
        /// „gültig", „abgelaufen", „unbegrenzt" -- der Satz vom Server
        /// und nicht aus `unbegrenzt` und `abgelaufen` zusammengereimt.
        /// Zusammengereimt stünde in der App irgendwann ein anderes Wort
        /// als im Browser, und beide sähen richtig aus.
        let zustand: String
        /// Wie oft schon jemand darüber hereingekommen ist. Die einzige
        /// Zahl, an der ein Trainer merkt, dass ein Code weiterwandert.
        let beitritte: Int
        let zuletztBenutzt: Date?

        enum CodingKeys: String, CodingKey {
            case code, lesbar, link, unbegrenzt, abgelaufen, beitritte
            case zustand
            case gueltigBis = "gueltig_bis"
            case zuletztBenutzt = "zuletzt_benutzt"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            code = try b.decode(String.self, forKey: .code)
            lesbar = try b.decodeIfPresent(String.self,
                                           forKey: .lesbar) ?? code
            link = try b.decodeIfPresent(String.self, forKey: .link) ?? ""
            gueltigBis = try b.decodeIfPresent(Date.self, forKey: .gueltigBis)
            unbegrenzt = try b.decodeIfPresent(
                Bool.self, forKey: .unbegrenzt) ?? (gueltigBis == nil)
            abgelaufen = try b.decodeIfPresent(Bool.self,
                                               forKey: .abgelaufen) ?? false
            zustand = try b.decodeIfPresent(String.self,
                                            forKey: .zustand) ?? ""
            beitritte = try b.decodeIfPresent(Int.self,
                                              forKey: .beitritte) ?? 0
            zuletztBenutzt = try b.decodeIfPresent(Date.self,
                                                   forKey: .zuletztBenutzt)
        }

        /// Nur für Tests und Vorschauen.
        init(code: String, lesbar: String, link: String = "",
             gueltigBis: Date? = nil, unbegrenzt: Bool = true,
             abgelaufen: Bool = false, zustand: String = "gültig",
             beitritte: Int = 0, zuletztBenutzt: Date? = nil) {
            self.code = code
            self.lesbar = lesbar
            self.link = link
            self.gueltigBis = gueltigBis
            self.unbegrenzt = unbegrenzt
            self.abgelaufen = abgelaufen
            self.zustand = zustand
            self.beitritte = beitritte
            self.zuletztBenutzt = zuletztBenutzt
        }
    }

    /// Was beim Erzeugen eines Codes herauskommt.
    struct NeuerTeamcode: Decodable {
        let teamcode: Teamcodestand
        /// Ob dabei ein vorhandener Code ersetzt wurde. Das ist keine
        /// Nebensache: Der alte gilt ab sofort nicht mehr, und wer ihn
        /// im Training vorgelesen hat, muss es erfahren.
        let ersetzt: Bool
    }

    /// Ein Einladungslink: EINE Person, EINMAL gültig, Rolle wählbar.
    struct Einladung: Decodable, Identifiable, Hashable {
        let id: Int
        let rolle: String
        let rolleText: String
        /// „offen", „eingelöst", „widerrufen", „abgelaufen" -- der Satz
        /// vom Server, nicht aus vier Feldern zusammengereimt.
        let zustand: String
        let offen: Bool
        let angelegtAm: Date?
        let gueltigBis: Date?
        /// **Nur solange sie offen ist.** Eine eingelöste Einladung
        /// führt nirgendwohin; ein Knopf „Teilen" verschickte dann eine
        /// tote Adresse, und der Trainer merkt es erst, wenn sich jemand
        /// meldet.
        let link: String?

        enum CodingKeys: String, CodingKey {
            case id, rolle, zustand, offen, link
            case rolleText = "rolle_text"
            case angelegtAm = "angelegt_am"
            case gueltigBis = "gueltig_bis"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(Int.self, forKey: .id)
            rolle = try b.decodeIfPresent(String.self, forKey: .rolle) ?? ""
            rolleText = try b.decodeIfPresent(String.self,
                                              forKey: .rolleText) ?? ""
            zustand = try b.decodeIfPresent(String.self,
                                            forKey: .zustand) ?? ""
            offen = try b.decodeIfPresent(Bool.self, forKey: .offen) ?? false
            angelegtAm = try b.decodeIfPresent(Date.self, forKey: .angelegtAm)
            gueltigBis = try b.decodeIfPresent(Date.self, forKey: .gueltigBis)
            link = try b.decodeIfPresent(String.self, forKey: .link)
        }

        /// Nur für Tests und Vorschauen.
        init(id: Int, rolle: String, rolleText: String, zustand: String,
             offen: Bool, angelegtAm: Date? = nil, gueltigBis: Date? = nil,
             link: String? = nil) {
            self.id = id
            self.rolle = rolle
            self.rolleText = rolleText
            self.zustand = zustand
            self.offen = offen
            self.angelegtAm = angelegtAm
            self.gueltigBis = gueltigBis
            self.link = link
        }
    }

    /// Ein Maschinenschlüssel: ein fremdes Programm darf Plays LESEN.
    struct Schluessel: Decodable, Identifiable, Hashable {
        let id: Int
        let name: String
        let bereich: String
        let bereichText: String
        let zustand: String
        let angelegtAm: Date?
        let gueltigBis: Date?
        let zuletztBenutzt: Date?
        /// **Der Klartext, und nur beim Anlegen.** Danach zeigt ihn
        /// niemand mehr, auch der Server nicht -- dort liegt nur ein
        /// Hash.
        let wert: String?

        enum CodingKeys: String, CodingKey {
            case id, name, bereich, zustand, wert
            case bereichText = "bereich_text"
            case angelegtAm = "angelegt_am"
            case gueltigBis = "gueltig_bis"
            case zuletztBenutzt = "zuletzt_benutzt"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(Int.self, forKey: .id)
            name = try b.decodeIfPresent(String.self, forKey: .name) ?? ""
            bereich = try b.decodeIfPresent(String.self,
                                            forKey: .bereich) ?? ""
            bereichText = try b.decodeIfPresent(String.self,
                                                forKey: .bereichText) ?? ""
            zustand = try b.decodeIfPresent(String.self,
                                            forKey: .zustand) ?? ""
            angelegtAm = try b.decodeIfPresent(Date.self, forKey: .angelegtAm)
            gueltigBis = try b.decodeIfPresent(Date.self, forKey: .gueltigBis)
            zuletztBenutzt = try b.decodeIfPresent(Date.self,
                                                   forKey: .zuletztBenutzt)
            wert = try b.decodeIfPresent(String.self, forKey: .wert)
        }

        /// Nur für Tests und Vorschauen.
        init(id: Int, name: String, bereich: String = "plays",
             bereichText: String = "Plays lesen", zustand: String = "gültig",
             angelegtAm: Date? = nil, gueltigBis: Date? = nil,
             zuletztBenutzt: Date? = nil, wert: String? = nil) {
            self.id = id
            self.name = name
            self.bereich = bereich
            self.bereichText = bereichText
            self.zustand = zustand
            self.angelegtAm = angelegtAm
            self.gueltigBis = gueltigBis
            self.zuletztBenutzt = zuletztBenutzt
            self.wert = wert
        }
    }

    /// Was eine Änderung am Kader ergeben hat.
    ///
    /// `meldung` kommt vom SERVER (`kader.Ergebnis`) und wird nicht in
    /// Swift gebaut: Derselbe Satz steht im Browser, und `test_ton.py`
    /// liest ihn an einer Stelle.
    struct Kaderergebnis: Decodable {
        /// „geaendert" oder „unveraendert". Der Unterschied zählt: Eine
        /// App, die „Rolle geändert" meldet, obwohl nichts geschehen
        /// ist, erzählt etwas Falsches.
        let art: String
        let meldung: String
        /// Beim Entfernen: ob die Person sich selbst herausgenommen hat.
        /// Dann gibt es die Mannschaftsseite für sie nicht mehr.
        let selbst: Bool

        var geaendert: Bool { art == "geaendert" }

        enum CodingKeys: String, CodingKey { case art, meldung, selbst }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            art = try b.decodeIfPresent(String.self, forKey: .art) ?? ""
            meldung = try b.decodeIfPresent(String.self,
                                            forKey: .meldung) ?? ""
            selbst = try b.decodeIfPresent(Bool.self, forKey: .selbst) ?? false
        }
    }

    /// Wohin die Aufgabenseite gehört: Mannschaft, Mitglied, Name.
    ///
    /// Ein eigener Wert und nicht `Kadermitglied`, weil der Weg dorthin
    /// die MANNSCHAFT braucht -- die Adresse lautet
    /// `/teams/<team>/aufgabe/<mitglied>/`. Eine Kaderzeile allein weiß
    /// nicht, zu welcher Mannschaft sie gehört, und eine falsche
    /// Kennung im Pfad ergäbe ein 404, das aussieht wie „diesen
    /// Menschen gibt es nicht".
    struct Aufgabenziel: Hashable {
        let team: Int
        let mitglied: Int
        let name: String
    }

    /// Der Lernauftrag einer Person (A7), zum Anhaken.
    struct Aufgabenblatt: Decodable {
        let ziel: Ziel
        let hefte: [Heft]
        /// Wie viele Plays gerade aufgegeben sind.
        let wieviele: Int
        let playsGesamt: Int

        struct Ziel: Decodable, Hashable {
            let id: Int
            let name: String
            let rolleText: String

            enum CodingKeys: String, CodingKey {
                case id, name
                case rolleText = "rolle_text"
            }
        }

        /// **Nach Playbook gruppiert**, damit bei zwei Heften
        /// nebeneinander erkennbar bleibt, woher ein Play kommt. Zwei
        /// gleichnamige Plays in zwei Playbooks sind der Regelfall.
        struct Heft: Decodable, Identifiable, Hashable {
            let id: Int
            let name: String
            let plays: [Eintrag]
        }

        struct Eintrag: Decodable, Identifiable, Hashable {
            let id: Int
            let name: String
            let nummer: Int?
            let angehakt: Bool

            var titel: String {
                guard let nummer else { return name }
                return "#\(nummer) \(name)"
            }
        }

        enum CodingKeys: String, CodingKey {
            case ziel, hefte, wieviele
            case playsGesamt = "plays_gesamt"
        }
    }

    /// Was hinter einem Teamcode steckt -- **ohne beizutreten**.
    struct Codeauskunft: Decodable {
        let team: Kopf
        /// Was man wird, wenn man beitritt: Zuschauer, immer.
        let rolleText: String
        let schonDabei: Bool
        /// Die eigene Rolle, wenn man schon dabei ist.
        let meineRolle: String?
        /// Vorbelegung für das Namensfeld, aus dem Konto.
        let namensvorschlag: String
        /// Reicht hier ein freiwilliges Kürzel statt eines Namens?
        ///
        /// **Das entscheidet der SERVER (R24).** Ob ein Verein auf
        /// Schullizenz steht, steht in seinem Zustand; eine zweite
        /// Regel in Swift sähe nie falsch aus, sondern nur nach einem
        /// anderen Formular. Fehlt das Feld -- eine ältere Fassung des
        /// Servers --, gilt der bisherige Weg: Name ist Pflicht. Das
        /// ist die vorsichtige Richtung: Ein Name zu viel ist ein
        /// Ärgernis, ein Name zu wenig eine Mitgliedschaft ohne
        /// Kadereintrag.
        let kuerzel: Bool
        /// Wie lang das Kürzel höchstens sein darf. Kommt ebenfalls vom
        /// Server, damit die Zahl nicht an zwei Stellen steht.
        let kuerzelMax: Int

        /// Die Mannschaft hinter dem Code. `verein` ist leer, wo er
        /// nicht mitkommt (nach dem Beitritt steht der Name schon in
        /// der Meldung) -- leer heißt „nicht mitgeschickt", nicht
        /// „vereinslos".
        struct Kopf: Decodable, Hashable {
            let id: Int
            let name: String
            let verein: String

            enum CodingKeys: String, CodingKey { case id, name, verein }

            init(from decoder: Decoder) throws {
                let b = try decoder.container(keyedBy: CodingKeys.self)
                id = try b.decode(Int.self, forKey: .id)
                name = try b.decode(String.self, forKey: .name)
                verein = try b.decodeIfPresent(String.self,
                                               forKey: .verein) ?? ""
            }
        }

        enum CodingKeys: String, CodingKey {
            case team, namensvorschlag, kuerzel
            case rolleText = "rolle_text"
            case schonDabei = "schon_dabei"
            case meineRolle = "meine_rolle"
            case kuerzelMax = "kuerzel_max"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            team = try b.decode(Kopf.self, forKey: .team)
            rolleText = try b.decodeIfPresent(String.self,
                                              forKey: .rolleText) ?? ""
            schonDabei = try b.decodeIfPresent(Bool.self,
                                               forKey: .schonDabei) ?? false
            meineRolle = try b.decodeIfPresent(String.self,
                                               forKey: .meineRolle)
            namensvorschlag = try b.decodeIfPresent(
                String.self, forKey: .namensvorschlag) ?? ""
            kuerzel = try b.decodeIfPresent(Bool.self, forKey: .kuerzel)
                ?? false
            kuerzelMax = try b.decodeIfPresent(Int.self, forKey: .kuerzelMax)
                ?? Kadernameblock.kuerzelMax
        }
    }

    /// Was ein Beitritt ergeben hat.
    struct Beitritt: Decodable {
        /// `false` heißt „war schon dabei" -- kein Fehler. Der Code
        /// ändert an einer bestehenden Mitgliedschaft nichts.
        let beigetreten: Bool
        let team: Codeauskunft.Kopf?
        let meldung: String

        enum CodingKeys: String, CodingKey {
            case beigetreten, team, meldung
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            beigetreten = try b.decodeIfPresent(
                Bool.self, forKey: .beigetreten) ?? false
            team = try b.decodeIfPresent(Codeauskunft.Kopf.self,
                                         forKey: .team)
            meldung = try b.decodeIfPresent(String.self,
                                            forKey: .meldung) ?? ""
        }
    }
}
