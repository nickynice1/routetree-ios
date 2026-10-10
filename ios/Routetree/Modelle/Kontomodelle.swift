import Foundation

// Was an einem Konto und an einem Abo hängt (B12).
//
// WARUM DAS NEBEN `Modelle.swift` STEHT UND NICHT DARIN. Dort steht, was
// ein Playbook ist. Hier steht, was ein Verein zahlt und wie jemand
// überhaupt hereinkommt -- ein anderes Thema, und eines, das genau
// zweimal im Jahr angefasst wird. Eine Datei mit beidem hätte zwei
// Themen und keins davon klar.
//
// WAS HIER NICHT PASSIERT: Es wird kein Preis gerechnet und keiner
// gesetzt. Beides sagt der Server (ADR-0006); die App zeigt es an.

extension Modell {

    /// Was ein Abo kostet und was es aufhebt -- gerechnet vom Server.
    ///
    /// **Die Preise kommen als Zahl UND als Text.** Die Zahl ist in
    /// ganzen Cent, der Text ist der, den auch die Webseite zeigt. Die
    /// App setzt keinen Preis zusammen: Eine zweite Schreibweise sähe
    /// nicht falsch aus, sondern nur anders -- „5,00 €" auf dem Rechner,
    /// „€5.00" auf dem Telefon --, und der Vorstand hätte zwei Angebote
    /// vor sich.
    ///
    /// `nil` heißt „noch nicht festgelegt" und ausdrücklich NICHT
    /// „kostenlos". Dann nennt die App keine Zahl, sondern den Weg zu
    /// einem Angebot.
    struct Abo: Decodable, Hashable {
        /// Steht dieser Verein auf Demo? Bei der Registrierung `false`:
        /// Dort gibt es noch keinen Verein.
        let demo: Bool
        let preisJePlatz: Int?
        let preisJePlatzText: String?
        let preisGrundgebuehr: Int?
        let grundgebuehrText: String?
        let plaetzeInklusive: Int
        /// Menschen mit Schreibrecht. Zuschauer kosten nichts.
        let plaetze: Int
        let monatlich: Int?
        let monatlichText: String?
        let waehrung: String

        // ZWEI STUFEN STATT EINES PLATZPREISES (R17).
        //
        // `modell` sagt, welche Rechnung gilt: „stufen" oder
        // „plaetze". Ohne das zeigte die App den Platzpreis aus dem
        // Stufenmodell -- und der ist dort null. „Je weiterem Platz
        // 0,00 €" unter einem Preis, der beim sechsten Zugang um sieben
        // Euro springt, ist schlimmer als gar keine Angabe.
        let modell: String?
        /// „basis" oder „unbegrenzt" -- in welcher Stufe der Verein
        /// gerade steht. Null im alten Platzmodell.
        let stufe: String?
        let preisBasis: Int?
        let preisUnbegrenzt: Int?
        let basisPlaetze: Int?
        let basisText: String?
        let unbegrenztText: String?

        /// Rechnet dieser Verein nach Stufen?
        var nachStufen: Bool { modell == "stufen" }
        let hebtAuf: [Abozeile]
        /// „Wir schalten frei und rechnen mit dem Verein ab."
        let hinweis: String
        let kontakt: String
        /// Der Betreff für die Mail. Vom Server, mit dem Vereinsnamen
        /// darin -- sonst lautet die erste Rückfrage „Für welchen
        /// Verein?", und das kostet zwei Tage.
        let betreff: String

        /// Ob überhaupt ein Preis hinterlegt ist.
        ///
        /// Gefragt wird am Text und nicht an der Zahl: Eine hinterlegte
        /// Grundgebühr von 0 mit einem Preis je Platz ergibt eine
        /// Rechnung, eine fehlende Angabe ergibt `nil`. Der Server
        /// unterscheidet beides schon; die App soll es nicht noch einmal
        /// ableiten.
        var preisBekannt: Bool { monatlichText != nil }

        // `kaufweg` wird ABSICHTLICH NICHT GELESEN. Der Server schickt
        // dort `null`, und zwar dauerhaft: Ein Weg AUS der App HERAUS
        // ist nach Apples Richtlinie 3.1.1 ein Ablehnungsgrund. Ein Feld
        // im Modell wäre die Einladung, daraus irgendwann einen Knopf zu
        // machen.

        /// „Alle Preise enthalten 19 % Umsatzsteuer." -- oder was der
        /// Betreiber dort hinterlegt hat (R110.2).
        ///
        /// **§ 6 Abs. 1 PAngV verlangt ihn dort, wo der Preis steht.**
        /// Solange die App keine Preise zeigte, war das eine Frage der
        /// Webseite; seit dem Stufenstapel zeigt sie welche.
        ///
        /// Optional wie `appleProdukte`, und aus demselben Grund: Ein
        /// älterer Server kennt das Feld nicht, und daran soll nicht
        /// der ganze Vorschlag scheitern.
        let steuerhinweis: String?

        /// Was sich IN der App kaufen lässt -- der einzige Weg, den
        /// Apple auf dem iPhone zulässt (R117).
        ///
        /// **Die Kennungen kommen vom Server und stehen nicht in
        /// Swift.** Wer bei Apple ein Produkt umbenennt, soll das nicht
        /// in einem Bau nachziehen müssen, der eine halbe Stunde dauert
        /// und über einen fremden Läufer geht (ADR-0010).
        ///
        /// **Optional, und das ist kein Versehen.** Eine App im Store
        /// spricht mit dem Server, der gerade läuft -- auch mit einem
        /// älteren, der das Feld noch nicht kennt. Wäre es
        /// verpflichtend, bräche dort das Entschlüsseln des GANZEN
        /// Vorschlags, und der Verein sähe statt eines fehlenden
        /// Kaufknopfes gar nichts mehr.
        let appleProdukte: [AppleProdukt]?

        /// Dieselbe Liste, ohne dass jede Sicht das `nil` behandeln muss.
        var kaufbareStufen: [AppleProdukt] { appleProdukte ?? [] }

        /// WAS WIRKLICH GEKAUFT IST -- und nicht, was die Platzzahl
        /// ergäbe (R118).
        ///
        /// `stufe` weiter oben kommt aus der RECHNUNG: Sie sagt, in
        /// welche Stufe die Zahl der Zugänge fällt. Das ist die richtige
        /// Auskunft für „was würde es kosten" und die falsche für „was
        /// habe ich". `nil` heißt: kein laufender Vertrag.
        let vertrag: Vertragsstand?

        /// Den Vorschlag aus einer Absage lesen (403 an der Grenze).
        ///
        /// **Eine Stelle und nicht zwei.** Die Grenze schlägt beim
        /// Playbook an und beim Play, also in zwei Speichern. Zwei
        /// Entschlüsselungen desselben Rumpfes wären zwei Gelegenheiten,
        /// den Schlüssel falsch zu schreiben -- und ein falsch
        /// geschriebener ergibt `nil`, sieht also aus wie „der Server
        /// hat nichts mitgeschickt".
        ///
        /// `nil` heißt genau das und ist kein Fehler: Dann zeigt die App
        /// den Satz des Servers ohne den Weg zum Vorschlag.
        static func ausAbsage(_ rumpf: Data?) -> Abo? {
            guard let rumpf else { return nil }
            return try? Server.entschluessler
                .decode(Absage.self, from: rumpf).abo
        }

        /// Der Rumpf einer Absage, soweit die App ihn liest.
        private struct Absage: Decodable {
            let abo: Abo?
        }

        enum CodingKeys: String, CodingKey {
            case demo, plaetze, waehrung, hinweis, kontakt, betreff
            case preisJePlatz = "preis_je_platz"
            case preisJePlatzText = "je_platz_text"
            case preisGrundgebuehr = "preis_grundgebuehr"
            case grundgebuehrText = "grundgebuehr_text"
            case plaetzeInklusive = "plaetze_inklusive"
            case modell, stufe
            case preisBasis = "preis_basis"
            case preisUnbegrenzt = "preis_unbegrenzt"
            case basisPlaetze = "basis_plaetze"
            case basisText = "basis_text"
            case unbegrenztText = "unbegrenzt_text"
            case monatlich
            case monatlichText = "monatlich_text"
            case hebtAuf = "hebt_auf"
            case appleProdukte = "apple_produkte"
            case vertrag, steuerhinweis
        }
    }

    /// Was ein Verein wirklich gekauft hat (R118).
    struct Vertragsstand: Decodable, Hashable {
        /// „basis" oder „unbegrenzt".
        let stufe: String
        /// „monat" oder „jahr".
        let laufzeit: String

        var istJahr: Bool { laufzeit == "jahr" }
    }

    /// Eine Stufe, wie sie im App Store heißt (R117).
    ///
    /// **Die App rechnet auch hier keinen Preis.** Der Betrag steht als
    /// fertiger Text daneben, damit die Liste etwas zeigen kann, bevor
    /// StoreKit geantwortet hat. Sobald `Product` da ist, gilt DESSEN
    /// `displayPrice`: Nur Apple weiß, was in der Währung des Käufers
    /// wirklich abgebucht wird -- und was auf der Kaufseite steht, muss
    /// stimmen.
    struct AppleProdukt: Decodable, Hashable, Identifiable {
        /// „basis" oder „unbegrenzt" -- dieselben Schlüssel wie in
        /// `Abo.stufe`. Daran erkennt die App, welche Stufe der Verein
        /// gerade hat.
        let stufe: String
        /// Wie die Stufe heisst -- **vom Server** (10.09.2026).
        ///
        /// Sie stand bis dahin in der App: „Standard" und „Premium",
        /// zugeordnet in `StufenAnsicht.name(_:)`. Im Browser hiessen
        /// dieselben Stufen „Basis" und „Unbegrenzt". Zwei Namen fuer
        /// eine Sache, und auf Apples Abrechnung stand der dritte.
        ///
        /// Optional, weil ein aelterer Server ihn nicht schickt. Dann
        /// bleibt die alte Zuordnung als Rueckfall -- besser ein
        /// veralteter Name als gar keine Ueberschrift.
        let name: String?
        /// „monat" oder „jahr" (R118).
        ///
        /// **Optional, wie `appleProdukte` selbst.** Ein älterer Server
        /// kennt nur Monatsabos und schickt das Feld nicht; es dann als
        /// verpflichtend zu lesen, machte den ganzen Vorschlag
        /// unlesbar. Fehlt es, ist es der Monat -- die Laufzeit, die es
        /// vorher als einzige gab.
        let laufzeit: String?
        /// Die Produktkennung im App Store.
        let produkt: String
        /// Der Preis, wie ihn auch die Webseite zeigt. Ein Rückfall,
        /// kein Ersatz.
        let betragText: String?
        /// Wie viele Monate die Jahreszahlung schenkt. Beim Monat `nil`.
        let geschenkt: Int?

        var id: String { produkt }

        /// Die Laufzeit, ohne dass jede Sicht das `nil` behandeln muss.
        var laufzeitOderMonat: String { laufzeit ?? "monat" }
        var istJahr: Bool { laufzeitOderMonat == "jahr" }

        enum CodingKeys: String, CodingKey {
            case stufe, name, produkt, laufzeit, geschenkt
            case betragText = "betrag_text"
        }
    }

    /// Eine Zeile der Gegenüberstellung -- **je Stufe ein Wert**.
    ///
    /// Ausgerechnet und nicht in der App hinterlegt: Die Zahlen der Demo
    /// sind im Betrieb änderbar, und wie viele Schreibrechte die
    /// Basisstufe trägt, steht in derselben Einstellung, nach der der
    /// Server die Grenze zieht.
    ///
    /// **`werte` statt `demo`/`abo` (10.09.2026).** Der Server schickte
    /// bis dahin zwei Spalten: was die Demo kann und was „ein Abo"
    /// aufhebt. Für die Preisseite im Browser geht das auf. Für diese
    /// App nicht -- sie zeigt je Stufe eine eigene Karte und nahm für
    /// Standard dieselbe Spalte wie für Premium. Niklas hat es in
    /// TestFlight gesehen: „Beim Standard Abo ist dir wohl ein Fehler
    /// unterlaufen, da stimmen die Details nicht." Unter „Standard"
    /// stand fünfmal „unbegrenzt", obwohl Standard bis zu fünf Trainer
    /// mit Schreibrecht trägt und nicht beliebig viele.
    struct Abozeile: Decodable, Hashable, Identifiable {
        let was: String
        /// Der Wert je Stufenschlüssel: „demo", „basis", „unbegrenzt".
        let werte: [String: String]

        var id: String { was }

        /// Was unter DIESER Stufe steht.
        ///
        /// `nil` heisst: Der Server kennt die Stufe nicht. Dann steht
        /// dort nichts statt eines Wertes, der einer anderen Stufe
        /// gehört -- genau der Fehler, aus dem diese Struktur entstanden
        /// ist.
        func wert(fuer stufe: String) -> String? { werte[stufe] }
    }

    /// Was die App wissen muss, BEVOR jemand das Formular ausfüllt.
    struct Registrierauskunft: Decodable {
        /// Ohne Impressum gibt es die Registrierung nicht (§ 5 DDG).
        /// Dann zeigt die App den Knopf gar nicht erst.
        let moeglich: Bool
        let demo: Demoumfang
        let abo: Abo
        let passwortMindestlaenge: Int
        let passwortHinweis: String
        /// Wie lang ein Feld sein darf -- je Feldname. `Registrierblock`
        /// rechnet damit; eine Zahl in der App wäre die zweite Fassung.
        let laengen: [String: Int]
        let kontakt: String

        enum CodingKeys: String, CodingKey {
            case moeglich, demo, abo, laengen, kontakt
            case passwortMindestlaenge = "passwort_mindestlaenge"
            case passwortHinweis = "passwort_hinweis"
        }
    }

    /// Was die Demo hergibt. Aus der Konfiguration des Servers.
    struct Demoumfang: Decodable {
        let playbooks: Int
        let playsJePlaybook: Int
        /// Der Streifen, der im Ausdruck steht. Der eigentliche Riegel.
        let streifen: String

        enum CodingKeys: String, CodingKey {
            case playbooks, streifen
            case playsJePlaybook = "plays_je_playbook"
        }
    }

    /// Was nach einer Registrierung zurückkommt -- ohne die Token.
    ///
    /// Die Token liest `Anmeldung.Tokenpaar` aus derselben Antwort. Zwei
    /// Sichten auf dieselben Bytes und nicht ein Modell, das beides
    /// trägt: Wer angemeldet ist, entscheidet `Anmeldung` und sonst
    /// niemand.
    struct Neuanmeldung: Decodable {
        let verein: NeuerVerein
        let team: Kurzteam
        let abo: Abo
        let meldung: String
    }

    struct NeuerVerein: Decodable {
        let id: Int
        let name: String
        let demo: Bool
    }

    struct Kurzteam: Decodable {
        let id: Int
        let name: String
    }

    /// Was nach einem Beitritt mit neuem Konto zurückkommt.
    struct Neubeitritt: Decodable {
        let team: Beitrittsteam
        let rolleText: String
        let name: String
        let meldung: String

        enum CodingKeys: String, CodingKey {
            case team, name, meldung
            case rolleText = "rolle_text"
        }
    }

    struct Beitrittsteam: Decodable {
        let id: Int
        let name: String
        let verein: String
    }
}
