// Mannschaften verwalten (B9): Kader, Zugänge, Teamcode, Einladungen,
// Schlüssel, Lernauftrag.
//
// WARUM DAS NEBEN `Heftspeicher` UND `Kategoriespeicher` STEHT. Es ist
// dieselbe Art Datei, aber ein anderes Thema: Hier geht es nie um einen
// Play, sondern immer um einen Menschen und um einen Zugang. Die
// schwierige Stelle ist auch eine andere -- der letzte Head Coach, der
// bleiben muss, und der Klartext eines Schlüssels, den es genau einmal
// gibt.
//
// WAS HIER NICHT PASSIERT: Es wird nie entschieden, ob jemand etwas
// darf. Das sagt der Server (ADR-0006), und zwar mit denselben
// Funktionen, die auch die Webseite fragt.

import Foundation

/// Mannschaften über die Schnittstelle.
enum Teamspeicher {

    static func liste(token: String) async throws -> [Modell.Mannschaft] {
        try await Server.hole(
            Server.anfrage("/api/v1/teams/", token: token),
            als: Modell.MannschaftsListe.self).teams
    }

    static func einzeln(team: Int,
                        token: String) async throws -> Modell.Mannschaft {
        try await Server.hole(
            Server.anfrage("/api/v1/teams/\(team)/", token: token),
            als: Modell.Mannschaft.self)
    }

    /// Eine Mannschaft anlegen. Wer sie anlegt, wird Head Coach.
    ///
    /// `verein` darf fehlen: Dann nimmt der Server den einzigen, den
    /// diese Person führt -- und wenn es keinen gibt, legt er einen
    /// gleichnamigen an. Diese Entscheidung trifft der Server und nicht
    /// die App: An ihr hängen die Grenzen der Demo.
    /// Was beim Anlegen herauskommt -- oder warum nicht.
    ///
    /// **Die Demo darf seit dem 10.09.2026 EINE Mannschaft**
    /// (`grenzen.demo_teams`). Vorher war sie unbegrenzt, und der
    /// Server hatte deshalb an dieser Stelle gar keinen Grenzfall;
    /// er wäre in der App als 500 angekommen, also als Fehler des
    /// Programms statt als Grenze der Demo.
    ///
    /// Dasselbe Muster wie bei Playbooks und Plays
    /// (`Heftspeicher.Anlegen`): Der Satz kommt vom SERVER -- was die
    /// Demo hergibt und was ein Abo kostet, weiß er, nicht die App --
    /// und der Vorschlag kommt mit, damit die Absage keine Sackgasse
    /// ist.
    enum Anlegen {
        case angelegt(Modell.Mannschaft)
        case grenze(text: String, abo: Modell.Abo?)
    }

    static func anlegen(name: String, verein: Int?, farbe: String?,
                        spielform: String? = nil,
                        token: String) async throws -> Anlegen {
        var rumpf: [String: Any] = ["name": name]
        if let verein { rumpf["verein"] = verein }
        if let farbe { rumpf["farbe"] = farbe }
        // OHNE ANGABE MACHT DER SERVER FLAG DARAUS, und genau das war
        // der Fehler: Die App legte Mannschaften an, ohne je nach der
        // Spielform zu fragen. Wer sie „TackleStrelitz" nannte, bekam
        // trotzdem ein Flagfeld -- ohne Meldung, weil nichts kaputt war.
        if let spielform { rumpf["spielform"] = spielform }
        let anfrage = try Server.anfrage(
            "/api/v1/teams/", methode: "POST", rumpf: rumpf, token: token)
        do {
            let (daten, _) = try await Server.ausfuehren(anfrage)
            return .angelegt(try Server.entschluessler.decode(
                Modell.Mannschaft.self, from: daten))
        } catch Server.Fehler.server(let text, let lage, let rumpf)
            where lage == 403 {
            return .grenze(text: text, abo: Modell.Abo.ausAbsage(rumpf))
        }
    }

    /// Name und Farbe ändern. **Kein Logo** -- ein Bild geht nicht durch
    /// ein JSON-Feld, und ein Umweg über base64 wäre eine zweite Art,
    /// Dateien hochzuladen.
    static func aendern(team: Int, name: String, farbe: String,
                        spielform: String? = nil,
                        token: String) async throws -> Modell.Mannschaft {
        var rumpf: [String: Any] = ["name": name, "farbe": farbe]
        // NUR WENN JEMAND DANACH GEFRAGT HAT. Der Server ändert die
        // Spielform genau dann, wenn der Schlüssel im Rumpf steht --
        // sonst rührt er sie nicht an. Ein festes `rumpf["spielform"]`
        // wäre hier dasselbe wie ein PUT und schriebe bei jedem
        // Umbenennen etwas, das niemand angefasst hat.
        if let spielform { rumpf["spielform"] = spielform }
        return try await Server.hole(
            Server.anfrage("/api/v1/teams/\(team)/", methode: "PATCH",
                           rumpf: rumpf, token: token),
            als: Modell.Mannschaft.self)
    }

    /// Die Mannschaft löschen -- mit allem, was daran hängt.
    ///
    /// Niklas am 08.09.2026: „man sollte übrigens wenn man auf
    /// mannschaft geht auch die möglichkeit haben eine mannschaft zu
    /// löschen sowohl in app als auch im web."
    ///
    /// Die Rückfrage steht in der Ansicht und nicht hier: Wer den Namen
    /// abtippt, hat gelesen, was verloren geht. Diese Funktion tut es
    /// dann ohne weitere Frage -- ein zweites „bist du sicher" an
    /// dieser Stelle wäre eine Sicherheit, die keine ist.
    static func loeschen(team: Int, token: String) async throws {
        try await Server.ausfuehren(
            Server.anfrage("/api/v1/teams/\(team)/", methode: "DELETE",
                           token: token))
    }

    // --- Das Logo (R33) ---------------------------------------------------
    //
    // Niklas am 28.08.2026: „Auch in der App vochladbar soll es sein."
    // Bis dahin stand in der App der Satz, dass das nur im Browser
    // geht. Das war richtig, solange es keine Adresse dafür gab.

    /// Die Antwort des Servers: die vollständige Adresse des Bildes.
    ///
    /// `nil` nach dem Entfernen. Ein eigener Typ und kein nacktes
    /// `String?`, damit `Server.hole` etwas zu entschlüsseln hat und
    /// die Antwort denselben Weg geht wie jede andere.
    struct Logostand: Decodable {
        let logo: String?
    }

    static func logoSetzen(team: Int, bild: Data, token: String)
        async throws -> Logostand {
        try await Server.hole(
            Server.anfrageMitDatei(
                "/api/v1/teams/\(team)/logo/", feld: "logo", daten: bild,
                // Der Name steht im Formular und landet auf der Platte.
                // `logo.png` und nicht der Name aus der Mediathek: Der
                // hieße `IMG_4711.HEIC` und sagte über das Bild nichts,
                // wohl aber darüber, wie viele Fotos jemand gemacht hat.
                dateiname: "logo.png", typ: "image/png", token: token),
            als: Logostand.self)
    }

    static func logoEntfernen(team: Int, token: String)
        async throws -> Logostand {
        try await Server.hole(
            Server.anfrage("/api/v1/teams/\(team)/logo/", methode: "DELETE",
                           token: token),
            als: Logostand.self)
    }

    // --- Kader ------------------------------------------------------------

    static func rolleSetzen(mitglied: Int, rolle: String,
                            token: String) async throws
        -> Modell.Kaderergebnis {
        try await Server.hole(
            Server.anfrage("/api/v1/mitgliedschaften/\(mitglied)/",
                           methode: "PATCH", rumpf: ["rolle": rolle],
                           token: token),
            als: Modell.Kaderergebnis.self)
    }

    /// Den Namen im Kader berichtigen (A5, A6).
    ///
    /// Leeren geht nicht, und das ist keine Bequemlichkeit: Leer heißt
    /// in der Datenbank „nie gefragt worden", und das lässt sich nicht
    /// nachträglich behaupten. Der Server weist es mit 400 ab.
    static func nameSetzen(mitglied: Int, name: String,
                           token: String) async throws
        -> Modell.Kaderergebnis {
        try await Server.hole(
            Server.anfrage("/api/v1/mitgliedschaften/\(mitglied)/",
                           methode: "PATCH", rumpf: ["anzeigename": name],
                           token: token),
            als: Modell.Kaderergebnis.self)
    }

    static func entfernen(mitglied: Int, token: String) async throws
        -> Modell.Kaderergebnis {
        try await Server.hole(
            Server.anfrage("/api/v1/mitgliedschaften/\(mitglied)/",
                           methode: "DELETE", token: token),
            als: Modell.Kaderergebnis.self)
    }

    // --- Teamcode ---------------------------------------------------------

    /// Einen Code erzeugen. **Ersetzt einen vorhandenen**, und das ist
    /// kein Nebeneffekt: Eine Mannschaft hat eine Tür, und ein neuer
    /// Schlüssel sperrt den alten aus.
    static func teamcodeAnlegen(team: Int, haltbarkeit: String,
                                token: String) async throws
        -> Modell.NeuerTeamcode {
        try await Server.hole(
            Server.anfrage("/api/v1/teams/\(team)/teamcode/",
                           methode: "POST",
                           rumpf: ["haltbarkeit": haltbarkeit],
                           token: token),
            als: Modell.NeuerTeamcode.self)
    }

    static func teamcodeAbschalten(team: Int, token: String) async throws
        -> Modell.Kaderergebnis {
        try await Server.hole(
            Server.anfrage("/api/v1/teams/\(team)/teamcode/",
                           methode: "DELETE", token: token),
            als: Modell.Kaderergebnis.self)
    }

    // --- Einladungen und Schlüssel ----------------------------------------

    static func einladungAnlegen(team: Int, rolle: String, tage: Int,
                                 token: String) async throws
        -> Modell.Einladung {
        try await Server.hole(
            Server.anfrage("/api/v1/teams/\(team)/einladungen/",
                           methode: "POST",
                           rumpf: ["rolle": rolle, "tage": tage],
                           token: token),
            als: Modell.Einladung.self)
    }

    static func einladungWiderrufen(_ id: Int, token: String) async throws
        -> Modell.Kaderergebnis {
        try await Server.hole(
            Server.anfrage("/api/v1/einladungen/\(id)/", methode: "DELETE",
                           token: token),
            als: Modell.Kaderergebnis.self)
    }

    /// Einen Maschinenschlüssel anlegen. Der Klartext steht **genau in
    /// dieser Antwort** und danach nirgends mehr, auch nicht auf dem
    /// Server.
    static func schluesselAnlegen(team: Int, name: String, bereich: String,
                                  tage: Int, token: String) async throws
        -> Modell.Schluessel {
        try await Server.hole(
            Server.anfrage("/api/v1/teams/\(team)/schluessel/",
                           methode: "POST",
                           rumpf: ["name": name, "bereich": bereich,
                                   "tage": tage],
                           token: token),
            als: Modell.Schluessel.self)
    }

    static func schluesselWiderrufen(_ id: Int, token: String) async throws
        -> Modell.Kaderergebnis {
        try await Server.hole(
            Server.anfrage("/api/v1/schluessel/\(id)/", methode: "DELETE",
                           token: token),
            als: Modell.Kaderergebnis.self)
    }

    // --- Lernauftrag ------------------------------------------------------

    static func aufgabe(team: Int, mitglied: Int, token: String) async throws
        -> Modell.Aufgabenblatt {
        try await Server.hole(
            Server.anfrage("/api/v1/teams/\(team)/aufgabe/\(mitglied)/",
                           token: token),
            als: Modell.Aufgabenblatt.self)
    }

    /// **`PUT` und die ganze Liste.** Was nicht mitkommt, ist nicht mehr
    /// aufgegeben -- ein `PATCH` hieße „das hier dazu", und dann würde
    /// niemand eine Aufgabe je wieder los.
    static func aufgabeSetzen(team: Int, mitglied: Int, plays: [Int],
                              token: String) async throws
        -> Modell.Kaderergebnis {
        try await Server.hole(
            Server.anfrage("/api/v1/teams/\(team)/aufgabe/\(mitglied)/",
                           methode: "PUT", rumpf: ["plays": plays],
                           token: token),
            als: Modell.Kaderergebnis.self)
    }

    // --- Beitreten --------------------------------------------------------

    /// Was hinter einem Code steckt -- **ohne beizutreten**.
    ///
    /// Zwei Adressen für zwei Handlungen, genau wie im Browser: Ein Code
    /// allein tritt niemandem bei. Wer beitritt, steht danach im Kader
    /// eines fremden Vereins, und das darf kein Nebeneffekt des
    /// Nachsehens sein.
    static func codeAnsehen(_ code: String, token: String) async throws
        -> Modell.Codeauskunft {
        try await Server.hole(
            Server.anfrage("/api/v1/beitreten/\(code)/", token: token),
            als: Modell.Codeauskunft.self)
    }

    /// Beitreten -- mit Namen. Ohne gültigen Namen entsteht keine
    /// Mitgliedschaft (A5); der Server prüft ihn vor dem Einlösen.
    static func beitreten(code: String, anzeigename: String,
                          token: String) async throws -> Modell.Beitritt {
        try await Server.hole(
            Server.anfrage("/api/v1/beitreten/", methode: "POST",
                           rumpf: ["code": code, "anzeigename": anzeigename],
                           token: token),
            als: Modell.Beitritt.self)
    }
}
