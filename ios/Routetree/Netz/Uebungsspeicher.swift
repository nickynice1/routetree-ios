// Üben und Lernstand über die Schnittstelle (B8).
//
// WAS HIER NICHT PASSIERT: Es wird nichts ausgewählt und nichts
// bewertet. Welcher Play gefragt wird, welche Namen danebenstehen und ob
// eine Antwort richtig war, entscheidet der SERVER -- dieselbe Rechnung,
// die auch die Seite im Browser benutzt (`designer/lernen.py`).
//
// WARUM DAS HIER ANDERS ENTSCHIEDEN IST ALS BEI `Ordnen` UND `Laufplan`.
// Dort rechnet die App mit, weil sie eine VORSCHAU braucht, bevor etwas
// gespeichert ist: Welche Nummer bekommt dieser Play, wenn ich jetzt
// loslasse. Hier braucht sie keine. Der Lernstand liegt ohnehin auf dem
// Server, jede Antwort geht also so oder so hin -- und eine zweite
// Gewichtung in Swift sähe nie falsch aus, sondern nur nach Zufall.

import Foundation

/// Fragen stellen lassen, antworten, und die Übersicht für den Coach.
enum Uebungsspeicher {

    /// Die nächste Frage.
    ///
    /// **POST**, obwohl nichts mitgeht: Die Anfrage legt fest, was
    /// gefragt IST. Ein GET, das ein Zwischenspeicher wiederholen darf,
    /// wäre hier falsch.
    static func frage(playbook: Int,
                      token: String) async throws -> Modell.Uebungsstand {
        try await Server.hole(
            Server.anfrage("/api/v1/playbooks/\(playbook)/uebung/",
                           methode: "POST", rumpf: [:], token: token),
            als: Modell.Uebungsstand.self)
    }

    /// Eine Antwort eintragen -- und gleich die nächste Frage bekommen.
    static func antworten(playbook: Int, antwort: Int,
                          token: String) async throws -> Modell.Antwortrunde {
        try await Server.hole(
            Server.anfrage("/api/v1/playbooks/\(playbook)/uebung/antwort/",
                           methode: "POST", rumpf: ["antwort": antwort],
                           token: token),
            als: Modell.Antwortrunde.self)
    }

    // MARK: - Ohne Empfang (R14)

    /// Die nächsten Fragen im Voraus holen -- **mit dem rohen Rumpf**.
    ///
    /// Der Rumpf geht mit heraus, weil er auf die Platte muss und nicht
    /// das Modell (`Uebungsvorrat`). Dieselbe Entscheidung wie beim
    /// Vorrat: Was hervorgeholt wird, geht durch dieselbe
    /// Entschlüsselung wie eine frische Antwort.
    static func paket(playbook: Int, token: String) async throws
        -> (wert: Modell.Uebungspaket, rumpf: Data) {
        try await Server.holeMitRumpf(
            Server.anfrage("/api/v1/playbooks/\(playbook)/uebung/paket/",
                           methode: "POST", rumpf: [:], token: token),
            als: Modell.Uebungspaket.self)
    }

    /// Am Platz gegebene Antworten gebündelt nachtragen.
    ///
    /// **Gebündelt und nicht einzeln.** Wer eine Stunde ohne Empfang
    /// geübt hat, bringt dreißig Antworten mit; dreißig Anfragen aus
    /// einem Handy-Hotspot sind der Weg in die Bremse des Servers.
    static func nachtragen(playbook: Int,
                           antworten: [Modell.OffeneAntwort],
                           token: String) async throws -> Modell.Nachtrag {
        // Nur Marke und Tipp gehen mit. Ob es richtig war, entscheidet
        // der Server -- was die App dazu meint, steht gar nicht erst im
        // Vertrag.
        let liste = antworten.map {
            ["marke": $0.marke, "gewaehlt": $0.gewaehlt] as [String: Any]
        }
        return try await Server.hole(
            Server.anfrage("/api/v1/playbooks/\(playbook)/uebung/nachtragen/",
                           methode: "POST", rumpf: ["antworten": liste],
                           token: token),
            als: Modell.Nachtrag.self)
    }

    /// Wer im Team wie weit ist. Nur für den Trainerstab -- wer nicht
    /// darf, bekommt vom Server 404, genau wie im Browser.
    static func lernstand(playbook: Int,
                          token: String) async throws -> Modell.Lernstandsliste {
        try await Server.hole(
            Server.anfrage("/api/v1/playbooks/\(playbook)/lernstand/",
                           token: token),
            als: Modell.Lernstandsliste.self)
    }
}
