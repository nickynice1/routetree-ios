// Was das Telefon der Uhr schickt (R140).
//
// Niklas am 25.09.2026: „ich möchte das wir für die 1.2 noch eine apple
// watch app mit rausbringen wo man seine plays auf seiner apple watch
// sieht. auch nach kategorien sortiert. [...] quasi wie ein digitaler
// wristcoach."
//
// DIESE DATEI GEHOERT BEIDEN SEITEN. Sie steht im Bauplan bei `Routetree`
// UND bei `RoutetreeUhr` -- das Telefon packt, die Uhr packt aus, und
// beide lesen dieselben Regeln. Zwei Fassungen desselben Formats wären
// genau der Fehler, den dieses Projekt am häufigsten an sich findet:
// zwei Quellen für dieselbe Sache, die auseinanderlaufen.
//
// WARUM EIN EIGENES FORMAT UND NICHT `Modelle.PlayVoll`.
//
// Die Antwort des Servers trägt vierzig Felder, die am Handgelenk
// niemanden interessieren: Besitzer, Zeitstempel, Lernstand, Notizen,
// Druckeinstellungen. Über WatchConnectivity ist jedes davon Ballast,
// der bei jedem Abgleich über Bluetooth geht. Hier steht nur, was die
// Uhr wirklich zeigt.
//
// Und es hat einen zweiten Grund: `Modelle.PlayVoll` ist `Decodable`
// und nicht `Encodable` (siehe `Vorrat`). Zum Verschicken braucht es
// beides.

import Foundation

/// Der Bestand, wie er auf der Uhr liegt.
///
/// Ein Paket ist immer VOLLSTAENDIG: Es ersetzt, was auf der Uhr liegt,
/// und ergänzt es nicht. Teilstände wären der Weg zu einer Uhr, die ein
/// gelöschtes Play noch zeigt -- und am Platz hat niemand die
/// Gelegenheit, das nachzuprüfen.
struct Uhrpaket: Codable, Equatable {

    /// Fassung des FORMATS, nicht des Inhalts.
    ///
    /// Die Uhr wird unabhängig vom Telefon aktualisiert: Es gibt
    /// Minuten, in denen eine neue Telefon-App einer alten Uhr-App
    /// gegenübersteht, und umgekehrt. Ein Paket, dessen Fassung die Uhr
    /// nicht kennt, wird VERWORFEN statt halb gelesen -- ein halb
    /// gelesenes Playbook ist schlimmer als ein altes.
    static let aktuelleFassung = 1

    var fassung: Int = Uhrpaket.aktuelleFassung

    /// Wann das Telefon gepackt hat. Die Uhr zeigt es, damit ein Trainer
    /// am Platz sieht, ob er einen alten Stand in der Hand hat.
    var stand: Date

    var hefte: [Heft]

    struct Heft: Codable, Equatable, Identifiable {
        let id: String
        let name: String
        /// Die Spielform, als Schlüssel wie in `Spielform.schluessel`.
        let spielform: String
        /// Die Maße DIESES Hefts.
        ///
        /// Mitgeschickt und nicht nachgeschlagen: Was ein Play an Maßen
        /// benutzt, entscheidet der Server beim Speichern, und ein Heft
        /// mit eigenen Maßen steht in keiner Voreinstellung. Die Uhr
        /// zeichnete sonst ein anderes Feld als das Telefon.
        let feld: Feld
        var kategorien: [Kategorie]

        /// Alle Plays des Hefts, quer über die Kategorien.
        var plays: [Play] { kategorien.flatMap(\.plays) }
    }

    struct Kategorie: Codable, Equatable, Identifiable {
        let id: String
        let name: String
        /// Die Farbe aus dem Playbook, als `#rrggbb`.
        ///
        /// Als TEXT und nicht als `Color`: `Color` ist nicht `Codable`,
        /// und eine eigene Farbcodierung wäre eine zweite Wahrheit
        /// neben der des Servers.
        let farbe: String?
        var plays: [Play]
    }

    struct Play: Codable, Equatable, Identifiable {
        let id: String
        let name: String
        /// Die Linie, an der es losgeht, in Yards von der eigenen
        /// Grundlinie -- dieselbe Zahl wie im Editor.
        let los: Double
        /// Blickrichtung: 1 nach oben, -1 nach unten.
        let richtung: Int
        /// Die Zeichnung selbst, im Format des Servers
        /// (`backend/designer/schema.py`).
        let zeichnung: Zeichnung
    }
}

// MARK: - Zählen, ohne die Listen zu bauen

extension Uhrpaket {

    var anzahlPlays: Int {
        hefte.reduce(0) { $0 + $1.kategorien.reduce(0) { $0 + $1.plays.count } }
    }

    /// Ein leeres Paket. Der Zustand vor dem ersten Abgleich -- und der
    /// nach einer Abmeldung.
    static func leer() -> Uhrpaket {
        Uhrpaket(stand: .distantPast, hefte: [])
    }

    /// Liest ein Paket und gibt `nil`, wenn es nicht passt.
    ///
    /// **Wirft nicht.** Ein Paket, das die Uhr nicht versteht, ist ein
    /// Grund, den alten Stand zu behalten -- kein Grund abzustürzen. Am
    /// Spielfeldrand ist ein Absturz das Ende der Halbzeit.
    static func lesen(_ daten: Data) -> Uhrpaket? {
        let leser = JSONDecoder()
        leser.dateDecodingStrategy = .iso8601
        guard let paket = try? leser.decode(Uhrpaket.self, from: daten),
              paket.fassung == Uhrpaket.aktuelleFassung
        else { return nil }
        return paket
    }

    func schreiben() throws -> Data {
        let schreiber = JSONEncoder()
        schreiber.dateEncodingStrategy = .iso8601
        return try schreiber.encode(self)
    }
}
