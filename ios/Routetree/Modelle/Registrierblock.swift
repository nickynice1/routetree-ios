import Foundation

/// Was ein Registrierformular beanstanden darf -- dieselbe Regel wie auf
/// dem Server.
///
/// **Warum die App das überhaupt beurteilt.** Sie könnte jede Eingabe
/// hinschicken und den Server antworten lassen. Aber wer sich
/// registriert, füllt acht Felder aus, bevor er zum ersten Mal etwas
/// erfährt -- und dann steht die Beanstandung an Feld zwei, das er
/// längst nicht mehr sieht. Also sagt die App es sofort, und der Server
/// bleibt der einzige, der wirklich entscheidet.
///
/// **DIE REGEL, AN DER ALLES HÄNGT: Diese Datei darf nur abweisen, was
/// der Server SICHER auch abweist.** Nicht „ungefähr dasselbe", sondern
/// strikt weniger. Eine App, die strenger ist als der Server, hat den
/// teuersten Fehler dieser Art: Sie lässt eine gültige Registrierung
/// nicht durch, der Server sieht die Anfrage nie, im Protokoll steht
/// nichts, und der Verein hält das Produkt für kaputt.
///
/// Deshalb steht hier weder Djangos Benutzernamensregel noch seine
/// E-Mail-Prüfung nachgebaut, sondern nur ihr unstrittiger Teil:
/// Leerraum mitten im Benutzernamen, ein fehlendes @, ein leeres
/// Pflichtfeld, ein zu langer Text. Alles Weitere geht hin.
///
/// **Warum das gemessen wird und nicht behauptet.**
/// `RegistrierProben.swift` hält fest, was der SERVER zu jeder Eingabe
/// sagt, und `RegistrierblockTests` vergleicht Satz für Satz.
/// `backend/designer/test_registrierung_swift.py` misst die andere
/// Hälfte: dass Djangos echtes Formular jede beanstandete Eingabe auch
/// wirklich ablehnt.
enum Registrierblock {

    /// Leerraum, buchstabengenau und nicht „was die Sprache dafür hält".
    ///
    /// `Character.isWhitespace` kennt mehr Zeichen als Pythons
    /// `str.strip`, und der Unterschied entscheidet darüber, ob ein Feld
    /// als leer gilt. Eine feste Liste ist in beiden Sprachen dieselbe;
    /// `test_registrierung_swift.py` hält sie zusammen.
    static let leerraum: Set<Character> = [
        " ", "\t", "\n", "\r", "\u{0B}", "\u{0C}", "\u{A0}",
    ]

    /// Rand weg, sonst nichts.
    static func straffen(_ text: String) -> String {
        var rest = Substring(text)
        while let erstes = rest.first, leerraum.contains(erstes) {
            rest = rest.dropFirst()
        }
        while let letztes = rest.last, leerraum.contains(letztes) {
            rest = rest.dropLast()
        }
        return String(rest)
    }

    // MARK: - Die Sätze

    /// Was dort steht, wenn jemand das Namensfeld leer lässt.
    ///
    /// Wortgleich mit dem Browser. Ein Satz, der in der App anders
    /// lautet, ist kein Tippfehler, sondern ein zweites Produkt.
    static let nameFehlt = String(localized: """
        Ohne Namen findet dich im Kader niemand. Trag ein, wie dich dein Team \
        nennt.
        """)

    private static let vereinFehlt =
        String(localized: """
            Ohne Vereinsnamen geht es nicht. Trag ein, unter welchem Namen \
            ihr antretet.
            """)

    private static let mannschaftFehlt =
        String(localized: """
            Ohne Mannschaft hat das erste Playbook keinen Platz. Trag einen \
            Namen ein, zum Beispiel U17.
            """)

    private static let benutzernameFehlt =
String(localized: "Ohne Benutzernamen kannst du dich später nicht anmelden.")

    private static let benutzernameMitLuecke =
        String(localized: """
            Im Benutzernamen darf kein Leerzeichen stehen. Erlaubt sind \
            Buchstaben, Ziffern und @ . + - _
            """)

    private static let emailFehlt =
        String(localized: """
            Ohne E-Mail-Adresse gibt es keinen Weg zurück, wenn du dein \
            Passwort vergisst.
            """)

    private static let emailOhneAffe =
String(localized: "Da fehlt das @. Eine Adresse sieht aus wie name@verein.de.")

    private static let emailHalb =
        String(localized: """
            Vor und hinter dem @ muss etwas stehen, zum Beispiel \
            name@verein.de.
            """)

    // MARK: - Die Prüfungen

    /// Ein Feld nach Namen prüfen. Leer heißt „nichts zu beanstanden".
    ///
    /// **`laengen` kommt vom SERVER** (`GET /api/v1/registrieren/`) und
    /// steht nicht hier: Wie lang ein Vereinsname sein darf, gehört dem
    /// Modell. Eine Zahl in der App wäre die zweite Fassung, und die
    /// erste Änderung an der Datenbank träfe sie nicht.
    ///
    /// Fehlt die Länge zu einem Feld, wird sie nicht geprüft -- die
    /// sichere Richtung. Ein Feld, über das die App nichts weiß, ist
    /// eines, über das nur der Server entscheidet.
    ///
    /// Unbekannte Feldnamen ergeben ebenfalls `""`, aus demselben Grund.
    static func pruefen(feld: String, eingabe: String,
                        laengen: [String: Int]) -> String {
        switch feld {
        case "verein":
            return pflichtfeld(eingabe, laenge: laengen[feld],
                               leer: vereinFehlt)
        case "mannschaft":
            return pflichtfeld(eingabe, laenge: laengen[feld],
                               leer: mannschaftFehlt)
        case "name_im_team":
            return pflichtfeld(eingabe, laenge: laengen[feld],
                               leer: nameFehlt)
        case "benutzername":
            return benutzername(eingabe, laenge: laengen[feld])
        case "email":
            return email(eingabe)
        default:
            return ""
        }
    }

    private static func pflichtfeld(_ text: String, laenge: Int?,
                                    leer: String) -> String {
        let gestrafft = straffen(text)
        if gestrafft.isEmpty { return leer }
        if let laenge, gestrafft.count > laenge {
            return String(localized:
                "Das ist zu lang. Höchstens \(laenge) Zeichen.")
        }
        return ""
    }

    /// Der Benutzername -- und nur das, was sicher nicht durchgeht.
    ///
    /// Leerraum am Rand ist KEIN Fehler: Djangos Formular schneidet ihn
    /// ab. Wer hier meckerte, wiese etwas ab, das der Server anstandslos
    /// genommen hätte -- und zwar an dem Feld, das jemand aus einer
    /// Nachricht einfügt.
    static func benutzername(_ text: String, laenge: Int?) -> String {
        let fehlt = pflichtfeld(text, laenge: laenge, leer: benutzernameFehlt)
        if !fehlt.isEmpty { return fehlt }
        if straffen(text).contains(where: { leerraum.contains($0) }) {
            return benutzernameMitLuecke
        }
        return ""
    }

    /// Die Adresse -- und nur das eine, was ohne Ausnahme falsch ist.
    ///
    /// Kein Punkt in der Domain, keine Längengrenze, kein Muster:
    /// Djangos Prüfung ist genauer, und sie ist die, die entscheidet.
    static func email(_ text: String) -> String {
        let gestrafft = straffen(text)
        if gestrafft.isEmpty { return emailFehlt }
        if !gestrafft.contains("@") { return emailOhneAffe }
        if gestrafft.hasPrefix("@") || gestrafft.hasSuffix("@") {
            return emailHalb
        }
        return ""
    }

    /// Länge und Gleichstand. Alles Weitere entscheidet der Server.
    ///
    /// **Die Mindestlänge wird nicht getippt, sondern übergeben.** Sie
    /// steht in den Einstellungen des Servers und kommt mit der Auskunft.
    /// Eine getippte Acht sagt „mindestens 8 Zeichen", während der
    /// Server zwölf verlangt -- und der Satz, der erklären soll, was
    /// fehlt, erklärt das Falsche.
    ///
    /// Ob ein Passwort zu üblich ist oder dem Benutzernamen ähnelt,
    /// prüft der Server. Beides braucht Listen und den Rest des
    /// Formulars.
    static func passwort(_ passwort: String, wiederholung: String,
                         mindestlaenge: Int) -> String {
        if passwort.isEmpty {
            return String(localized: "Ohne Passwort geht es nicht.")
        }
        if passwort.count < mindestlaenge {
            return String(localized: """
                Das Passwort ist zu kurz. Mindestens \(mindestlaenge) \
                Zeichen.
                """)
        }
        if passwort != wiederholung {
            return String(localized: "Die beiden Passwörter sind nicht gleich.")
        }
        return ""
    }
}
