// Die Schlüssel, unter denen Telefon und Uhr sich verständigen (R140).
//
// DIESE DATEI GEHOERT BEIDEN SEITEN -- sie steht im Bauplan bei
// `Routetree` UND bei `RoutetreeUhr`.
//
// Der Grund ist derselbe wie bei `Uhrpaket`, nur schärfer: Ein
// Wörterbuch, das über eine Funkstrecke geht, hat keine Typen. Steht
// auf der einen Seite `"paket"` und auf der anderen `"Paket"`, kommt
// nichts an -- kein Fehler, keine Meldung, nichts. Genau diese Sorte
// stiller Fehlschlag soll auffallen, und der einzige Weg dahin ist,
// dass es die Zeichenkette nur EINMAL gibt.

import Foundation

/// Die Schlüssel im Wörterbuch, das über WatchConnectivity geht.
enum Uhrfunk {

    /// Das ganze Paket als `Data` -- in `transferUserInfo`.
    static let paket = "paket"

    /// Nur der Zeitpunkt des letzten Packens, als
    /// `timeIntervalSince1970` -- im Anwendungszusammenhang.
    ///
    /// Eine Zahl und kein `Date`: Der Anwendungszusammenhang nimmt nur
    /// Datentypen, die sich in eine Eigenschaftsliste schreiben lassen.
    /// `Date` gehört dazu, `Double` aber auch -- und `Double` überlebt
    /// jede Fassung von Foundation unverändert.
    static let stand = "stand"

    /// Die Uhr bittet um einen frischen Stand.
    static let bitteSchicken = "bitteSchicken"

    /// Dateiname beim Übertragen als Datei. Nur zur Wiedererkennung im
    /// Protokoll; gelesen wird der Inhalt.
    static let dateiname = "uhrpaket.json"

    /// Ab dieser Größe geht das Paket als DATEI statt als Wörterbuch.
    ///
    /// `transferUserInfo` legt sein Wörterbuch in eine Warteschlange,
    /// die das System verwaltet; für ein paar Kilobyte ist das der
    /// einfachste Weg. Für ein Heft mit fünfzig Plays ist es der
    /// falsche: Apple nennt keine harte Grenze, aber große Wörterbücher
    /// werden still verworfen. `transferFile` ist dafür gebaut.
    ///
    /// 16 KB ist bewusst niedrig gewählt. Die Datei ist kein schlechter
    /// Weg -- sie ist nur umständlicher, wenn es auch kurz geht.
    static let grenzeFuerDatei = 16 * 1024
}
