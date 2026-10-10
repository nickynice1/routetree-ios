import Foundation

/// Der Stapel der Abo-Stufen: welche Seiten es gibt, was auf jeder
/// steht, und welche man gerade hat (R117).
///
/// **Der Auftrag** (Niklas, 10.09.2026): „ich meinte das so das man docj
/// wenn man mehrere mannschaften jat kann man docj so hin und jer swipen
/// zwischen den mannschaften und so wünscje icj es mir beim abo modell
/// auch. demo version darunter funktion -> 8€ standard und darunter
/// funktion -> 15€ premium darunter funktion und denn gleich die
/// variante die man will das man die gleicj dort kaufen kann. weisst du?
/// und denn soll immer bei dem was man jat auch stejen ‚das jast du
/// aktuell'"
///
/// **Warum das hier steht und nicht in der Ansicht.** Es gibt keinen
/// Mac. Eine Regel in einer SwiftUI-Ansicht lässt sich nicht
/// ausprobieren, sondern nur behaupten, und die Rückmeldung vom Läufer
/// dauert eine halbe Stunde. Dieselbe Entscheidung wie bei
/// `Kachelblock` (R13), `Kaderblock` (B9) und `Zeichenblock` (B4).
///
/// **Was hier NICHT entschieden wird: was eine Stufe kostet und was sie
/// kann.** Beides sagt der Server (ADR-0006, ADR-0008). Hier wird nur
/// sortiert, zugeordnet und ausgewählt.
enum Stufenblock {

    /// Der Schlüssel der Demo. **Sie ist keine Stufe des Servers** --
    /// `abo.stufen()` kennt „basis" und „unbegrenzt", die Demo ist der
    /// Zustand davor. Als Seite gehört sie trotzdem dazu: Sie ist die,
    /// auf der die meisten stehen, und ohne sie fehlte der Vergleich.
    static let demo = "demo"

    /// Die beiden Laufzeiten (R118). Dieselben Wörter wie im Server
    /// (`abo.MONAT`, `abo.JAHR`) -- zwei Schreibweisen für dieselbe
    /// Laufzeit wären zwei Laufzeiten.
    static let monat = "monat"
    static let jahr = "jahr"

    /// Eine Seite des Stapels.
    struct Seite: Identifiable, Hashable {
        /// „demo", „basis" oder „unbegrenzt".
        let stufe: String
        /// Wie die Stufe heisst -- vom Server. `nil` bei der Demo und
        /// bei einem aelteren Server, der den Namen nicht schickt.
        let name: String?
        /// Die Produktkennung im App Store. Bei der Demo `nil` -- sie
        /// wird nicht gekauft.
        let produkt: String?
        // HIER STAND DER PREIS VOM SERVER („betragText"), und er war
        // der Rückfall, solange StoreKit noch nicht geantwortet hatte.
        // Weg seit R122: Er ist in Euro gerechnet und gilt nur für den
        // deutschen Store. Auf einem Gerät im US-Store las man erst
        // „8,00 €" und danach „$7.00".
        //
        // Das Feld ist NICHT nur ungenutzt, es ist absichtlich fort:
        // Was in einer Struktur steht, liest irgendwann wieder jemand
        // -- und dann steht der Euro-Preis wieder unter einem
        // Dollar-Knopf. Der Betrag kommt aus `Product.displayPrice`,
        // und ob einer dasteht, entscheidet `preistext`.
        /// Wie viele Monate die Jahreszahlung schenkt. `nil` beim
        /// Monat und bei der Demo.
        let geschenkt: Int?
        /// Steht der Verein gerade auf dieser Stufe?
        let aktuell: Bool
        /// Was diese Stufe kann -- die Zeilen der Gegenüberstellung,
        /// aus der Sicht DIESER Stufe.
        let leistungen: [Leistung]

        var id: String { stufe }
    }

    /// Eine Zeile unter einer Stufe: „Mannschaften -- beliebig viele".
    struct Leistung: Identifiable, Hashable {
        let was: String
        let wert: String

        var id: String { was }
    }

    /// Die Seiten des Stapels, in der Reihenfolge des Preises.
    ///
    /// **Die Demo steht vorn**, weil sie der Ausgangspunkt ist: Wer
    /// diesen Stapel aufmacht, steht in aller Regel darauf, und die
    /// erste Seite soll die sein, die er kennt.
    ///
    /// **Die Reihenfolge der Stufen kommt vom Server** und wird hier
    /// nicht sortiert. Der Server gibt sie nach dem Preis heraus; hier
    /// nach `betrag` zu sortieren wäre eine zweite Regel, die beim
    /// ersten Jahrespreis auseinanderläuft.
    static func seiten(_ abo: Modell.Abo,
                       laufzeit: String = monat) -> [Seite] {
        // DIE DEMO-SEITE FRAGT DIESELBE REGEL WIE ALLE ANDEREN
        // (18.09.2026).
        //
        // Hier stand `abo.vertrag == nil && abo.demo` ausgeschrieben --
        // eine zweite Regel fuer dieselbe Frage, neben `istAktuell`.
        // Genau davor warnt der Kommentar in `Kasse.swift`, und genau so
        // ist es gekommen: Als `istAktuell` lernte, dass ohne Vertrag
        // nichts gekauft ist, zog die Demo-Seite nicht mit. Der Verein
        // hatte dann NIRGENDS einen aktuellen Stand -- weder bei der
        // Demo noch bei einer bezahlten Stufe.
        var heraus = [Seite(stufe: demo, name: nil, produkt: nil,
                            geschenkt: nil,
                            aktuell: istAktuell(demo, laut: abo,
                                                laufzeit: laufzeit),
                            leistungen: leistungen(abo, stufe: demo))]
        for eintrag in abo.kaufbareStufen
        where eintrag.laufzeitOderMonat == laufzeit {
            heraus.append(Seite(
                stufe: eintrag.stufe,
                name: eintrag.name,
                produkt: eintrag.produkt,
                geschenkt: eintrag.geschenkt,
                aktuell: istAktuell(eintrag.stufe, laut: abo,
                                    laufzeit: laufzeit),
                leistungen: leistungen(abo, stufe: eintrag.stufe)))
        }
        return heraus
    }

    /// Welche Laufzeiten der Server überhaupt anbietet, in fester
    /// Reihenfolge.
    ///
    /// **Nicht geraten, sondern gezählt.** Solange bei Apple kein
    /// Jahresprodukt angelegt ist, gibt es hier nur den Monat -- und
    /// die Oberfläche zeigt dann keinen Umschalter statt eines, der auf
    /// eine leere Seite führt.
    static func laufzeiten(_ abo: Modell.Abo) -> [String] {
        let vorhanden = Set(abo.kaufbareStufen.map(\.laufzeitOderMonat))
        return [monat, jahr].filter(vorhanden.contains)
    }

    /// Steht der Verein auf dieser Stufe?
    ///
    /// **Die Demo ist der Sonderfall, und sie ist es in beide
    /// Richtungen.** Ein Verein auf Demo hat KEINE gekaufte Stufe --
    /// stünde „das hast du aktuell" trotzdem unter „basis", weil
    /// `Abo.stufe` dort aus dem Preismodell noch „basis" sagt, wäre das
    /// die eine Falschaussage, die einen Kauf verhindert: Wer glaubt,
    /// er habe schon das Standardabo, kauft es nicht.
    static func istAktuell(_ stufe: String, laut abo: Modell.Abo,
                           laufzeit: String = monat) -> Bool {
        // DER VERTRAG ZAEHLT, wenn der Server einen nennt (R118). Er
        // sagt, was GEKAUFT ist; `abo.stufe` sagt nur, in welche Stufe
        // die Zahl der Zugaenge faellt.
        if let vertrag = abo.vertrag {
            return stufe == vertrag.stufe && laufzeit == vertrag.laufzeit
        }
        // OHNE VERTRAG IST NICHTS GEKAUFT (18.09.2026).
        //
        // Niklas: „wenn du das bei premium so anpasst denn solltest du
        // es bei standard und demo auch so machen." Auf seinem
        // Bildschirm stand unter „Standard" der Satz „Du bezahlst diese
        // Stufe bereits" -- und damit kein Kaufknopf. Sein Verein steht
        // als `kunde` in der Tabelle, hat aber keinen laufenden
        // Vertrag: `abo.stufe` sagt „basis", weil ein Zugang nun einmal
        // in die Basis faellt.
        //
        // Das ist genau die Falschaussage, vor der der Absatz oben
        // warnt, nur eine Stufe hoeher: Wer glaubt, er habe das
        // Standardabo schon, kauft es nicht. Die Regel wurde damals fuer
        // `abo.demo` geschrieben -- und ein Verein ohne Vertrag, der
        // nicht auf „demo" steht, fiel durch.
        //
        // WORAN MAN DEN NEUEN SERVER ERKENNT: Er schickt
        // `apple_produkte`. Beide Felder kamen am 10.09.2026 zusammen.
        // Steht die Liste da und fehlt der Vertrag, ist das eine
        // Aussage und keine Luecke -- dann ist die Demo der aktuelle
        // Stand, und beide bezahlten Stufen sind zu haben.
        if abo.appleProdukte != nil { return stufe == demo }
        // Nur ein aelterer Server faellt auf die alte Regel zurueck.
        if abo.demo { return stufe == demo }
        return stufe != demo && abo.stufe == stufe
    }

    /// Was auf dieser Seite unter dem Preis steht.
    ///
    /// Die Gegenüberstellung des Servers hat je Zeile einen Wert JE
    /// STUFE. Hier wird der passende genommen -- nichts umformuliert
    /// und nichts erfunden.
    ///
    /// **Bis zum 10.09.2026 stand hier `stufe == demo ? zeile.demo :
    /// zeile.abo`**, also für Standard und Premium dieselbe Spalte.
    /// Niklas in TestFlight: „Beim Standard Abo ist dir wohl ein Fehler
    /// unterlaufen, da stimmen die Details nicht." Unter „Standard"
    /// stand fünfmal „unbegrenzt" -- unter anderem bei den Trainern mit
    /// Schreibrecht, wo Standard bis zu fünf trägt. Das ist genau die
    /// Zeile, die den Unterschied der beiden Stufen ausmacht.
    ///
    /// **Eine Zeile ohne Wert für diese Stufe fällt weg.** Ein älterer
    /// Server, der die Stufe nicht kennt, führt dann zu einer kürzeren
    /// Liste -- und nicht zu einer Zeile, unter der nichts steht oder,
    /// schlimmer, der Wert einer anderen Stufe.
    static func leistungen(_ abo: Modell.Abo, stufe: String) -> [Leistung] {
        abo.hebtAuf.compactMap { zeile in
            guard let wert = zeile.wert(fuer: stufe) else { return nil }
            return Leistung(was: zeile.was, wert: wert)
        }
    }

    // MARK: - Preis und Steuer (R122)

    /// Der Store, für den der Umsatzsteuerhinweis geschrieben ist.
    ///
    /// Drei Buchstaben, so wie Apple die Länder nennt.
    static let steuerStore = "DEU"

    /// Gehört der Umsatzsteuerhinweis unter diesen Preis?
    ///
    /// **Nur im deutschen Store.** Der Satz nennt die gesetzliche
    /// Umsatzsteuer von 19 % und steht dort, wo der Preis steht
    /// (§ 6 Abs. 1 PAngV) -- das ist deutsches Recht für deutsche
    /// Verbraucher. In jedem anderen Store ist er nicht bloss
    /// überflüssig, sondern unzutreffend: Der angezeigte Betrag
    /// enthält dann eine andere Steuer oder gar keine, und Verkäufer
    /// ist Apple.
    ///
    /// **Ohne bekannten Store steht nichts da.** Lieber keine Angabe
    /// als eine falsche -- und `nil` heisst hier wirklich „noch nicht
    /// bekannt", nicht „vermutlich Deutschland".
    static func steuerhinweisZeigen(storefront: String?) -> Bool {
        storefront == steuerStore
    }

    /// Was als Preis auf der Karte steht.
    ///
    /// **NUR was StoreKit sagt.** Dort steht, was in der Währung des
    /// Käufers wirklich abgebucht wird; der Text des Servers ist in
    /// Euro gerechnet und gilt nur für den deutschen Store.
    ///
    /// Bis zum 15.09.2026 war der Servertext der Rückfall. Auf einem
    /// Gerät im US-Store hiess das: erst „8,00 €", und sobald Apple
    /// geantwortet hatte, „$7.00". Ein Preis, der sich ändert, während
    /// man hinsieht, ist schlimmer als einer, der noch fehlt -- und
    /// über einem Kaufknopf ist er das Gegenteil einer Zusage.
    ///
    /// `nil` heisst: Es steht noch keiner da. Die Karte zeigt dann
    /// auch keinen Kaufknopf (`kaufbar` verlangt dasselbe Produkt).
    static func preistext(_ seite: Seite, ausStoreKit: String?) -> String? {
        guard seite.produkt != nil else { return nil }
        return ausStoreKit
    }

    // MARK: - Demo gegen Abo

    /// Ein Wert unter EINER bezahlten Stufe.
    struct Vergleichswert: Identifiable, Hashable {
        let stufe: String
        /// Wie die Stufe heisst -- vom Server. Rückfall: der Schlüssel,
        /// denn eine Spalte ohne Überschrift ist schlimmer als eine mit
        /// einem technischen Wort.
        let name: String
        let wert: String

        var id: String { stufe }
    }

    /// Eine Zeile der Gegenüberstellung „Demo gegen Abo".
    struct Vergleichszeile: Identifiable, Hashable {
        let was: String
        let demo: String
        /// Gesetzt, wenn ALLE bezahlten Stufen dasselbe sagen. Dann
        /// steht eine Spalte „Mit Abo" da statt zweier gleicher.
        let abo: String?
        /// Sonst je Stufe eine -- in der Reihenfolge des Servers.
        let jeStufe: [Vergleichswert]

        var id: String { was }
    }

    /// Demo gegen Abo, Zeile für Zeile.
    ///
    /// **Das ist die Rechnung, an der R119 gescheitert ist**, und
    /// deshalb steht sie hier und nicht in einer Ansicht. Bis zum
    /// 10.09.2026 schickte der Server eine Spalte „mit Abo" für BEIDE
    /// bezahlten Stufen, und unter „Standard" stand fünfmal
    /// „unbegrenzt" -- unter anderem bei den Trainern mit Schreibrecht,
    /// wo Standard bis zu fünf trägt. Niklas hat es in TestFlight
    /// gesehen: „Beim Standard Abo ist dir wohl ein Fehler unterlaufen,
    /// da stimmen die Details nicht."
    ///
    /// **Eine gemeinsame Spalte gibt es nur, wenn sie stimmt.** Sagen
    /// die bezahlten Stufen dasselbe, ist eine Spalte ehrlicher als
    /// zwei gleiche -- das ist die Mehrzahl der Zeilen, und drei
    /// Spalten sind auf einem Telefon zwei zu viel. Sobald sie sich
    /// unterscheiden, stehen sie einzeln da, mit ihrem Namen darüber.
    ///
    /// **Jede Stufe genau einmal.** `kaufbareStufen` führt sie je
    /// Laufzeit auf (Monat und Jahr, R118); für die Gegenüberstellung
    /// ist die Laufzeit gleichgültig, und zweimal „Standard"
    /// nebeneinander wäre eine Spalte, die niemand erklären kann.
    static func vergleich(_ abo: Modell.Abo) -> [Vergleichszeile] {
        var stufen: [(stufe: String, name: String)] = []
        for eintrag in abo.kaufbareStufen
        where !stufen.contains(where: { $0.stufe == eintrag.stufe }) {
            stufen.append((eintrag.stufe, eintrag.name ?? eintrag.stufe))
        }
        // Ohne hinterlegte Produkte kennt die App keine Stufen. Dann
        // bleibt, was der Server je Zeile ausser der Demo nennt -- sonst
        // stünde auf der Seite nur die Demo-Spalte und daneben nichts.
        if stufen.isEmpty {
            for zeile in abo.hebtAuf {
                for schluessel in zeile.werte.keys.sorted()
                where schluessel != demo
                    && !stufen.contains(where: { $0.stufe == schluessel }) {
                    stufen.append((schluessel, schluessel))
                }
            }
        }

        return abo.hebtAuf.map { zeile in
            let werte = stufen.compactMap { eintrag -> Vergleichswert? in
                guard let wert = zeile.wert(fuer: eintrag.stufe) else {
                    return nil
                }
                return Vergleichswert(stufe: eintrag.stufe,
                                      name: eintrag.name, wert: wert)
            }
            let einig = Set(werte.map(\.wert)).count == 1
            return Vergleichszeile(
                was: zeile.was,
                demo: zeile.wert(fuer: demo) ?? "",
                abo: einig ? werte.first?.wert : nil,
                jeStufe: werte)
        }
    }

    /// Lässt sich auf dieser Seite kaufen?
    ///
    /// Drei Bedingungen, und alle drei sind nötig:
    ///
    /// * Es gibt ein Produkt -- die Demo hat keins.
    /// * Der Verein steht nicht schon darauf. Ein zweites Abo derselben
    ///   Stufe wäre eine zweite Abbuchung.
    /// * StoreKit kennt das Produkt. Solange es noch lädt oder Apple
    ///   nicht antwortet, steht dort kein Knopf statt eines, der ins
    ///   Leere greift.
    static func kaufbar(_ seite: Seite, bekannteProdukte: [String]) -> Bool {
        guard let produkt = seite.produkt, !seite.aktuell else { return false }
        return bekannteProdukte.contains(produkt)
    }

    /// Auf welcher Seite der Stapel aufgeht.
    ///
    /// **Auf der eigenen.** Wer schon zahlt, soll nicht bei der Demo
    /// anfangen und sich zu seiner Stufe wischen müssen -- er sucht
    /// dort nach etwas anderem, nämlich nach dem, was die nächste Stufe
    /// mehr kann.
    static func anfangsseite(_ seiten: [Seite]) -> String? {
        seiten.first(where: \.aktuell)?.id ?? seiten.first?.id
    }
}
