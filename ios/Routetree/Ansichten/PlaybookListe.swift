import SwiftUI

/// Die Playbooks, auf die diese Person Zugriff hat.
///
/// Der Weg ist derselbe wie im Web: Playbook → Play. Zwei Stufen, nicht
/// vier -- wer am Spielfeldrand steht, hat keine Zeit zu navigieren.
///
/// Seit B6 lässt sich hier auch anlegen, umbenennen und löschen. **Kein
/// Knopf davon wird geraten:** Der Server sagt an jedem Heft, ob er
/// hingehört (`darf_aendern`, `darf_loeschen`), und an jeder Mannschaft,
/// ob dort angelegt werden darf. Ein Knopf, der beim Drücken 403 bekommt,
/// ist ein toter Knopf (ADR-0007).
struct PlaybookListe: View {
    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var playbooks: [Modell.Playbook] = []
    @State private var vereine: [Modell.Verein] = []
    @State private var zustand: Zustand = .laedt
    @State private var zeigtKonto = false
    /// Die Hilfe, auf JEDEM Reiter an derselben Stelle (B6).
    @State private var zeigtHilfe = false
    @State private var zeigtAnlegen = false
    /// Das Heft, das gerade umbenannt wird. `nil` heißt: keins.
    @State private var inArbeit: Modell.Playbook?
    /// Das Heft, dessen Löschung bestätigt werden soll.
    @State private var zumLoeschen: Modell.Playbook?
    @State private var meldung: String?
    /// Die Demo ist am Ende -- samt Abo-Vorschlag, wenn der Server einen
    /// mitgeschickt hat (B12). Getrennt von `meldung`, weil hier ein Weg
    /// weiter dranhängt und dort nicht.
    @State private var grenze: Grenzmeldung?
    @State private var vorschlag: Abovorschlag?
    @State private var laeuft = false
    /// Wann diese Liste entstanden ist, wenn sie vom GERÄT kommt (R14).
    /// `nil` heißt „frisch vom Server" -- dann steht keine Leiste da.
    @State private var vorratsstand: Date?

    enum Zustand: Equatable {
        case laedt
        case da
        case leer
        case fehler(String)
    }

    /// Die Mannschaften, in denen angelegt werden darf -- über alle
    /// Vereine hinweg, denn die Auswahl im Blatt ist eine Liste.
    private var anlegbareTeams: [Modell.Team] {
        vereine.flatMap(\.teams).filter(\.darfAnlegen)
    }

    /// Der Weg, den die Ansicht selbst gehen kann (R40).
    ///
    /// **Ohne ihn bleibt man nach dem Anlegen stehen.** Cyell am
    /// 01.09.2026: „sowie wenn man was ausgewählt hat das man wieder
    /// zurück gebracht wird." Ein neues Heft entstand, das Blatt ging
    /// zu, die Liste lud neu -- und der Trainer stand vor derselben
    /// Liste wie vorher und musste sein eigenes Heft darin suchen. Eine
    /// Handlung, deren Ergebnis man suchen muss, fühlt sich an, als
    /// wäre sie nicht angekommen.
    ///
    /// EIN `NavigationPath` UND KEIN `NavigationLink(isActive:)`: Der
    /// ist seit iOS 16 abgekündigt, und die Ansicht muss den Weg auch
    /// dann gehen können, wenn gar kein Link angetippt wurde.
    @State private var weg = NavigationPath()

    var body: some View {
        NavigationStack(path: $weg) {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                // Die Leiste steht ÜBER dem Zustand und nicht in einem
                // Zweig davon: Ohne Netz kann die Liste voll sein, leer
                // sein oder gar nicht kommen -- und in allen drei
                // Fällen ist es dieselbe Auskunft (R14).
                VStack(spacing: 0) {
                    if let vorratsstand {
                        Vorratsleiste(stand: vorratsstand)
                    }
                    inhalt
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Playbooks")
            .toolbarBackground(Farben.flaeche, for: .navigationBar)
            .toolbar {
                // DIE HILFE STEHT AUF JEDEM REITER (B6).
                //
                // WCAG 3.2.6 „Consistent Help" ist Stufe A, und über
                // WCAG2ICT gilt es auch für ein natives Programm: Ist ein
                // Selbsthilfe-Weg auf mehreren Bildschirmen da, muss er
                // überall an derselben Stelle stehen.
                //
                // Bis zum 02.09.2026 lag die Hilfe IM Konto-Blatt, und
                // das war nur von Reiter 1 aus erreichbar. Genau daher
                // kam Niklas' Satz vom 01.09.: „also ich sehe nirgendwo
                // hilfecenter". Der Fehler war nie, dass die Hilfe
                // fehlt, sondern dass sie hinter einem stummen Symbol
                // auf einem von zwei Reitern lag.
                //
                // Der Browser macht es seit jeher richtig: In
                // `base.html` steht im Kopf jeder Seite ein „?" MIT dem
                // Wort „Hilfe".
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        zeigtHilfe = true
                    } label: {
                        Label("Hilfe", systemImage: "questionmark.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Ein eigener Bildschirm statt eines Menues mit einem
                    // Eintrag: Dorthin gehoeren Kontoloeschung (Apple
                    // 5.1.1(v), Pflicht) und der Datenschutz-Link, und die
                    // brauchen Platz fuer eine Erklaerung.
                    //
                    // MIT DEM WORT, nicht nur dem Zeichen (B5). Zwei
                    // A/B-Tests mit 250.000 und 300.000 Nutzern messen
                    // plus 20 und plus 61 Prozent Nutzung, sobald das
                    // Wort danebensteht. Und beim GEHEN ist Zeichen plus
                    // Wort nicht nur schneller, sondern fehlerärmer
                    // (Majrashi 2020) -- das ist genau der Spielfeldrand.
                    Button {
                        zeigtKonto = true
                    } label: {
                        Label("Konto", systemImage: "person.crop.circle")
                            .accessibilityIdentifier("konto")
                    }
                }
                if !anlegbareTeams.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            zeigtAnlegen = true
                        } label: {
                            Label("Playbook anlegen", systemImage: "plus")
                        }
                        .disabled(laeuft)
                    }
                }
            }
            .task { await laden() }
            .refreshable { await laden() }
            .sheet(isPresented: $zeigtKonto) {
                KontoAnsicht().environmentObject(anmeldung)
            }
            .sheet(isPresented: $zeigtHilfe) {
                HilfeAnsicht().environmentObject(anmeldung)
            }
            .sheet(isPresented: $zeigtAnlegen) {
                HeftAnlegen(teams: anlegbareTeams) { ergebnis in
                    zeigtAnlegen = false
                    switch ergebnis {
                    case .angelegt(let neu):
                        // ERST HINEIN, DANN NACHLADEN (R40). Andersherum
                        // stünde man einen Wimpernschlag lang wieder vor
                        // der Liste, und das sieht aus, als wäre etwas
                        // schiefgegangen.
                        weg.append(neu)
                        Task { await laden() }
                    case .grenze(let text, let abo):
                        grenze = Grenzmeldung(text: text, abo: abo)
                    case .abgebrochen: break
                    }
                }
                .environmentObject(anmeldung)
            }
            .sheet(item: $inArbeit) { buch in
                HeftBearbeiten(playbook: buch) { geaendert in
                    inArbeit = nil
                    if geaendert { Task { await laden() } }
                }
                .environmentObject(anmeldung)
            }
            .alert("Playbook löschen",
                   isPresented: Binding(get: { zumLoeschen != nil },
                                        set: { if !$0 { zumLoeschen = nil } }),
                   presenting: zumLoeschen) { buch in
                Button("Löschen", role: .destructive) {
                    Task { await loeschen(buch) }
                }
                Button("Abbrechen", role: .cancel) { zumLoeschen = nil }
            } message: { buch in
                // Die Zahl steht drin, nicht „einige Plays": „38 Plays"
                // liest sich anders als „einige".
                Text(loeschfrage(buch))
            }
            .alert("Hinweis",
                   isPresented: Binding(get: { meldung != nil },
                                        set: { if !$0 { meldung = nil } })) {
                Button("Verstanden", role: .cancel) { meldung = nil }
            } message: {
                Text(meldung ?? "")
            }
            // EINE GRENZE IST KEINE FEHLERMELDUNG, sondern ein Angebot.
            // Bis B12 stand hier ein Satz und der Knopf „Verstanden" --
            // eine Sackgasse, und der Coach hält sie für einen Fehler
            // der App. Jetzt steht daneben, was ein Abo aufhebt.
            .alert("Grenze der Demo",
                   isPresented: Binding(get: { grenze != nil },
                                        set: { if !$0 { grenze = nil } }),
                   presenting: grenze) { angestossen in
                if let weiter = angestossen.vorschlag {
                    Button("Was ein Abo kostet") {
                        grenze = nil
                        vorschlag = weiter
                    }
                }
                Button("Verstanden", role: .cancel) { grenze = nil }
            } message: { angestossen in
                Text(angestossen.text)
            }
            .sheet(item: $vorschlag) { gezeigt in
                AboAnsicht(abo: gezeigt.abo, verein: gezeigt.verein,
                           titel: gezeigt.titel,
                           weiterText: gezeigt.weiterText)
            }
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch zustand {
        case .laedt:
            ProgressView().tint(Farben.akzent)

        case .leer:
            // Ein leerer Bildschirm ohne Erklärung sieht aus wie ein
            // Fehler. Er ist keiner -- also steht hier, was fehlt.
            //
            // Und seit B6 steht hier auch der Weg heraus, wenn es einen
            // gibt: Wer eine Mannschaft führt, muss nicht warten, bis
            // ihn jemand zuordnet.
            Hinweis(zeichen: "book.closed",
                    titel: String(localized: "Noch kein Playbook"),
                    text: anlegbareTeams.isEmpty
                        ? String(localized: """
                            Sobald dein Verein dich einer Mannschaft \
                            zuordnet, erscheinen die Playbooks hier.
                            """)
                        : String(localized: """
                            Leg das erste an – Kategorien und Feldformat \
                            sind vorbelegt.
                            """)) {
                if !anlegbareTeams.isEmpty {
                    Button("Playbook anlegen") { zeigtAnlegen = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Farben.akzent)
                }
            }

        case .fehler(let text):
            Hinweis(zeichen: "exclamationmark.triangle",
                    titel: String(localized: "Das hat nicht geklappt"),
                    text: text) {
                Button("Nochmal versuchen") { Task { await laden() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
            }

        case .da:
            List(playbooks) { buch in
                // DER SICHTBARE WEG (B1), neben Zeile und Geste.
                //
                // Hier stand: „Wischen statt Knöpfen in der Zeile: Die
                // Liste bleibt ruhig, und die gefährliche Handlung
                // braucht eine Geste, die niemand im Vorbeigehen
                // macht." Das erste Argument stimmt, das zweite ist
                // falsch herum gedacht: Eine Geste, die niemand im
                // Vorbeigehen macht, macht auch niemand, der sie sucht.
                // Sadana 2018 hat es gezählt -- 1 von 16.
                HStack(spacing: 0) {
                    NavigationLink(value: buch) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(buch.name)
                                .font(.headline)
                                .foregroundStyle(Farben.ink)
                            Text(untertitel(buch))
                                .font(.caption)
                                .foregroundStyle(Farben.inkStill)
                        }
                        .padding(.vertical, 4)
                    }
                    if buch.darfAendern || buch.darfLoeschen {
                        Zeilenmenue {
                            if buch.darfAendern {
                                Button {
                                    inArbeit = buch
                                } label: {
                                    Label("Umbenennen", systemImage: "pencil")
                                }
                            }
                            if buch.darfLoeschen {
                                Button(role: .destructive) {
                                    zumLoeschen = buch
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Farben.flaechePanel)
                .swipeActions(edge: .trailing) {
                    if buch.darfLoeschen {
                        Button(role: .destructive) {
                            zumLoeschen = buch
                        } label: { Label("Löschen", systemImage: "trash") }
                    }
                    if buch.darfAendern {
                        Button {
                            inArbeit = buch
                        } label: { Label("Umbenennen", systemImage: "pencil") }
                            .tint(Farben.akzent)
                    }
                }
                // AUCH AUF LANGES DRÜCKEN (R51). Eine Geste hat keine
                // Beschriftung: Cyell hat am 01.09.2026 die Löschfunktion
                // für Plays nicht gefunden, weil sie nur auf dem Wisch
                // lag. Dieselben Handgriffe, aus demselben Zustand.
                .contextMenu {
                    if buch.darfAendern {
                        Button {
                            inArbeit = buch
                        } label: { Label("Umbenennen", systemImage: "pencil") }
                    }
                    if buch.darfLoeschen {
                        Button(role: .destructive) {
                            zumLoeschen = buch
                        } label: { Label("Löschen", systemImage: "trash") }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationDestination(for: Modell.Playbook.self) { buch in
                PlayListe(playbook: buch)
            }
        }
    }

    /// Was beim Löschen verloren geht, mit Zahl.
    ///
    /// Als eigene Funktion und nicht als Ausdruck in der Ansicht: Eine
    /// Textzusammensetzung mit Einzahl und Mehrzahl gehört nicht in
    /// einen `Text(...)`-Aufruf. Der erste Versuch stand dort, verteilt
    /// über drei Zeilen mit einer Interpolation in der Mitte, und ließ
    /// sich nicht übersetzen -- ein Swift-Literal muss auf seiner Zeile
    /// enden.
    private func loeschfrage(_ buch: Modell.Playbook) -> String {
        // Ein ganzer Satz je Fall (R22). Vorher wurde ein Satzstück
        // eingesetzt; „sein" und „seine" richten sich in anderen
        // Sprachen nach einem Geschlecht, das dieses Wort hier gar
        // nicht kennt.
        let erste = buch.plays == 1
            ? String(localized:
                "„\(buch.name)“ und sein 1 Play sind danach weg.")
            : String(localized: """
                „\(buch.name)“ und seine \(buch.plays) Plays sind danach \
                weg.
                """)
        return erste + " " + String(localized:
            "Auch die Lernstände. Das lässt sich nicht rückgängig machen.")
    }

    private func untertitel(_ buch: Modell.Playbook) -> String {
        var teile = [buch.team.name]
        if let saison = buch.saison, !saison.isEmpty { teile.append(saison) }
        // Einzahl und Mehrzahl auseinanderhalten. „1 Plays" liest sich
        // wie ein Fehler, und es ist einer.
        teile.append(buch.plays == 1
                     ? String(localized: "1 Play")
                     : String(localized: "\(buch.plays) Plays"))
        return teile.joined(separator: " · ")
    }

    private func laden() async {
        spur("playbooks", "offen")
        let laden = Laden(anmeldung: anmeldung)
        do {
            // Beides zusammen: Die Hefte für die Liste, die Vereine für
            // die Frage, wo angelegt werden darf. Nacheinander wären es
            // zwei Wartezeiten für einen Bildschirm.
            async let hefte = laden.heftlisteMitVorrat()
            // DIE VEREINE DÜRFEN FEHLEN, die Hefte nicht (R14). Sie
            // beantworten nur, WO angelegt werden darf -- und angelegt
            // wird ohnehin nicht ohne Netz. Wer beides in dasselbe
            // `try` legte, zeigte am Platz „Keine Verbindung" statt der
            // Playbooks, die längst auf dem Gerät liegen.
            async let orte = laden.vereine()
            let ausgabe = try await hefte
            vereine = (try? await orte) ?? []
            playbooks = ausgabe.wert
            vorratsstand = ausgabe.stand
            zustand = ausgabe.wert.isEmpty ? .leer : .da
        } catch Server.Fehler.abgemeldet {
            // Kein Fehlerbild: Die Wurzelansicht schaltet gleich auf die
            // Anmeldung um, und zwei Meldungen übereinander verwirren.
            await anmeldung.abmelden()
        } catch {
            zustand = .fehler(Fehlertext.von(error))
        }
    }

    private func loeschen(_ buch: Modell.Playbook) async {
        zumLoeschen = nil
        laeuft = true
        defer { laeuft = false }
        do {
            try await Laden(anmeldung: anmeldung).playbookLoeschen(buch.id)
            await laden()
        } catch {
            meldung = Fehlertext.von(error)
        }
    }
}

// MARK: - Anlegen

/// Das Blatt zum Anlegen eines Playbooks.
///
/// Dieselben Felder wie das Formular im Browser, in derselben
/// Reihenfolge und mit derselben Vorbelegung -- bis hin zum Haken für
/// die Standardkategorien. Dieselbe Handlung soll auf beiden Wegen
/// dasselbe anlegen; genau das ist der Punkt von Strecke B.
struct HeftAnlegen: View {
    let teams: [Modell.Team]
    let fertig: (Ergebnis) -> Void

    enum Ergebnis {
        /// Das neue Heft geht MIT. Ohne es könnte die Liste danach nicht
        /// hineingehen, sondern nur neu laden -- und genau das war R40.
        case angelegt(Modell.Playbook)
        /// Samt Abo-Vorschlag, wenn der Server einen mitgeschickt hat.
        case grenze(text: String, abo: Modell.Abo?)
        case abgebrochen
    }

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var name = ""
    @State private var saison = ""
    @State private var team: Int?
    @State private var feldformat = Feldformat.vorgabe
    @State private var kategorien = true
    /// Ob die beiden Vorgaben aufgeklappt sind (R39). Zu beim Aufmachen.
    @State private var zeigtVorgaben = false
    @State private var laeuft = false
    @State private var fehler: String?

    /// Was zugeklappt danebensteht -- die Antwort, nicht die Frage.
    ///
    /// Ein ganzer Satz je Fall und keine zusammengesetzte Zeile: der
    /// Name des Feldformats plus „mit Kategorien" liesse sich in
    /// anderen Sprachen nicht durch dieselbe Fuge legen (R22).
    private var vorgabenzeile: String {
        // BEI TACKLE STEHT DORT DIE SPIELFORM, nicht das Feldformat.
        //
        // Die drei Feldformate sind FLAGMASSE (50 mal 25 und die beiden
        // Abweichungen). Bei einer Tackle-Mannschaft holt sich das
        // Playbook sein Feld aus der Spielform, und die Wahl darüber
        // bewirkt nichts. Eine Zeile, die „IFAF 5v5, 50 × 25 yd"
        // unter einem Elfer-Playbook nennt, ist schlicht falsch.
        let feld = form.kontakt ? form.name : feldformat.name
        return kategorien
            ? String(localized: "\(feld), mit üblichen Kategorien")
            : String(localized: "\(feld), ohne Kategorien")
    }

    /// Die Spielform der gewählten Mannschaft.
    ///
    /// Das Playbook erbt sie. Abweichen kann man am Schreibtisch; hier
    /// wäre es eine Frage, die beim ersten Playbook niemand hat.
    private var form: Spielform {
        Spielform.zu(teams.first { $0.id == team }?.spielform)
    }

    private var bereit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && team != nil && !laeuft
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z. B. Saison 2026", text: $name)
                    TextField("Saison (2026)", text: $saison)
                }
                // Die Mannschaftswahl entfällt, wenn es nur eine gibt.
                // Ein Auswahlfeld mit einem Eintrag ist eine Frage ohne
                // Antwortmöglichkeit.
                if teams.count > 1 {
                    Section("Mannschaft") {
                        Picker("Mannschaft", selection: $team) {
                            ForEach(teams) { t in
                                Text(t.name).tag(Optional(t.id))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
                // ZUGEKLAPPT, UND DAS IST R39.
                //
                // Cyell am 01.09.2026: „wieso muss ich wenn ich ein
                // playbook anlege welche auswählen, ganz oben ein
                // hinzufügen Button (leer) wäre auch cool." Gemeint
                // sind genau diese beiden Fragen. Wer zum ersten Mal
                // ein Heft anlegt, hat zu keiner von beiden eine
                // Meinung -- und muss sie trotzdem beantworten, bevor
                // er weiterkommt.
                //
                // WEGGENOMMEN WIRD NICHTS. Ein Feldformat, das man
                // nachträglich nicht mehr ändern kann, gehört nicht
                // versteckt. Die Zeile NENNT deshalb, was gilt:
                // „IFAF 5v5 …, mit üblichen Kategorien". Wer es anders
                // will, tippt
                // darauf. Wer nicht, liest es und geht weiter.
                //
                // Das ist der Unterschied zwischen Verstecken und
                // Aufräumen: Ein zugeklappter Abschnitt, dessen
                // Überschrift die Antwort schon enthält, verlangt keine
                // Entscheidung mehr -- er bietet eine an.
                Section {
                    DisclosureGroup(isExpanded: $zeigtVorgaben) {
                        if form.kontakt {
                            // KEINE FELDFORMATWAHL BEI TACKLE. Die drei
                            // Formate sind Flagmaße; das Feld kommt hier
                            // aus der Spielform. Eine Auswahl, die nichts
                            // bewirkt, ist schlimmer als keine.
                            Text("Spielform: \(form.name)")
                                .foregroundStyle(Farben.inkStill)
                            Text("""
                                Wie die Mannschaft. Das Feld folgt der \
                                Spielform; ein eigenes Feldformat gibt es \
                                dafür nicht.
                                """)
                                .font(.footnote)
                                .foregroundStyle(Farben.inkStill)
                        } else {
                            Picker("Feldformat", selection: $feldformat) {
                                ForEach(Feldformat.alle, id: \.kennung) { f in
                                    Text(f.name).tag(f)
                                }
                            }
                            // OHNE „AFVD" UND OHNE „deutsch" (R128).
                            // Der Satz stand in vier Sprachen da und
                            // sagte jedem ausserhalb Deutschlands,
                            // hier gehe es nicht um sein Spiel.
                            Text("""
                                Das Normmaß der IFAF ist der \
                                Normalfall. Es lässt sich später nicht \
                                ändern: Ein anderes Feld würde jede \
                                Zeichnung in diesem Playbook \
                                verschieben.
                                """)
                                .font(.footnote)
                                .foregroundStyle(Farben.inkStill)
                        }
                        Toggle("Übliche Kategorien mit anlegen",
                               isOn: $kategorien)
                        Text("""
                            Pass kurz, Pass tief, Red Zone und Trick, \
                            später änderbar.
                            """)
                            .font(.footnote)
                            .foregroundStyle(Farben.inkStill)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vorgaben")
                            Text(vorgabenzeile)
                                .font(.footnote)
                                .foregroundStyle(Farben.inkStill)
                        }
                    }
                }
                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            .navigationTitle("Playbook anlegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        fertig(.abgebrochen)
                    } label: {
                        // EIN X STATT „Ab…" (R57).
                        //
                        // Niklas am 02.09.2026 mit einem
                        // Bildschirmfoto: „Statt abbrechen
                        // vielleicht einfach ein X".
                        // „Abbrechen" passt in der
                        // Werkzeugleiste von iOS 26 nicht
                        // mehr und stand als „Ab…" da --
                        // und eine abgeschnittene
                        // Beschriftung sagt weniger als
                        // ein Zeichen, das jeder kennt.
                        Label("Abbrechen",
                              systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Fertigknopf(name: String(localized: "Anlegen")) {
                        Task { await anlegen() }
                    }
                        .disabled(!bereit)
                }
            }
            .onAppear { if team == nil { team = teams.first?.id } }
        }
    }

    private func anlegen() async {
        guard let team else { return }
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            switch try await Laden(anmeldung: anmeldung).playbookAnlegen(
                team: team,
                name: name.trimmingCharacters(in: .whitespaces),
                saison: saison.trimmingCharacters(in: .whitespaces),
                feldformat: feldformat.kennung,
                kategorien: kategorien) {
            case .angelegt(let heft):
                fertig(.angelegt(heft))
            case .grenze(let text, let abo):
                fertig(.grenze(text: text, abo: abo))
            }
        } catch {
            // Der Satz des Servers, nicht meiner: Er weiß, ob der Name
            // schon vergeben ist.
            fehler = Fehlertext.von(error)
        }
    }
}

// MARK: - Umbenennen

/// Das Blatt zum Umbenennen. Name, Saison, Notizen -- mehr nicht.
///
/// **Kein Feldformat.** Es zu ändern verschöbe jede vorhandene Zeichnung:
/// Die Yards bleiben stehen, das Feld darunter wird ein anderes, und ein
/// Receiver an der Seitenlinie steht danach im Aus. Der Server lehnt es
/// deshalb ab; ein Feld, das nichts tun darf, gehört nicht ins Formular.
struct HeftBearbeiten: View {
    let playbook: Modell.Playbook
    let fertig: (Bool) -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var name: String
    @State private var saison: String
    @State private var hinweise: String
    @State private var laeuft = false
    @State private var fehler: String?

    init(playbook: Modell.Playbook, fertig: @escaping (Bool) -> Void) {
        self.playbook = playbook
        self.fertig = fertig
        _name = State(initialValue: playbook.name)
        _saison = State(initialValue: playbook.saison ?? "")
        _hinweise = State(initialValue: playbook.hinweise)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name des Playbooks", text: $name)
                    TextField("Saison", text: $saison)
                }
                Section("Notizen") {
                    TextField("Wofür ist dieses Playbook gedacht?",
                              text: $hinweise, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    // DIE SPIELFORM ZUERST (T8): Sie bestimmt das Feld,
                    // und bei Tackle hat das Feldformat unter ihr gar
                    // keine Bedeutung mehr -- die drei Formate sind
                    // Flag-Maße.
                    Text("Spielform: \(Spielform.zu(playbook.spielform).name)")
                        .foregroundStyle(Farben.inkStill)
                    // `if let` UND NICHT NUR `!kontakt` (08.09.2026).
                    // Der Server schickt bei Tackle ausdrücklich `null`
                    // -- „ein fehlender Wert ist ehrlicher als ein
                    // geratener". Seit die App das `null` behält statt
                    // es auf „afvd" zu setzen, ist die Prüfung auf die
                    // Spielform nicht mehr die einzige Sicherung,
                    // sondern die zweite. Beide zusammen sagen dasselbe
                    // und kosten eine Zeile.
                    if !Spielform.zu(playbook.spielform).kontakt,
                       let format = playbook.feldformat {
                        Text("Feldformat: \(Feldformat.anzeigename(fuer: format))")
                            .foregroundStyle(Farben.inkStill)
                    }
                } footer: {
                    Text("""
                        Es bleibt, wie es ist. Ein anderes Feld würde jede \
                        Zeichnung in diesem Playbook verschieben.
                        """)
                }
                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            .navigationTitle("Playbook bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        fertig(false)
                    } label: {
                        // EIN X STATT „Ab…" (R57).
                        //
                        // Niklas am 02.09.2026 mit einem
                        // Bildschirmfoto: „Statt abbrechen
                        // vielleicht einfach ein X".
                        // „Abbrechen" passt in der
                        // Werkzeugleiste von iOS 26 nicht
                        // mehr und stand als „Ab…" da --
                        // und eine abgeschnittene
                        // Beschriftung sagt weniger als
                        // ein Zeichen, das jeder kennt.
                        Label("Abbrechen",
                              systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Fertigknopf(name: String(localized: "Sichern")) {
                        Task { await sichern() }
                    }
                        .disabled(name.trimmingCharacters(in: .whitespaces)
                                    .isEmpty || laeuft)
                }
            }
        }
    }

    private func sichern() async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            _ = try await Laden(anmeldung: anmeldung).playbookAendern(
                playbook.id,
                name: name.trimmingCharacters(in: .whitespaces),
                saison: saison.trimmingCharacters(in: .whitespaces),
                hinweise: hinweise)
            fertig(true)
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}

/// Ein leerer Zustand mit Grund -- statt einer weißen Fläche.
struct Hinweis<Aktion: View>: View {
    let zeichen: String
    let titel: String
    let text: String
    @ViewBuilder var aktion: () -> Aktion

    init(zeichen: String, titel: String, text: String,
         @ViewBuilder aktion: @escaping () -> Aktion = { EmptyView() }) {
        self.zeichen = zeichen
        self.titel = titel
        self.text = text
        self.aktion = aktion
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: zeichen)
                .font(.system(size: 34))
                .foregroundStyle(Farben.inkStill)
            Text(titel)
                .font(.headline)
                .foregroundStyle(Farben.ink)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Farben.inkStill)
            aktion()
        }
        .padding(32)
    }
}
