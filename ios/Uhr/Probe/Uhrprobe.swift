// Ein Probestand für die Uhr -- damit es Bildschirmfotos gibt (R140).
//
// Niklas am 30.09.2026: „kannst du nicht auch echte apple watch
// screenshots nehmen?"
//
// ## Das Hindernis
//
// Die Uhr holt ihre Daten AUSSCHLIESSLICH vom Telefon, über
// WatchConnectivity (`Uhrempfang`). Sie spricht nie selbst mit dem
// Server, und das soll auch so bleiben. Für ein Bildschirmfoto hieße
// das: ein gekoppeltes Paar aus iPhone- und Watch-Simulator, ein
// angemeldetes Telefon, ein Playbook darauf und eine gelungene
// Übertragung. Genau diese Kopplung ist im Simulator unzuverlässig.
//
// ## Und warum kein Oberflächentest
//
// **watchOS kennt XCUITest nicht.** Es gibt kein `XCUIApplication` für
// die Uhr, also auch kein Ziel vom Typ `bundle.ui-testing`, das tippen
// und fotografieren könnte -- anders als auf dem Telefon, wo genau das
// in `RoutetreeBilder` steht.
//
// Was es gibt, ist `simctl`: booten, installieren, starten,
// fotografieren. Tippen kann `simctl` aber nicht. Deshalb wird die
// Ansicht nicht ERTIPPT, sondern beim Start GESETZT -- ein Schalter
// sagt, was die App zeigen soll, und sie zeigt es sofort.
//
// ## Was hier echt ist
//
// Die Plays kommen aus `bibliothek.py` und sind mit denselben
// Koordinaten gezeichnet wie im Editor; gezeichnet wird von `Uhrfeld`,
// also von der Ansicht, die auch am Handgelenk läuft. Es ist kein
// Nachbau eines Uhrschirms, es IST der Uhrschirm.
//
// ## Was davon in den Store geht
//
// Nichts. Diese Datei steht vollständig in `#if DEBUG`, und ihre Daten
// stehen als Swift-Text in `Uhrprobedaten.swift` -- nicht als Datei im
// Bündel, die jeder Bau mitgenommen hätte.

#if DEBUG
import Foundation
import SwiftUI

/// Der Probestand und die Ansicht, die beim Start gezeigt wird.
enum Uhrprobe {

    /// Ohne diesen Schalter passiert hier gar nichts.
    ///
    /// **Die Voreinstellung ist AUS**, und das ist wichtig: Ein
    /// Entwickler, der die Uhr-App aus Xcode auf seine eigene Uhr
    /// spielt, bekäme sonst fremde Plays in sein Lager geschrieben --
    /// über `Uhrlager.ablegen`, das den echten Stand ERSETZT.
    static let schalter = "-uhrprobe"

    /// Welche Ansicht gezeigt werden soll, z. B. `-uhrprobe-ziel plays`.
    private static let zielschalter = "-uhrprobe-ziel"

    static var aktiv: Bool {
        ProcessInfo.processInfo.arguments.contains(schalter)
    }

    /// Legt den Probestand ins Lager -- VOR dem ersten `Uhrempfang`.
    ///
    /// `Uhrempfang.init` liest `Uhrlager.holen()`. Wer später einlegt,
    /// legt hinter der Ansicht ein und sie bleibt leer.
    static func einlegen() {
        guard aktiv else { return }
        guard let daten = Uhrprobedaten.json.data(using: .utf8),
              let paket = Uhrpaket.lesen(daten)
        else {
            // Kein Absturz, aber auch kein Schweigen: Ein leerer
            // Uhrschirm im Bilderlauf sähe aus wie ein Fehler in der
            // App, und dann sucht jemand an der falschen Stelle.
            print("[Uhrprobe] Das Probepaket ist unlesbar. "
                  + "scripts/uhrprobe_bauen.py neu laufen lassen?")
            return
        }
        Uhrlager.ablegen(paket)
    }

    /// Die Ansicht zum Schalter. `nil` heißt: der gewöhnliche Einstieg.
    ///
    /// Gibt es den Schalter, aber das Paket ist leer, kommt ebenfalls
    /// `nil` -- dann zeigt `UhrHefte` seinen eigenen Leertext, und der
    /// sagt einem Menschen mehr als eine halb gebaute Ansicht.
    /// `@MainActor`, weil `Uhrempfang` es ist. Ein Zugriff auf
    /// `empfang.paket` aus einem Zusammenhang ohne Aktor ist unter
    /// strenger Nebenläufigkeitsprüfung eine Warnung -- und
    /// Warnungen sind hier Fehler (`SWIFT_TREAT_WARNINGS_AS_ERRORS`).
    /// Gerufen wird die Funktion aus dem Rumpf der Szene, und der
    /// läuft ohnehin auf dem Hauptaktor.
    @MainActor
    @ViewBuilder
    static func ansicht(empfang: Uhrempfang) -> some View {
        if aktiv, let heft = empfang.paket.hefte.first {
            switch ziel {
            case "kategorien":
                NavigationStack { UhrKategorien(heft: heft) }
            case "plays":
                NavigationStack {
                    if let kategorie = heft.kategorien.first {
                        UhrPlayblatt(heft: heft, kategorie: kategorie,
                                     beginnBei: 0)
                    }
                }
            case "spielmodus":
                NavigationStack { UhrSpielmodus(heft: heft) }
            default:
                UhrHefte(empfang: empfang)
            }
        } else {
            UhrHefte(empfang: empfang)
        }
    }

    // KEIN PAKET JE SPRACHE MEHR (30.09.2026).
    //
    // Kurz gab es fuenf, weil die Kategorien „Pass kurz" und „Pass
    // tief" hiessen und auf einem englischen Uhrbild deutscher Text
    // nichts zu suchen hat. Seit die Bibliothek global englisch ist,
    // waren die fuenf Fassungen Zeichen fuer Zeichen gleich -- 47
    // Kilobyte Dubletten und eine Auswahl, die nichts auswaehlt.

    private static var ziel: String {
        let teile = ProcessInfo.processInfo.arguments
        guard let n = teile.firstIndex(of: zielschalter),
              n + 1 < teile.count
        else { return "hefte" }
        return teile[n + 1]
    }
}
#endif
