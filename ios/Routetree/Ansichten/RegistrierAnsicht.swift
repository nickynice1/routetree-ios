import SwiftUI

/// Ein Konto anlegen -- mit eigenem Verein (B12).
///
/// **Warum es das gibt.** Seit A1 (21.08.) legt sich ein Verein selbst
/// an; im Browser heißt der Knopf auf der Startseite „Kostenlos
/// ausprobieren". In der App stand bis B12 das Gegenteil: eine
/// Anmeldemaske und der Satz „Zugänge vergibt dein Verein". Wer die App
/// im Store fand, konnte sie nicht benutzen und erfuhr auch nicht, wie.
///
/// **Die Beanstandung kommt sofort, die Entscheidung vom Server.**
/// `Registrierblock` beurteilt die Form der Eingabe, während jemand
/// tippt -- und nur das, was der Server sicher auch ablehnt. Ob es den
/// Vereinsnamen schon gibt, ob der Benutzername frei ist und ob das
/// Passwort taugt, sagt der Server. Ein Formular, das erst nach dem
/// Abschicken meckert, meckert an Feld zwei, das man längst nicht mehr
/// sieht; eines, das strenger ist als der Server, lässt eine gültige
/// Registrierung gar nicht erst durch.
///
/// **Am Ende steht der Abo-Vorschlag, nicht die Playbook-Liste.** A3,
/// wörtlich: „erst innerhalb der registration ein abo vorgeschlagen".
/// Deshalb wird das Tokenpaar erst übernommen, wenn dort „Weiter"
/// gedrückt ist: Vorher wechselt die App nicht in den angemeldeten
/// Zustand, und der Vorschlag verschwindet nicht unter dem Finger.
struct RegistrierAnsicht: View {
    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen

    @State private var auskunft: Modell.Registrierauskunft?
    @State private var ladefehler: String?

    @State private var verein = ""
    @State private var mannschaft = ""
    @State private var vorname = ""
    @State private var nachname = ""
    @State private var email = ""
    @State private var benutzername = ""
    @State private var passwort = ""
    @State private var wiederholung = ""

    @FocusState private var feld: Feld?
    @State private var stand = Formularstand()
    /// Was nach dem Anlegen dasteht -- bis „Weiter" gedrückt ist.
    @State private var fertig: Fertig?

    private enum Feld: Hashable, CaseIterable {
        case verein, mannschaft, vorname, nachname, email
        case benutzername, passwort, wiederholung

        /// Wie das Feld an der Schnittstelle heißt. Ein zweiter
        /// Namenssatz wäre die Stelle, an der die Absage des Servers
        /// unter der falschen Zeile landet.
        var kennung: String {
            switch self {
            case .verein: return "verein"
            case .mannschaft: return "mannschaft"
            case .vorname: return "vorname"
            case .nachname: return "nachname"
            case .email: return "email"
            case .benutzername: return "benutzername"
            case .passwort: return "passwort"
            case .wiederholung: return "passwort_wiederholung"
            }
        }
    }

    private struct Fertig: Identifiable {
        let id = UUID()
        let paar: Anmeldung.Tokenpaar
        let ergebnis: Modell.Neuanmeldung
    }

    var body: some View {
        NavigationStack {
            inhalt
                .scrollContentBackground(.hidden)
                .background(Grundflaeche())
                .navigationTitle("Kostenlos ausprobieren")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Abbruchknopf { schliessen() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Fertigknopf(name: String(localized: "Anlegen")) {
                            Task { await anlegen() }
                        }
                            .disabled(stand.laeuft || auskunft == nil)
                    }
                }
        }
        .task { await auskunftHolen() }
        // `sheet(item:)` und keine eigene Hülle: `Fertig` trägt seine
        // Kennung selbst. Eine Hülle, die bei jedem Auswerten eine neue
        // UUID bekäme, gäbe dem Blatt in jedem Bilddurchlauf eine neue
        // Identität -- und SwiftUI baut es dann immer wieder neu auf.
        .sheet(item: $fertig) { ab in
            AboAnsicht(abo: ab.ergebnis.abo,
                       titel: String(localized: "Willkommen"),
                       weiterText: String(localized: "Los geht's"),
                       meldung: ab.ergebnis.meldung) {
                // ERST HIER ist jemand angemeldet. Damit steht der
                // Vorschlag wirklich am Ende der Registrierung und nicht
                // auf einer Seite, die man erst suchen muss.
                anmeldung.uebernehmen(ab.paar)
            }
            .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        if let auskunft, auskunft.moeglich {
            formular(auskunft)
        } else if let auskunft, !auskunft.moeglich {
            // Ohne Impressum gibt es die Registrierung nicht (§ 5 DDG).
            // Der Knopf wird gar nicht erst gezeigt; wer trotzdem hier
            // landet, bekommt den Weg und keine leere Maske.
            hinweisSeite(String(localized:
                "Registrierung ist gerade nicht möglich."),
                         auskunft.kontakt)
        } else if let ladefehler {
            hinweisSeite(ladefehler, "")
        } else {
            ProgressView().tint(Farben.akzent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Grundflaeche())
        }
    }

    private func hinweisSeite(_ text: String, _ kontakt: String) -> some View {
        VStack(spacing: 12) {
            Text(text)
                .font(.callout)
                .foregroundStyle(Farben.ink)
                .multilineTextAlignment(.center)
            if !kontakt.isEmpty {
                Text(kontakt)
                    .font(.footnote)
                    .foregroundStyle(Farben.akzent)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Grundflaeche())
    }

    // --- Das Formular -----------------------------------------------------

    private func formular(_ auskunft: Modell.Registrierauskunft) -> some View {
        Form {
            if let satz = stand.oben {
                Section {
                    Text(satz).foregroundStyle(Farben.fehler)
                }
            }

            Section {
                feldZeile(.verein,
                          String(localized: "z. B. Rostock Griffins"),
                          $verein)
                feldZeile(.mannschaft,
                          String(localized: "z. B. U17"), $mannschaft)
            } header: {
                Text("Verein")
            } footer: {
                Text("Weitere Mannschaften legst du später dazu.")
            }

            Section {
                feldZeile(.vorname, "Vorname", $vorname)
                feldZeile(.nachname, "Nachname", $nachname)
                feldZeile(.email, "name@verein.de", $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Du")
            } footer: {
                Text("""
                    Die Adresse brauchen wir für das Zurücksetzen des \
                    Passworts. Wir schreiben dir sonst nichts.
                    """)
            }

            Section {
                feldZeile(.benutzername, "Benutzername", $benutzername)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                geheimZeile(.passwort, String(localized: "Passwort"), $passwort)
                geheimZeile(.wiederholung,
                            String(localized: "Passwort wiederholen"),
                            $wiederholung)
                // DER STAERKEBALKEN (R110.10). Er steht UNTER dem
                // Passwortfeld und über der Wiederholung: Der Hinweis
                // im Fuss sagt die REGEL, der Balken den STAND, und
                // gemessen wird das erste Feld.
                Staerkebalken(passwort: passwort,
                              mindestlaenge: auskunft.passwortMindestlaenge,
                              umfeld: [benutzername, vorname, nachname,
                                       email].filter { !$0.isEmpty })
            } header: {
                Text("Anmeldedaten")
            } footer: {
                // Der Hinweis kommt vom Server, samt Zahl. Eine getippte
                // Acht sagt „mindestens 8 Zeichen", während der Server
                // zwölf verlangt.
                Text(passwortsatz(auskunft) ?? auskunft.passwortHinweis)
                    .foregroundStyle(passwortsatz(auskunft) == nil
                                     ? Farben.inkStill : Farben.fehler)
            }

            demoAbschnitt(auskunft)
        }
        // Ein Feld gilt als gesehen, sobald es verlassen wurde -- nicht
        // beim ersten Buchstaben. Wer tippt, ist noch nicht fertig, und
        // eine Beanstandung mitten im Wort ist Lärm.
        .onChange(of: feld) { vorher, _ in
            if let vorher { stand.zeigen(vorher.kennung) }
        }
    }

    /// Was die Demo hergibt -- angekündigt, bevor jemand tippt.
    ///
    /// Dieselbe Regel wie im Browser: Ein Versprechen, das der erste
    /// Ausdruck widerlegt, ist teurer als gar keins. Der Streifen auf dem
    /// Armband steht deshalb hier und nicht erst beim Drucken.
    private func demoAbschnitt(
        _ auskunft: Modell.Registrierauskunft) -> some View {
        Section {
            ForEach(auskunft.abo.hebtAuf) { zeile in
                HStack(alignment: .top) {
                    Text(zeile.was)
                        .font(.footnote)
                        .foregroundStyle(Farben.inkStill)
                    Spacer(minLength: 12)
                    // Die Demo-Spalte aus dem Wertverzeichnis
                    // (R119). `zeile.demo` gibt es nicht mehr:
                    // Die Zeile trägt seitdem einen Wert JE
                    // Stufe, und die Demo ist eine davon.
                    Text(zeile.wert(fuer: Stufenblock.demo) ?? "")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Farben.ink)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Text("Was du sofort bekommst")
        } footer: {
            Text("""
                Alle Werkzeuge sind offen, der Umfang ist begrenzt. Was ein \
                Abo aufhebt, steht am Ende.
                """)
        }
    }

    private func feldZeile(_ welches: Feld, _ platzhalter: String,
                           _ wert: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(platzhalter, text: wert)
                .focused($feld, equals: welches)
                .onChange(of: wert.wrappedValue) { _, _ in
                    stand.vergessen(welches.kennung)
                }
            if let satz = satzZu(welches) {
                Text(satz)
                    .font(.caption)
                    .foregroundStyle(Farben.fehler)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func geheimZeile(_ welches: Feld, _ platzhalter: String,
                             _ wert: Binding<String>) -> some View {
        SecureField(platzhalter, text: wert)
            .textContentType(.newPassword)
            .focused($feld, equals: welches)
            .onChange(of: wert.wrappedValue) { _, _ in
                stand.vergessen(welches.kennung)
                stand.vergessen(Feld.passwort.kennung)
                stand.vergessen(Feld.wiederholung.kennung)
            }
    }

    // --- Was wo steht ------------------------------------------------------

    /// Der Satz unter einem Feld: erst der des Servers, dann der eigene.
    ///
    /// Der Server hat immer recht -- er weiß, ob es den Vereinsnamen
    /// schon gibt. Der eigene Satz erscheint erst, wenn das Feld einmal
    /// verlassen wurde: Wer tippt, ist noch nicht fertig, und eine
    /// Beanstandung nach dem ersten Buchstaben ist Lärm.
    private func satzZu(_ welches: Feld) -> String? {
        if let vomServer = stand.vomServer[welches.kennung] { return vomServer }
        guard stand.zeigt(welches.kennung), let auskunft else { return nil }
        let satz = Registrierblock.pruefen(
            feld: welches.kennung, eingabe: wert(welches),
            laengen: auskunft.laengen)
        return satz.isEmpty ? nil : satz
    }

    /// Beide Passwortfelder teilen sich eine Zeile.
    ///
    /// Djangos Formular hängt die Beschwerde über ein schwaches Passwort
    /// an das WIEDERHOLUNGSfeld (`_post_clean`). Umgehängt wird sie
    /// nicht -- das hieße, in Djangos Ablauf hineinzugreifen, und zwar
    /// im wichtigsten Formular des Produkts. Statt dessen steht sie
    /// unter beiden, denn dort gehört sie hin.
    private func passwortsatz(
        _ auskunft: Modell.Registrierauskunft) -> String? {
        if let vomServer = stand.vomServer[Feld.passwort.kennung]
            ?? stand.vomServer[Feld.wiederholung.kennung] {
            return vomServer
        }
        guard stand.zeigt(Feld.wiederholung.kennung) else { return nil }
        let satz = Registrierblock.passwort(
            passwort, wiederholung: wiederholung,
            mindestlaenge: auskunft.passwortMindestlaenge)
        return satz.isEmpty ? nil : satz
    }

    private func wert(_ welches: Feld) -> String {
        switch welches {
        case .verein: return verein
        case .mannschaft: return mannschaft
        case .vorname: return vorname
        case .nachname: return nachname
        case .email: return email
        case .benutzername: return benutzername
        case .passwort: return passwort
        case .wiederholung: return wiederholung
        }
    }

    // --- Laden und Anlegen -------------------------------------------------

    private func auskunftHolen() async {
        do {
            auskunft = try await Konten.auskunft()
        } catch {
            ladefehler = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Die Auskunft ließ sich nicht laden.")
        }
    }

    private func anlegen() async {
        guard let auskunft else { return }
        feld = nil
        // Vor dem Absenden zählt jedes Feld als gesehen: Sonst drückt
        // jemand „Anlegen" und nichts passiert, weil ein Satz auf ein
        // Verlassen wartet, das nie kommt.
        stand.alleZeigen(Feld.allCases.map(\.kennung))
        let eigene = Feld.allCases.compactMap { satzZu($0) }
            + [passwortsatz(auskunft)].compactMap { $0 }
        guard eigene.isEmpty else {
            stand.oben = eigene.first
            return
        }

        stand.laeuft = true
        stand.oben = nil
        stand.vomServer = [:]
        defer { stand.laeuft = false }
        do {
            let (paar, ergebnis) = try await Konten.registrieren(
                verein: verein, mannschaft: mannschaft, vorname: vorname,
                nachname: nachname, email: email,
                benutzername: benutzername, passwort: passwort,
                wiederholung: wiederholung, geraet: Geraetename.eigener)
            passwort = ""
            wiederholung = ""
            fertig = Fertig(paar: paar, ergebnis: ergebnis)
        } catch let absage as Konten.Absage {
            stand.uebernehmen(absage)
        } catch {
            stand.oben = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Das hat nicht geklappt.")
        }
    }
}

/// Was ein Formular über sich selbst weiß: was läuft, was der Server
/// beanstandet hat und welche Felder schon einmal verlassen wurden.
///
/// **Als eigener Typ und nicht als fünf `@State`.** Beide Formulare
/// dieser Datei brauchen dasselbe, und die eine Regel, die man leicht
/// vergisst, steht damit nur einmal da: Wer ein Feld ändert, wird den
/// Satz des Servers dazu los. Ohne sie bleibt „Diesen Benutzernamen gibt
/// es schon" stehen, während jemand längst einen anderen eingetippt hat.
struct Formularstand {
    var laeuft = false
    /// Der Satz über dem Formular. Der erste, den der Server nennt.
    var oben: String?
    /// Je Feldname der Satz des Servers.
    var vomServer: [String: String] = [:]

    private var gesehen: Set<String> = []

    func zeigt(_ feld: String) -> Bool { gesehen.contains(feld) }

    mutating func alleZeigen(_ felder: [String]) {
        gesehen.formUnion(felder)
    }

    /// Ein Feld wurde geändert: Was der Server dazu sagte, gilt nicht mehr.
    ///
    /// Ausdrücklich OHNE es als gesehen zu vermerken. Sonst erschiene
    /// die eigene Beanstandung schon beim ersten Buchstaben -- „Ohne
    /// Vereinsnamen geht es nicht" unter einem Feld, in das gerade
    /// jemand tippt.
    mutating func vergessen(_ feld: String) {
        vomServer[feld] = nil
    }

    /// Das Feld wurde verlassen. Ab jetzt darf die eigene Beanstandung
    /// darunter stehen.
    mutating func zeigen(_ feld: String) {
        gesehen.insert(feld)
    }

    mutating func uebernehmen(_ absage: Konten.Absage) {
        oben = absage.text
        vomServer = absage.felder.compactMapValues { $0.first }
        gesehen.formUnion(absage.felder.keys)
    }
}

// MARK: - Beitreten ohne Konto

/// Konto anlegen und mit einem Teamcode in einem Schritt beitreten (B12).
///
/// **Die Lücke, die B9 offengelassen hat.** Dort stand: „ein Konto
/// anlegen mit einem Code in der Hand (das führt durch die Registrierung
/// und ist Punkt 12)". Ohne diesen Weg ist der Teamcode in der App für
/// genau die Hälfte der Leute wertlos, für die er gedacht ist: Ein
/// Sechzehnjähriger, der den Code in der Mannschaftsgruppe bekommt, hat
/// kein Konto.
///
/// **Kein zweites Blatt für den Namen.** Er steht hier im Formular, wie
/// in `BeitretenAnsicht` und wie im Browser (A5). Eine Seite, die nach
/// dem Beitritt nach dem Namen fragt, klickt man weg -- und dann steht
/// eine Mitgliedschaft ohne Namen in der Datenbank.
struct BeitretenNeuAnsicht: View {
    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen

    @State private var auskunft: Modell.Registrierauskunft?
    @State private var eingabe = ""
    @State private var anzeigename = ""
    @State private var benutzername = ""
    @State private var passwort = ""
    @State private var wiederholung = ""
    @State private var stand = Formularstand()
    @State private var meldung: String?
    @State private var paar: Anmeldung.Tokenpaar?
    /// Was der Code fragt -- sobald er vollständig ist (R24).
    /// `nil` heißt „noch nicht gefragt oder nicht gefunden", und das ist
    /// etwas anderes als „keine Schule": Solange sie fehlt, steht der
    /// vorsichtige Fall da, also der Name.
    @State private var codeauskunft: Modell.Codeauskunft?

    private var code: String { Teamcodeblock.normalisieren(eingabe) }

    /// Wonach gefragt wird -- dieselbe Regel wie in `BeitretenAnsicht`.
    ///
    /// **Nicht hier ausgeschrieben, sondern aus `Kadernameblock`.** Eine
    /// zweite Fassung sähe nie falsch aus, sondern nur nach einem
    /// anderen Formular; genau daran ist der Punkt einmal gescheitert.
    private var namensfeld: Kadernameblock.Feld {
        guard let codeauskunft else { return Kadernameblock.feldOhneAuskunft }
        return Kadernameblock.feld(fuer: codeauskunft)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let satz = stand.oben {
                    Section { Text(satz).foregroundStyle(Farben.fehler) }
                }

                Section {
                    TextField("P7QK-3MRW-9XTB", text: $eingabe)
                        .font(.title3.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        // SOBALD DER CODE VOLLSTÄNDIG IST, wird gefragt,
                        // wonach er fragt (R24). Nicht bei jedem
                        // Buchstaben: Das wären zwölf Anfragen für einen
                        // Code, elf davon auf gut Glück.
                        .onChange(of: code) { _, neu in
                            codeauskunft = nil
                            // `code` ist die NORMALISIERTE Eingabe und
                            // deshalb genau dann nicht leer, wenn zwölf
                            // gültige Zeichen dastehen
                            // (`Teamcodeblock.normalisieren`). Es gibt
                            // also eine Anfrage je fertigem Code und
                            // nicht eine je Buchstabe.
                            guard !neu.isEmpty else { return }
                            Task { await auskunftHolen(fuer: neu) }
                        }
                } header: {
                    Text("Der Code deines Trainers")
                } footer: {
                    Text("Zwölf Zeichen, Bindestriche sind egal.")
                }

                Section {
                    TextField(namensfeld.aufschrift, text: $anzeigename)
                        // KEIN `.textContentType(.name)` IN EINER SCHULE:
                        // Das Telefon böte sonst den vollen Namen an,
                        // den das Kind im Konto hinterlegt hat -- ein
                        // Feld, das die Namensfreiheit aushebelt, indem
                        // es hilfsbereit ist. Dieselbe Entscheidung wie
                        // beim `autocomplete="off"` im Browser.
                        .textContentType(namensfeld.pflicht ? .name : .none)
                        .autocorrectionDisabled(!namensfeld.pflicht)
                        .onChange(of: anzeigename) { _, _ in
                            stand.vergessen("anzeigename")
                        }
                    if let satz = stand.vomServer["anzeigename"] {
                        Text(satz).font(.caption)
                            .foregroundStyle(Farben.fehler)
                    }
                } header: {
                    // DIESELBE ZEILE WIE IN `BeitretenAnsicht`. Zwei
                    // eigene Überschriften („Name" / „Kürzel") wären
                    // zwei weitere Sätze, die dasselbe sagen und beim
                    // nächsten Umbau auseinanderlaufen.
                    Text(namensfeld.aufschrift)
                } footer: {
                    // WAS HIER STEHT, ENTSCHEIDET `Kadernameblock` (R24)
                    // aus dem, was der Server über den Code gesagt hat.
                    // Vorher stand hier ein Satz, der BEIDE Fälle
                    // beschrieb, und ein Feld, das in einer
                    // Schulmannschaft nach einem Namen fragte, den dort
                    // niemand angeben muss. Der Grund dafür war, dass
                    // `codeAnsehen` eine Anmeldung verlangt -- die es
                    // auf diesem Blatt nicht gibt. Dafür gibt es jetzt
                    // `Konten.codeVorschau`.
                    Text(namensfeld.hilfe)
                }

                Section {
                    TextField("Benutzername", text: $benutzername)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: benutzername) { _, _ in
                            stand.vergessen("benutzername")
                        }
                    if let satz = stand.vomServer["benutzername"] {
                        Text(satz).font(.caption)
                            .foregroundStyle(Farben.fehler)
                    }
                    SecureField("Passwort", text: $passwort)
                        .textContentType(.newPassword)
                    SecureField("Passwort wiederholen", text: $wiederholung)
                        .textContentType(.newPassword)
                    // R110.10, auch hier. Wer über einen Teamcode
                    // hereinkommt, legt dasselbe Passwort an -- und
                    // bekam bisher denselben Balken nicht.
                    if let auskunft {
                        Staerkebalken(
                            passwort: passwort,
                            mindestlaenge: auskunft.passwortMindestlaenge,
                            umfeld: [benutzername].filter { !$0.isEmpty })
                    }
                } header: {
                    Text("Neues Konto")
                } footer: {
                    Text(passwortsatz ?? (auskunft?.passwortHinweis ?? ""))
                        .foregroundStyle(passwortsatz == nil
                                         ? Farben.inkStill : Farben.fehler)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            .navigationTitle("Konto anlegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Abbruchknopf { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Fertigknopf(name: String(localized: "Beitreten")) {
                        Task { await beitreten() }
                    }
                        // WAS DASTEHEN MUSS, ENTSCHEIDET
                        // `Kadernameblock` (R24) -- in einer Schule darf
                        // das Feld leer bleiben, und der Knopf darf dort
                        // nicht sperren, wo der ganze Punkt ist, dass
                        // man nichts angeben muss. Dieselbe Zeile wie in
                        // `BeitretenAnsicht`.
                        .disabled(stand.laeuft || code.isEmpty
                                  || !Kadernameblock.darfAbsenden(
                                      anzeigename, feld: namensfeld))
                }
            }
            .alert("Willkommen",
                   isPresented: Binding(get: { meldung != nil },
                                        set: { if !$0 { meldung = nil } })) {
                Button("Los geht's") {
                    meldung = nil
                    // Erst jetzt angemeldet: Sonst verschwindet die
                    // Meldung unter dem Finger, und niemand erfährt,
                    // unter welchem Namen er im Kader steht.
                    if let paar { anmeldung.uebernehmen(paar) }
                }
            } message: {
                Text(meldung ?? "")
            }
        }
        .task {
            // Nur wegen des Passworthinweises. Schlägt es fehl, bleibt
            // die Zeile leer -- ein Beitritt darf daran nicht scheitern.
            auskunft = try? await Konten.auskunft()
        }
    }

    /// Nachfragen, wonach dieser Code fragt (R24).
    ///
    /// **Scheitert es, bleibt es beim vorsichtigen Fall.** Kein Fehler
    /// auf dem Bildschirm: Ob es den Code gibt, sagt ohnehin erst der
    /// Beitritt, und eine rote Zeile beim Tippen des zwölften Zeichens
    /// wäre eine Anschuldigung, bevor jemand fertig ist.
    ///
    /// Der Vergleich am Ende ist der Punkt: Wer weitertippt, während die
    /// Antwort unterwegs ist, bekäme sonst die Auskunft zu einem Code,
    /// der nicht mehr im Feld steht. Dieselbe Buchführung wie beim
    /// Sicherstand aus R4, nur kleiner.
    private func auskunftHolen(fuer gefragt: String) async {
        let antwort = try? await Konten.codeVorschau(gefragt)
        guard gefragt == code else { return }
        codeauskunft = antwort
    }

    private var passwortsatz: String? {
        if let vomServer = stand.vomServer["passwort"]
            ?? stand.vomServer["passwort_wiederholung"] {
            return vomServer
        }
        // Erst wenn die Wiederholung angefangen ist: Sonst steht „zu
        // kurz" schon nach dem ersten Buchstaben.
        guard let auskunft, !wiederholung.isEmpty else { return nil }
        let satz = Registrierblock.passwort(
            passwort, wiederholung: wiederholung,
            mindestlaenge: auskunft.passwortMindestlaenge)
        return satz.isEmpty ? nil : satz
    }

    private func beitreten() async {
        stand.laeuft = true
        stand.oben = nil
        stand.vomServer = [:]
        defer { stand.laeuft = false }
        do {
            let (neu, ergebnis) = try await Konten.beitretenMitKonto(
                code: code, anzeigename: anzeigename,
                benutzername: benutzername, passwort: passwort,
                wiederholung: wiederholung, geraet: Geraetename.eigener)
            passwort = ""
            wiederholung = ""
            paar = neu
            meldung = ergebnis.meldung
        } catch let absage as Konten.Absage {
            stand.uebernehmen(absage)
        } catch {
            stand.oben = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Das hat nicht geklappt.")
        }
    }
}
