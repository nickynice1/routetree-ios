import Foundation

/// Was der Server schickt, eins zu eins.
///
/// Die Felder heißen hier so wie in `shared/openapi.yaml` -- deutsch,
/// weil die Schnittstelle deutsch ist. Eine Umbenennung an der Grenze
/// wäre eine zweite Namensliste, die beim nächsten Feld auseinanderläuft.
enum Modell {

    struct Verein: Decodable, Identifiable, Hashable {
        let id: Int
        let name: String
        let rolle: String
        let teams: [Team]
        /// Das Vereinswappen (R30).
        ///
        /// Gemeldet von Niklas am 25.08.2026 mit Bildschirmfoto: In der
        /// Konto-Ansicht stand beim Verein ein allgemeines Haussymbol.
        /// Es stand dort nicht aus Nachlaessigkeit -- die App hatte
        /// nichts anderes: Zu einem Verein kamen `name` und `demo`.
        ///
        /// Leer ist der Normalfall und kein Fehler. Der Server faellt
        /// dabei schon auf das Logo der ersten Mannschaft zurueck
        /// (`Verein.wappen`); kommt trotzdem nichts, sind die Initialen
        /// da -- und zwar VOM SERVER, aus derselben Regel wie auf jedem
        /// Ausdruck. Wuerde die App sie selbst rechnen, hiesse derselbe
        /// Verein auf dem Blatt „SD" und im Telefon „SU".
        ///
        /// Optional mit Vorgabe, wie ueberall in diesem Modell: Eine
        /// aeltere Serverfassung ohne dieses Feld darf nicht die ganze
        /// Antwort unlesbar machen.
        ///
        /// **ACHTUNG, hier lag ein stiller Fehler bis zum 28.08.2026.**
        /// Diese beiden Felder standen zwar hier, aber weder in
        /// `CodingKeys` noch in `init(from:)` -- und dieser Typ hat
        /// einen EIGENEN Entschluessler. Ein Feld, das dort nicht
        /// vorkommt, behaelt seinen Vorgabewert, ohne dass irgendetwas
        /// meckert. Der Server schickte das Wappen seit R30, die App
        /// warf es weg, und in der Konto-Ansicht standen weiter die
        /// Initialen.
        ///
        /// Die Lehre ist allgemein: **Wer `init(from:)` selbst
        /// schreibt, hat die Vollstaendigkeit selbst in der Hand.** Bei
        /// einem erzeugten Entschluessler waere das nicht passiert.
        var logo: String? = nil
        var initialen: String = ""
        /// Steht dieser Verein auf Demo? (A2)
        let demo: Bool
        let grenzen: Vereinsgrenzen
        /// Was ein Abo kostet und aufhebt (A3, in der App seit B12).
        ///
        /// Optional, und zwar aus der Lehre von B9: Eine Antwort wird
        /// auf einmal entschlüsselt. Fehlt der Schlüssel -- eine ältere
        /// Serverfassung, ein Feld, das umbenannt wurde --, fiele nicht
        /// der Abo-Vorschlag aus, sondern die ganze Vereinsliste, und
        /// damit der Einstieg der App.
        let abo: Abo?

        /// Darf diese Person hier ein Abo bestellen? **Vom Server.**
        ///
        /// Nicht aus `rolle` geschlossen, und das ist der Punkt:
        /// `kasse.darf_bestellen` laesst den Vereinsadmin UND den Head
        /// Coach einer Mannschaft dieses Vereins bestellen -- der zweite
        /// steht hier als „team". Wer es aus `rolle` rechnet, sperrt
        /// genau den aus, der in kleinen Vereinen Routetree einfuehrt.
        ///
        /// `false` als Vorgabe, weil ein aelterer Server das Feld nicht
        /// schickt: Lieber ein fehlender Kaufknopf als einer, hinter dem
        /// ein 403 steht.
        var darfBestellen: Bool = false

        /// Wer den Verein führt, führt jede Mannschaft darin.
        var istVereinsadmin: Bool { rolle == "vereinsadmin" }

        // `CaseIterable`, damit ein Test die Schluessel AUFZAEHLEN kann.
        // Ohne das liesse sich „kennt der Typ jedes Feld der Antwort?"
        // nur gegen eine zweite, handgepflegte Liste pruefen -- und die
        // ist beim naechsten Feld die, die man vergisst.
        enum CodingKeys: String, CodingKey, CaseIterable {
            case id, name, rolle, teams, demo, grenzen, abo, logo, initialen
            case darfBestellen = "darf_bestellen"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(Int.self, forKey: .id)
            name = try b.decode(String.self, forKey: .name)
            rolle = try b.decode(String.self, forKey: .rolle)
            teams = try b.decode([Team].self, forKey: .teams)
            demo = try b.decodeIfPresent(Bool.self, forKey: .demo) ?? false
            grenzen = try b.decodeIfPresent(
                Vereinsgrenzen.self, forKey: .grenzen) ?? Vereinsgrenzen()
            abo = try b.decodeIfPresent(Abo.self, forKey: .abo)
            logo = try b.decodeIfPresent(String.self, forKey: .logo)
            initialen = try b.decodeIfPresent(String.self,
                                              forKey: .initialen) ?? ""
            darfBestellen = try b.decodeIfPresent(
                Bool.self, forKey: .darfBestellen) ?? false
        }
    }

    /// Was dieser Verein anlegen darf. `nil` heißt unbegrenzt und
    /// ausdrücklich NICHT „null" -- dieselbe Bedeutung wie in
    /// `grenzen.py`, wo `UNBEGRENZT` bewusst `None` ist und keine sehr
    /// große Zahl.
    struct Vereinsgrenzen: Decodable, Hashable {
        var playbooks: Int? = nil
        var playbooksFrei: Int? = nil
        var playsJePlaybook: Int? = nil

        enum CodingKeys: String, CodingKey {
            case playbooks
            case playbooksFrei = "playbooks_frei"
            case playsJePlaybook = "plays_je_playbook"
        }
    }

    struct Team: Decodable, Identifiable, Hashable {
        let id: Int
        let name: String
        /// Ob hier ein Playbook angelegt werden darf.
        ///
        /// Je Mannschaft und nicht je Verein: Wer bei der U17 Head Coach
        /// ist und bei der U19 nur zusieht, sieht beide -- anlegen darf
        /// er nur in einer. Fehlt der Schlüssel (ältere Serverfassung
        /// oder die Mannschaft steht in einem Playbook), heißt das
        /// „nicht gefragt", und dann wird kein Knopf gezeigt.
        let darfAnlegen: Bool
        /// Was diese Mannschaft spielt (T4).
        ///
        /// Gebraucht beim ANLEGEN eines Playbooks: Bei einer
        /// Tackle-Mannschaft hat die Feldformatwahl keine Bedeutung --
        /// die drei Formate sind Flagmaße.
        ///
        /// **Es gibt zwei Mannschaftstypen in dieser App**, und der
        /// Unterschied hat mich einen roten Bau gekostet:
        /// `Modell.Mannschaft` ist die volle Mannschaft mit Kader und
        /// Rechten, `Modell.Team` der kurze Kopf, den ein Playbook
        /// mitbringt. Die Ansicht zum Anlegen benutzt den kurzen.
        let spielform: String

        enum CodingKeys: String, CodingKey {
            case id, name, spielform
            case darfAnlegen = "darf_anlegen"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(Int.self, forKey: .id)
            name = try b.decode(String.self, forKey: .name)
            darfAnlegen = try b.decodeIfPresent(
                Bool.self, forKey: .darfAnlegen) ?? false
            spielform = try b.decodeIfPresent(String.self,
                                              forKey: .spielform)
                        ?? Spielform.standard
        }
    }

    struct VereinsListe: Decodable {
        let vereine: [Verein]
    }

    struct Playbook: Decodable, Identifiable, Hashable {
        let id: Int
        let name: String
        let saison: String?
        /// Der Server schickt hier ein OBJEKT, keinen Text -- nachgesehen
        /// in `api_v1_playbooks`, nicht geraten. Ein `String?` hätte
        /// beim ersten Aufruf einen Entschlüsselungsfehler gegeben, und
        /// zwar erst auf dem Gerät.
        let team: Team
        let plays: Int
        let geaendert: Date?
        /// Die Notizen zum Heft. Leer heißt leer, nicht „nicht gefragt".
        let hinweise: String
        /// Die Kennung des Feldformats (`afvd`, `afvd_klein`, …).
        ///
        /// Als KENNUNG und nicht als Maße: Die Maße rechnet `Feld.swift`
        /// daraus aus, und zwei Stellen, die dasselbe ableiten, laufen
        /// auseinander. Gebraucht wird sie beim Anlegen -- danach steht
        /// sie fest.
        /// Das Feldformat -- `nil` bei Tackle, wo es keins gibt.
        let feldformat: String?
        /// Was diese Mannschaft spielt: Flag oder Tackle, und mit wie
        /// vielen (T8). Bei einem Server ohne diese Angabe bleibt es
        /// Flag -- das ist jedes Playbook, das es vor T4 gab.
        let spielform: String
        /// Ob DIESER Mensch DIESES Heft umbenennen darf. Der Server sagt
        /// es (ADR-0007), die App leitet es nicht aus Rolle und
        /// Vereinszustand ab -- das wäre die Regel ein zweites Mal in
        /// Swift.
        let darfAendern: Bool
        /// Ob er es löschen darf. Enger als `darfAendern`: Ein Griff,
        /// und die Arbeit einer Saison ist weg, deshalb nur der Head
        /// Coach.
        let darfLoeschen: Bool

        enum CodingKeys: String, CodingKey {
            case id, name, saison, team, plays, geaendert, feldformat
            case spielform
            case hinweise
            case darfAendern = "darf_aendern"
            case darfLoeschen = "darf_loeschen"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(Int.self, forKey: .id)
            name = try b.decode(String.self, forKey: .name)
            saison = try b.decodeIfPresent(String.self, forKey: .saison)
            team = try b.decode(Team.self, forKey: .team)
            plays = try b.decodeIfPresent(Int.self, forKey: .plays) ?? 0
            geaendert = try b.decodeIfPresent(Date.self, forKey: .geaendert)
            hinweise = try b.decodeIfPresent(String.self,
                                             forKey: .hinweise) ?? ""
            // NULL BLEIBT NULL (08.09.2026). Der Server schickt bei
            // Tackle ausdrücklich `null` -- „Ein fehlender Wert ist
            // ehrlicher als ein geratener", steht dort. Ein `?? "afvd"`
            // machte daraus wieder eine Flagbehauptung: Die App führte
            // ein Elfer-Playbook intern als AFVD-Feldformat.
            //
            // Folgenlos war es nur, weil die Anzeige abzweigt. Genau
            // diese Sorte „folgenlos" ist die, die beim nächsten
            // Aufrufer aufhört, folgenlos zu sein.
            feldformat = try b.decodeIfPresent(String.self,
                                               forKey: .feldformat)
            spielform = try b.decodeIfPresent(String.self,
                                              forKey: .spielform)
                        ?? Spielform.standard
            // Fehlt der Schlüssel, wurde nicht gefragt. Dann lieber
            // keinen Knopf zeigen als einen, der mit 403 endet.
            darfAendern = try b.decodeIfPresent(
                Bool.self, forKey: .darfAendern) ?? false
            darfLoeschen = try b.decodeIfPresent(
                Bool.self, forKey: .darfLoeschen) ?? false
        }
    }

    struct PlaybookListe: Decodable {
        let playbooks: [Playbook]
    }

    struct PlayKurz: Decodable, Identifiable, Hashable {
        let id: Int
        let name: String
        let nummer: Int?
        let seite: String?
        let kategorie: String?
        /// Die Kennung der Kategorie. `nil` heißt „ohne Kategorie".
        ///
        /// Gebraucht zum UMORDNEN (B7): Gesetzt wird die Kategorie mit
        /// ihrer Kennung, nicht mit ihrem Namen. Ohne sie müsste die App
        /// aus dem Namen zurückschließen, und bei zwei gleichnamigen
        /// Kategorien in zwei Playbooks fällt genau das um.
        let kategorieId: Int?
        /// Ihre Farbe, für den Punkt in der Liste. `nil` heißt „ohne
        /// Kategorie" -- NICHT „grau": Was ohne Farbe gezeichnet wird,
        /// entscheidet die Ansicht.
        let kategorieFarbe: String?
        let situationen: [String]
        /// Der Platz, den dieser Play im Heft einnimmt.
        ///
        /// Gebraucht beim Umsortieren (B6): Getauscht werden die Plätze,
        /// die genau die umsortierten Plays schon einnehmen. Ohne diese
        /// Zahl müsste die App 1..n annehmen, und das ist falsch, sobald
        /// die Liste gefiltert war.
        let position: Int
        /// Die gelesene Fassung. Sie muss beim Umbenennen mitgehen,
        /// sonst überschreibt die App die Arbeit von jemand anderem.
        let version: Int
        /// Ob dieser Play DIESEM Menschen aufgegeben ist (A7, B8).
        ///
        /// Der Server sagt es, die App schließt es nicht aus einer
        /// zweiten Liste: Wer die Aufträge getrennt holte, hätte sie
        /// nach dem nächsten Nachladen einen Moment lang anders als die
        /// Plays -- und in dieser Zeit stünde die Marke am falschen.
        /// Fehlt der Schlüssel (Maschinenschlüssel, ältere
        /// Serverfassung), heißt das „nicht gefragt" und nicht „nein".
        let aufgabe: Bool

        /// Was auf der Karte oben steht. Ohne Nummer nur der Name --
        /// „#0 Slant" wäre eine Nummer, die es nicht gibt.
        var titel: String {
            guard let nummer else { return name }
            return "#\(nummer) \(name)"
        }

        /// Was `Ordnen` von diesem Play braucht.
        var alsPlatz: Ordnen.Platz {
            Ordnen.Platz(id: id, platz: position, nummer: nummer)
        }

        enum CodingKeys: String, CodingKey {
            case id, name, nummer, seite, kategorie, situationen
            case position, version, aufgabe
            case kategorieId = "kategorie_id"
            case kategorieFarbe = "kategorie_farbe"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(Int.self, forKey: .id)
            name = try b.decode(String.self, forKey: .name)
            nummer = try b.decodeIfPresent(Int.self, forKey: .nummer)
            seite = try b.decodeIfPresent(String.self, forKey: .seite)
            kategorie = try b.decodeIfPresent(String.self, forKey: .kategorie)
            kategorieId = try b.decodeIfPresent(Int.self, forKey: .kategorieId)
            kategorieFarbe = try b.decodeIfPresent(String.self,
                                                   forKey: .kategorieFarbe)
            situationen = try b.decodeIfPresent(
                [String].self, forKey: .situationen) ?? []
            // Rückfall auf 0 und nicht auf einen erfundenen Platz: Eine
            // ältere Serverfassung schickt das Feld nicht, und dann darf
            // die App nicht umsortieren, aber auch nicht abstürzen.
            position = try b.decodeIfPresent(Int.self, forKey: .position) ?? 0
            version = try b.decodeIfPresent(Int.self, forKey: .version) ?? 0
            aufgabe = try b.decodeIfPresent(Bool.self, forKey: .aufgabe)
                ?? false
        }

        /// Nur für Tests und Vorschauen -- der Server liefert sonst alles.
        init(id: Int, name: String, nummer: Int?, seite: String? = nil,
             kategorie: String? = nil, kategorieId: Int? = nil,
             kategorieFarbe: String? = nil, situationen: [String] = [],
             position: Int, version: Int = 1, aufgabe: Bool = false) {
            self.id = id
            self.name = name
            self.nummer = nummer
            self.seite = seite
            self.kategorie = kategorie
            self.kategorieId = kategorieId
            self.kategorieFarbe = kategorieFarbe
            self.situationen = situationen
            self.position = position
            self.version = version
            self.aufgabe = aufgabe
        }
    }

    // --- Bibliothek (B11) ------------------------------------------------

    /// Ein Standardplay zum Übernehmen, mit seiner Zeichnung.
    ///
    /// Die Zeichnung kommt in YARDS und nicht als Bild: So zeichnet die
    /// App die Vorschau mit `Feldansicht` -- dasselbe Bild wie im Editor,
    /// und beim zweiten Ansehen auch ohne Netz.
    struct Bibliothekseintrag: Decodable, Identifiable, Hashable {
        /// Die Kennung des Konzepts (`mesh`, `flood`, …). Sie geht beim
        /// Übernehmen zurück an den Server.
        let schluessel: String
        let name: String
        let kategorie: String
        /// Ein Absatz dazu, wogegen der Play läuft. Ohne ihn wäre die
        /// Liste eine Reihe von Namen, die niemandem etwas sagen.
        let hinweis: String
        let situationen: [String]
        /// Liegt ein Play dieses Namens schon im Heft? Ein HINWEIS und
        /// keine Sperre: Wer denselben Play ein zweites Mal will (etwa
        /// gespiegelt), bekommt ihn als „… (2)".
        let schonDa: Bool
        let zeichnung: Zeichnung

        var id: String { schluessel }

        enum CodingKeys: String, CodingKey {
            case schluessel, name, kategorie, hinweis, situationen, zeichnung
            case schonDa = "schon_da"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            schluessel = try b.decode(String.self, forKey: .schluessel)
            name = try b.decode(String.self, forKey: .name)
            kategorie = try b.decodeIfPresent(String.self,
                                              forKey: .kategorie) ?? ""
            hinweis = try b.decodeIfPresent(String.self,
                                            forKey: .hinweis) ?? ""
            situationen = try b.decodeIfPresent([String].self,
                                                forKey: .situationen) ?? []
            schonDa = try b.decodeIfPresent(Bool.self,
                                            forKey: .schonDa) ?? false
            zeichnung = try b.decodeIfPresent(Zeichnung.self,
                                              forKey: .zeichnung) ?? Zeichnung()
        }

        static func == (a: Bibliothekseintrag, b: Bibliothekseintrag) -> Bool {
            a.schluessel == b.schluessel && a.schonDa == b.schonDa
        }
        func hash(into hasher: inout Hasher) { hasher.combine(schluessel) }
    }

    struct Bibliothek: Decodable {
        let eintraege: [Bibliothekseintrag]
        /// Das Feldformat DIESES Playbooks. Ohne es zeichnete die
        /// Vorschau auf einem Normfeld, auch wenn das Heft ein kleines
        /// hat.
        let feld: Feld
        /// Wie viele Plays noch hineinpassen. `nil` heißt unbegrenzt.
        let playsFrei: Int?

        enum CodingKeys: String, CodingKey {
            case eintraege, feld
            case playsFrei = "plays_frei"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            eintraege = try b.decode([Bibliothekseintrag].self,
                                     forKey: .eintraege)
            feld = (try b.decodeIfPresent(Feld.VomServer.self,
                                          forKey: .feld))?.alsFeld ?? .afvd
            playsFrei = try b.decodeIfPresent(Int.self, forKey: .playsFrei)
        }
    }

    /// Was beim Übernehmen herauskam.
    struct Uebernommen: Decodable {
        let angelegt: [PlayKurz]
        /// Wie viele nicht mehr hineinpassten. Getrennt gezählt, weil es
        /// einen anderen Satz verdient als der Erfolg.
        let uebergangen: Int
        let playsFrei: Int?

        enum CodingKeys: String, CodingKey {
            case angelegt, uebergangen
            case playsFrei = "plays_frei"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            angelegt = try b.decode([PlayKurz].self, forKey: .angelegt)
            uebergangen = try b.decodeIfPresent(Int.self,
                                                forKey: .uebergangen) ?? 0
            playsFrei = try b.decodeIfPresent(Int.self, forKey: .playsFrei)
        }
    }

    // --- Kategorien und Formationen (B7) ---------------------------------

    /// Eine farbcodierte Gruppe innerhalb eines Playbooks.
    ///
    /// Die Farbe färbt die Kachel des Plays und den Punkt daneben, die
    /// Reihenfolge bestimmt die Blöcke auf der Wristcoach-Einlage. Was
    /// oben steht, steht auch auf dem Armband oben.
    struct Kategorie: Decodable, Identifiable, Hashable {
        let id: Int
        let name: String
        /// Der Hexwert, wie der Server ihn gespeichert hat. Als TEXT und
        /// nicht als `Color`: Er geht beim Sichern wieder hinaus, und
        /// eine Farbe, die durch `Color` gelaufen ist, kommt nicht als
        /// derselbe Hexwert zurück.
        let farbe: String
        let position: Int
        /// Wie viele Plays darin stehen. `nil` heißt „nicht gezählt" --
        /// NICHT „keine". Der Server lässt den Schlüssel weg, wo er die
        /// Zahl nicht erhoben hat, etwa nach dem Umsortieren.
        let plays: Int?

        enum CodingKeys: String, CodingKey {
            case id, name, farbe, position, plays
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(Int.self, forKey: .id)
            name = try b.decode(String.self, forKey: .name)
            farbe = try b.decodeIfPresent(String.self, forKey: .farbe)
                ?? Farbwert.standard
            position = try b.decodeIfPresent(Int.self, forKey: .position) ?? 0
            plays = try b.decodeIfPresent(Int.self, forKey: .plays)
        }

        /// Nur für Tests und Vorschauen.
        init(id: Int, name: String, farbe: String, position: Int,
             plays: Int? = nil) {
            self.id = id
            self.name = name
            self.farbe = farbe
            self.position = position
            self.plays = plays
        }
    }

    struct KategorienListe: Decodable {
        let kategorien: [Kategorie]
    }

    /// Eine gespeicherte Aufstellung, ohne Linien.
    ///
    /// Wer sie anwendet, bekommt die Positionen; was jeder Spieler
    /// danach läuft, entscheidet er im Play neu. Deshalb hängt an einem
    /// Play kein Verweis auf sie, und eine gelöschte Formation reißt
    /// nichts mit.
    struct Formation: Decodable, Identifiable, Equatable {
        let id: Int
        let name: String
        /// Wie viele Spieler darin stehen. Der Server zählt, nicht die
        /// App: Krumme Datensätze aus dem Verwaltungsbereich ergeben
        /// dort eine leere Aufstellung statt eines Absturzes.
        let anzahl: Int
        /// Die Aufstellung selbst, zum Anwenden. Als `Zeichnung`, weil
        /// genau die in den Editor geht -- eine eigene Spielerliste wäre
        /// dasselbe Datenformat ein zweites Mal.
        let data: Zeichnung

        enum CodingKeys: String, CodingKey {
            case id, name, anzahl, data
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(Int.self, forKey: .id)
            name = try b.decode(String.self, forKey: .name)
            data = try b.decodeIfPresent(Zeichnung.self,
                                         forKey: .data) ?? Zeichnung()
            // Die Zahl des Servers, und nur ersatzweise die eigene: Eine
            // App, die selbst zählt, sagt bei krummen Daten etwas
            // anderes als die Liste im Browser.
            anzahl = try b.decodeIfPresent(Int.self, forKey: .anzahl)
                ?? data.spieler.count
        }

        /// Nur für Tests und Vorschauen.
        init(id: Int, name: String, anzahl: Int, data: Zeichnung = Zeichnung()) {
            self.id = id
            self.name = name
            self.anzahl = anzahl
            self.data = data
        }
    }

    struct FormationsListe: Decodable {
        let formationen: [Formation]
        /// Die EINGEBAUTEN Vorlagen (R110.5).
        ///
        /// **Optional, und das ist kein Versehen.** Eine App im Store
        /// spricht mit dem Server, der gerade läuft -- auch mit einem
        /// älteren, der das Feld noch nicht kennt. Wäre es
        /// verpflichtend, bräche dort das Entschlüsseln der GANZEN
        /// Liste, und der Trainer sähe statt fehlender Vorlagen gar
        /// keine Formationen mehr.
        let vorlagen: Vorlagensatz?

        var eingebaut: Vorlagensatz { vorlagen ?? Vorlagensatz() }
    }

    /// Die Aufstellungen, die es ohne Zutun schon gibt (R110.5).
    ///
    /// **Welche gelten, entscheidet die Spielform, und das entscheidet
    /// der Server.** Im Tackle sind es andere: Die sieben benannten
    /// sind Fünf-Mann-Aufstellungen mit den Rollen C, QB, X, Y, Z, und
    /// auf einen Elfer-Play angewandt setzten sie fünf Leute um und
    /// liessen sechs stehen.
    struct Vorlagensatz: Decodable, Equatable {
        var offense: [Vorlage] = []
        var defense: [Vorlage] = []
    }

    /// Eine Aufstellung als Vorlage.
    struct Vorlage: Decodable, Equatable, Identifiable {
        let schluessel: String
        let name: String
        /// Ein Satz dazu: „Drei Empfänger verteilt, sauberes Spacing".
        let hinweis: String
        let leute: [Vorlagenplatz]

        var id: String { schluessel }
    }

    /// Ein Platz in einer Vorlage.
    ///
    /// **Die Längslage bleibt offen** (`zurueck`), weil sie an der Line
    /// of Scrimmage und der Angriffsrichtung hängt:
    /// `x = los + zurueck * richtung`. Das ist die einzige Rechnung,
    /// die die App selbst macht -- dieselbe wie im Browser.
    struct Vorlagenplatz: Decodable, Equatable {
        let id: String
        let role: String
        let label: String
        let zurueck: Double
        let y: Double
    }

    struct PlayListe: Decodable {
        let plays: [PlayKurz]
        let playbook: HeftKopf?

        /// Was die Liste über ihr Playbook mitbringt.
        ///
        /// Getrennt von `Playbook`: Dieses hier kommt aus der PLAY-Liste
        /// und trägt Angaben, die die Playbook-Liste nicht hat. Ein
        /// gemeinsamer Typ mit lauter optionalen Feldern wäre an beiden
        /// Stellen halb leer, und man müsste jedes Mal nachsehen, welche
        /// Hälfte gerade gilt.
        struct HeftKopf: Decodable {
            let id: Int
            let name: String
            /// Ob hier ein Knopf „Play anlegen" hingehört. Sagt der
            /// Server (ADR-0007: keine toten Knöpfe).
            let darfAnlegen: Bool
            /// Ob umbenannt, gelöscht und umsortiert werden darf (B6).
            ///
            /// Getrennt von `darfAnlegen`, obwohl beides heute dasselbe
            /// Schreibrecht ist: „darf anlegen" fällt weg, sobald es
            /// einen Grund gibt, das Anlegen enger zu fassen als das
            /// Ändern -- und ein gemeinsames Feld wäre dann an einer der
            /// beiden Stellen falsch.
            let darfAendern: Bool
            /// Wie viele Plays noch hineinpassen. `nil` heißt
            /// unbegrenzt -- NICHT „null Stück".
            let playsFrei: Int?
            /// Ob hier ein Knopf „Lernstand" hingehört (B8). Die
            /// Übersicht über eine ganze Mannschaft sieht der
            /// Trainerstab, nicht jeder Spieler -- und wer sie nicht
            /// sehen darf, bekommt vom Server 404 statt einer Liste.
            let darfLernstand: Bool
            /// Ab wie vielen Plays sich Üben lohnt. Die Zahl kommt vom
            /// SERVER: Ein zweiter Schwellwert in Swift wäre irgendwann
            /// ein anderer, und dann zeigte die App den Knopf, wo die
            /// Webseite ihn nicht zeigt.
            let uebungAb: Int

            enum CodingKeys: String, CodingKey {
                case id, name
                case darfAnlegen = "darf_anlegen"
                case darfAendern = "darf_aendern"
                case playsFrei = "plays_frei"
                case darfLernstand = "darf_lernstand"
                case uebungAb = "uebung_ab"
            }

            init(from decoder: Decoder) throws {
                let b = try decoder.container(keyedBy: CodingKeys.self)
                id = try b.decode(Int.self, forKey: .id)
                name = try b.decode(String.self, forKey: .name)
                darfAnlegen = try b.decodeIfPresent(
                    Bool.self, forKey: .darfAnlegen) ?? false
                darfAendern = try b.decodeIfPresent(
                    Bool.self, forKey: .darfAendern) ?? false
                playsFrei = try b.decodeIfPresent(Int.self, forKey: .playsFrei)
                darfLernstand = try b.decodeIfPresent(
                    Bool.self, forKey: .darfLernstand) ?? false
                // Ohne Angabe wird nicht geübt. Ein geratener Schwellwert
                // wäre ein Knopf, der beim Drücken „zu wenige Plays"
                // sagt -- und das ist ein toter Knopf (ADR-0007).
                uebungAb = try b.decodeIfPresent(
                    Int.self, forKey: .uebungAb) ?? Int.max
            }
        }
    }

    /// Ein Play mit allem. `svg` kommt nur, wenn `?svg=1` gefragt wurde.
    struct PlayVoll: Decodable, Identifiable {
        let id: Int
        let name: String
        let nummer: Int?
        /// Das Heft, in dem dieser Play steht.
        ///
        /// Gebraucht seit B7: Die gespeicherten Aufstellungen hängen am
        /// Playbook, nicht am Play, und der Editor kommt über eine
        /// Kachel in der Liste hierher -- ohne diese Zahl müsste er sie
        /// von dort durchreichen, und beim nächsten Einstieg wäre es
        /// vergessen.
        let playbook: Int?
        let hinweise: String?
        let los: Double
        let richtung: Int
        let version: Int
        let svg: String?
        /// Die Zeichnung selbst. Bis zum Editor las die App nur das
        /// fertige SVG vom Server; zum Zeichnen braucht sie die Yards.
        ///
        /// Nicht optional, sondern leer als Rueckfall: Ein neu angelegter
        /// Play hat `{}`, und das ist kein Fehler, sondern ein leeres
        /// Feld.
        let zeichnung: Zeichnung
        /// Das Feldformat DIESES Playbooks. Ohne es müsste der Editor
        /// die Normmaße annehmen, und auf einem kleinen Feld stünde die
        /// Aufstellung fünf Yards neben der Seitenlinie -- lautlos, weil
        /// der Server sie beim Speichern hineinschiebt.
        let feld: Feld
        /// Was in diesem Playbook gespielt wird -- als Schlüssel.
        ///
        /// **Der Schlüssel fehlte bis zum 07.09.2026**, und damit fehlte
        /// er der ganzen Zeichenkette: `Feldansicht` und `Projektion`
        /// bekamen nur `feld`. Wie groß eine Figur ist (`figurradius`)
        /// und ob die Mitte die Line to Gain ist, steht aber nicht im
        /// Feld, sondern in der Spielform. Die App hat beides mit dem
        /// Flagwert geraten -- auf einem Elfer-Feld trug danach keine
        /// Figur mehr ihr Kürzel.
        ///
        /// Leer heißt Flag, wie überall sonst: ein Play aus der Zeit
        /// vor T4 oder von einer älteren Serverfassung.
        let spielform: String
        /// Was an dieser Zeichnung dem Regelwerk widerspricht.
        ///
        /// **ANMERKUNGEN, KEINE VERBOTE.** Wer eine Übungsform mit
        /// sieben Spielern zeichnet, soll das können -- er soll nur
        /// sehen, dass es keine Spielform ist.
        ///
        /// Der Browser bekommt sie seit T7, die App bis zum 08.09.2026
        /// nicht: Wer dort einen Spieler von der Linie ins Backfield
        /// zog, hatte fünf Backs und kein Wort dazu.
        let anmerkungen: [Anmerkung]
        /// Ob DIESER Mensch DIESEN Play ändern darf. Der Server sagt es,
        /// die App rät es nicht: Ein Knopf, der beim Drücken 403 bekommt,
        /// ist ein toter Knopf (ADR-0007).
        let darfAendern: Bool
        /// Ob dieser Play als fertig gesperrt ist (R6), und von wem.
        ///
        /// Getrennt von `darfAendern`, weil es zwei verschiedene Dinge
        /// sind: Die Rolle sagt, ob dieser Mensch überhaupt an diesem
        /// Heft arbeiten darf; das Schloss sagt, ob dieser EINE Play
        /// gerade offen ist. Wer beides in ein Feld legt, kann dem
        /// Trainer nicht mehr „Entsperren" anbieten, sondern nur noch
        /// „kein Zugriff" -- und das ist die falsche Auskunft.
        let gesperrt: Bool
        let gesperrtVon: String?

        // --- Die Felder, die nicht die Zeichnung sind (B7) --------------
        //
        // Cyell am 01.09.2026: „Mann will ein Play erstellen und kann die
        // Formation, Katalogisieren auswählen, allgemeine Play Notiz
        // erstellen." Der Server schickt diese drei seit jeher mit
        // (`_play_kurz`), die App las sie nur in der Liste und nicht im
        // Editor -- also konnte sie dort auch nichts davon ändern.

        /// „off", „def" oder „st". Als Zeichenkette und nicht als
        /// `enum`, damit eine vierte Seite auf dem Server die App nicht
        /// beim Entschlüsseln umwirft. Die Namen dazu stehen in
        /// ``Seite/alle`` und werden aus `models.py` erzeugt.
        let seite: String?
        /// Die KENNUNG der Kategorie, nicht ihr Name.
        ///
        /// Gesetzt wird sie mit der Kennung (`_play_felder`); zwei
        /// gleichnamige Kategorien in zwei Heften ließen sich über den
        /// Namen nicht auseinanderhalten. `nil` heißt „ohne Kategorie".
        let kategorieId: Int?
        /// Die Spielsituationen, in denen dieser Play gerufen wird.
        ///
        /// Leer als Rückfall und nicht `nil`: „keine gesetzt" und „nicht
        /// mitgeschickt" laufen für die Auswahl auf dasselbe hinaus, und
        /// ein `Optional` zwänge jede Stelle zu einem `?? []`.
        let situationen: [String]

        enum CodingKeys: String, CodingKey {
            case id, name, nummer, hinweise, los, richtung, version, svg
            case zeichnung, feld, playbook, gesperrt, spielform
            case seite, situationen, anmerkungen
            case kategorieId = "kategorie_id"
            case darfAendern = "darf_aendern"
            case gesperrtVon = "gesperrt_von"
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            id = try b.decode(Int.self, forKey: .id)
            name = try b.decode(String.self, forKey: .name)
            nummer = try b.decodeIfPresent(Int.self, forKey: .nummer)
            playbook = try b.decodeIfPresent(Int.self, forKey: .playbook)
            hinweise = try b.decodeIfPresent(String.self, forKey: .hinweise)
            los = try b.decode(Double.self, forKey: .los)
            richtung = try b.decode(Int.self, forKey: .richtung)
            version = try b.decode(Int.self, forKey: .version)
            svg = try b.decodeIfPresent(String.self, forKey: .svg)
            zeichnung = try b.decodeIfPresent(Zeichnung.self,
                                              forKey: .zeichnung) ?? Zeichnung()
            // Rückfall auf die Norm, damit eine ältere Serverfassung die
            // App nicht abstürzen lässt. Sie ist ein Rückfall und keine
            // Annahme: Der Server schickt das Feld seit B3 immer mit.
            feld = (try b.decodeIfPresent(Feld.VomServer.self,
                                          forKey: .feld))?.alsFeld ?? .afvd
            spielform = try b.decodeIfPresent(String.self, forKey: .spielform)
                ?? Spielform.standard
            anmerkungen = try b.decodeIfPresent([Anmerkung].self,
                                                forKey: .anmerkungen) ?? []
            // Fehlt der Schlüssel, wurde nicht gefragt. Dann lieber
            // keinen Knopf zeigen als einen, der nicht funktioniert.
            darfAendern = try b.decodeIfPresent(Bool.self,
                                                forKey: .darfAendern) ?? false
            // Fehlt der Schlüssel, ist nichts gesperrt. Anders als bei
            // `darfAendern` ist das hier die sichere Annahme: Ein
            // Schloss, das die App erfindet, sperrt jemanden aus seinem
            // eigenen Play aus -- und der Server lehnt ohnehin ab, wenn
            // wirklich zu ist.
            gesperrt = try b.decodeIfPresent(Bool.self,
                                             forKey: .gesperrt) ?? false
            gesperrtVon = try b.decodeIfPresent(String.self,
                                                forKey: .gesperrtVon)
            // HIER MUSS ES AUCH STEHEN, und genau das ist die Falle, in
            // die dieses Projekt am 28.08.2026 schon einmal gelaufen ist
            // (`Verein.logo`): Ein handgeschriebener `init(from:)` LÄSST
            // Felder weg, die nur in `CodingKeys` stehen -- lautlos, und
            // die App zeigt dann etwas nicht an, das der Server sehr wohl
            // geschickt hat.
            seite = try b.decodeIfPresent(String.self, forKey: .seite)
            kategorieId = try b.decodeIfPresent(Int.self,
                                                forKey: .kategorieId)
            situationen = try b.decodeIfPresent(
                [String].self, forKey: .situationen) ?? []
        }

        /// Derselbe Play, wie ihn eine Liste führt (R40).
        ///
        /// Gebraucht nach dem ANLEGEN: Der Server antwortet mit dem
        /// vollen Play, der Editor wird aber über einen `PlayKurz`
        /// aufgerufen -- wie jeder andere Weg dorthin auch.
        ///
        /// **Was hier NICHT herüberkommt und warum das in Ordnung ist:**
        /// `position` und die Kategorie mit Namen und Farbe. Beides
        /// braucht die LISTE, um zu sortieren und den Punkt zu färben;
        /// der Editor braucht Kennung und Titel. Diesen Wert in eine
        /// Liste zu legen wäre falsch -- er stünde dann auf Platz null
        /// und ohne Punkt. Er ist ein Wegweiser, kein Listeneintrag.
        var alsKurz: PlayKurz {
            PlayKurz(id: id, name: name, nummer: nummer, seite: seite,
                     kategorieId: kategorieId, situationen: situationen,
                     position: 0, version: version)
        }
    }

    // --- Die Hilfe (B6) --------------------------------------------------

    /// Die Hilfe, wie der Server sie zusammensetzt.
    ///
    /// **KEIN einziges Wort davon steht in Swift.** `hilfe.alles()` auf
    /// dem Server baut die Abschnitte aus `druck.py`, `render.py`,
    /// `schema.py`, `regelwerk.py`, `abo.py` und den Formularen
    /// zusammen. Eine abgeschriebene Fassung hier wäre die zweite
    /// Wahrheit, vor der R28 warnt: Sie beschriebe drei Umbauten später
    /// ein Produkt, das es nicht mehr gibt, und nichts würde rot.
    ///
    /// Deshalb sind alle Felder Listen aus Zeichenketten und nicht
    /// Aufzählungen: Was der Server hinzufügt, erscheint hier ohne
    /// Änderung.
    struct Hilfe: Decodable {
        struct Zeile: Decodable, Identifiable {
            let name: String
            let text: String
            var id: String { name + text }
        }
        struct Block: Decodable, Identifiable {
            let titel: String
            let zeilen: [Zeile]
            var id: String { titel }
        }
        /// Eine Linienart mit ihrem Schlüssel, damit die App sie
        /// selbst zeichnen kann.
        struct Linienzeile: Identifiable {
            let art: Zeichnung.Linie.Art?
            let name: String
            let text: String
            var id: String { name + text }
        }

        struct Symbolzeile: Identifiable {
            /// „off" oder „def". Ein `String` und kein eigener Typ: Was
            /// der Server hier dazulegt, soll die App nicht umfallen
            /// lassen.
            let seite: String
            let name: String
            var id: String { seite }
        }

        struct Abozeile: Decodable, Identifiable {
            let was: String
            let demo: String
            /// Was ein Abo daraus macht -- **`nil`, wenn die bezahlten
            /// Stufen verschiedene Werte haben** (R119).
            ///
            /// Bis zum 10.09.2026 stand hier ein `String` ohne
            /// Fragezeichen. Seit R119 schickt der Server bei der Zeile
            /// „Trainer mit Schreibrecht" ausdrücklich `null` -- dort
            /// trägt Standard fünf und Premium beliebig viele, und eine
            /// gemeinsame Spalte wäre genau die Falschaussage, aus der
            /// R119 entstanden ist. Ein nicht optionales Feld hätte die
            /// Zeile nicht gelesen, und weil die Liste mit `try?`
            /// dekodiert wird, wäre die GANZE Gegenüberstellung aus der
            /// Hilfe verschwunden. Ohne Meldung.
            let abo: String?
            /// Je bezahlter Stufe eine Spalte, mit Namen vom Server.
            /// Optional, weil ein älterer Server sie nicht schickt.
            let spalten: [Abospalte]?
            var id: String { was }
        }

        /// Ein Wert unter EINER bezahlten Stufe -- mit ihrem Namen.
        ///
        /// Der Name kommt vom Server (`abo.stufenname`) und wird in der
        /// App nicht zugeordnet: Im Browser hiessen dieselben Stufen
        /// einmal anders als in der App, und auf Apples Abrechnung
        /// stand der dritte Name.
        struct Abospalte: Decodable, Identifiable {
            let stufe: String
            let name: String
            let wert: String
            var id: String { stufe }
        }

        /// Jede Funktion des Programms, nach Bereich gruppiert (R70).
        ///
        /// **Vom SERVER und nicht in Swift getippt.** Die Sätze stehen
        /// am Dekorator über der jeweiligen Sicht (`hilfe.erklaert`);
        /// eine zweite Fassung in der App beschriebe drei Umbauten
        /// später ein Programm, das es nicht mehr gibt -- und nichts
        /// würde rot.
        struct Funktion: Decodable, Identifiable {
            let titel: String
            let was: String
            let wo: String
            let denk: String
            var id: String { titel }
        }
        struct Funktionsbereich: Decodable, Identifiable {
            let bereich: String
            let eintraege: [Funktion]
            var id: String { bereich }
        }

        let funktionen: [Funktionsbereich]
        /// Die Werkzeuge des Editors, aus ihren eigenen Kurzhinweisen
        /// gelesen (R70).
        let editorgriffe: [String]
        let ausdrucke: [Zeile]
        /// Die Linienarten -- MIT ihrem Schlüssel.
        ///
        /// **Warum der Schlüssel mitmuss (09.09.2026).** Die App zeigt
        /// nicht das SVG des Servers, sondern zeichnet die Probe selbst
        /// (`Linienbild`), aus demselben erzeugten `Linienstil.swift`,
        /// aus dem auch der Editor zeichnet. Dafür braucht sie `route`
        /// und nicht „Route" -- der übersetzte Name ist auf einem
        /// spanischen Telefon ein anderer, und ein Bild, das dann
        /// fehlt, fiele niemandem auf.
        let linien: [Linienzeile]
        let linienenden: [String]
        /// Kreis gegen Viereck. Gezeichnet wird in der Oberfläche; hier
        /// steht nur, welche Seite gemeint ist und was sie bedeutet.
        let spielersymbole: [Symbolzeile]
        let situationen: [Zeile]
        let regelwerke: [Zeile]
        let formulare: [Block]
        let abo: [Abozeile]

        enum CodingKeys: String, CodingKey {
            case ausdrucke, linien, linienenden, situationen
            case regelwerke, formulare, abo
            case funktionen, editorgriffe, spielersymbole
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            // Die Abschnitte des Servers tragen verschiedene
            // Feldnamen (`titel`/`text`, `name`/`kurz`, `name`/`hinweis`).
            // Sie hier auf EIN Paar zu bringen ist die einzige Stelle,
            // an der die App etwas über den Aufbau wissen muss.
            ausdrucke = Modell.Hilfe.zeilen(b, .ausdrucke,
                                            titel: "titel", text: "text")
            linien = ((try? b.decode([[String: String]].self,
                                      forKey: .linien)) ?? [])
                .compactMap { eintrag in
                    guard let name = eintrag["name"] else { return nil }
                    // `art` DARF FEHLEN. Eine ältere Serverfassung
                    // schickt den Schlüssel nicht; dann steht die Zeile
                    // eben ohne Bild da. Das ist weniger, aber es ist
                    // nicht kaputt.
                    return Linienzeile(
                        art: eintrag["art"].flatMap(
                            Zeichnung.Linie.Art.init(rawValue:)),
                        name: name, text: eintrag["kurz"] ?? "")
                }
            spielersymbole = ((try? b.decode([[String: String]].self,
                                             forKey: .spielersymbole)) ?? [])
                .compactMap { eintrag in
                    guard let seite = eintrag["seite"],
                          let name = eintrag["name"] else { return nil }
                    return Symbolzeile(seite: seite, name: name)
                }
            situationen = Modell.Hilfe.zeilen(b, .situationen,
                                              titel: "name", text: "hinweis")
            regelwerke = Modell.Hilfe.zeilen(b, .regelwerke,
                                             titel: "verband", text: "jahr")
            linienenden = (try? b.decode([[String: String]].self,
                                         forKey: .linienenden))?
                .compactMap { $0["name"] } ?? []
            formulare = (try? b.decode([Block].self,
                                       forKey: .formulare)) ?? []
            abo = (try? b.decode([Abozeile].self, forKey: .abo)) ?? []
            // MIT `try?` UND RÜCKFALL wie alles hier: Eine ältere
            // Serverfassung kennt diese beiden Schlüssel nicht, und
            // eine App, die daran stirbt, zeigt gar keine Hilfe mehr.
            funktionen = (try? b.decode([Funktionsbereich].self,
                                        forKey: .funktionen)) ?? []
            editorgriffe = (try? b.decode([[String: String]].self,
                                          forKey: .editorgriffe))?
                .compactMap { $0["text"] } ?? []
        }

        /// Eine Liste von Wörterbüchern auf `Zeile` bringen.
        ///
        /// `[String: String]` und kein eigener Typ je Abschnitt: Was der
        /// Server an Feldern dazulegt, soll die App nicht umfallen
        /// lassen. Fehlt eines der beiden gesuchten, bleibt die Zeile
        /// weg -- eine halbe Zeile sagt weniger als keine.
        private static func zeilen(
            _ b: KeyedDecodingContainer<CodingKeys>, _ schluessel: CodingKeys,
            titel: String, text: String) -> [Zeile] {
            guard let roh = try? b.decode([[String: String]].self,
                                          forKey: schluessel) else { return [] }
            return roh.compactMap { eintrag in
                guard let name = eintrag[titel] else { return nil }
                return Zeile(name: name, text: eintrag[text] ?? "")
            }
        }
    }

    /// Was der Server über das Schloss zurückgibt (R6).
    struct Sperrstand: Decodable {
        let gesperrt: Bool
        let gesperrtVon: String?

        enum CodingKeys: String, CodingKey {
            case gesperrt
            case gesperrtVon = "gesperrt_von"
        }
    }

    // --- Üben und Lernstand (B8) -----------------------------------------

    /// Die gestellte Frage -- **ohne Kennung und ohne Namen**.
    ///
    /// Das ist keine Sparsamkeit, sondern der Sinn der Übung. Stünde der
    /// Name hier, läge die Lösung im Speicher der App, und der
    /// Übungsmodus prüfte nur noch, wer in die Antwort des Servers
    /// hineinsehen kann. Gefragt wird deshalb auf dem SERVER; die App
    /// bekommt eine Zeichnung und vier Namen.
    /// Eine Regelanmerkung: ein Schlüssel und die Zahlen dazu.
    ///
    /// **Der Satz steht nicht darin, und das ist der Punkt** (R22).
    /// Übersetzt wird in der Oberfläche; ein fertiger deutscher Satz
    /// vom Server wäre auf einem französischen Telefon deutsch.
    ///
    /// Die Zahlen sind ein loses Wörterbuch, weil jeder Schlüssel
    /// andere trägt: „zu wenige an der Linie" hat `ist` und `noetig`,
    /// „zu viele Spieler" hat zusätzlich `seite`. Ein festes Modell
    /// müsste jedes Feld optional führen und wäre bei jedem neuen
    /// Schlüssel wieder falsch.
    struct Anmerkung: Decodable, Equatable, Identifiable {
        let schluessel: String
        let zahlen: [String: Int]
        let seite: String?

        var id: String { schluessel + (seite ?? "") }

        enum CodingKeys: String, CodingKey {
            case schluessel, seite
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            schluessel = try b.decode(String.self, forKey: .schluessel)
            seite = try b.decodeIfPresent(String.self, forKey: .seite)
            var gesammelt: [String: Int] = [:]
            let alle = try decoder.container(keyedBy: FreierSchluessel.self)
            for name in alle.allKeys where name.stringValue != "schluessel"
                                       && name.stringValue != "seite" {
                if let zahl = try? alle.decode(Int.self, forKey: name) {
                    gesammelt[name.stringValue] = zahl
                }
            }
            zahlen = gesammelt
        }

        /// Nur für Tests und Vorschauen.
        init(schluessel: String, zahlen: [String: Int] = [:],
             seite: String? = nil) {
            self.schluessel = schluessel
            self.zahlen = zahlen
            self.seite = seite
        }

        /// Der Satz dazu, in der Sprache des Betrachters.
        ///
        /// **Dieselben Sätze wie im Browser** (`editor.js`,
        /// `anmerkungSatz`). Ein unbekannter Schlüssel gibt `nil` --
        /// dann zeigt die Leiste ihn nicht, statt eine leere Zeile zu
        /// öffnen.
        var satz: String? {
            func z(_ name: String) -> Int { zahlen[name] ?? 0 }
            switch schluessel {
            case "zu_viele_spieler":
                // Das eingesetzte Wort geht selbst durch die
                // Übersetzung. Der Satz ringsum tut es schon, aber
                // `%@` nimmt genau das, was hier steht, und dann
                // stand im spanischen Satz „Defense" statt „Defensa".
                // Die Wörter sind im Katalog, aus FEFA, FFFA und
                // FIDAF.
                let wo = seite == "defense" ? String(localized: "Defense")
                                            : String(localized: "Offense")
                return String(localized:
                    "\(z("ist")) Spieler in der \(wo), erlaubt sind \(z("erlaubt")).")
            case "kein_rush_in_dieser_klasse":
                return String(localized:
                    "In dieser Altersklasse wird nicht gerusht.")
            case "zu_wenige_an_der_linie":
                return String(localized:
                    "Nur \(z("ist")) Spieler an der Line of Scrimmage, mindestens \(z("noetig")) müssen es sein.")
            case "zu_viele_im_backfield":
                return String(localized:
                    "\(z("ist")) Spieler im Backfield, erlaubt sind \(z("erlaubt")).")
            case "zu_wenige_nummern":
                return String(localized:
                    "Nur \(z("ist")) Trikotnummern von 50 bis 79 an der Linie, mindestens \(z("noetig")) müssen es sein.")
            case "zu_wenige_im_rahmen":
                return String(localized:
                    "Nur \(z("ist")) Spieler im Backfield stehen zwischen den äußeren Linemen, mindestens \(z("noetig")) müssen es sein. Die Regel schützt den Quarterback.")
            default:
                return nil
            }
        }
    }

    struct Uebungsfrage: Decodable, Equatable {
        let los: Double
        let richtung: Int
        /// Zum nativen Zeichnen -- dieselbe Zeichnung, die auch der
        /// Editor bekommt, und dieselbe Projektion.
        let zeichnung: Zeichnung
        let feld: Feld
        /// Was hier gespielt wird. Ohne den Schlüssel zeichnet die
        /// Übung in Flaggröße -- auf einem Elfer-Feld sind die Figuren
        /// dann Punkte ohne Kürzel, und erkennen soll man den Play.
        let spielform: String
        /// Ob gerade ein aufgegebener Play drankommt (A7). Der Spieler
        /// sieht, dass seine Aufgabe geübt wird -- nicht, welcher Play
        /// es ist.
        let aufgabe: Bool

        enum CodingKeys: String, CodingKey {
            case los, richtung, zeichnung, feld, aufgabe, spielform
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            los = try b.decode(Double.self, forKey: .los)
            richtung = try b.decode(Int.self, forKey: .richtung)
            zeichnung = try b.decodeIfPresent(Zeichnung.self,
                                              forKey: .zeichnung) ?? Zeichnung()
            feld = (try b.decodeIfPresent(Feld.VomServer.self,
                                          forKey: .feld))?.alsFeld ?? .afvd
            spielform = try b.decodeIfPresent(String.self,
                                              forKey: .spielform)
                ?? Spielform.standard
            aufgabe = try b.decodeIfPresent(Bool.self, forKey: .aufgabe)
                ?? false
        }

        /// Nur für Tests und Vorschauen.
        init(los: Double, richtung: Int, zeichnung: Zeichnung = Zeichnung(),
             feld: Feld = .afvd, spielform: String = Spielform.standard,
             aufgabe: Bool = false) {
            self.los = los
            self.richtung = richtung
            self.zeichnung = zeichnung
            self.feld = feld
            self.spielform = spielform
            self.aufgabe = aufgabe
        }
    }

    /// Ein Name zum Antippen. Vier davon stehen unter der Zeichnung.
    struct Antwortknopf: Decodable, Identifiable, Hashable {
        let id: Int
        let name: String
    }

    /// Wie viel schon sitzt. Gerechnet hat das der Server
    /// (`lernen.fortschritt`) -- die App zeichnet nur den Balken.
    ///
    /// `Hashable` und nicht bloß `Equatable`, seit eine Kaderzeile (B9)
    /// einen Fortschritt trägt und selbst in eine `NavigationLink`-Kette
    /// geht. Ein Typ, der nur `Equatable` ist, macht jeden Behälter
    /// darüber ebenfalls nur `Equatable` -- und das fällt erst beim
    /// Übersetzen auf, also eine halbe Stunde später auf dem Läufer.
    struct Fortschritt: Decodable, Hashable {
        let gesamt: Int
        let sitzen: Int
        let angefangen: Int
        let offen: Int
        let prozent: Int
        /// Ob gegen den Lernauftrag gezählt wird statt gegen das ganze
        /// Playbook (A7). Der Unterschied gehört sichtbar gemacht: „3
        /// von 6" und „3 von 40" sehen sonst nach einem Fehler aus.
        let ausAuftrag: Bool

        enum CodingKeys: String, CodingKey {
            case gesamt, sitzen, angefangen, offen, prozent
            case ausAuftrag = "aus_auftrag"
        }

        /// Für den Balken. `Double`, damit er nicht in Prozentschritten
        /// springt -- gerundet wird nur die ZAHL, die danebensteht.
        var anteil: Double {
            gesamt > 0 ? Double(sitzen) / Double(gesamt) : 0
        }

        /// Nur für Tests und Vorschauen.
        init(gesamt: Int, sitzen: Int, angefangen: Int = 0, offen: Int = 0,
             prozent: Int = 0, ausAuftrag: Bool = false) {
            self.gesamt = gesamt
            self.sitzen = sitzen
            self.angefangen = angefangen
            self.offen = offen
            self.prozent = prozent
            self.ausAuftrag = ausAuftrag
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            gesamt = try b.decodeIfPresent(Int.self, forKey: .gesamt) ?? 0
            sitzen = try b.decodeIfPresent(Int.self, forKey: .sitzen) ?? 0
            angefangen = try b.decodeIfPresent(Int.self,
                                               forKey: .angefangen) ?? 0
            offen = try b.decodeIfPresent(Int.self, forKey: .offen) ?? 0
            prozent = try b.decodeIfPresent(Int.self, forKey: .prozent) ?? 0
            ausAuftrag = try b.decodeIfPresent(Bool.self,
                                               forKey: .ausAuftrag) ?? false
        }
    }

    /// Was der Server auf „stell mir die nächste Frage" antwortet.
    ///
    /// **Zwei Fälle und nicht ein Typ mit lauter leeren Feldern.** Ein
    /// Playbook mit zwei Plays hat kein Problem, es hat nur zu wenige --
    /// „jede Frage wäre geraten" ist eine Auskunft und keine Absage.
    enum Uebungsstand: Decodable, Equatable {
        case frage(Runde)
        /// Zum Üben fehlen Plays. `noetig` ist die Zahl des Servers.
        case zuWenige(noetig: Int, hat: Int)

        struct Runde: Decodable, Equatable {
            let frage: Uebungsfrage
            /// **In dieser Reihenfolge anzeigen.** Der Server hat sie
            /// gemischt; wer sie sortiert, stellt die richtige Antwort
            /// irgendwann an eine berechenbare Stelle.
            let auswahl: [Antwortknopf]
            let fortschritt: Fortschritt
            /// Wie oft richtig hintereinander, dann sitzt ein Play.
            /// Vom Server, nicht als Zahl in der App.
            let serieFuerSitzt: Int

            enum CodingKeys: String, CodingKey {
                case frage, auswahl, fortschritt
                case serieFuerSitzt = "serie_fuer_sitzt"
            }
        }

        private enum CodingKeys: String, CodingKey {
            case zuWenige = "zu_wenige"
            case plays
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            if let noetig = try b.decodeIfPresent(Int.self, forKey: .zuWenige) {
                self = .zuWenige(
                    noetig: noetig,
                    hat: try b.decodeIfPresent(Int.self, forKey: .plays) ?? 0)
                return
            }
            self = .frage(try Runde(from: decoder))
        }
    }

    /// Ein Übungspaket: die nächsten Fragen im Voraus, für den Platz
    /// ohne Empfang (R14).
    ///
    /// **Warum es das gibt.** Welcher Play drankommt, rechnet der
    /// Server (`lernen.gewicht`) -- nie gefragt vor sitzt-noch-nicht vor
    /// sitzt, gewichtet nach den bisherigen Fehlern. Diese Rechnung in
    /// Swift zu wiederholen ist ausdrücklich verworfen: „eine zweite
    /// Gewichtung in Swift sähe nie falsch aus, sondern nur nach
    /// Zufall." Also rechnet der Server voraus, und die App spielt eine
    /// fertige Reihe ab.
    struct Uebungspaket: Decodable, Equatable {
        let fragen: [Paketfrage]
        /// Wie lange der Server die Fragen aufhebt. Danach zählt ein
        /// Nachtrag nicht mehr -- die App darf dann aufräumen.
        let haltbarTage: Int

        enum CodingKeys: String, CodingKey {
            case fragen
            case haltbarTage = "haltbar_tage"
        }
    }

    /// Eine Frage aus einem Paket.
    ///
    /// **Nur `Decodable`, wie alles andere hier -- und das ist wichtig.**
    /// Auf der Platte liegt die ROHE Antwort des Servers, nicht dieser
    /// Typ. Ihn schreibbar zu machen hieße, jedes Feld ein zweites Mal
    /// zu pflegen, und ein vergessenes fehlte am Platz und nirgends
    /// sonst. Dieselbe Entscheidung wie beim Vorrat (R14): Was
    /// hervorgeholt wird, geht durch DIESELBE Stelle wie eine frische
    /// Antwort. Die Kopie kann gar nicht anders gelesen werden als das
    /// Original.
    ///
    /// Was die App selbst schreibt, ist nur `OffeneAntwort` -- drei
    /// Felder, die kein Servermodell spiegeln.
    struct Paketfrage: Decodable, Equatable, Identifiable {
        /// Die Adresse dieser einen Antwort beim Nachtragen. Sie steht
        /// auf einer Zeile beim Server, und die verschwindet beim
        /// Verbuchen -- deshalb zählt ein zweites Nachtragen nichts.
        let marke: String
        /// **Die Kennung des gefragten Plays.**
        ///
        /// Überall sonst schickt der Server sie ausdrücklich NICHT --
        /// `_frage_antwort` lässt sie weg, und `Quizfrage` beginnt mit
        /// der Begründung dafür. Am Platz gibt es aber niemanden, der
        /// sagen könnte, ob eine Antwort richtig war, und ein
        /// Zwischenweg über eine Prüfsumme nützt nichts: Bei vier
        /// Antworten rechnet man sie viermal aus.
        ///
        /// **Gewertet wird trotzdem auf dem Server.** Das hier ist nur
        /// für den Moment am Platz; was im Lernstand landet, rechnet
        /// `nachtragen/` aus seiner eigenen Zeile nach.
        let loesung: Int
        /// Je möglicher Antwort der Satz, der danach dasteht --
        /// Schlüssel ist die Kennung des ANGETIPPTEN Plays, denn der
        /// Satz nennt beide Namen.
        ///
        /// **Er kommt vom Server und wird nicht in Swift gebaut.**
        /// Denselben Satz liest der Browser; in Swift nachgebaut wäre
        /// er beim nächsten Wort ein anderer, und `test_ton.py` käme an
        /// ihn nicht heran.
        let saetze: [String: String]
        let frage: Uebungsfrage
        let auswahl: [Antwortknopf]
        /// Der Lernstand VOM ZEITPUNKT DES HOLENS.
        ///
        /// Er bewegt sich ohne Netz nicht -- deshalb zeigt die Ansicht
        /// daneben den Paketstand (`Paketblock.stand`), der sich bewegt.
        /// Beides zu vermischen hiesse, am Platz eine Zahl zu zeigen,
        /// die stillsteht.
        let fortschritt: Fortschritt
        let serieFuerSitzt: Int

        var id: String { marke }

        /// Der Satz zu einem Fingertipp. Leer, wenn der Server zu
        /// dieser Antwort keinen geschickt hat -- besser nichts als ein
        /// selbstgebauter.
        func satz(fuer gewaehlt: Int) -> String {
            saetze[String(gewaehlt)] ?? ""
        }

        enum CodingKeys: String, CodingKey {
            case marke, loesung, saetze, frage, auswahl, fortschritt
            case serieFuerSitzt = "serie_fuer_sitzt"
        }
    }

    /// Eine am Platz gegebene Antwort, die noch niemand kennt.
    struct OffeneAntwort: Codable, Equatable {
        let marke: String
        /// Die Kennung des angetippten Plays. Was daraus wird,
        /// entscheidet der Server.
        let gewaehlt: Int
        /// Wann getippt wurde. **Die Reihenfolge hängt daran**:
        /// `Lernstand.serie` ist eine andere, wenn erst falsch und dann
        /// richtig kam als umgekehrt.
        let wann: Date
    }

    /// Was das Nachtragen ergeben hat.
    struct Nachtrag: Decodable {
        let ergebnisse: [Ergebnis]
        let fortschritt: Fortschritt

        struct Ergebnis: Decodable {
            let marke: String
            /// `false` heißt: schon gezählt oder zu alt. **Kein
            /// Fehler** -- die App darf danach aufräumen.
            let gewertet: Bool
            /// Nur bei `gewertet`.
            let richtig: Bool?
        }
    }

    /// Was nach einer Antwort zurückkommt: das Ergebnis UND die nächste
    /// Frage.
    ///
    /// **Beides in einer Antwort**, weil Üben eine Bewegung ist: tippen,
    /// sehen was es war, weitermachen. Zwei Anfragen hießen zwei
    /// Wartezeiten je Frage; im Browser ist es auch eine.
    struct Antwortrunde: Decodable {
        /// `nil` heißt: Es stand keine Frage offen, gezählt wurde
        /// nichts. Kein Fehler -- der Normalfall nach einem Neustart
        /// oder einem doppelten Fingertipp.
        let ergebnis: Ergebnis?
        let naechste: Uebungsstand

        struct Ergebnis: Decodable, Equatable {
            let richtig: Bool
            /// Der Satz, der dasteht -- **vom Server**
            /// (`lernen.rueckmeldung`). In Swift gebaut wäre er beim
            /// nächsten Wort ein anderer als im Browser, und
            /// `test_ton.py` käme gar nicht an ihn heran.
            let meldung: String
            /// Der Play, der gefragt war. Jetzt darf sein Name heraus:
            /// Die Frage ist beantwortet.
            let war: Antwortknopf
            /// Was angetippt wurde. `nil`, wenn es den Play nicht mehr
            /// gibt -- dann nennt die Meldung nur den richtigen.
            let gewaehlt: Antwortknopf?
            let stand: Stand

            struct Stand: Decodable, Equatable {
                let richtig: Int
                let falsch: Int
                let serie: Int
                let sitzt: Bool
            }
        }

        private enum CodingKeys: String, CodingKey {
            case gewertet, richtig, meldung, war, gewaehlt, stand
        }

        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            naechste = try Uebungsstand(from: decoder)
            // Das Ergebnis hängt an `gewertet` und nicht daran, ob
            // `war` mitkam: Ein fehlendes Feld wäre auch ein
            // Übertragungsfehler, `gewertet: false` ist eine Aussage.
            guard try b.decodeIfPresent(Bool.self, forKey: .gewertet) == true
            else {
                ergebnis = nil
                return
            }
            ergebnis = Ergebnis(
                richtig: try b.decodeIfPresent(Bool.self,
                                               forKey: .richtig) ?? false,
                meldung: try b.decodeIfPresent(String.self,
                                               forKey: .meldung) ?? "",
                war: try b.decode(Antwortknopf.self, forKey: .war),
                gewaehlt: try b.decodeIfPresent(Antwortknopf.self,
                                                forKey: .gewaehlt),
                stand: try b.decode(Ergebnis.Stand.self, forKey: .stand))
        }
    }

    /// Wer im Team welchen Play sicher kennt -- für den Trainerstab.
    ///
    /// Sortiert hat der Server, nach Namen. **Keine Rangliste:** Eine
    /// Liste, die von „kann alles" nach „kann nichts" sortiert, ist ein
    /// Aushang, und ein Aushang gehört nicht in eine Jugendmannschaft.
    /// Deshalb wird sie in der App auch nicht umsortiert.
    struct Lernstandsliste: Decodable {
        let plays: Int
        let serieFuerSitzt: Int
        let zeilen: [Zeile]
        let schwierig: [Schwieriger]

        enum CodingKeys: String, CodingKey {
            case plays, zeilen, schwierig
            case serieFuerSitzt = "serie_fuer_sitzt"
        }

        struct Zeile: Decodable, Identifiable, Equatable {
            /// Die Kennung der MITGLIEDSCHAFT, nicht die des Kontos: Ein
            /// Kader gehört der Mannschaft (A5).
            let mitglied: Int
            let name: String
            let rolle: String
            let fortschritt: Fortschritt

            var id: Int { mitglied }
        }

        /// Ein Play, den wenige können. Die Liste, nach der ein Training
        /// geplant wird.
        struct Schwieriger: Decodable, Identifiable, Equatable {
            let id: Int
            let name: String
            let nummer: Int?
            let sitzen: Int
            let von: Int
            let falsch: Int
        }
    }

    /// Was an DIESEM Heft hängt, wenn es gedruckt wird (B10).
    ///
    /// **Was hier NICHT steht: die Liste der Ausgaben.** Die kennt die
    /// App aus `Druckwahl.swift`, erzeugt aus `designer/druck.py`. Über
    /// die Leitung geht nur, was die App nicht wissen kann.
    struct Druckauskunft: Decodable, Equatable {
        let playbook: Kopf
        /// Wie viele Plays es überhaupt gibt. Null heißt: Hier ist
        /// nichts zu drucken, und das sagt die Ansicht statt einen
        /// leeren Bogen zu erzeugen.
        let plays: Int
        /// Nur die BELEGTEN Seiten. Eine Auswahl mit „Defense (0)" darin
        /// wäre ein Eintrag, der ein leeres Blatt druckt.
        let seiten: [Seite]
        let hatLogo: Bool
        /// Das Kürzel, das statt eines Logos gedruckt wird.
        let kuerzel: String
        /// Ob der Streifen der Demo mitdruckt (A2). Angekündigt und
        /// nicht verschwiegen: Wer vorher weiß, dass er kommt, druckt
        /// keine dreißig Bogen umsonst.
        let demo: Bool
        let demoText: String

        enum CodingKeys: String, CodingKey {
            case playbook, plays, seiten, kuerzel, demo
            case hatLogo = "hat_logo"
            case demoText = "demo_text"
        }

        struct Kopf: Decodable, Equatable {
            let id: Int
            let name: String
        }

        struct Seite: Decodable, Equatable, Identifiable {
            let wert: String
            let name: String
            let anzahl: Int
            var id: String { wert }
        }
    }
}


/// Ein Schlüssel, dessen Name erst zur Laufzeit feststeht.
///
/// Gebraucht von `Modell.Anmerkung`: Der Server schickt zu jedem
/// Regelbefund die Zahlen, die genau dieser Befund trägt -- „zu wenige
/// an der Linie" hat `ist` und `noetig`, „zu viele Spieler" zusätzlich
/// `seite`. Ein festes Modell müsste jedes Feld optional führen und
/// wäre bei jedem neuen Schlüssel wieder falsch.
///
/// **AUSSERHALB VON `Modell` UND NICHT VERSCHACHTELT**, und das hat
/// einen Grund, der nichts mit Stil zu tun hat: Der Wächter
/// `test_appsprache.test_kein_init_vergisst_ein_feld` teilt Swift an
/// jedem `struct` und weiß nichts von schließenden Klammern. Ein
/// verschachtelter Typ bekommt dadurch die Bauwege des äußeren
/// zugerechnet, und der Wächter meldet, ein `init` vergesse ein Feld,
/// das ihm gar nicht gehört. Ein Fehlalarm, den man wegdrückt, schützt
/// beim nächsten Mal nichts mehr.
struct FreierSchluessel: CodingKey {
    let stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { return nil }
}
