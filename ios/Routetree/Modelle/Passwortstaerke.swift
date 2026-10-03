import Foundation

/// Wie stark ist dieses Passwort? Gemessen, während getippt wird
/// (R110.10, der Browser-Punkt R108 für die App).
///
/// **Der Anlass** war ein Bild des Registrierformulars mit einem Kreis
/// um die beiden Passwortfelder: „Passwort Indikator" (Niklas,
/// 10.09.2026). Der Browser hat ihn seit demselben Tag; die App zeigte
/// weiter nur den Satz, WAS verlangt wird, und nicht, wo man steht.
///
/// **Was das hier IST und was es nicht ist.** Es prüft nicht noch
/// einmal, sondern zeigt vorher an, was der Server gleich entscheidet
/// (`AUTH_PASSWORD_VALIDATORS`). Die Entscheidung bleibt beim Server.
///
/// **Was die App nicht kann, sagt sie auch nicht.** Die Liste der
/// verbreiteten Passwörter hat zwanzigtausend Einträge und liegt auf
/// dem Server. Ein Balken, der „stark" sagt und danach abgelehnt wird,
/// wäre schlimmer als keiner.
///
/// **Die Mindestlänge kommt vom Server** (`passwort_mindestlaenge` in
/// der Registrierauskunft) und steht nicht hier. Eine getippte Acht
/// sagt „mindestens 8 Zeichen", während der Server zwölf verlangt --
/// und dann macht der Balken genau die Zusage, die er nicht halten
/// kann.
///
/// **Warum hier und nicht in der Ansicht.** Es gibt keinen Mac. Eine
/// Regel in einer SwiftUI-Ansicht lässt sich nicht ausprobieren,
/// sondern nur behaupten. Dieselbe Entscheidung wie bei `Zeichenblock`
/// (B4), `Kaderblock` (B9) und `Stufenblock` (R117).
enum Passwortstaerke {

    /// Die fünf Stände. `-1` gibt es nicht als Fall, sondern als
    /// `nil`-Ergebnis: Ein leeres Feld bekommt keinen Balken, sondern
    /// gar nichts.
    ///
    /// Dieselben fünf wie im Browser (`passwortstaerke.js`) und in
    /// derselben Reihenfolge -- wer beides benutzt, soll nicht zweimal
    /// etwas anderes lesen.
    enum Stufe: Int, CaseIterable {
        case zuKurz = 0
        case schwach = 1
        case gehtSo = 2
        case gut = 3
        case stark = 4

        /// Wie viele der vier Striche gefüllt sind.
        ///
        /// **Vier Striche und kein durchlaufender Balken.** Ein Balken,
        /// der von rot nach grün läuft, ist für eine Rot-Grün-Schwäche
        /// keine Auskunft. Vier gefüllte Striche zählt man auch ohne
        /// Farbe.
        var striche: Int { rawValue }

        /// Genügt dieser Stand dem Server? Unter `schwach` nicht.
        var reicht: Bool { self != .zuKurz }
    }

    /// Was der Balken zeigt: den Stand und, wenn es einen gibt, den
    /// Grund.
    struct Stand: Equatable {
        let stufe: Stufe
        /// Warum es nicht reicht. Leer heisst: Es reicht, und dann
        /// steht das Wort der Stufe da.
        let grund: String

        /// Was neben den Strichen steht.
        var wort: String {
            if !grund.isEmpty { return grund }
            switch stufe {
            case .zuKurz: return String(localized: "zu kurz")
            case .schwach: return String(localized: "schwach")
            case .gehtSo: return String(localized: "geht so")
            case .gut: return String(localized: "gut")
            case .stark: return String(localized: "stark")
            }
        }
    }

    /// Was ein Mensch beim Tippen aus Versehen tut -- keine
    /// Kryptographie, sondern die drei Fälle, die der Server gleich
    /// ablehnt, und danach vier Eigenschaften.
    ///
    /// `nil` bei leerem Feld: Ein Balken über einem leeren Feld sieht
    /// aus wie ein Vorwurf, bevor jemand angefangen hat.
    ///
    /// - Parameter umfeld: Benutzername, Namen, Mailadresse aus
    ///   DEMSELBEN Formular. Auf dem Blatt „Passwort ändern" gibt es
    ///   sie nicht; dann bleibt die Liste leer und die Prüfung
    ///   entfällt still.
    static func bewerten(_ wort: String, mindestens: Int,
                         umfeld: [String] = []) -> Stand? {
        if wort.isEmpty { return nil }

        if wort.count < mindestens {
            let fehlt = mindestens - wort.count
            return Stand(stufe: .zuKurz,
                         grund: String(localized: "Noch \(fehlt) Zeichen."))
        }
        // REINE ZIFFERNFOLGE. Der `NumericPasswordValidator` lehnt sie
        // ab, und zwar unabhängig von der Länge: „12345678901234" ist
        // vierzehn Zeichen lang und trotzdem raus.
        if wort.allSatisfy({ $0.isNumber }) {
            return Stand(stufe: .zuKurz,
                         grund: String(localized: "Nur Ziffern reicht nicht."))
        }
        // ZU NAH AM BENUTZERNAMEN. Der
        // `UserAttributeSimilarityValidator` vergleicht mit
        // Benutzername, Vor- und Nachname und Mailadresse. Hier nur die
        // grobe Fassung: Steht eines davon im Passwort drin? Das fängt
        // den häufigsten Fall („niklas2026"). Was der Server feiner
        // prüft, prüft er weiterhin.
        let klein = wort.lowercased()
        for teil in umfeld where teil.count >= 4 {
            if klein.contains(teil.lowercased()) {
                return Stand(stufe: .zuKurz,
                             grund: String(localized: "Zu nah an deinem Namen."))
            }
        }

        // Ab hier ist es gültig, und der Balken sagt nur noch, wie gut.
        // Vier Eigenschaften, jede einen Punkt, dazu einer für
        // deutliche Überlänge -- dieselbe Rechnung wie im Browser.
        var punkte = 0
        if wort.contains(where: { $0.isLowercase }) { punkte += 1 }
        if wort.contains(where: { $0.isUppercase }) { punkte += 1 }
        if wort.contains(where: { $0.isNumber }) { punkte += 1 }
        if wort.contains(where: { !$0.isLetter && !$0.isNumber }) { punkte += 1 }
        if wort.count >= mindestens + 6 { punkte += 1 }
        let stufe = Stufe(rawValue: min(4, max(1, punkte))) ?? .schwach
        return Stand(stufe: stufe, grund: "")
    }
}
