// Einen fremden Playbook-Bogen in der App einlesen (R141.1).
//
// **Niklas, 25.09.2026:** „ich möchte, dass du für alle diese
// verschiedenen Sachen ein Importer in den Einstellungen einbaust …
// sodass sie einfach SVG oder JPEG oder PNG oder PDF hochladen können
// und ein Playbook anlegen können oder zu einem Playbook hinzufügen
// können."
//
// Der Importer stand zuerst nur im Browser -- das war meine Auslegung
// von „in den Einstellungen" und nicht seine Ansage. Hier ist er in
// der App.
//
// **Zweistufig, und zustandslos.** Erst lesen und zeigen, dann
// übernehmen. Die Datei geht dabei zweimal hinüber, weil eine
// Schnittstelle, die sich zwischen zwei Aufrufen etwas merkt, eine
// Sitzung bräuchte -- und die hat eine App nicht. Der Preis ist ein
// zweiter Upload, der Gewinn ist eine Zusage: Was in der Vorschau
// stand, ist garantiert das, was ankommt.

import Foundation

/// Ein Play, wie ihn der Leser auf dem Bogen gefunden hat.
struct Bogenplay: Decodable, Identifiable, Equatable {

    let nummer: Int
    let seite: Int
    let spieler: Int
    let routen: Int
    let sicher: Bool

    /// Was nachgesehen werden muss -- fertige Sätze vom Server.
    ///
    /// **Sie stehen NUR im Python-Katalog.** Dieselben fünf Sätze hier
    /// noch einmal zu führen hiesse, zwei Kataloge zu pflegen, und der
    /// zweite wäre nach dem ersten Zusatz veraltet.
    let bedenken: [String]

    var id: Int { nummer }
}

/// Was beim Einlesen herauskam.
struct Bogenfund: Decodable, Equatable {

    let plays: [Bogenplay]
    let angelegt: Int
    let nachzuarbeiten: Int
    let aus_bild: Bool
}

enum Einleser {

    /// Liest den Bogen und legt NICHTS an.
    static func vorschau(playbook: Int, datei: Data, name: String,
                         typ: String, token: String) async throws
        -> Bogenfund {
        try await schicken(playbook: playbook, datei: datei, name: name,
                           typ: typ, scharf: false, token: token)
    }

    /// Legt die Plays wirklich an.
    static func uebernehmen(playbook: Int, datei: Data, name: String,
                            typ: String, token: String) async throws
        -> Bogenfund {
        try await schicken(playbook: playbook, datei: datei, name: name,
                           typ: typ, scharf: true, token: token)
    }

    private static func schicken(playbook: Int, datei: Data, name: String,
                                 typ: String, scharf: Bool,
                                 token: String) async throws -> Bogenfund {
        let anfrage = try Server.anfrageMitDatei(
            "/api/v1/playbooks/\(playbook)/einlesen/",
            feld: "datei", daten: datei, dateiname: name, typ: typ,
            felder: scharf ? ["scharf": "1"] : [:],
            token: token,
            // **Länger als die üblichen 60 Sekunden.** Ein Bogen mit
            // sechsunddreissig Seiten wird Seite für Seite gelesen; ein
            // Abbruch nach einer Minute sähe aus wie „kein Netz", und
            // der Trainer versuchte es dreimal.
            wartezeit: 180)
        return try await Server.hole(anfrage, als: Bogenfund.self)
    }

    /// Der Medientyp zu einer Endung -- für den Upload.
    ///
    /// **Der Server entscheidet trotzdem selbst.** Er schaut auf die
    /// Endung des Dateinamens, nicht auf diesen Wert; eine App, die
    /// hier etwas Falsches schickt, bekommt deshalb keine andere
    /// Behandlung. Der Typ steht da, weil Multipart ihn vorsieht und
    /// weil er in einem mitgeschnittenen Rumpf hilft.
    static func medientyp(fuer endung: String) -> String {
        switch endung.lowercased() {
        case "pdf": return "application/pdf"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "tif", "tiff": return "image/tiff"
        default: return "application/octet-stream"
        }
    }
}
