import SwiftUI

/// Eine Mannschaft: Kader, Teamcode, Einladungen, Schlüssel (B9).
///
/// **Ein Bildschirm, eine Anfrage.** Der Server liefert alles in einer
/// Antwort (`GET /api/v1/teams/<id>/`). Der naheliegende Weg wäre je
/// Abschnitt eine Adresse gewesen, und er wäre falsch: fünf Wartezeiten
/// für einen Bildschirm, und die Umkleide hat kein WLAN.
///
/// **Was jemand nicht sehen darf, kommt gar nicht erst mit.** Teamcode,
/// Einladungen und Schlüssel fehlen in der Antwort an einen Zuschauer --
/// sie sind dann `nil` und nicht leer. Deshalb steht hier `if let` und
/// nirgends eine eigene Rechnung aus der Rolle: Ein zweites Regelwerk in
/// Swift ist die Stelle, an der beim nächsten Mal ein `||` statt eines
/// `&&` steht.
struct MannschaftAnsicht: View {
    /// Was die Liste schon wusste. Damit steht der Name im Titel, bevor
    /// die erste Antwort da ist -- ein Bildschirm, der „Laden" heißt,
    /// sieht aus, als sei man falsch abgebogen.
    let kopf: Modell.Mannschaft
    /// Wird gerufen, wenn die Mannschaft gelöscht wurde. Die Liste lädt
    /// dann neu -- stehen bliebe sonst eine Kachel für etwas, das es
    /// nicht mehr gibt, bis jemand die App neu startet.
    var geloescht: () -> Void = { }

    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen
    @State private var team: Modell.Mannschaft?
    @State private var fehler: String?
    @State private var meldung: String?
    @State private var zeigtBearbeiten = false
    @State private var zeigtCodeblatt = false
    @State private var zeigtEinladung = false
    @State private var zeigtSchluessel = false
    @State private var zeigtLoeschen = false
    /// Der frisch angelegte Schlüssel. Sein Klartext steht genau in
    /// dieser einen Antwort und danach nirgends mehr.
    @State private var frischerSchluessel: Modell.Schluessel?
    @State private var laeuft = false

    private var stand: Modell.Mannschaft { team ?? kopf }

    var body: some View {
        ZStack {
            Farben.flaeche.ignoresSafeArea()
            inhalt
        }
        .navigationTitle(stand.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if stand.darfFuehren {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { zeigtBearbeiten = true } label: {
                        Bearbeitenzeichen()
                    }
                    .disabled(laeuft)
                }
            }
        }
        .task { await laden() }
        .refreshable { await laden() }
        .navigationDestination(for: Modell.Kadermitglied.self) { zeile in
            KaderAnsicht(team: stand, zeile: zeile) {
                Task { await laden() }
            }
            .environmentObject(anmeldung)
        }
        .sheet(isPresented: $zeigtBearbeiten) {
            MannschaftBearbeiten(team: stand) { geaendert in
                zeigtBearbeiten = false
                if geaendert { Task { await laden() } }
            }
            .environmentObject(anmeldung)
        }
        .sheet(isPresented: $zeigtCodeblatt) {
            TeamcodeBlatt(team: stand) { satz in
                zeigtCodeblatt = false
                if let satz { meldung = satz }
                Task { await laden() }
            }
            .environmentObject(anmeldung)
        }
        .sheet(isPresented: $zeigtEinladung) {
            EinladungBlatt(team: stand) { angelegt in
                zeigtEinladung = false
                if angelegt { Task { await laden() } }
            }
            .environmentObject(anmeldung)
        }
        .sheet(isPresented: $zeigtSchluessel) {
            SchluesselBlatt(team: stand) { neuer in
                zeigtSchluessel = false
                if let neuer {
                    frischerSchluessel = neuer
                    Task { await laden() }
                }
            }
            .environmentObject(anmeldung)
        }
        .sheet(isPresented: $zeigtLoeschen) {
            MannschaftLoeschen(team: stand) { weg in
                zeigtLoeschen = false
                if weg {
                    // ERST MELDEN, DANN ZURUECK. Andersherum wäre diese
                    // Ansicht schon fort, wenn die Liste erfährt, dass
                    // sie neu laden soll.
                    geloescht()
                    schliessen()
                }
            }
            .environmentObject(anmeldung)
        }
        .sheet(item: $frischerSchluessel) { schluessel in
            SchluesselZeigen(schluessel: schluessel) {
                frischerSchluessel = nil
            }
        }
        .alert("Hinweis",
               isPresented: Binding(get: { meldung != nil },
                                    set: { if !$0 { meldung = nil } })) {
            Button("Verstanden", role: .cancel) { meldung = nil }
        } message: {
            Text(meldung ?? "")
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        if let fehler, team == nil {
            Hinweis(zeichen: "exclamationmark.triangle",
                    titel: String(localized: "Das hat nicht geklappt"),
                    text: fehler) {
                Button("Nochmal versuchen") { Task { await laden() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
            }
        } else if team == nil {
            ProgressView().tint(Farben.akzent)
        } else {
            List {
                wappenteil
                kaderteil
                if let code = stand.teamcode {
                    teamcodeteil(code)
                } else if stand.darfFuehren {
                    keinCodeTeil
                }
                if let einladungen = stand.einladungen {
                    einladungsteil(einladungen)
                }
                if let schluessel = stand.schluessel {
                    schluesselteil(schluessel)
                }
                if stand.darfFuehren {
                    loeschteil
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Das Wappen

    /// Dasselbe Wappen wie auf der Kachel, oben auf der Seite (R13).
    ///
    /// Wer eine Kachel mit Logo antippt und danach auf einer Seite ohne
    /// landet, hat den Faden verloren -- der Name allein im Titel ist
    /// genau das, was die Liste vorher war.
    private var wappenteil: some View {
        Section {
            VStack(spacing: 10) {
                Wappen(team: stand, groesse: 84)
                Text(Kachelblock.untertitel(stand))
                    .font(.footnote)
                    .foregroundStyle(Farben.inkLeise)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Die Mannschaft löschen

    /// **Ganz unten und ohne Farbe im Titel.** Der Knopf muss da sein --
    /// eine Mannschaft, die man anlegen, aber nicht wieder wegräumen
    /// kann, ist ein halbes Werkzeug. Er darf aber nicht dort stehen,
    /// wo jemand hinlangt, der etwas anderes wollte. Was er anrichtet,
    /// steht auf dem Blatt dahinter, nicht hier: Eine Warnung, die man
    /// beim Scrollen streift, liest niemand.
    private var loeschteil: some View {
        Section {
            Button(role: .destructive) {
                zeigtLoeschen = true
            } label: {
                Label("Mannschaft löschen", systemImage: "trash")
            }
            .disabled(laeuft)
            .listRowBackground(Farben.flaechePanel)
        }
    }

    // MARK: - Kader

    private var kaderteil: some View {
        Section {
            ForEach(stand.kader) { zeile in
                NavigationLink(value: zeile) {
                    KaderZeile(zeile: zeile)
                }
                .listRowBackground(Farben.flaechePanel)
            }
        } header: {
            Text("Kader")
        } footer: {
            Text(kaderfuss)
        }
    }

    /// Der Satz unter dem Kader. Als eigene Eigenschaft und nicht als
    /// Ausdruck in der Ansicht -- dieselbe Lehre wie aus
    /// `PlaybookListe.loeschfrage` (B6).
    private var kaderfuss: String {
        if stand.darfAendern {
            return String(localized: """
                Sortiert nach Namen, nicht nach Fortschritt. Tipp auf \
                jemanden, um Rolle, Name oder Aufgabe zu ändern.
                """)
        }
        return String(localized:
            "Sortiert nach Namen. Wie weit jemand ist, sieht der Trainerstab.")
    }

    // MARK: - Teamcode

    private func teamcodeteil(_ code: Modell.Teamcodestand) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(code.lesbar)
                    .font(.title2.monospaced())
                    .foregroundStyle(Farben.ink)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    // Der Satz kommt vom Server („gültig", „abgelaufen",
                    // „abgeschaltet"). Aus vier Feldern zusammengereimt
                    // stünde hier irgendwann etwas anderes als im
                    // Browser.
                    Marke(text: code.zustand)
                    Text(code.beitritte == 1
                         ? String(localized: "1 Beitritt")
                         : String(localized:
                            "\(code.beitritte) Beitritte"))
                        .font(.caption)
                        .foregroundStyle(Farben.inkStill)
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Farben.flaechePanel)

            if !code.link.isEmpty, let ziel = URL(string: code.link) {
                ShareLink(item: ziel) {
                    Label("Link verschicken", systemImage: "square.and.arrow.up")
                }
                .listRowBackground(Farben.flaechePanel)
            }
            Button {
                zeigtCodeblatt = true
            } label: {
                Label("Neuen Code erzeugen", systemImage: "arrow.clockwise")
            }
            .listRowBackground(Farben.flaechePanel)
            Button(role: .destructive) {
                Task { await codeAbschalten() }
            } label: {
                Label("Teamcode abschalten", systemImage: "xmark.circle")
            }
            .disabled(laeuft)
            .listRowBackground(Farben.flaechePanel)
        } header: {
            Text("Teamcode")
        } footer: {
            Text("""
                Ein Code für die ganze Mannschaft, wiederverwendbar. Wer ihn \
                hat, wird Zuschauer und sieht alle Playbooks. Ein neuer Code \
                ersetzt diesen. Abschalten lässt den Kader stehen.
                """)
        }
    }

    private var keinCodeTeil: some View {
        Section {
            Button {
                zeigtCodeblatt = true
            } label: {
                Label("Teamcode erzeugen", systemImage: "key")
            }
            .listRowBackground(Farben.flaechePanel)
        } header: {
            Text("Teamcode")
        } footer: {
            Text("""
                Zwölf Zeichen zum Abtippen, dazu ein Link. Damit tritt eine \
                ganze Mannschaft bei, ohne dass du jeden einzeln einlädst.
                """)
        }
    }

    // MARK: - Einladungen

    private func einladungsteil(_ liste: [Modell.Einladung]) -> some View {
        Section {
            ForEach(liste) { einladung in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(einladung.rolleText)
                            .foregroundStyle(Farben.ink)
                        Text(einladung.zustand)
                            .font(.caption)
                            .foregroundStyle(Farben.inkStill)
                    }
                    Spacer()
                    // DER TEILEN-KNOPF NUR, SOLANGE ES EINEN LINK GIBT.
                    // Eine eingelöste Einladung führt nirgendwohin; ein
                    // Knopf, der eine tote Adresse verschickt, fällt erst
                    // auf, wenn sich jemand meldet.
                    if let link = einladung.link, let ziel = URL(string: link) {
                        ShareLink(item: ziel) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Farben.akzent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
                // DER SICHTBARE WEG (B1). Eine Einladung zu widerrufen
                // sperrt jemanden aus -- und das lag bis zum 02.09.2026
                // ausschliesslich auf einer Wischgeste.
                .overlay(alignment: .trailing) {
                    if einladung.offen {
                        Zeilenmenue {
                            Button(role: .destructive) {
                                Task { await einladungWiderrufen(einladung) }
                            } label: {
                                Label("Widerrufen", systemImage: "xmark")
                            }
                        }
                    }
                }
                .listRowBackground(Farben.flaechePanel)
                .swipeActions(edge: .trailing) {
                    if einladung.offen {
                        Button(role: .destructive) {
                            Task { await einladungWiderrufen(einladung) }
                        } label: {
                            Label("Widerrufen", systemImage: "xmark")
                        }
                    }
                }
                // Auch auf langes Drücken (R51).
                .contextMenu {
                    if einladung.offen {
                        Button(role: .destructive) {
                            Task { await einladungWiderrufen(einladung) }
                        } label: {
                            Label("Widerrufen", systemImage: "xmark")
                        }
                    }
                }
            }
            Button {
                zeigtEinladung = true
            } label: {
                Label("Einladung anlegen", systemImage: "envelope")
            }
            .listRowBackground(Farben.flaechePanel)
        } header: {
            Text("Einladungen")
        } footer: {
            Text("""
                Ein Link für EINE Person, EINMAL gültig, mit Rolle. Der \
                sichere Weg für einen Assistenztrainer. Für eine ganze \
                Mannschaft ist der Teamcode bequemer.
                """)
        }
    }

    // MARK: - Schlüssel

    private func schluesselteil(_ liste: [Modell.Schluessel]) -> some View {
        Section {
            ForEach(liste) { schluessel in
                VStack(alignment: .leading, spacing: 4) {
                    Text(schluessel.name)
                        .foregroundStyle(Farben.ink)
                    Text("\(schluessel.bereichText) · \(schluessel.zustand)")
                        .font(.caption)
                        .foregroundStyle(Farben.inkStill)
                }
                .padding(.vertical, 2)
                // DER SICHTBARE WEG (B1), wie bei den Einladungen. Was
                // mit diesem Schluessel angebunden ist, kommt danach
                // sofort nicht mehr an die Daten.
                .overlay(alignment: .trailing) {
                    Zeilenmenue {
                        Button(role: .destructive) {
                            Task { await schluesselWiderrufen(schluessel) }
                        } label: {
                            Label("Widerrufen", systemImage: "xmark")
                        }
                    }
                }
                .listRowBackground(Farben.flaechePanel)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await schluesselWiderrufen(schluessel) }
                    } label: {
                        Label("Widerrufen", systemImage: "xmark")
                    }
                }
            }
            Button {
                zeigtSchluessel = true
            } label: {
                Label("Schlüssel anlegen", systemImage: "gearshape.2")
            }
            .listRowBackground(Farben.flaechePanel)
        } header: {
            Text("Maschinenschlüssel")
        } footer: {
            Text("""
                Für fremde Programme, die Plays lesen sollen. Kein Zugang für \
                Menschen: Ein Schlüssel gehört der Mannschaft und niemandem \
                sonst.
                """)
        }
    }

    // MARK: - Arbeit

    private func laden() async {
        do {
            team = try await Laden(anmeldung: anmeldung).team(kopf.id)
            fehler = nil
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            fehler = Fehlertext.von(error)
        }
    }

    private func codeAbschalten() async {
        laeuft = true
        defer { laeuft = false }
        do {
            let ergebnis = try await Laden(anmeldung: anmeldung)
                .teamcodeAbschalten(team: stand.id)
            meldung = ergebnis.meldung
            await laden()
        } catch {
            meldung = Fehlertext.von(error)
        }
    }

    private func einladungWiderrufen(_ einladung: Modell.Einladung) async {
        do {
            meldung = try await Laden(anmeldung: anmeldung)
                .einladungWiderrufen(einladung.id).meldung
            await laden()
        } catch {
            meldung = Fehlertext.von(error)
        }
    }

    private func schluesselWiderrufen(_ schluessel: Modell.Schluessel) async {
        do {
            meldung = try await Laden(anmeldung: anmeldung)
                .schluesselWiderrufen(schluessel.id).meldung
            await laden()
        } catch {
            meldung = Fehlertext.von(error)
        }
    }
}

// MARK: - Eine Zeile im Kader

/// Name, Rolle, seit wann, wie viel sitzt.
///
/// Der Balken fehlt, wo der Server keinen Fortschritt geschickt hat --
/// und das ist keine Lücke: Wie weit jemand ist, geht den Trainerstab
/// etwas an. Ein Balken auf null Prozent sähe aus wie eine Aussage über
/// den Menschen, obwohl bloß niemand fragen durfte.
struct KaderZeile: View {
    let zeile: Modell.Kadermitglied

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(zeile.name)
                    .font(.headline)
                    .foregroundStyle(Farben.ink)
                if zeile.ich { Marke(text: "du") }
                Spacer()
                if let fortschritt = zeile.fortschritt {
                    Text("\(fortschritt.sitzen) von \(fortschritt.gesamt)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Farben.inkStill)
                }
            }
            if let fortschritt = zeile.fortschritt, fortschritt.gesamt > 0 {
                Balken(anteil: fortschritt.anteil)
            }
            HStack(spacing: 6) {
                Text(Kaderblock.unterzeile(zeile))
                    .font(.caption)
                    .foregroundStyle(Farben.inkStill)
                if zeile.fortschritt?.ausAuftrag == true {
                    Marke(text: String(localized: "gegen die Aufgabe"))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
