// Ein abfotografiertes Blatt zum Server schicken (R142).
//
// **Diese Adresse legt nichts an**, und darauf ruht der ganze Ablauf:
// Der Trainer sieht erst, was erkannt wurde, gibt dann einen Namen und
// legt den Play über den gewöhnlichen Weg an. Ein Scanner, der beim
// Auslösen schon schreibt, füllt das Heft mit Fehlversuchen.
//
// **Die Erkennung läuft auf dem Server und nicht im Telefon**, und das
// ist eine bewusste Entscheidung. Auf dem Telefon lägen die Regeln in
// Swift, auf dem Server in Python -- zwei Lesarten desselben Blatts,
// die beim ersten Unterschied auseinanderlaufen. Dann bekäme ein
// Trainer am Telefon einen anderen Play als am Rechner, aus derselben
// Datei. Dass es Netz braucht, ist der Preis; beim Import einer Datei
// ist es ohnehin so.

import Foundation

/// Was der Server aus einem Blatt gelesen hat.
struct Scanfund: Equatable, Decodable {

    let zeichnung: Zeichnung
    let spieler: Int
    let routen: Int
    let sicher: Bool

    /// Was nachgesehen werden muss -- fertige Sätze vom Server.
    ///
    /// **Übersetzt kommen sie schon an.** Die Sätze stehen im
    /// Python-Katalog, weil sie dort entstehen; sie hier noch einmal
    /// zu führen hiesse, dieselben fünf Sätze in zwei Katalogen zu
    /// pflegen -- und der zweite wäre nach dem ersten Zusatz veraltet.
    let bedenken: [String]

    /// Ob der Maßstab geraten werden musste.
    let tiefeGeraten: Bool
    let querGeraten: Bool

    enum CodingKeys: String, CodingKey {
        case zeichnung, spieler, routen, sicher, bedenken
        case tiefeGeraten = "tiefe_geraten"
        case querGeraten = "quer_geraten"
    }
}

enum Scanner {

    private struct Antwort: Decodable {
        let plays: [Scanfund]
        let aus_dem_rahmen: Bool
    }

    /// Schickt das Bild samt Rahmen und gibt den ersten Fund zurück.
    ///
    /// `nil` heisst: gelesen, aber nichts gefunden. Das ist kein
    /// Fehler -- ein leeres Blatt oder ein schlecht getroffenes Foto
    /// ist ein gewöhnlicher Ausgang, und ein geworfener Fehler dafür
    /// hiesse, dem Trainer eine Störung zu melden, wo er nur noch
    /// einmal auslösen muss.
    ///
    /// **Nur der erste Play.** Ein abfotografiertes Blatt zeigt einen
    /// Spielzug; wer einen ganzen Bogen hat, lädt ihn als Datei hoch
    /// (R141) und bekommt dort alle auf einmal samt Vorschau.
    static func lesen(bild: Data, felder: [String: String],
                      token: String) async throws -> Scanfund? {
        let anfrage = try Server.anfrageMitDatei(
            "/api/v1/scannen/", feld: "bild", daten: bild,
            dateiname: "scan.jpg", typ: "image/jpeg", felder: felder,
            token: token,
            // **Länger als die üblichen 60 Sekunden.** Das Lesen eines
            // Bildes dauert auf dem Server länger als eine Abfrage,
            // und ein Abbruch nach einer Minute wäre der schlechteste
            // Ausgang: Der Trainer hat das Blatt noch in der Hand und
            // weiss nicht, ob es an ihm lag.
            wartezeit: 120)
        let antwort = try await Server.hole(anfrage, als: Antwort.self)
        return antwort.plays.first
    }
}
