// Wo der Coaching-Schlüssel auf der Uhr liegt (R143).
//
// **Warum nicht in `Uhrlager`.** Dort liegt das Paket -- der Bestand,
// der bei jedem Abgleich ersetzt wird. Der Schlüssel hat einen anderen
// Lebenslauf: Er kommt einmal bei der Einrichtung und bleibt, bis die
// Uhr abgemeldet wird. Läge er im Paket, wäre er bei jedem neuen
// Bestand weg, und vor jedem Training stünde wieder Einrichtung an.
//
// **Und warum nicht im Schlüsselbund.** Er wäre dort besser aufgehoben,
// das stimmt. Er ist aber kein Passwort, sondern ein Lesezugang zu
// EINER Adresse: Wer ihn hat, sieht, welcher Play gerade gerufen ist --
// mehr nicht. Dafür einen Schlüsselbund-Zugriff einzurichten, der auf
// watchOS eine eigene Berechtigungsgruppe braucht, wäre Aufwand ohne
// Gegenwert. Widerrufen lässt er sich jederzeit vom Telefon aus.

import Foundation

enum Coachinglager {

    private static let schluesselname = "de.routetree.uhr.coaching"

    /// Der Schlüssel, oder `nil`, wenn die Uhr nie eingerichtet wurde.
    static var schluessel: String? {
        let wert = UserDefaults.standard.string(forKey: schluesselname)
        // LEER IST NICHT GESETZT. Ein leerer Text käme durch jede
        // Prüfung auf `nil` hindurch und erzeugte eine Anfrage mit
        // `Bearer `, die der Server mit 401 beantwortet -- und auf dem
        // Handgelenk stünde „nicht mehr angemeldet", obwohl nie
        // jemand angemeldet hat.
        guard let wert, !wert.isEmpty else { return nil }
        return wert
    }

    static func ablegen(_ wert: String) {
        UserDefaults.standard.set(wert, forKey: schluesselname)
    }

    static func leeren() {
        UserDefaults.standard.removeObject(forKey: schluesselname)
    }
}
