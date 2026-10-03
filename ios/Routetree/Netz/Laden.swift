import Foundation

/// Holt Listen und einzelne Plays. Eine Stelle, an der Anmeldung und
/// Server zusammenkommen -- die Ansichten sprechen nur mit dieser.
@MainActor
final class Laden: ObservableObject {

    private let anmeldung: Anmeldung

    init(anmeldung: Anmeldung) {
        self.anmeldung = anmeldung
    }

    /// Ruft eine Adresse mit gültigem Token.
    ///
    /// Der eine Wiederholungsversuch bei `abgemeldet` ist wichtig: Das
    /// Zugriffstoken läuft nach dreißig Minuten ab, und ein Nutzer, der
    /// deshalb aus der App fliegt, hält sie für kaputt. `gueltigesToken`
    /// erneuert vorausschauend, aber zwischen Prüfung und Ankunft der
    /// Anfrage kann trotzdem Zeit vergehen.
    private func holen<T: Decodable>(_ weg: String, als: T.Type) async throws -> T {
        try await holenMitRumpf(weg, als: T.self).wert
    }

    /// Wie `holen`, gibt aber die Antwort mit heraus -- für den Vorrat
    /// (R14). Der Wiederholungsversuch steht nur hier, damit es keine
    /// zweite Fassung davon gibt.
    private func holenMitRumpf<T: Decodable>(
        _ weg: String, als: T.Type
    ) async throws -> (wert: T, rumpf: Data) {
        do {
            let token = try await anmeldung.gueltigesToken()
            return try await Server.holeMitRumpf(
                try Server.anfrage(weg, token: token), als: T.self)
        } catch Server.Fehler.abgemeldet {
            let token = try await anmeldung.gueltigesToken()
            return try await Server.holeMitRumpf(
                try Server.anfrage(weg, token: token), als: T.self)
        }
    }

    // --- Ohne Netz (R14) --------------------------------------------------

    /// Holen -- und wenn kein Netz da ist, die letzte Kopie nehmen.
    ///
    /// **Warum das NICHT in `holen` steht.** Dann bekämen alle
    /// dreißig Aufrufer stillschweigend alte Daten, ohne es zu wissen
    /// und ohne es sagen zu können. Eine alte Aufstellung ohne Hinweis
    /// ist schlimmer als ein Fehler: Der Trainer am Platz liest sie und
    /// hält sie für die von heute. Wer hier hereinkommt, bekommt den
    /// Zeitpunkt mit und muss ihn anzeigen.
    ///
    /// **Erst entschlüsseln, dann merken.** Was die App nicht lesen
    /// kann, hilft ihr am Platz auch nicht -- es verdrängte nur die
    /// letzte Kopie, die sie lesen konnte.
    func ausVorratOderNetz<T: Decodable>(
        _ weg: String, als: T.Type, marke: String? = nil
    ) async throws -> Vorratsblock.Ausgabe<T> {
        do {
            let (wert, rumpf) = try await holenMitRumpf(weg, als: T.self)
            if Vorratsblock.gehoertInDenVorrat(weg) {
                Vorrat.merken(rumpf, fuer: weg, marke: marke)
            }
            return Vorratsblock.Ausgabe(wert: wert, stand: nil)
        } catch {
            guard Vorratsblock.ausDemVorrat(bei: error),
                  let eintrag = Vorrat.holen(fuer: weg),
                  let wert = try? Server.entschluessler.decode(
                      T.self, from: eintrag.rumpf)
            else { throw error }
            return Vorratsblock.Ausgabe(wert: wert, stand: eintrag.stand)
        }
    }

    func heftlisteMitVorrat() async throws
        -> Vorratsblock.Ausgabe<[Modell.Playbook]> {
        let ausgabe = try await ausVorratOderNetz(
            Vorratsblock.wegFuerHefte, als: Modell.PlaybookListe.self)
        return Vorratsblock.Ausgabe(wert: ausgabe.wert.playbooks,
                                    stand: ausgabe.stand)
    }

    func playlisteMitVorrat(playbook: Int) async throws
        -> Vorratsblock.Ausgabe<Modell.PlayListe> {
        try await ausVorratOderNetz(
            Vorratsblock.wegFuerPlayliste(playbook),
            als: Modell.PlayListe.self)
    }

    /// Ein Play samt Zeichnung -- notfalls vom Gerät.
    ///
    /// `version` kommt aus der Liste und wird als Marke abgelegt.
    /// Ohne sie könnte die App nur nach dem Alter fragen, und das ist
    /// eine Schätzung; mit ihr ist „meine Kopie ist noch die richtige"
    /// eine Frage mit einer genauen Antwort.
    func playMitVorrat(_ id: Int, version: Int?) async throws
        -> Vorratsblock.Ausgabe<Modell.PlayVoll> {
        try await ausVorratOderNetz(
            Vorratsblock.wegFuerPlay(id), als: Modell.PlayVoll.self,
            marke: version.map { Vorratsblock.marke(version: $0) })
    }

    /// Die Hilfe -- notfalls vom Gerät (B6).
    ///
    /// Niklas am 02.09.2026: „ich finde sie sollte auch inapp
    /// zusätzlich sein, damit sie auch offline verfügbar ist weißt du?"
    /// Genau dort braucht man sie: Wer am Spielfeldrand nicht
    /// weiterkommt, hat oft auch kein Netz.
    ///
    /// **Ohne Token.** Die Adresse ist offen, wie die Hilfeseite selbst:
    /// Wer nicht weiterkommt, ist manchmal genau der, der sich nicht
    /// anmelden kann.
    func hilfeMitVorrat(sprache: String) async throws
        -> Vorratsblock.Ausgabe<Modell.Hilfe> {
        try await ausVorratOderNetz(
            Vorratsblock.wegFuerHilfe(sprache), als: Modell.Hilfe.self)
    }

    func kategorienMitVorrat(playbook: Int) async throws
        -> Vorratsblock.Ausgabe<[Modell.Kategorie]> {
        let ausgabe = try await ausVorratOderNetz(
            Vorratsblock.wegFuerKategorien(playbook),
            als: Modell.KategorienListe.self)
        return Vorratsblock.Ausgabe(wert: ausgabe.wert.kategorien,
                                    stand: ausgabe.stand)
    }

    /// Die Zeichnungen eines Hefts auf das Gerät holen, solange noch
    /// Netz da ist (R14).
    ///
    /// **Der Reihe nach und nicht alle auf einmal.** Vierzig
    /// gleichzeitige Anfragen aus einem Handy-Hotspot sind der Weg in
    /// die Bremse des Servers (429) -- und hier wartet niemand: Das
    /// läuft im Hintergrund, während der Trainer schon seine Liste
    /// liest.
    ///
    /// **Beim ersten Fehlschlag ist Schluss.** Wer kein Netz mehr hat,
    /// hat es auch beim neununddreißigsten Play nicht, und jede weitere
    /// Anfrage kostet nur Wartezeit.
    @discardableResult
    func vorratFuellen(_ plays: [Modell.PlayKurz],
                       melden: (@Sendable (Int, Int) -> Void)? = nil)
        async -> Bool {
        let offen = Self.fehlend(plays)
        let fassung = Dictionary(plays.map { ($0.id, $0.version) },
                                 uniquingKeysWith: { erste, _ in erste })
        var geholt = 0
        melden?(geholt, offen.count)
        for id in offen {
            guard let ausgabe = try? await playMitVorrat(
                    id, version: fassung[id]),
                  !ausgabe.ausDemVorrat else { return false }
            geholt += 1
            melden?(geholt, offen.count)
        }
        return true
    }

    /// Welche Plays noch nicht auf dem Gerät liegen (R69).
    ///
    /// **Eine eigene Stelle, weil zwei Fragen daran hängen.** Das
    /// Nachladen braucht die Liste; die ANZEIGE braucht nur ihre Länge.
    /// Niklas am 03.09.2026 zum stillen Vorratfüllen: Gemeint ist ein
    /// ausdrücklicher Griff „dieses Heft mitnehmen", mit Anzeige, was
    /// schon da ist -- und dafür muss man fragen können, ohne etwas zu
    /// holen.
    static func fehlend(_ plays: [Modell.PlayKurz]) -> [Int] {
        var marken: [Int: String] = [:]
        for play in plays {
            if let vorhanden = Vorrat.marke(
                fuer: Vorratsblock.wegFuerPlay(play.id)) {
                marken[play.id] = vorhanden
            }
        }
        return Vorratsblock.nachzuladen(plays, marken: marken)
    }

    /// Das eigene Passwort ändern (R50).
    ///
    /// Niklas am 01.09.2026: „mach auf die roadmap ob man sein passwort
    /// zurücksetzen kann. davon hab ich noch gar nix gesehen glaub
    /// ich." Im Browser gibt es beides seit langem, in der App keines.
    ///
    /// **Der Server prüft, nicht die App.** Ob ein Passwort lang genug
    /// ist, ob es zu häufig vorkommt, ob es dem eigenen Namen ähnelt --
    /// das steht in `AUTH_PASSWORD_VALIDATORS` und nirgends sonst. Eine
    /// nachgebaute Prüfung in Swift liesse irgendwann eines durch, das
    /// der Server ablehnt, und der Trainer bekäme eine Absage, die er
    /// sich nicht erklären kann.
    ///
    /// **Ohne `mitToken`-Wiederholung ist hier nichts zu retten**, aber
    /// mit: Wessen Token gerade abgelaufen ist, soll nicht sein
    /// getipptes Passwort verlieren.
    func passwortAendern(altes: String, neues: String) async throws {
        try await mitToken { token in
            let anfrage = try Server.anfrage(
                "/api/v1/konto/passwort/", methode: "POST",
                rumpf: ["altes": altes, "neues": neues], token: token)
            _ = try await Server.ausfuehren(anfrage)
        }
    }

    func vereine() async throws -> [Modell.Verein] {
        try await holen("/api/v1/vereine/", als: Modell.VereinsListe.self).vereine
    }

    func playbooks() async throws -> [Modell.Playbook] {
        try await holen(Vorratsblock.wegFuerHefte,
                        als: Modell.PlaybookListe.self).playbooks
    }

    func plays(playbook: Int) async throws -> [Modell.PlayKurz] {
        try await playliste(playbook: playbook).plays
    }

    /// Die Liste MIT ihrem Kopf. Dort steht, ob ein Knopf „Play anlegen"
    /// hingehört und wie viele Plays noch hineinpassen.
    func playliste(playbook: Int) async throws -> Modell.PlayListe {
        try await holen(Vorratsblock.wegFuerPlayliste(playbook),
                        als: Modell.PlayListe.self)
    }

    /// Ein Play samt fertiger Zeichnung.
    ///
    /// **Vorerst zeichnet der Server.** Die eigene Zeichenfläche kommt
    /// in Phase 7 (ADR-0002) und ist der Grund, überhaupt nativ zu
    /// bauen. Bis dahin ist ein serverseitig erzeugtes SVG richtig und
    /// nicht faul: Es ist dasselbe Bild wie im Druck, es kann nicht
    /// abweichen, und es macht die App ab dem ersten TestFlight-Bau
    /// benutzbar statt leer.
    func play(_ id: Int) async throws -> Modell.PlayVoll {
        try await holen(Vorratsblock.wegFuerPlay(id), als: Modell.PlayVoll.self)
    }

    /// Einen neuen Play anlegen (B3).
    ///
    /// Ohne Zeichnung: Der Server setzt dann dieselbe Startaufstellung,
    /// mit der auch „Play zeichnen" im Browser beginnt.
    func playAnlegen(playbook: Int,
                     name: String) async throws -> Playspeicher.Anlegen {
        do {
            return try await Playspeicher.anlegen(
                playbook: playbook, name: name,
                token: try await anmeldung.gueltigesToken())
        } catch Server.Fehler.abgemeldet {
            return try await Playspeicher.anlegen(
                playbook: playbook, name: name,
                token: try await anmeldung.gueltigesToken())
        }
    }

    /// Führt etwas mit gültigem Token aus -- mit dem einen
    /// Wiederholungsversuch, den auch das Lesen hat.
    ///
    /// **Warum das eine eigene Hülle ist.** Ohne sie stünde in jeder der
    /// sieben Schreibfunktionen dasselbe `do/catch`, und beim nächsten
    /// wäre es vergessen. Der Wiederholungsversuch ist nicht schmückend:
    /// Das Zugriffstoken läuft nach dreißig Minuten ab, und ein Coach,
    /// der beim Löschen eines Playbooks aus der App fliegt, hält sie für
    /// kaputt.
    private func mitToken<T>(_ tun: (String) async throws -> T) async throws -> T {
        do {
            return try await tun(try await anmeldung.gueltigesToken())
        } catch Server.Fehler.abgemeldet {
            return try await tun(try await anmeldung.gueltigesToken())
        }
    }

    // --- Anlegen und Ordnen (B6) ------------------------------------------

    func playbookAnlegen(team: Int, name: String, saison: String,
                         feldformat: String,
                         kategorien: Bool) async throws -> Heftspeicher.Anlegen {
        try await mitToken {
            try await Heftspeicher.anlegen(
                team: team, name: name, saison: saison,
                feldformat: feldformat, kategorien: kategorien, token: $0)
        }
    }

    func playbookAendern(_ id: Int, name: String, saison: String,
                         hinweise: String) async throws -> Modell.Playbook {
        try await mitToken {
            try await Heftspeicher.aendern(
                playbook: id, name: name, saison: saison,
                hinweise: hinweise, token: $0)
        }
    }

    func playbookLoeschen(_ id: Int) async throws {
        try await mitToken { try await Heftspeicher.loeschen(playbook: id,
                                                             token: $0) }
    }

    func reihenfolgeSichern(playbook: Int, kennungen: [Int],
                            nummernMitziehen: Bool)
        async throws -> [Heftspeicher.NeueNummer] {
        try await mitToken {
            try await Heftspeicher.reihenfolgeSichern(
                playbook: playbook, kennungen: kennungen,
                nummernMitziehen: nummernMitziehen, token: $0)
        }
    }

    func playUmbenennen(_ id: Int, name: String,
                        version: Int) async throws -> Playspeicher.Ergebnis {
        try await mitToken {
            try await Playspeicher.umbenennen(
                play: id, name: name, version: version, token: $0)
        }
    }

    func playLoeschen(_ id: Int) async throws {
        try await mitToken { try await Playspeicher.loeschen(play: id,
                                                             token: $0) }
    }

    /// Einen Spielzug melden (Apple-Richtlinie 1.2).
    ///
    /// Kein Schreibrecht nötig, und das ist der Punkt: Melden darf, wer
    /// den Inhalt SIEHT. Ein Zuschauer ist genau der, dem etwas
    /// auffällt und der nichts dagegen tun kann.
    @discardableResult
    func playMelden(_ id: Int, grund: Meldestelle.Grund, text: String,
                    inGutemGlauben: Bool)
        async throws -> Meldestelle.Bestaetigung {
        try await mitToken { try await Meldestelle.melden(
            play: id, grund: grund, text: text,
            inGutemGlauben: inGutemGlauben, token: $0) }
    }

    // --- Kategorien und Formationen (B7) ----------------------------------

    func kategorien(playbook: Int) async throws -> [Modell.Kategorie] {
        try await holen(Vorratsblock.wegFuerKategorien(playbook),
                        als: Modell.KategorienListe.self).kategorien
    }

    func kategorieAnlegen(playbook: Int, name: String, farbe: String)
        async throws -> Kategoriespeicher.Anlegen {
        try await mitToken {
            try await Kategoriespeicher.anlegen(
                playbook: playbook, name: name, farbe: farbe, token: $0)
        }
    }

    func kategorieAendern(_ id: Int, name: String,
                          farbe: String) async throws -> Modell.Kategorie {
        try await mitToken {
            try await Kategoriespeicher.aendern(
                kategorie: id, name: name, farbe: farbe, token: $0)
        }
    }

    func kategorieLoeschen(_ id: Int) async throws
        -> Kategoriespeicher.Geloescht {
        try await mitToken {
            try await Kategoriespeicher.loeschen(kategorie: id, token: $0)
        }
    }

    func kategorienOrdnen(playbook: Int, kennungen: [Int]) async throws
        -> [Modell.Kategorie] {
        try await mitToken {
            try await Kategoriespeicher.reihenfolgeSichern(
                playbook: playbook, kennungen: kennungen, token: $0)
        }
    }

    func playKategorieSetzen(_ id: Int, kategorie: Int?,
                             version: Int) async throws
        -> Playspeicher.Ergebnis {
        try await mitToken {
            try await Playspeicher.kategorieSetzen(
                play: id, kategorie: kategorie, version: version, token: $0)
        }
    }

    func formationen(playbook: Int) async throws -> [Modell.Formation] {
        try await formationsliste(playbook: playbook).formationen
    }

    /// Dasselbe MIT den eingebauten Vorlagen (R110.5).
    ///
    /// Eine Anfrage und nicht zwei: Beide kommen aus derselben Antwort,
    /// und eine zweite Adresse waere eine zweite Gelegenheit, sie
    /// auseinanderlaufen zu lassen.
    func formationsliste(playbook: Int) async throws
        -> Modell.FormationsListe {
        try await holen("/api/v1/playbooks/\(playbook)/formationen/",
                        als: Modell.FormationsListe.self)
    }

    func formationSichern(playbook: Int, name: String,
                          aufstellung: [Zeichnung.Spieler]) async throws
        -> Formationsspeicher.Gesichert {
        try await mitToken {
            try await Formationsspeicher.sichern(
                playbook: playbook, name: name, aufstellung: aufstellung,
                token: $0)
        }
    }

    func formationUmbenennen(_ id: Int, name: String) async throws
        -> Modell.Formation {
        try await mitToken {
            try await Formationsspeicher.umbenennen(formation: id, name: name,
                                                    token: $0)
        }
    }

    func formationLoeschen(_ id: Int) async throws {
        try await mitToken {
            try await Formationsspeicher.loeschen(formation: id, token: $0)
        }
    }

    // --- Üben und Lernstand (B8) ------------------------------------------

    func uebungsfrage(playbook: Int) async throws -> Modell.Uebungsstand {
        try await mitToken {
            try await Uebungsspeicher.frage(playbook: playbook, token: $0)
        }
    }

    func uebungAntwort(playbook: Int,
                       antwort: Int) async throws -> Modell.Antwortrunde {
        try await mitToken {
            try await Uebungsspeicher.antworten(playbook: playbook,
                                                antwort: antwort, token: $0)
        }
    }

    // --- Ohne Empfang (R14) -----------------------------------------------

    /// Ein Übungspaket holen und **gleich ablegen**.
    ///
    /// Beides zusammen, weil es kein Paket gibt, das man holt und nicht
    /// ablegt: Der ganze Zweck ist, dass es am Platz da ist. Zwei
    /// Aufrufe wären zwei Gelegenheiten, den zweiten zu vergessen.
    func uebungspaketHolen(playbook: Int) async throws
        -> Modell.Uebungspaket {
        let (wert, rumpf) = try await mitToken {
            try await Uebungsspeicher.paket(playbook: playbook, token: $0)
        }
        Uebungsvorrat.paketMerken(rumpf, playbook: playbook)
        return wert
    }

    /// Die wartenden Antworten nachtragen und die erledigten aus der
    /// Schlange nehmen.
    ///
    /// **Auch die, die der Server mit `gewertet: false` beantwortet.**
    /// Das heißt „schon gezählt oder zu alt" -- wer sie liegen ließe,
    /// schickte sie bis in alle Ewigkeit erneut.
    ///
    /// Gibt zurück, wie viele wirklich gezählt haben. `0` bei leerer
    /// Schlange, ohne dass eine Anfrage rausgeht.
    @discardableResult
    func uebungNachtragen(playbook: Int) async throws -> Int {
        let fuhre = Paketblock.naechsteFuhre(
            Uebungsvorrat.offeneAntworten(playbook: playbook))
        guard !fuhre.isEmpty else { return 0 }

        let nachtrag = try await mitToken {
            try await Uebungsspeicher.nachtragen(
                playbook: playbook, antworten: fuhre, token: $0)
        }
        Uebungsvorrat.antwortenEntfernen(
            Set(nachtrag.ergebnisse.map(\.marke)), playbook: playbook)
        return nachtrag.ergebnisse.filter(\.gewertet).count
    }

    func lernstand(playbook: Int) async throws -> Modell.Lernstandsliste {
        try await mitToken {
            try await Uebungsspeicher.lernstand(playbook: playbook, token: $0)
        }
    }

    // --- Mannschaften, Kader, Zugänge (B9) --------------------------------
    //
    // Alles über `mitToken`, also mit dem einen Wiederholungsversuch. Das
    // ist hier nicht schmückend: Ein Head Coach, der in der Umkleide
    // einen Teamcode erzeugt und dabei abgemeldet wird, liest der
    // Mannschaft nichts vor.

    func teams() async throws -> [Modell.Mannschaft] {
        try await mitToken { try await Teamspeicher.liste(token: $0) }
    }

    func team(_ id: Int) async throws -> Modell.Mannschaft {
        try await mitToken { try await Teamspeicher.einzeln(team: id,
                                                            token: $0) }
    }

    func teamAnlegen(name: String, verein: Int?, farbe: String?,
                     spielform: String?) async throws
        -> Teamspeicher.Anlegen {
        try await mitToken {
            try await Teamspeicher.anlegen(name: name, verein: verein,
                                           farbe: farbe,
                                           spielform: spielform, token: $0)
        }
    }

    func teamAendern(_ id: Int, name: String, farbe: String,
                     spielform: String? = nil) async throws
        -> Modell.Mannschaft {
        try await mitToken {
            try await Teamspeicher.aendern(team: id, name: name, farbe: farbe,
                                           spielform: spielform, token: $0)
        }
    }

    /// Die Mannschaft löschen.
    ///
    /// Gibt nichts zurück, weil es danach nichts mehr gibt. Die Ansicht
    /// geht anschließend zurück in die Liste und lädt die neu.
    func teamLoeschen(_ id: Int) async throws {
        try await mitToken {
            try await Teamspeicher.loeschen(team: id, token: $0)
        }
    }

    // --- Das Vereinswappen (R30, Rest) ------------------------------------

    func vereinLogoSetzen(_ id: Int, bild: Data) async throws
        -> Vereinsspeicher.Wappenstand {
        try await mitToken {
            try await Vereinsspeicher.logoSetzen(verein: id, bild: bild,
                                                 token: $0)
        }
    }

    func vereinLogoEntfernen(_ id: Int) async throws
        -> Vereinsspeicher.Wappenstand {
        try await mitToken {
            try await Vereinsspeicher.logoEntfernen(verein: id, token: $0)
        }
    }

    /// Das Mannschaftslogo hochladen (R33).
    ///
    /// `bild` ist bereits verkleinert (`Bildpaket`). Über `mitToken`
    /// wie alles andere: Ein Head Coach, der zwanzig Sekunden auf ein
    /// Bild wartet und dabei abgemeldet wird, hält die App für kaputt.
    func teamLogoSetzen(_ id: Int, bild: Data) async throws
        -> Teamspeicher.Logostand {
        try await mitToken {
            try await Teamspeicher.logoSetzen(team: id, bild: bild, token: $0)
        }
    }

    func teamLogoEntfernen(_ id: Int) async throws -> Teamspeicher.Logostand {
        try await mitToken {
            try await Teamspeicher.logoEntfernen(team: id, token: $0)
        }
    }

    func rolleSetzen(mitglied: Int,
                     rolle: String) async throws -> Modell.Kaderergebnis {
        try await mitToken {
            try await Teamspeicher.rolleSetzen(mitglied: mitglied,
                                               rolle: rolle, token: $0)
        }
    }

    func nameImKaderSetzen(mitglied: Int,
                           name: String) async throws -> Modell.Kaderergebnis {
        try await mitToken {
            try await Teamspeicher.nameSetzen(mitglied: mitglied, name: name,
                                              token: $0)
        }
    }

    func mitgliedEntfernen(_ id: Int) async throws -> Modell.Kaderergebnis {
        try await mitToken {
            try await Teamspeicher.entfernen(mitglied: id, token: $0)
        }
    }

    func teamcodeAnlegen(team: Int,
                         haltbarkeit: String) async throws
        -> Modell.NeuerTeamcode {
        try await mitToken {
            try await Teamspeicher.teamcodeAnlegen(team: team,
                                                   haltbarkeit: haltbarkeit,
                                                   token: $0)
        }
    }

    func teamcodeAbschalten(team: Int) async throws -> Modell.Kaderergebnis {
        try await mitToken {
            try await Teamspeicher.teamcodeAbschalten(team: team, token: $0)
        }
    }

    func einladungAnlegen(team: Int, rolle: String,
                          tage: Int) async throws -> Modell.Einladung {
        try await mitToken {
            try await Teamspeicher.einladungAnlegen(team: team, rolle: rolle,
                                                    tage: tage, token: $0)
        }
    }

    func einladungWiderrufen(_ id: Int) async throws -> Modell.Kaderergebnis {
        try await mitToken {
            try await Teamspeicher.einladungWiderrufen(id, token: $0)
        }
    }

    func schluesselAnlegen(team: Int, name: String, bereich: String,
                           tage: Int) async throws -> Modell.Schluessel {
        try await mitToken {
            try await Teamspeicher.schluesselAnlegen(
                team: team, name: name, bereich: bereich, tage: tage,
                token: $0)
        }
    }

    func schluesselWiderrufen(_ id: Int) async throws
        -> Modell.Kaderergebnis {
        try await mitToken {
            try await Teamspeicher.schluesselWiderrufen(id, token: $0)
        }
    }

    func aufgabe(team: Int,
                 mitglied: Int) async throws -> Modell.Aufgabenblatt {
        try await mitToken {
            try await Teamspeicher.aufgabe(team: team, mitglied: mitglied,
                                           token: $0)
        }
    }

    func aufgabeSetzen(team: Int, mitglied: Int,
                       plays: [Int]) async throws -> Modell.Kaderergebnis {
        try await mitToken {
            try await Teamspeicher.aufgabeSetzen(team: team,
                                                 mitglied: mitglied,
                                                 plays: plays, token: $0)
        }
    }

    func codeAnsehen(_ code: String) async throws -> Modell.Codeauskunft {
        try await mitToken { try await Teamspeicher.codeAnsehen(code,
                                                                token: $0) }
    }

    func beitreten(code: String,
                   anzeigename: String) async throws -> Modell.Beitritt {
        try await mitToken {
            try await Teamspeicher.beitreten(code: code,
                                             anzeigename: anzeigename,
                                             token: $0)
        }
    }

    // --- Drucken (B10) ----------------------------------------------------

    // MARK: - Bibliothek (B11)

    /// Die Standardplays dieser Spielform, mit Zeichnung.
    ///
    /// „Die zehn" stand hier bis zum 07.09.2026. Seit T10 schickt der
    /// Server nur die Konzepte der jeweiligen Form: zehn im Flag, vier
    /// beim Elfer, zwei beim Neuner.
    func bibliothek(playbook: Int) async throws -> Modell.Bibliothek {
        try await holen("/api/v1/playbooks/\(playbook)/bibliothek/",
                        als: Modell.Bibliothek.self)
    }

    /// Die gewählten Konzepte ins Playbook übernehmen.
    ///
    /// Über denselben Weg wie der Browser (`uebernahme.py`): dieselbe
    /// Demo-Grenze, dieselbe Namensvergabe, dieselbe Reihenfolge. Was
    /// hier herauskommt, ist Play für Play dasselbe, und ein Test misst
    /// das gegeneinander.
    func bibliothekUebernehmen(playbook: Int, schluessel: [String])
        async throws -> Modell.Uebernommen {
        try await mitToken { token in
            let anfrage = try Server.anfrage(
                "/api/v1/playbooks/\(playbook)/bibliothek/", methode: "POST",
                rumpf: ["eintraege": schluessel], token: token)
            return try await Server.hole(anfrage, als: Modell.Uebernommen.self)
        }
    }

    func druckauskunft(playbook: Int) async throws -> Modell.Druckauskunft {
        try await mitToken {
            try await Druckspeicher.auskunft(playbook: playbook, token: $0)
        }
    }

    /// Eine Ausgabe abholen und als Datei ablegen.
    ///
    /// Über `mitToken`, also mit dem einen Wiederholungsversuch. Das ist
    /// hier nicht schmückend: Ein Bogen mit vierzig Playcards braucht
    /// auf dem Server Zeit, und wer in dieser Zeit abgemeldet wird,
    /// steht ohne Armband da.
    func druckdatei(_ wunsch: Druckwunsch, kennung: Int,
                    ersatzname: String) async throws -> Druckspeicher.Datei {
        try await mitToken {
            try await Druckspeicher.holen(wunsch, kennung: kennung,
                                          ersatzname: ersatzname, token: $0)
        }
    }

    /// Eine geänderte Zeichnung zurückschicken (B3).
    ///
    /// Läuft über dieselbe Tokenbehandlung wie das Lesen, samt dem einen
    /// Wiederholungsversuch: Ein Trainer, der zwanzig Minuten zeichnet
    /// und beim Sichern abgemeldet wird, hält die App für kaputt -- und
    /// hat seine Arbeit verloren.
    ///
    /// Das Ergebnis unterscheidet **gespeichert** von **Konflikt**. Ein
    /// 409 ist kein Fehler, sondern eine Nachricht: Jemand anderes war
    /// schneller, und dessen Arbeit gehört nicht überschrieben.
    /// `eigenschaften` trägt seit B7 die sechs Felder mit, die nicht die
    /// Zeichnung sind. Weggelassen heißt „unverändert", nicht „leer".
    func sichern(play: Int, zeichnung: Zeichnung, version: Int,
                 eigenschaften: Playspeicher.Eigenschaften
                     = Playspeicher.Eigenschaften())
        async throws -> Playspeicher.Ergebnis {
        do {
            return try await Playspeicher.sichern(
                play: play, zeichnung: zeichnung, version: version,
                eigenschaften: eigenschaften,
                token: try await anmeldung.gueltigesToken())
        } catch Server.Fehler.abgemeldet {
            return try await Playspeicher.sichern(
                play: play, zeichnung: zeichnung, version: version,
                eigenschaften: eigenschaften,
                token: try await anmeldung.gueltigesToken())
        }
    }

    /// Das Schloss am Play umlegen (R6).
    func sperre(play: Int, gesperrt: Bool) async throws -> Modell.Sperrstand {
        try await mitToken { token in
            try await Playspeicher.sperre(play: play, gesperrt: gesperrt,
                                          token: token)
        }
    }
}
