// Playbooks anlegen, umbenennen, löschen -- und Plays ordnen (B6).
//
// WARUM DAS NEBEN `Playspeicher` STEHT UND NICHT DARIN. Der `Playspeicher`
// hat genau eine schwierige Stelle: den Konflikt beim Sichern einer
// Zeichnung. Hier sind es andere -- die Grenze der Demo beim Anlegen und
// die Frage, was mit den Nummern passiert. Eine Datei mit beidem hätte
// zwei Themen und keins davon klar.
//
// WAS HIER NICHT PASSIERT: Es wird nie entschieden, ob jemand etwas darf.
// Das sagt der Server (ADR-0006), und er sagt es zweimal: in
// `darf_aendern`/`darf_loeschen` an jedem Heft, damit die App keinen
// toten Knopf zeigt, und beim Versuch selbst.

import Foundation

/// Anlegen und Ordnen über die Schnittstelle.
enum Heftspeicher {

    /// Was beim Anlegen herauskommt.
    ///
    /// Getrennt vom Fehler, weil die Grenze der Demo keiner ist: Sie ist
    /// eine Nachricht, und in ihr steckt der Abo-Vorschlag (A2, A3).
    enum Anlegen {
        case angelegt(Modell.Playbook)
        /// Die Demo ist am Ende. `text` ist der Satz des SERVERS -- was
        /// die Demo hergibt und was ein Abo kostet, weiß er, nicht die
        /// App.
        ///
        /// Seit B12 kommt der Vorschlag mit (siehe `Playspeicher`).
        /// `nil` heißt „nicht mitgeschickt", nicht „gibt es nicht".
        case grenze(text: String, abo: Modell.Abo?)
    }

    static func anlegen(team: Int, name: String, saison: String,
                        feldformat: String, kategorien: Bool,
                        token: String) async throws -> Anlegen {
        let anfrage = try Server.anfrage(
            "/api/v1/playbooks/", methode: "POST",
            rumpf: ["team": team, "name": name, "saison": saison,
                    "feldformat": feldformat, "kategorien": kategorien],
            token: token)
        do {
            let (daten, _) = try await Server.ausfuehren(anfrage)
            return .angelegt(try Server.entschluessler.decode(
                Modell.Playbook.self, from: daten))
        } catch Server.Fehler.server(let text, let lage, let rumpf)
            where lage == 403 {
            return .grenze(text: text, abo: Modell.Abo.ausAbsage(rumpf))
        }
    }

    /// Name, Saison und Notizen ändern.
    ///
    /// `PATCH` und nicht `PUT`: Ein weggelassenes Feld bleibt stehen.
    /// Bei `PUT` löschte ein Umbenennen die Notizen mit.
    static func aendern(playbook: Int, name: String, saison: String,
                        hinweise: String,
                        token: String) async throws -> Modell.Playbook {
        try await Server.hole(
            Server.anfrage("/api/v1/playbooks/\(playbook)/", methode: "PATCH",
                           rumpf: ["name": name, "saison": saison,
                                   "hinweise": hinweise],
                           token: token),
            als: Modell.Playbook.self)
    }

    static func loeschen(playbook: Int, token: String) async throws {
        try await Server.ausfuehren(
            Server.anfrage("/api/v1/playbooks/\(playbook)/",
                           methode: "DELETE", token: token))
    }

    /// Die neue Reihenfolge sichern.
    ///
    /// Zurück kommen die Nummern, wie sie NACHHER stehen. Sie werden
    /// gebraucht, auch wenn die App sie vorher schon gerechnet hat:
    /// `Ordnen` ist die Vorschau, dies hier ist, was passiert ist. Wer
    /// die Vorschau stehen ließe, zeigte nach einem halb
    /// durchgekommenen Sichern etwas, das es nicht gibt.
    struct NeueNummer: Decodable {
        let id: Int
        let nummer: Int?
    }

    private struct Reihenfolgeantwort: Decodable {
        let plays: [NeueNummer]
    }

    static func reihenfolgeSichern(playbook: Int, kennungen: [Int],
                                   nummernMitziehen: Bool,
                                   token: String) async throws -> [NeueNummer] {
        try await Server.hole(
            Server.anfrage("/api/v1/playbooks/\(playbook)/reihenfolge/",
                           methode: "POST",
                           rumpf: ["plays": kennungen,
                                   "nummern_mitziehen": nummernMitziehen],
                           token: token),
            als: Reihenfolgeantwort.self).plays
    }
}

/// Einen Play umbenennen und löschen (B6).
///
/// Beim `Playspeicher`, weil es dieselbe Adresse und denselben
/// Konfliktschutz betrifft: Ein `PUT` schickt die gelesene Fassung mit,
/// und stimmt sie nicht mehr, antwortet der Server mit 409 statt zu
/// überschreiben.
extension Playspeicher {

    /// Nur den Namen ändern -- die Zeichnung bleibt unangetastet.
    ///
    /// **Ohne `zeichnung` im Rumpf, und das ist wichtig.** Der Server
    /// lässt jedes Feld stehen, das nicht mitkommt. Wer hier die
    /// Zeichnung aus der Liste mitschickte, hätte keine -- die Liste
    /// trägt sie nicht --, und ein Umbenennen leerte den Play.
    static func umbenennen(play: Int, name: String, version: Int,
                           token: String) async throws -> Ergebnis {
        let anfrage = try Server.anfrage(
            "/api/v1/plays/\(play)/", methode: "PUT",
            rumpf: ["name": name, "version": version], token: token)
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

    static func loeschen(play: Int, token: String) async throws {
        try await Server.ausfuehren(
            Server.anfrage("/api/v1/plays/\(play)/", methode: "DELETE",
                           token: token))
    }
}
