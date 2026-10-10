import Foundation
import StoreKit

/// Der Kauf in der App -- StoreKit auf der einen, unser Server auf der
/// anderen Seite (R117).
///
/// **Der Auftrag:** „Ind warum kann ich aus der App heraus nicht gleich
/// kaufen?" (Niklas, 10.09.2026)
///
/// ## Die eine Regel, an der alles hängt
///
/// **Die App entscheidet NICHT, ob jemand bezahlt hat.** Sie führt den
/// Kauf, reicht Apples Unterschrift an den Server weiter und wartet auf
/// dessen Antwort. Was danach gilt, steht im Server (ADR-0006).
///
/// Das ist kein Formalismus. Würde die App selbst freischalten, wäre
/// die Freischaltung genau so haltbar wie das Gerät, auf dem sie steht
/// -- und zwar für alle Mannschaftsmitglieder mit, denn die
/// Freischaltung hängt am Verein. Ein einziges verändertes Telefon
/// schaltete damit den ganzen Verein frei.
///
/// ## Warum `Transaction.updates` mitläuft
///
/// Ein Kauf ist nicht mit dem Tippen fertig. Er kann später kommen (der
/// Vater bestätigt die Familienfreigabe), er kann sich wiederholen
/// (jeder Monat), und er kann von einem anderen Gerät stammen. Wer nur
/// das Ergebnis von `purchase()` verarbeitet, verliert genau die Fälle,
/// in denen niemand mehr zuschaut -- und der Verein hat bezahlt und
/// steht trotzdem vor der Demo.
///
/// ## Was `verifikation` bedeutet
///
/// StoreKit prüft die Unterschrift selbst und gibt `.verified` oder
/// `.unverified` heraus. Wir schicken trotzdem den ROHEN Beleg
/// (`jwsRepresentation`) an den Server und lassen ihn dort ein zweites
/// Mal prüfen. StoreKits Urteil zählt auf dem GERÄT, und das Gerät ist
/// die Seite, der man nicht glauben darf.
@MainActor
final class Kasse: ObservableObject {

    /// Was gerade zu haben ist, in der Reihenfolge des Servers.
    @Published private(set) var produkte: [Product] = []
    /// Läuft gerade ein Kauf? Dann wird kein zweiter angefangen.
    @Published private(set) var laeuft = false
    /// Der letzte Fehler, in Worten für den Menschen davor.
    @Published var fehler: String?

    /// Was der Server nach einem Kauf über den Verein sagt. Die
    /// Oberfläche zeigt danach den neuen Stand, ohne noch einmal zu
    /// fragen.
    @Published private(set) var stand: Modell.Abo?

    /// In welchem Store das Gerät steht -- als Länderkennung mit drei
    /// Buchstaben („DEU", „USA"), so wie Apple sie nennt (R122).
    ///
    /// **Wozu die App das wissen muss:** Der Umsatzsteuerhinweis
    /// („Alle Beträge sind Endbeträge und enthalten die gesetzliche
    /// Umsatzsteuer von 19 %.") ist deutsches Recht und steht so nur
    /// für den deutschen Store richtig. Bis zum 15.09.2026 stand er
    /// unter JEDEM Preis in JEDEM Land -- Niklas hat ihn in TestFlight
    /// unter „$7.00" gesehen. Wer in den USA kauft, zahlt keine
    /// deutsche Umsatzsteuer, und Verkäufer ist dort ohnehin Apple.
    ///
    /// `nil` heisst „noch nicht bekannt" und nicht „irgendein Land":
    /// Ohne Kenntnis wird nichts behauptet.
    @Published private(set) var storefront: String?

    private var lauscher: Task<Void, Never>?
    private var anmeldung: Anmeldung?
    private var verein: Int?

    /// Woran diese Kasse hängt -- die Anmeldung und der Verein.
    ///
    /// **Nicht im `init`, und das hat einen Grund.** Die `Anmeldung`
    /// ist ein `EnvironmentObject` und steht im `init` einer Ansicht
    /// noch nicht zur Verfügung. Sie dort zu kopieren hiesse ausserdem,
    /// ein Zugriffstoken zu kopieren -- und das ist nach einer halben
    /// Stunde abgelaufen. Gefragt wird deshalb bei jedem Kauf frisch.
    ///
    /// Mehrfach aufzurufen ist ausdrücklich erlaubt: Der Verein lässt
    /// sich in der App wechseln. Der Lauscher wird dabei nur EINMAL
    /// gestartet.
    func verbinden(anmeldung: Anmeldung, verein: Int?) {
        self.anmeldung = anmeldung
        self.verein = verein
        guard lauscher == nil else { return }
        // LAUSCHEN, nicht nur auf das Ergebnis von `purchase()` warten.
        // Apple stellt einen Vorgang auch später zu -- wenn die
        // Familienfreigabe kommt, bei jeder Verlängerung, und von einem
        // anderen Gerät.
        lauscher = Task { [weak self] in
            for await ergebnis in Transaction.updates {
                await self?.melden(ergebnis)
            }
        }
    }

    /// Den Lauscher beenden.
    ///
    /// **Und zwar ausdrücklich, nicht im `deinit`.** Ein `deinit` läuft
    /// ausserhalb des Hauptakteurs und käme an `lauscher` je nach
    /// Übersetzerfassung gar nicht heran -- ein Bau, der erst auf dem
    /// Läufer scheitert und eine halbe Stunde kostet. Der Aufrufer
    /// beendet ihn, wenn das Blatt geht; `for await` läuft sonst
    /// endlos weiter, auch wenn niemand mehr zusieht.
    func loesen() {
        lauscher?.cancel()
        lauscher = nil
    }

    // --- Was zu haben ist -------------------------------------------------

    /// Die Produkte bei Apple nachschlagen.
    ///
    /// **Die Kennungen kommen vom Server** und stehen nicht in Swift
    /// (ADR-0010). Ist die Liste leer, ist sie leer: Dann zeigt die
    /// Oberfläche keinen Kaufknopf statt eines, der ins Leere greift.
    ///
    /// **Die Reihenfolge des Servers bleibt.** `Product.products` gibt
    /// keine bestimmte zurück, und „unbegrenzt vor Basis" wäre auf dem
    /// Bildschirm eine andere Aussage.
    func laden(_ gewuenscht: [Modell.AppleProdukt]) async {
        let kennungen = gewuenscht.map(\.produkt)
        guard !kennungen.isEmpty else {
            produkte = []
            return
        }
        // WO DAS GERÄT STEHT, ZUERST (R122). Danach steht fest, ob der
        // Steuerhinweis unter den Preis gehört -- und der steht neben
        // der Zahl, nicht danach.
        storefront = await Storefront.current?.countryCode
        do {
            let gefunden = try await Product.products(for: kennungen)
            produkte = kennungen.compactMap { kennung in
                gefunden.first { $0.id == kennung }
            }
        } catch {
            // KEIN FEHLERTEXT AUF DEM BILDSCHIRM. Dass die Preise nicht
            // laden, ist kein Fehler des Trainers und keiner, den er
            // beheben kann. Er sieht dann die Stufen ohne Kaufknopf --
            // dieselbe Anzeige wie ohne hinterlegte Produkte.
            produkte = []
        }
    }

    // „Welche Stufe hat der Verein gerade?" steht NICHT hier, sondern
    // in `Stufenblock.istAktuell`. Sie stand kurz an beiden Stellen,
    // und die hiesige Fassung war schon falsch: Sie hätte einem Verein
    // auf Demo „das hast du aktuell" unter die Basisstufe geschrieben,
    // weil `Abo.stufe` dort aus dem Preismodell „basis" sagt. Zwei
    // Regeln für dieselbe Frage, und die zweite verhindert einen Kauf.

    // --- Kaufen -----------------------------------------------------------

    /// Kaufen -- und erst dann fertig, wenn der Server es bestätigt hat.
    ///
    /// **Kein `finish()` vor der Antwort des Servers.** Ein
    /// abgeschlossener Vorgang wird von Apple nicht noch einmal
    /// zugestellt. Wer ihn abschliesst, bevor der Server ihn kennt,
    /// hat bei einem Netzabbruch einen bezahlten Kauf, von dem niemand
    /// mehr erfährt -- und der Käufer sieht die Abbuchung.
    ///
    /// **Warum hier eine Bedienspur mitläuft (18.09.2026).**
    ///
    /// Niklas: „es passiert trotzdem nix wenn ich auf jetzt buchen
    /// tippe. Also wirklich einfach gar nichts." Von aussen sind
    /// „der Finger kommt nicht an" und „StoreKit antwortet nicht"
    /// dasselbe Bild: nichts. Auf dem Server war der Messwert ein
    /// Nichts zweiter Art -- null Aufrufe von `/api/v1/abo/apple/`.
    ///
    /// Zwei Nichtse lassen sich nicht unterscheiden, also musste ein
    /// Etwas her. Die Spur schreibt, DASS getippt wurde und WIE der
    /// Kauf ausging -- Handgriffe, kein Inhalt, und nur mit
    /// Einwilligung (`Konto.bedienspur`). Ohne sie wäre die nächste
    /// Runde wieder eine Vermutung, und eine Vermutung kostet hier eine
    /// halbe Stunde Laufzeit auf einem fremden Rechner.
    func kaufen(_ produkt: Product) async {
        guard !laeuft else {
            spur("stufen", "kauf_schon_unterwegs")
            return
        }
        laeuft = true
        fehler = nil
        spur("stufen", "kauf_getippt", produkt.id)
        let begonnen = Date()
        defer { laeuft = false }

        do {
            switch try await produkt.purchase() {
            case .success(let verifikation):
                spur("stufen", "kauf_erfolg")
                await melden(verifikation)
            case .userCancelled:
                // EIN ABBRUCH IN UNTER EINER SEKUNDE IST KEINER.
                //
                // StoreKit meldet `userCancelled` auch dann, wenn der
                // Kaufdialog gar nicht erscheinen konnte -- am
                // häufigsten, weil In-App-Käufe in der Bildschirmzeit
                // gesperrt sind. Für den Menschen davor sieht das aus
                // wie nichts, und „nichts" ist die Meldung, die niemand
                // weiterbringt.
                //
                // Die Zeit ist der Unterschied: Wer wirklich abbricht,
                // braucht dafür den Dialog und mindestens eine Sekunde.
                let dauer = Date().timeIntervalSince(begonnen)
                spur("stufen", "kauf_abgebrochen",
                     String(format: "%.2f", dauer))
                if dauer < 1 {
                    fehler = String(localized: """
                        Der Kaufdialog ist gar nicht erst erschienen. \
                        Meist liegt das an einer Sperre: Einstellungen → \
                        Bildschirmzeit → Beschränkungen → Käufe im \
                        iTunes & App Store → In-App-Käufe erlauben.
                        """)
                }
                // Ein echter Abbruch bleibt ohne Meldung. Wer sich
                // entschieden hat, braucht keine Nachfrage.
            case .pending:
                spur("stufen", "kauf_wartet")
                // Familienfreigabe: Der Kauf hängt an einer
                // Zustimmung, die anderswo passiert. `Transaction.updates`
                // fängt ihn auf, sobald sie da ist.
                fehler = String(localized: """
                    Der Kauf wartet noch auf eine Bestätigung. Wir \
                    schalten frei, sobald sie da ist.
                    """)
            @unknown default:
                spur("stufen", "kauf_unbekannt")
                fehler = String(localized: "Der Kauf ist nicht durchgegangen.")
            }
        } catch {
            // DIE ART DES FEHLERS, NICHT SEIN TEXT. Der Text kann einen
            // Produktnamen oder einen Preis tragen; die Art ist
            // `StoreKitError` oder `PurchaseError` und sagt für die
            // Suche dasselbe, ohne etwas mitzunehmen.
            spur("stufen", "kauf_fehler", String(describing: type(of: error)))
            fehler = error.localizedDescription
        }
    }

    /// Käufe wiederherstellen -- Apples Richtlinie 3.1.1 verlangt den
    /// Knopf.
    ///
    /// Wer das Telefon wechselt, hat sein Abo nicht verloren, und die
    /// App muss einen Weg zeigen, das klarzustellen, ohne ein zweites
    /// Mal zu zahlen.
    func wiederherstellen() async {
        guard !laeuft else { return }
        laeuft = true
        fehler = nil
        defer { laeuft = false }

        for await ergebnis in Transaction.currentEntitlements {
            await melden(ergebnis, abschliessen: false)
        }
    }

    // --- Was danach passiert ----------------------------------------------

    /// Einen Vorgang an den Server melden und den neuen Stand übernehmen.
    private func melden(_ ergebnis: VerificationResult<Transaction>,
                        abschliessen: Bool = true) async {
        // AUCH DEN UNGEPRÜFTEN SCHICKEN. StoreKits Urteil gilt auf dem
        // Gerät; entscheiden soll der Server, der den Beleg gleich
        // selbst prüft. Ein hier weggeworfener Vorgang wäre ein Kauf,
        // der nie ankommt -- und der Server hätte nie erfahren, dass es
        // ihn gab.
        let vorgang: Transaction
        switch ergebnis {
        case .verified(let geprueft): vorgang = geprueft
        case .unverified(let roh, _): vorgang = roh
        }

        guard let anmeldung else {
            fehler = String(localized: """
                Wir konnten den Kauf nicht zuordnen. Melde dich an und \
                versuch es noch einmal – bezahlt hast du bereits.
                """)
            return
        }

        do {
            // DAS TOKEN WIRD JETZT GEHOLT und nicht vorher gemerkt:
            // `gueltigesToken` erneuert es, wenn es abgelaufen ist. Ein
            // gemerktes wäre nach einer halben Stunde ungültig -- und
            // zwar genau im letzten Schritt eines bezahlten Kaufs.
            stand = try await Abospeicher.appleKaufMelden(
                vorgang: ergebnis.jwsRepresentation, verein: verein,
                token: try await anmeldung.gueltigesToken())
            // ERST JETZT. Ab hier weiss der Server Bescheid, und Apple
            // darf den Vorgang vergessen.
            if abschliessen { await vorgang.finish() }
        } catch {
            fehler = String(localized: """
                Der Kauf ist durch, wir konnten ihn aber noch nicht \
                freischalten. Wir versuchen es beim nächsten Start \
                wieder.
                """)
        }
    }
}

// `VerificationResult.jwsRepresentation` gibt es bei StoreKit 2 fertig,
// und zwar in BEIDEN Fällen -- auch bei `.unverified`. Eine eigene Hülle
// darum stand hier kurz und war ein Fehler: Sie hätte sich selbst
// aufgerufen. Der rohe Beleg wird oben direkt gelesen.

/// Die Adresse, an der ein App-Store-Kauf abgeliefert wird.
enum Abospeicher {

    /// Den signierten Vorgang an den Server geben. Zurück kommt, was
    /// danach gilt.
    ///
    /// **Ohne Verein ist kein Fehler.** Der Server sucht ihn dann selbst
    /// -- er muss ihn ohnehin prüfen, und die App weiss ihn nicht an
    /// jeder Stelle, an der ein Vorschlag erscheint. Eine erfundene
    /// Kennung wäre die schlechtere Antwort: Sie schaltete den falschen
    /// Verein frei.
    static func appleKaufMelden(vorgang: String, verein: Int?,
                                token: String) async throws -> Modell.Abo {
        var rumpf: [String: Any] = ["vorgang": vorgang]
        if let verein { rumpf["verein"] = verein }
        return try await Server.hole(
            Server.anfrage("/api/v1/abo/apple/", methode: "POST",
                           rumpf: rumpf, token: token),
            als: Modell.Abo.self)
    }
}
