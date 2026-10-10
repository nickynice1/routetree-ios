// Routetree auf der Apple Watch (R140).
//
// Niklas am 25.09.2026: „ich möchte das wir für die 1.2 noch eine apple
// watch app mit rausbringen wo man seine plays auf seiner apple watch
// sieht. auch nach kategorien sortiert. [...] quasi wie ein digitaler
// wristcoach."
//
// Und am selben Tag, zur Abgrenzung: „auf der uhr muss auch kein editor
// sein. also man muss keine plays zeichnen können."
//
// **Diese App ist reine Anzeige.** Sie schreibt nichts, sie schickt
// nichts an den Server, sie kennt kein Passwort. Was sie zeigt, hat ihr
// das Telefon gegeben. Damit fällt die ganze Frage weg, was mit einem
// Zugang passiert, wenn eine Uhr weitergegeben wird -- es gibt keinen.

import SwiftUI

@main
struct UhrApp: App {

    /// Einer für die ganze App. Er hält den Bestand und hört auf das
    /// Telefon; eine zweite Sitzung daneben bekäme dieselben Pakete ein
    /// zweites Mal.
    @StateObject private var empfang = Uhrempfang()

    init() {
        // DER PROBESTAND MUSS VOR DEM EMPFANG DA SEIN (siehe
        // `Uhrprobe`): `Uhrempfang.init` liest das Lager EINMAL, beim
        // Bauen. Wer danach einlegt, legt hinter die Ansicht.
        //
        // Dass das hier funktioniert, haengt daran, dass `@StateObject`
        // seinen Wert erst beim ersten Zeichnen herstellt und nicht
        // hier -- deshalb ist dieser Rumpf frueher dran als
        // `Uhrempfang()`.
        //
        // Ohne den Schalter `-uhrprobe` tut der Aufruf nichts, und im
        // Store-Bau gibt es ihn gar nicht.
        #if DEBUG
        Uhrprobe.einlegen()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            Uhrprobe.ansicht(empfang: empfang)
            #else
            UhrHefte(empfang: empfang)
            #endif
        }
    }
}
