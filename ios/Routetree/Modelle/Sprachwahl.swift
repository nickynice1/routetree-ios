// Welche Sprache die App spricht (R31).
//
// DER AUFTRAG, Niklas am 28.08.2026: „man sollte bei ersten mal app
// öffnen gefragt werden welche sprache man will und später in den
// settings auch noch ändern können".
//
// WAS iOS VON SICH AUS TUT. Es nimmt die Systemsprache, und für die
// meisten ist das richtig. Der Fall, um den es geht, ist ein anderer:
// ein Trainer mit einem englisch eingestellten Telefon, der seine Plays
// auf Deutsch ruft. Der sieht heute eine englische App und findet
// keinen Weg heraus -- außer das ganze Telefon umzustellen.
//
// WIE MAN ES ÜBERSTEUERT, und warum es unbequem ist. Die Sprache eines
// Bündels steht beim START fest: `Bundle.main` sucht sich beim Laden
// den passenden `.lproj`-Ordner und behält ihn. Ein Schalter zur
// Laufzeit ändert daran nichts.
//
// Es gibt zwei Wege, und wir nehmen den ehrlichen:
//
//   1. `AppleLanguages` in den `UserDefaults` setzen. Greift beim
//      NÄCHSTEN Start. Fünf Zeilen, kein Trick, und Apple sieht es
//      seit jeher vor.
//   2. `Bundle` austauschen (Methoden zur Laufzeit vertauschen). Wirkt
//      sofort und ist ein Eingriff in das Laufzeitsystem, den jede
//      neue iOS-Fassung brechen kann -- an einer Stelle, die kein Test
//      hier erreicht, weil es keinen Mac gibt.
//
// Also Weg 1. UND DIE OBERFLÄCHE SAGT ES DAZU: Eine Einstellung, die
// erst nach einem Neustart wirkt und das verschweigt, hält man für
// kaputt und drückt sie noch dreimal.

import Foundation

enum Sprachwahl {

    /// Die fünf Sprachen, in denen es Routetree gibt.
    ///
    /// Sie stehen NICHT hier als Wahrheit, sondern werden aus dem
    /// Bündel gelesen: `Bundle.main.localizations` sind genau die
    /// `.lproj`-Ordner, die `scripts/app_sprachen.py` geschrieben hat.
    /// Eine getippte Liste wäre eine sechste Stelle, an der jemand eine
    /// Sprache vergisst.
    static var verfuegbar: [String] {
        Bundle.main.localizations
            .filter { $0 != "Base" }
            .sorted()
    }

    /// Wie eine Sprache sich SELBST nennt.
    ///
    /// Dieselbe Regel wie im Web (`_sprachwahl.html`): „Español" und
    /// nicht „Spanisch". Wer die Oberfläche nicht lesen kann, sucht
    /// seine Sprache so, wie SIE sich nennt -- eine übersetzte Liste
    /// hilft genau dem nicht, der sie braucht.
    static func name(_ code: String) -> String {
        let eigene = Locale(identifier: code)
        return eigene.localizedString(forLanguageCode: code)?.capitalized
            ?? code.uppercased()
    }

    private static let schluessel = "AppleLanguages"
    private static let gefragt = "routetree.sprache.gefragt"

    /// Die gewählte Sprache, oder `nil` für „die des Systems".
    static var gewaehlt: String? {
        guard let liste = UserDefaults.standard.array(forKey: schluessel)
                as? [String], let erste = liste.first else { return nil }
        return verfuegbar.contains(erste) ? erste : nil
    }

    /// Ob schon einmal gefragt wurde.
    ///
    /// **Getrennt von `gewaehlt`, und das ist der Punkt.** Wer beim
    /// ersten Start „die des Systems" wählt, hat GEWÄHLT -- er darf
    /// nicht bei jedem Start wieder gefragt werden. Ein einziges Feld
    /// könnte die beiden Fälle nicht auseinanderhalten.
    static var schonGefragt: Bool {
        get { UserDefaults.standard.bool(forKey: gefragt) }
        set { UserDefaults.standard.set(newValue, forKey: gefragt) }
    }

    /// Setzt die Sprache. `nil` heißt „wieder die des Systems".
    ///
    /// Wirkt beim nächsten Start -- siehe der Kopf dieser Datei. Die
    /// Ansicht, die das aufruft, MUSS es dazusagen.
    static func setzen(_ code: String?) {
        let speicher = UserDefaults.standard
        if let code, verfuegbar.contains(code) {
            speicher.set([code], forKey: schluessel)
        } else {
            // Entfernen und nicht auf `[]` setzen: Eine leere Liste ist
            // etwas anderes als „keine Vorgabe", und iOS behandelt sie
            // auch anders.
            speicher.removeObject(forKey: schluessel)
        }
        schonGefragt = true
    }

    /// Der Text, der neben der Wahl steht.
    ///
    /// Er sagt zwei Dinge, und beide gehören dazu: dass es beim
    /// nächsten Start greift, und dass „System" eine gültige Antwort
    /// ist.
    static var hinweis: String {
        // EIN Literal, nicht zwei zusammengesetzte: `appsprache.py`
        // liest den Text aus dem Quelltext, und ein `"a" + "b"` ist für
        // den Extraktor kein Satz. Die Meldung bliebe in jeder Sprache
        // deutsch, ohne dass irgendwo ein Fehler stünde.
        String(localized: "Die neue Sprache gilt, sobald du die App das nächste Mal öffnest.")
    }
}
