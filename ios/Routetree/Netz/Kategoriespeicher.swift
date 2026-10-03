// Kategorien und Formationen verwalten (B7).
//
// WARUM DAS NEBEN `Heftspeicher` STEHT UND NICHT DARIN. Der
// `Heftspeicher` hat zwei schwierige Stellen: die Grenze der Demo beim
// Anlegen und die Frage, was mit den Nummern passiert. Hier sind es
// andere -- ein Name, den es schon gibt, ist kein Fehler, und eine
// Reihenfolge muss VOLLSTÄNDIG sein. Eine Datei mit beidem hätte vier
// Themen und keins davon klar.
//
// WAS HIER NICHT PASSIERT: Es wird nie entschieden, ob jemand etwas
// darf. Das sagt der Server (ADR-0006). Und es wird nie entschieden, ob
// eine Farbe taugt -- das sagt `Farbwert`, gemessen gegen denselben
// Server.

import Foundation

/// Kategorien über die Schnittstelle.
enum Kategoriespeicher {

    /// Was beim Anlegen herauskommt.
    ///
    /// **`schonDa` ist kein Fehler.** Zweimal dieselbe Kategorie
    /// anzulegen ist eine Wiederholung, keine Verfehlung: Der Server
    /// gibt die vorhandene zurück, und die App sagt es, statt eine rote
    /// Meldung zu zeigen. Wer den Namen wirklich zum zweiten Mal
    /// braucht, hätte ihn auch beim dritten Versuch nicht bekommen.
    enum Anlegen {
        case angelegt(Modell.Kategorie)
        case schonDa(Modell.Kategorie)
    }

    private struct Angelegt: Decodable {
        let id: Int
        let name: String
        let farbe: String
        let position: Int
        let schonDa: Bool

        enum CodingKeys: String, CodingKey {
            case id, name, farbe, position
            case schonDa = "schon_da"
        }

        var alsKategorie: Modell.Kategorie {
            Modell.Kategorie(id: id, name: name, farbe: farbe,
                             position: position)
        }
    }

    static func anlegen(playbook: Int, name: String, farbe: String,
                        token: String) async throws -> Anlegen {
        let antwort = try await Server.hole(
            Server.anfrage("/api/v1/playbooks/\(playbook)/kategorien/",
                           methode: "POST",
                           rumpf: ["name": name, "farbe": farbe],
                           token: token),
            als: Angelegt.self)
        return antwort.schonDa
            ? .schonDa(antwort.alsKategorie)
            : .angelegt(antwort.alsKategorie)
    }

    /// Name und Farbe ändern.
    ///
    /// `PATCH` und nicht `PUT`: Ein weggelassenes Feld bleibt stehen.
    /// Beide gehen hier trotzdem immer mit, weil das Blatt in der App
    /// beide zeigt -- aber die Adresse muss das aushalten, sonst löschte
    /// ein späteres „nur die Farbe" den Namen.
    static func aendern(kategorie: Int, name: String, farbe: String,
                        token: String) async throws -> Modell.Kategorie {
        try await Server.hole(
            Server.anfrage("/api/v1/kategorien/\(kategorie)/",
                           methode: "PATCH",
                           rumpf: ["name": name, "farbe": farbe],
                           token: token),
            als: Modell.Kategorie.self)
    }

    /// Was beim Entfernen herauskommt.
    ///
    /// Die Zahl der betroffenen Plays gehört dazu. Ein Trainer, der „Red
    /// Zone" mit vierzehn Plays entfernt, soll die Zahl sehen und nicht
    /// suchen müssen, wo sie geblieben sind -- sie stehen alle noch da,
    /// nur ohne Kategorie.
    struct Geloescht: Decodable {
        let geloescht: String
        let playsOhneKategorie: Int

        enum CodingKeys: String, CodingKey {
            case geloescht
            case playsOhneKategorie = "plays_ohne_kategorie"
        }
    }

    static func loeschen(kategorie: Int,
                         token: String) async throws -> Geloescht {
        try await Server.hole(
            Server.anfrage("/api/v1/kategorien/\(kategorie)/",
                           methode: "DELETE", token: token),
            als: Geloescht.self)
    }

    /// Die neue Reihenfolge sichern.
    ///
    /// **Immer die ganze Liste.** Anders als bei den Plays, wo eine
    /// gefilterte Auswahl umsortiert werden darf: Die Wristcoach-Einlage
    /// läuft die Kategorien von oben nach unten ab, und eine Teilliste
    /// ließe den Rest auf Plätzen, die auf keinem Bildschirm stehen. Der
    /// Server weist sie mit 400 ab, und das ist richtig so.
    static func reihenfolgeSichern(playbook: Int, kennungen: [Int],
                                   token: String) async throws
        -> [Modell.Kategorie] {
        try await Server.hole(
            Server.anfrage(
                "/api/v1/playbooks/\(playbook)/kategorien/reihenfolge/",
                methode: "POST", rumpf: ["kategorien": kennungen],
                token: token),
            als: Modell.KategorienListe.self).kategorien
    }
}

/// Formationen über die Schnittstelle.
enum Formationsspeicher {

    /// Was beim Sichern herauskommt.
    ///
    /// **`ersetzt` ist kein Fehler, sondern eine Auskunft.** Der Server
    /// legt unter demselben Namen keine zweite Formation an, sondern
    /// überschreibt die vorhandene -- genau wie im Browser. Wer das
    /// nicht wollte, muss es erfahren: „Neu gesichert" und „ersetzt"
    /// sind zwei verschiedene Nachrichten.
    struct Gesichert: Decodable {
        let id: Int
        let name: String
        let anzahl: Int
        let ersetzt: Bool
    }

    static func sichern(playbook: Int, name: String,
                        aufstellung: [Zeichnung.Spieler],
                        token: String) async throws -> Gesichert {
        // Über denselben Verschlüssler wie beim Sichern einer Zeichnung:
        // Die Spielerliste muss beim Server ankommen, wie `schema.py`
        // sie erwartet, und eine zweite Verpackung liefe irgendwann
        // auseinander.
        let daten = try JSONEncoder().encode(aufstellung)
        guard let liste = try JSONSerialization.jsonObject(with: daten)
                as? [Any] else {
            throw Server.Fehler.server(
                text: String(localized:
                    "Die Aufstellung ließ sich nicht verpacken."),
                lage: 0, rumpf: nil)
        }
        return try await Server.hole(
            Server.anfrage("/api/v1/playbooks/\(playbook)/formationen/",
                           methode: "POST",
                           rumpf: ["name": name, "players": liste],
                           token: token),
            als: Gesichert.self)
    }

    static func umbenennen(formation: Int, name: String,
                           token: String) async throws -> Modell.Formation {
        try await Server.hole(
            Server.anfrage("/api/v1/formationen/\(formation)/",
                           methode: "PATCH", rumpf: ["name": name],
                           token: token),
            als: Modell.Formation.self)
    }

    static func loeschen(formation: Int, token: String) async throws {
        try await Server.ausfuehren(
            Server.anfrage("/api/v1/formationen/\(formation)/",
                           methode: "DELETE", token: token))
    }
}

/// Einen Play einer Kategorie zuordnen (B7).
///
/// Beim `Playspeicher`, weil es dieselbe Adresse und denselben
/// Konfliktschutz betrifft wie das Umbenennen: Ein `PUT` schickt die
/// gelesene Fassung mit, und stimmt sie nicht mehr, antwortet der Server
/// mit 409 statt zu überschreiben.
extension Playspeicher {

    /// Setzt die Kategorie -- oder nimmt sie weg (`nil`).
    ///
    /// **Ohne `zeichnung` im Rumpf, und das ist wichtig.** Der Server
    /// lässt jedes Feld stehen, das nicht mitkommt. Wer hier die
    /// Zeichnung aus der Liste mitschickte, hätte keine, und ein
    /// Einordnen leerte den Play.
    ///
    /// `NSNull` und nicht „Schlüssel weglassen": Weglassen hieße „keine
    /// Meinung", und dann bliebe die alte Kategorie stehen. Gemeint ist
    /// hier aber ausdrücklich „ohne Kategorie".
    static func kategorieSetzen(play: Int, kategorie: Int?, version: Int,
                                token: String) async throws -> Ergebnis {
        let wert: Any = kategorie.map { $0 as Any } ?? NSNull()
        let anfrage = try Server.anfrage(
            "/api/v1/plays/\(play)/", methode: "PUT",
            rumpf: ["kategorie": wert, "version": version],
            token: token)
        do {
            let antwort = try await Server.hole(anfrage,
                                                als: Modell.PlayVoll.self)
            return .gespeichert(version: antwort.version,
                                anmerkungen: antwort.anmerkungen)
        } catch Server.Fehler.server(_, let lage, _) where lage == 409 {
            let fremd = try await Server.hole(
                Server.anfrage("/api/v1/plays/\(play)/", token: token),
                als: Modell.PlayVoll.self)
            return .konflikt(fremd: fremd)
        }
    }
}
