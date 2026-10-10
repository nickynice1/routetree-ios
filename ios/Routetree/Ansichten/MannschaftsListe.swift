import SwiftUI

/// Die Mannschaften, in denen diese Person steht (B9).
///
/// **Warum das ein eigener Reiter ist und kein Zweig der Playbook-Liste.**
/// Ein Playbook öffnet man am Spielfeldrand, eine Mannschaft verwaltet man
/// am Küchentisch. Beides in eine Liste zu legen hieße, dass der Weg zum
/// nächsten Play über einen Bildschirm führt, auf dem Zugänge widerrufen
/// werden.
///
/// **Kein Knopf wird geraten.** Ob jemand anlegen, ändern oder führen
/// darf, sagt der Server an jeder Mannschaft (`darf_aendern`,
/// `darf_fuehren`). Ein Knopf, der beim Drücken 403 bekommt, ist ein
/// toter Knopf (ADR-0007).
struct MannschaftsListe: View {
    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var teams: [Modell.Mannschaft] = []
    @State private var zustand: Zustand = .laedt
    @State private var zeigtAnlegen = false
    @State private var zeigtHilfe = false
    @State private var zeigtKonto = false
    @State private var zeigtBeitreten = false
    @State private var meldung: String?
    /// Welche Kachel oben liegt -- als KENNUNG und nicht als
    /// Mannschaft. Nach dem Aktualisieren ist dieselbe Mannschaft ein
    /// anderer Wert, sobald sich eine Zahl daran geändert hat, und der
    /// Stapel spränge auf die erste Kachel zurück.
    @State private var seiteId = ""
    /// Die Absage der Demo, mit dem Weg, der sie aufhebt.
    @State private var grenze: Grenzmeldung?
    @State private var vorschlag: Abovorschlag?

    enum Zustand: Equatable {
        case laedt
        case da
        case leer
        case fehler(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                inhalt
            }
            .navigationTitle("Mannschaften")
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
                    // AUCH DAS KONTO GEHOERT AUF BEIDE REITER. Wer hier
                    // steht, kam bis zum 02.09.2026 weder an die Hilfe
                    // noch an die Sprache, die Rechtstexte oder das
                    // Abmelden -- der Knopf gab es nur auf Reiter 1.
                    Button {
                        zeigtKonto = true
                    } label: {
                        Label("Konto", systemImage: "person.crop.circle")
                            .accessibilityIdentifier("konto")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            zeigtAnlegen = true
                        } label: {
                            Label("Mannschaft anlegen",
                                  systemImage: "person.3")
                        }
                        Button {
                            zeigtBeitreten = true
                        } label: {
                            Label("Mit Teamcode beitreten",
                                  systemImage: "key")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Anlegen oder beitreten")
                }
            }
            .task { await laden() }
            .refreshable { await laden() }
            .sheet(isPresented: $zeigtHilfe) {
                HilfeAnsicht().environmentObject(anmeldung)
            }
            .sheet(isPresented: $zeigtKonto) {
                KontoAnsicht().environmentObject(anmeldung)
            }
            .sheet(isPresented: $zeigtAnlegen) {
                MannschaftAnlegen { ergebnis in
                    zeigtAnlegen = false
                    switch ergebnis {
                    case .angelegt(let neu):
                        // ERST LADEN, DANN HINBLÄTTERN. Umgekehrt
                        // zeigte der Stapel auf eine Seite, die es noch
                        // nicht gibt, und fiele auf die erste zurück.
                        Task {
                            await laden()
                            seiteId = Kachelblock.Seite.mannschaft(neu).id
                        }
                    case .grenze(let text, let abo):
                        grenze = Grenzmeldung(text: text, abo: abo)
                    case .abgebrochen:
                        break
                    }
                }
                .environmentObject(anmeldung)
            }
            // EINE ABSAGE OHNE ALTERNATIVE IST EINE SACKGASSE (A3).
            // Dieselbe Meldung wie bei Playbooks und Plays -- der Satz
            // vom Server, daneben der Weg, der ihn aufhebt.
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
            .sheet(isPresented: $zeigtBeitreten) {
                BeitretenAnsicht { beigetreten in
                    zeigtBeitreten = false
                    if beigetreten { Task { await laden() } }
                }
                .environmentObject(anmeldung)
            }
            .alert("Hinweis",
                   isPresented: Binding(get: { meldung != nil },
                                        set: { if !$0 { meldung = nil } })) {
                Button("Verstanden", role: .cancel) { meldung = nil }
            } message: {
                Text(meldung ?? "")
            }
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch zustand {
        case .laedt:
            ProgressView().tint(Farben.akzent)

        case .leer:
            // Zwei Wege heraus, und beide gehören hierhin: Wer eine
            // Mannschaft gründet, legt sie an. Wer zu einer eingeladen
            // wurde, hat einen Code. Nur einen davon anzubieten macht
            // aus der Hälfte der Leute eine Sackgasse.
            Hinweis(zeichen: "person.3",
                    titel: String(localized: "Noch keine Mannschaft"),
                    text: String(localized: """
                        Leg eine an oder tritt mit dem Teamcode deines \
                        Trainers bei.
                        """)) {
                VStack(spacing: 10) {
                    Button("Mannschaft anlegen") { zeigtAnlegen = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Farben.akzent)
                    Button("Mit Teamcode beitreten") {
                        zeigtBeitreten = true
                    }
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
            // EIN STAPEL KACHELN, KEINE LISTE (R13). Die Skizze zeigt
            // eine große Kachel mit Logo oben und Name darunter, und
            // hinter der letzten Mannschaft das Plus: „Und denn wenn man
            // nach rechts wischt kann man aufs plus und noch eine
            // Mannschaft hinzufügen." Der Daumen liegt in der Mitte des
            // Bildschirms, nicht in der oberen rechten Ecke.
            VStack(spacing: 0) {
                TabView(selection: $seiteId) {
                    ForEach(Kachelblock.seiten(teams)) { seite in
                        kachelseite(seite)
                            .padding(.horizontal, 22)
                            .tag(seite.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Text(Kachelblock.wischhinweis)
                    .font(.caption)
                    .foregroundStyle(Farben.inkStill)
                    .padding(.bottom, 10)
                    .opacity(Kachelblock.zeigtWischhinweis(seiteId: seiteId)
                             ? 1 : 0)
                    // Ausgeblendet und nicht entfernt: Sonst rutschte
                    // der ganze Stapel beim Wischen um eine Zeilenhöhe
                    // nach unten.
                    .accessibilityHidden(
                        !Kachelblock.zeigtWischhinweis(seiteId: seiteId))
            }
            .navigationDestination(for: Modell.Mannschaft.self) { team in
                MannschaftAnsicht(kopf: team) {
                    // Nach dem Löschen: Die Liste holt sich den Stand
                    // vom Server. Die Kachel aus der eigenen Liste zu
                    // streichen wäre schneller und wäre eine zweite
                    // Wahrheit -- was es gibt, sagt der Server.
                    Task { await laden() }
                }
            }
        }
    }

    /// Eine Seite des Stapels.
    ///
    /// **Warum eine `ScrollView` um eine Kachel, die passt.** Zwei
    /// Gründe, und beide fielen erst beim Umbau auf: `.refreshable`
    /// braucht etwas zum Ziehen -- bis heute war das die Liste, und ohne
    /// Ersatz wäre das Herunterziehen zum Aktualisieren lautlos weg.
    /// Und bei großer Schrift wird aus derselben Kachel eine, die nicht
    /// mehr auf den Bildschirm passt.
    @ViewBuilder
    private func kachelseite(_ seite: Kachelblock.Seite) -> some View {
        ScrollView {
            switch seite {
            case .mannschaft(let team):
                NavigationLink(value: team) {
                    Mannschaftskachel(team: team)
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
            case .hinzufuegen:
                Hinzufuegekachel(anlegen: { zeigtAnlegen = true },
                                 beitreten: { zeigtBeitreten = true })
                    .padding(.top, 18)
            }
        }
    }

    /// Die Kachel, auf der der Stapel nach dem Laden steht.
    ///
    /// Nur, wenn die gemerkte gar nicht mehr dabei ist -- sonst spränge
    /// der Stapel bei jedem Aktualisieren auf die erste Mannschaft
    /// zurück.
    private func stelleHalten() {
        let ids = Kachelblock.seiten(teams).map(\.id)
        if !ids.contains(seiteId) {
            seiteId = ids.first ?? Kachelblock.Seite.hinzufuegen.id
        }
    }

    private func laden() async {
        do {
            let neu = try await Laden(anmeldung: anmeldung).teams()
            teams = neu
            stelleHalten()
            zustand = neu.isEmpty ? .leer : .da
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            zustand = .fehler(Fehlertext.von(error))
        }
    }
}

// MARK: - Anlegen

/// Eine Mannschaft anlegen. Wer sie anlegt, wird Head Coach.
///
/// **Ohne Vereinsauswahl, wenn es nur einen gibt.** Ein Auswahlfeld mit
/// einem Eintrag ist eine Frage ohne Antwortmöglichkeit. Wer noch gar
/// keinen Verein hat, bekommt einen gleichnamigen dazu, und das
/// entscheidet der Server: An dieser Stelle hängen die Grenzen der Demo.
struct MannschaftAnlegen: View {
    /// Was herausgekommen ist: die Mannschaft, eine Grenze, oder nichts.
    ///
    /// **Nicht `Bool`, und das ist der Punkt.** Bis zum 10.09.2026 kam
    /// hier nur „ja, angelegt" zurück. Die Liste lud daraufhin neu --
    /// und blieb auf der Seite stehen, auf der sie war. Die neue
    /// Mannschaft war eine Seite weiter im Stapel, also unsichtbar.
    ///
    /// Niklas hat daraus geschlossen, die Demo lasse keine zweite
    /// Mannschaft zu: „dann erstellt er keine, ist ja klar soll er auch
    /// nicht weil es demo ist". Das Protokoll des Servers sagt etwas
    /// anderes -- zwei POST auf `/api/v1/teams/`, beide 201, beide
    /// Mannschaften liegen in der Datenbank. Die Demo begrenzt
    /// Mannschaften überhaupt nicht (`grenzen.teams_erlaubt`); begrenzt
    /// sind Playbooks, Plays und der Streifen auf dem Ausdruck.
    ///
    /// Eine Handlung, die wirkt und nichts zeigt, ist von einer, die
    /// nicht wirkt, nicht zu unterscheiden.
    let fertig: (Ergebnis) -> Void

    /// **Die Grenze gehört dazu.** Die Demo darf seit dem 10.09.2026
    /// EINE Mannschaft; ohne diesen Fall käme die Absage des Servers
    /// als roter Satz unter dem Formular an -- ohne den Weg, der sie
    /// aufhebt. Dieselbe Lehre wie bei Playbooks und Plays: Eine
    /// Absage ohne Alternative hält der Coach für einen Fehler der App.
    enum Ergebnis {
        case angelegt(Modell.Mannschaft)
        case grenze(text: String, abo: Modell.Abo?)
        case abgebrochen
    }

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var name = ""
    @State private var farbe = Farbvorschlaege.standard
    @State private var vereine: [Modell.Vereinskopf] = []
    @State private var verein: Int?
    @State private var spielform = Spielform.standard
    @State private var laeuft = false
    @State private var fehler: String?

    /// Was `Farbwert` zu der Eingabe sagt. An EINER Stelle gefragt: Der
    /// Knopf und der Fehlersatz müssen sich einig sein.
    private var geprueft: Farbwert.Ergebnis { Farbwert.pruefen(farbe) }

    private var bereit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && geprueft.taugt && !laeuft
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    // ERFUNDENER VEREIN, UND ZWAR MIT ABSICHT. Hier
                    // stand „Rostock Griffins" -- ein echter Verein, der
                    // nie gefragt wurde, ob er als Beispiel herhalten
                    // will. Im Web ist das längst geändert; in der App
                    // stand es noch.
                    TextField("z. B. Sturmhagen Kraken U17", text: $name)
                }

                // DIE FRAGE, DIE DEN REST BESTIMMT (T4).
                //
                // **Sie fehlte hier, und das war der ganze Fehler.** Die
                // App legte Mannschaften mit Name und Farbe an; die
                // Spielform setzte der Server auf Flag, weil niemand
                // etwas anderes sagte. Wer seine Mannschaft
                // „TackleStrelitz" nannte, bekam trotzdem ein Flagfeld
                // -- ohne Meldung, denn kaputt war nichts.
                //
                // Karten und kein Auswahlrad: Der Unterschied zwischen
                // „9 gegen 9" und „9 gegen 9, schmales Feld" steht im
                // Hinweis, nicht im Namen. In einem zugeklappten Rad
                // liest ihn niemand.
                Section {
                    ForEach(Spielform.alle) { form in
                        Button {
                            spielform = form.schluessel
                        } label: {
                            Formkachel(form: form,
                                       gewaehlt: spielform == form.schluessel)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Was spielt diese Mannschaft?")
                } footer: {
                    Text("""
                        Flag oder Tackle, und mit wie vielen Leuten. \
                        Bestimmt Feldmaße, Aufstellung und die \
                        Regelhinweise im Editor.
                        """)
                }
                if vereine.count > 1 {
                    Section("Verein") {
                        Picker("Verein", selection: $verein) {
                            ForEach(vereine, id: \.id) { v in
                                Text(v.name).tag(Optional(v.id))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
                Section {
                    Farbwahl(farbe: $farbe)
                } header: {
                    Text("Vereinsfarbe")
                } footer: {
                    // Der Satz des Servers, wörtlich. Wer am Telefon
                    // etwas anderes liest als am Schreibtisch, hält eins
                    // von beiden für kaputt.
                    Text(geprueft.fehler
                         ?? String(localized: """
                             Wird für Kacheln und Akzente dieser Mannschaft \
                             benutzt.
                             """))
                        .foregroundStyle(geprueft.taugt ? Farben.inkStill
                                                        : Farben.fehler)
                }
                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            .navigationTitle("Mannschaft anlegen")
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
            .task { await vereineHolen() }
        }
    }

    /// Die Vereine kommen aus den vorhandenen Mannschaften.
    ///
    /// Eine eigene Anfrage wäre eine zweite Wartezeit für ein
    /// Auswahlfeld, das die meisten gar nicht sehen: Wer in einem Verein
    /// ist, bekommt keins.
    private func vereineHolen() async {
        guard let teams = try? await Laden(anmeldung: anmeldung).teams()
        else { return }
        var gesehen = Set<Int>()
        vereine = teams.map(\.verein).filter { gesehen.insert($0.id).inserted }
        if verein == nil { verein = vereine.first?.id }
    }

    private func anlegen() async {
        guard let wert = geprueft.wert else { return }
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            switch try await Laden(anmeldung: anmeldung).teamAnlegen(
                name: name.trimmingCharacters(in: .whitespaces),
                verein: verein, farbe: wert, spielform: spielform) {
            case .angelegt(let neu):
                fertig(.angelegt(neu))
            case .grenze(let text, let abo):
                fertig(.grenze(text: text, abo: abo))
            }
        } catch {
            // Der Satz des Servers, nicht meiner: Er weiß, ob der Name im
            // Verein schon vergeben ist.
            fehler = Fehlertext.von(error)
        }
    }
}


/// Eine Spielform zur Auswahl, mit dem Satz, der sie unterscheidet.
///
/// Eigene Ansicht und nicht inline: Der Übersetzer von Swift braucht
/// für einen `Form`-Abschnitt mit `ForEach` und drei verschachtelten
/// Stapeln sonst unangenehm lange -- dasselbe Muster wie bei den
/// Menügruppen im Editor.
///
/// NICHT MEHR `private`: Dasselbe Kärtchen steht beim Anlegen UND beim
/// Bearbeiten (`MannschaftBearbeiten`). Zwei Fassungen hätten sich
/// auseinanderentwickelt, und die eine, die man seltener sieht, wäre
/// die falsche geworden.
struct Formkachel: View {
    let form: Spielform
    let gewaehlt: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: gewaehlt ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(gewaehlt ? Farben.akzent : Farben.inkStill)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(form.name)
                    .font(.body.weight(gewaehlt ? .semibold : .regular))
                    .foregroundStyle(Farben.ink)
                Text(form.hinweis)
                    .font(.caption)
                    .foregroundStyle(Farben.inkStill)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(gewaehlt ? [.isButton, .isSelected]
                                         : .isButton)
    }
}
