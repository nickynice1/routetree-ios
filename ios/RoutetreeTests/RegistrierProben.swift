// ERZEUGT VON scripts/registrierung_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/registrierung.py. Was hier steht, hat
// der SERVER gerechnet: Aus dieser Eingabe wird genau dieser Satz.
// Leere `meldung` heißt „sieht in Ordnung aus, der Server entscheidet".
//
// DER WUNDE PUNKT SIND DIE FÄLLE MIT LEERRAUM AM RAND. Sie dürfen NICHT
// meckern: Djangos Formular schneidet ihn ab, und eine App, die hier
// abweist, lässt eine gültige Registrierung nicht durch -- der Server
// sieht die Anfrage nie, und niemand erfährt davon.
//
// Neu erzeugen:  ./scripts/registrierung_swift.py
// Geprüft von:   backend/designer/test_registrierung_swift.py
//                (Gleichstand, und dass der Server jeden Fall mit Meldung
//                 wirklich abweist)
//                RoutetreeTests/RegistrierblockTests.swift (Swift rechnet gleich)

import Foundation

enum RegistrierProben {

    /// Ein Feld, eine Eingabe und der Satz, den der Server dazu sagt.
    struct Fall {
        let feld: String
        let eingabe: String
        /// Leer heißt „nichts zu beanstanden".
        let meldung: String
    }

    static let faelle: [Fall] = [
        Fall(feld: "verein", eingabe: "Rostock Griffins", meldung: ""),
        Fall(feld: "verein", eingabe: "  Rostock Griffins  ", meldung: ""),
        Fall(feld: "verein", eingabe: "", meldung: "Ohne Vereinsnamen geht es nicht. Trag ein, unter welchem Namen ihr antretet."),
        Fall(feld: "verein", eingabe: "   ", meldung: "Ohne Vereinsnamen geht es nicht. Trag ein, unter welchem Namen ihr antretet."),
        Fall(feld: "verein", eingabe: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", meldung: ""),
        Fall(feld: "verein", eingabe: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", meldung: "Das ist zu lang. Höchstens 120 Zeichen."),
        Fall(feld: "verein", eingabe: "Füchse Köln e. V.", meldung: ""),
        Fall(feld: "mannschaft", eingabe: "U17", meldung: ""),
        Fall(feld: "mannschaft", eingabe: "", meldung: "Ohne Mannschaft hat das erste Playbook keinen Platz. Trag einen Namen ein, zum Beispiel U17."),
        Fall(feld: "mannschaft", eingabe: "\t", meldung: "Ohne Mannschaft hat das erste Playbook keinen Platz. Trag einen Namen ein, zum Beispiel U17."),
        Fall(feld: "mannschaft", eingabe: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", meldung: "Das ist zu lang. Höchstens 120 Zeichen."),
        Fall(feld: "name_im_team", eingabe: "Robin Bergmann", meldung: ""),
        Fall(feld: "name_im_team", eingabe: "Robin  Bergmann", meldung: ""),
        Fall(feld: "name_im_team", eingabe: "", meldung: "Ohne Namen findet dich im Kader niemand. Trag ein, wie dich dein Team nennt."),
        Fall(feld: "name_im_team", eingabe: " ", meldung: "Ohne Namen findet dich im Kader niemand. Trag ein, wie dich dein Team nennt."),
        Fall(feld: "name_im_team", eingabe: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", meldung: ""),
        Fall(feld: "name_im_team", eingabe: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", meldung: "Das ist zu lang. Höchstens 60 Zeichen."),
        Fall(feld: "benutzername", eingabe: "jamie", meldung: ""),
        Fall(feld: "benutzername", eingabe: "  jamie  ", meldung: ""),
        Fall(feld: "benutzername", eingabe: "jamie@example.org", meldung: ""),
        Fall(feld: "benutzername", eingabe: "jamie.kern+u17", meldung: ""),
        Fall(feld: "benutzername", eingabe: "Björn", meldung: ""),
        Fall(feld: "benutzername", eingabe: "Björn Müller", meldung: "Im Benutzernamen darf kein Leerzeichen stehen. Erlaubt sind Buchstaben, Ziffern und @ . + - _"),
        Fall(feld: "benutzername", eingabe: "ja\tmie", meldung: "Im Benutzernamen darf kein Leerzeichen stehen. Erlaubt sind Buchstaben, Ziffern und @ . + - _"),
        Fall(feld: "benutzername", eingabe: "", meldung: "Ohne Benutzernamen kannst du dich später nicht anmelden."),
        Fall(feld: "benutzername", eingabe: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", meldung: ""),
        Fall(feld: "benutzername", eingabe: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", meldung: "Das ist zu lang. Höchstens 150 Zeichen."),
        Fall(feld: "email", eingabe: "jamie@example.org", meldung: ""),
        Fall(feld: "email", eingabe: "  jamie@example.org  ", meldung: ""),
        Fall(feld: "email", eingabe: "", meldung: "Ohne E-Mail-Adresse gibt es keinen Weg zurück, wenn du dein Passwort vergisst."),
        Fall(feld: "email", eingabe: "jamie.example.org", meldung: "Da fehlt das @. Eine Adresse sieht aus wie name@verein.de."),
        Fall(feld: "email", eingabe: "@example.org", meldung: "Vor und hinter dem @ muss etwas stehen, zum Beispiel name@verein.de."),
        Fall(feld: "email", eingabe: "jamie@", meldung: "Vor und hinter dem @ muss etwas stehen, zum Beispiel name@verein.de."),
    ]

    /// Passwort, Wiederholung und die Mindestlänge, die der Server nennt.
    struct Passwortfall {
        let passwort: String
        let wiederholung: String
        let mindestlaenge: Int
        let meldung: String
    }

    static let passwoerter: [Passwortfall] = [
        Passwortfall(passwort: "Flagfootball2026!", wiederholung: "Flagfootball2026!", mindestlaenge: 8, meldung: ""),
        Passwortfall(passwort: "Flagfootball2026!", wiederholung: "Flagfootball2025!", mindestlaenge: 8, meldung: "Die beiden Passwörter sind nicht gleich."),
        Passwortfall(passwort: "", wiederholung: "", mindestlaenge: 8, meldung: "Ohne Passwort geht es nicht."),
        Passwortfall(passwort: "kurz", wiederholung: "kurz", mindestlaenge: 8, meldung: "Das Passwort ist zu kurz. Mindestens 8 Zeichen."),
        Passwortfall(passwort: "achtzehn", wiederholung: "achtzehn", mindestlaenge: 8, meldung: ""),
        Passwortfall(passwort: "achtzehn", wiederholung: "", mindestlaenge: 8, meldung: "Die beiden Passwörter sind nicht gleich."),
        Passwortfall(passwort: "zwoelfzeichen", wiederholung: "zwoelfzeichen", mindestlaenge: 14, meldung: "Das Passwort ist zu kurz. Mindestens 14 Zeichen."),
    ]

    /// Wie lang ein Feld sein darf. Die Zahlen gehören den Modellen.
    static let laengen: [(feld: String, zeichen: Int)] = [
        ("benutzername", 150),
        ("mannschaft", 120),
        ("name_im_team", 60),
        ("verein", 120),
    ]

    /// Der Leerraum, den beide Seiten wegschneiden -- buchstabengenau.
    static let leerraum = " \t\n\r\u{0B}\u{0C}\u{A0}"

    /// Die Felder, die diese Regel überhaupt kennt.
    static let felder: [String] = [
        "verein", "mannschaft", "name_im_team", "benutzername", "email",
    ]
}
