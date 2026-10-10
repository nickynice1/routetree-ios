// Ein Konto anlegen -- mit eigenem Verein oder mit einem Teamcode (B12).
//
// WARUM DAS NEBEN `Anmeldung` STEHT UND NICHT DARIN. `Anmeldung` hat
// genau eine Aufgabe: zu wissen, wer angemeldet ist, und die Token über
// Neustarts hinweg zu behalten. Hier geht es um Formulare, um Absagen an
// einzelnen Feldern und um zwei sehr verschiedene Wege herein. Eine
// Datei mit beidem hätte zwei Themen und keins davon klar.
//
// DIE TOKEN LANDEN TROTZDEM NUR AN EINER STELLE. Diese Datei gibt das
// Paar zurück, `Anmeldung.uebernehmen` legt es weg. Wer angemeldet ist,
// entscheidet `Anmeldung` und sonst niemand -- sonst gäbe es zwei
// Stellen, an denen die App „ja, drin" sagen kann, und eine davon
// vergisst den Schlüsselbund.

import Foundation

/// Registrieren und Beitreten über die Schnittstelle.
enum Konten {

    /// Eine Absage des Servers, mit den Sätzen an ihren Feldern.
    ///
    /// **Warum das nicht `Server.Fehler` ist.** Der trägt einen Satz.
    /// Ein Registrierformular hat acht Felder, und ein Satz ohne Feld
    /// steht am Ende über dem ersten -- also meistens über einem, das in
    /// Ordnung ist. Der Mensch ändert dann das Falsche und probiert es
    /// noch einmal.
    struct Absage: LocalizedError {
        /// Der erste Satz, für die Zeile über dem Formular.
        let text: String
        /// Je Feldname die Sätze dazu. Die Namen sind die der
        /// Schnittstelle (`benutzername`), nicht die von Django.
        let felder: [String: [String]]

        var errorDescription: String? { text }

        /// Aus dem Rumpf einer 400er-Antwort. `nil`, wenn nichts
        /// Lesbares darinsteht -- dann bleibt es beim Fehler des Servers.
        static func aus(_ rumpf: Data?, text: String) -> Absage? {
            guard let rumpf,
                  let objekt = try? JSONSerialization.jsonObject(with: rumpf)
                    as? [String: Any],
                  let felder = objekt["felder"] as? [String: [String]]
            else { return nil }
            return Absage(text: text, felder: felder)
        }
    }

    // MARK: - Auskunft

    /// Was die App wissen muss, BEVOR jemand tippt.
    ///
    /// Ohne Token: Wer sich registrieren will, hat noch keins.
    static func auskunft() async throws -> Modell.Registrierauskunft {
        try await Server.hole(Server.anfrage("/api/v1/registrieren/"),
                              als: Modell.Registrierauskunft.self)
    }

    /// Was ein Teamcode fragt -- ebenfalls OHNE Token (R24).
    ///
    /// **Die Lücke, die R24 hinterlassen hat.** In `BeitretenNeuAnsicht`
    /// stand als Begründung, `codeAnsehen` verlange eine Anmeldung, die
    /// es auf diesem Blatt noch nicht gibt. Das stimmte -- war aber eine
    /// Grenze der Schnittstelle und keine Entscheidung: Im Browser
    /// beantwortet dieselbe Seite die Frage seit jeher ohne Anmeldung.
    /// Die App fragte deshalb in einer Schulmannschaft nach einem Namen,
    /// den dort niemand angeben muss.
    ///
    /// Zurück kommt dieselbe `Codeauskunft` wie bei `codeAnsehen`, nur
    /// ohne die Felder, die an einem Konto hängen -- `schonDabei` steht
    /// dann auf `false` und `namensvorschlag` ist leer, und beides ist
    /// genau richtig für ein Blatt, auf dem es noch kein Konto gibt.
    static func codeVorschau(_ code: String) async throws
        -> Modell.Codeauskunft {
        try await Server.hole(
            Server.anfrage("/api/v1/beitreten/vorschau/\(code)/"),
            als: Modell.Codeauskunft.self)
    }

    // MARK: - Registrieren

    /// Konto, Verein und erste Mannschaft anlegen.
    ///
    /// Zurück kommen das Tokenpaar und das, was entstanden ist. Wer sich
    /// gerade registriert hat, soll nicht als Nächstes eine
    /// Anmeldemaske sehen: Er hat sein Passwort vor zwei Sekunden
    /// vergeben.
    static func registrieren(
        verein: String, mannschaft: String, vorname: String,
        nachname: String, email: String, benutzername: String,
        passwort: String, wiederholung: String, geraet: String
    ) async throws -> (Anmeldung.Tokenpaar, Modell.Neuanmeldung) {
        try await anlegen("/api/v1/registrieren/", rumpf: [
            "verein": verein, "mannschaft": mannschaft,
            "vorname": vorname, "nachname": nachname, "email": email,
            "benutzername": benutzername, "passwort": passwort,
            "passwort_wiederholung": wiederholung, "geraet": geraet,
        ])
    }

    /// Konto anlegen und mit einem Teamcode in einem Schritt beitreten.
    ///
    /// Der Weg für den, der den Code in der Mannschaftsgruppe bekommen
    /// hat und kein Konto besitzt. Ohne ihn ist der Teamcode in der App
    /// für genau die Hälfte der Leute wertlos, für die er gedacht ist.
    static func beitretenMitKonto(
        code: String, anzeigename: String, benutzername: String,
        passwort: String, wiederholung: String, geraet: String
    ) async throws -> (Anmeldung.Tokenpaar, Modell.Neubeitritt) {
        try await anlegen("/api/v1/beitreten/konto/", rumpf: [
            "code": code, "anzeigename": anzeigename,
            "benutzername": benutzername, "passwort": passwort,
            "passwort_wiederholung": wiederholung, "geraet": geraet,
        ])
    }

    /// Beide Wege herein, an einer Stelle.
    ///
    /// Sie unterscheiden sich in der Adresse und im Rumpf, sonst in
    /// nichts: Beide legen ein Konto an, beide melden mit 201, beide
    /// antworten mit einem Tokenpaar und einer Absage an Feldern. Zwei
    /// Fassungen wären zwei Gelegenheiten, die Absage zu verlieren.
    ///
    /// **Zweimal entschlüsselt, absichtlich.** Dieselben Bytes werden
    /// einmal als Tokenpaar und einmal als Ergebnis gelesen. Ein Modell,
    /// das beides trägt, müsste die vier Tokenfelder ein zweites Mal
    /// aufzählen -- und `Anmeldung` bekäme etwas anderes zu sehen als
    /// beim gewöhnlichen Anmelden.
    private static func anlegen<T: Decodable>(
        _ weg: String, rumpf: [String: Any]
    ) async throws -> (Anmeldung.Tokenpaar, T) {
        let anfrage = try Server.anfrage(weg, methode: "POST", rumpf: rumpf)
        do {
            let (daten, _) = try await Server.ausfuehren(anfrage)
            let paar = try Server.entschluessler.decode(
                Anmeldung.Tokenpaar.self, from: daten)
            return (paar, try Server.entschluessler.decode(T.self, from: daten))
        } catch Server.Fehler.server(let text, let lage, let antwort) {
            // Die Bremse kommt als 429 und damit gar nicht hier an --
            // sie bleibt `Server.Fehler.gebremst`, samt Wartezeit. Das
            // ist der Unterschied, der dem Menschen sagt, dass Warten
            // hilft und ein anderer Benutzername nicht.
            //
            // `lage` wird DURCHGEREICHT und nicht auf 400 gesetzt: Ein
            // falscher Teamcode ist 404 und ein zugesperrter Weg 403,
            // und beide tragen keine Felder. Wer hier 400 hinschreibt,
            // macht aus „diesen Code gibt es nicht" ein Formularproblem.
            if let absage = Absage.aus(antwort, text: text) { throw absage }
            throw Server.Fehler.server(text: text, lage: lage, rumpf: antwort)
        }
    }
}

/// Die eigenen Kontodaten ändern (R100).
///
/// Niklas am 09.09.2026: „Kontodaten sollten änderbar sein."
///
/// **Was sich ändern lässt und was nicht.** Name und Mailadresse ja, der
/// Benutzername nicht. Er steht an Einladungen, in Protokolleinträgen
/// und in den Anzeigenamen der Kader; ihn zu ändern hiesse, eine Spur
/// umzuschreiben, die es zum Nachvollziehen gibt.
///
/// **Und warum die Adresse hier nicht sofort gilt.** An ihr hängt das
/// Zurücksetzen des Passworts. Der Server setzt sie deshalb erst, wenn
/// ein Link geöffnet wurde, der an die NEUE Adresse ging -- und schickt
/// der alten einen Hinweis darüber. Ein kürzerer Weg für die App wäre
/// eine zweite Sicherheitsregel, und die schwächere setzt sich am Ende
/// durch.
///
/// Deshalb trägt die Antwort `bestaetigungUnterwegs`: Ohne diese Angabe
/// zeigte die App die alte Adresse und keinen Hinweis, warum die neue
/// nicht dasteht -- das sähe aus wie ein Programm, das nichts getan hat.
enum Kontodaten {

    struct Stand: Decodable {
        let benutzername: String
        let vorname: String
        let nachname: String
        let email: String
        /// Die Adresse, auf deren Bestätigung gewartet wird -- leer,
        /// wenn keine unterwegs ist.
        let bestaetigungUnterwegs: String

        enum CodingKeys: String, CodingKey {
            case benutzername, vorname, nachname, email
            case bestaetigungUnterwegs = "bestaetigung_unterwegs"
        }

        /// Wie dieser Mensch anderen gegenüber heisst (R143).
        ///
        /// **Gebraucht für die Schlüsselübergabe per Funk**: Der Coach
        /// liest eine Liste von Telefonen in Reichweite und muss darin
        /// seine Spieler erkennen. Der Gerätename hilft nicht -- seit
        /// iOS 16 heissen alle „iPhone" (siehe `funkname`).
        ///
        /// **Rückfall auf den Anmeldenamen und nicht auf „Unbenannt".**
        /// Wer seinen Namen nie eingetragen hat, ist unter seinem
        /// Anmeldenamen immer noch wiedererkennbar; „Unbenannt" wäre
        /// für den Coach dasselbe Problem wie zwölfmal „iPhone".
        var anzeigename: String {
            let voll = "\(vorname) \(nachname)"
                .trimmingCharacters(in: .whitespaces)
            return voll.isEmpty ? benutzername : voll
        }
    }

    /// Schickt nur, was sich ändern soll.
    ///
    /// **`nil` heisst „nicht anfassen" und nicht „leeren".** Wer nur die
    /// Adresse ändert, soll dabei nicht seinen Namen verlieren -- und
    /// ein leerer String ist ein gültiger Name.
    static func setzen(vorname: String? = nil, nachname: String? = nil,
                       email: String? = nil, token: String) async throws
        -> Stand {
        var rumpf: [String: Any] = [:]
        if let vorname { rumpf["vorname"] = vorname }
        if let nachname { rumpf["nachname"] = nachname }
        if let email { rumpf["email"] = email }
        return try await Server.hole(
            Server.anfrage("/api/v1/konto/daten/", methode: "PATCH",
                           rumpf: rumpf, token: token),
            als: Stand.self)
    }
}
