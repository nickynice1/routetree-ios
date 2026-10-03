// Gespeicherte Aufstellungen im Editor (B7).
//
// Dieselben vier Handgriffe wie im Fenster „Formationen" des Browsers:
// anwenden, sichern, umbenennen, entfernen. Eine Formation ist nur die
// Aufstellung, ohne Linien -- wer sie anwendet, bekommt die Positionen,
// und was jeder Spieler danach läuft, entscheidet er im Play neu.
//
// WARUM DAS EIN BLATT IST UND KEINE EIGENE SEITE. Eine Formation wird im
// Editor gebraucht und sonst nirgends: Man zieht sie über die
// Aufstellung, sieht das Feld darunter und arbeitet weiter. Wer dafür
// die Seite verlassen müsste, käme mit einem ungesicherten Play zurück
// und wüsste nicht mehr, was er eigentlich vorhatte.
//
// WAS HIER NICHT ENTSCHIEDEN WIRD: was „anwenden" mit der Zeichnung
// macht. Das steht in `Zeichenblock.formationAnwenden` und ist dort
// gemessen -- ein Zug, ein Schritt im Verlauf, die Linien bleiben.

import SwiftUI

struct Formationsblatt: View {
    let playbook: Int
    /// Die Aufstellung, die gerade auf dem Feld steht -- zum Sichern.
    let aufstellung: [Zeichnung.Spieler]
    /// Das Feldformat dieses Playbooks. Der Bauer (R46) braucht es, um
    /// überhaupt ein Feld zu zeichnen -- und es muss DASSELBE sein wie
    /// im Editor: Auf einem kleinen Feld stünde eine Aufstellung sonst
    /// fünf Yards neben der Seitenlinie.
    let feld: Feld
    /// Nur zum Durchreichen an den Bauer: Er zeichnet, und wie gross
    /// eine Figur dabei wird, haengt an der Spielform.
    var spielform: String = Spielform.standard
    /// Ob hier gesichert, umbenannt und entfernt werden darf. Sagt der
    /// Server über den Play, nicht die App (ADR-0007).
    let darfAendern: Bool
    /// Eine Formation anwenden. Das Blatt geht danach zu: Wer sie
    /// übernommen hat, will das Feld sehen und nicht die Liste.
    let anwenden: (Modell.Formation) -> Void
    /// Eine EINGEBAUTE Vorlage anwenden (R110.5).
    ///
    /// **Getrennt von `anwenden`, obwohl beides eine Aufstellung
    /// setzt.** Eine gespeicherte Formation ist eine Liste von
    /// Positionen; eine Vorlage ist eine Rechnung, die erst mit der
    /// Line of Scrimmage und der Angriffsrichtung fertig wird. Wer das
    /// hier auflöste, hätte die Rechnung in der Ansicht -- und es gibt
    /// keinen Mac, auf dem sie sich ausprobieren liesse.
    var vorlageAnwenden: ((Modell.Vorlage, Zeichnung.Spieler.Seite)
                          -> Void)?
    /// Die Verteidigung vom Feld nehmen (R110.5).
    var defenseEntfernen: (() -> Void)?
    let schliessen: () -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var formationen: [Modell.Formation] = []
    /// Die eingebauten Vorlagen (R110.5). Welche gelten, entscheidet
    /// die Spielform, und das entscheidet der Server.
    @State private var vorlagen = Modell.Vorlagensatz()
    @State private var laedt = true
    @State private var fehler: String?
    @State private var meldung: String?

    @State private var neuerName = ""
    @State private var sichert = false

    @State private var inArbeit: Modell.Formation?
    @State private var arbeitsname = ""
    @State private var zumLoeschen: Modell.Formation?
    /// Welche Aufstellung angewendet werden soll -- nach Rückfrage.
    ///
    /// **Warum überhaupt gefragt wird.** Ein Tipp auf die Zeile hat die
    /// Aufstellung bis zum 02.09.2026 SOFORT angewendet, und das
    /// überschreibt die Positionen aller Spieler in der laufenden
    /// Zeichnung. Wer die Zeile antippt, um an das Löschen zu kommen
    /// (die Wischgeste kennt nicht jeder), hat damit seine eigene Arbeit
    /// überschrieben -- rückgängig geht es, aber nur wer weiß, dass
    /// gerade etwas passiert ist.
    @State private var zumAnwenden: Modell.Formation?
    /// Was der Bauer bauen soll (R46). `nil` heisst: er ist zu.
    @State private var baut: Bauauftrag?

    /// Womit der Bauer anfängt.
    ///
    /// Eigener Typ und kein `Bool`: Er trägt die Startaufstellung mit,
    /// und beim ÄNDERN einer vorhandenen wäre das eine andere.
    struct Bauauftrag: Identifiable {
        let start: [Zeichnung.Spieler]
        let name: String
        var id: String { name }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                inhalt
            }
            .navigationTitle("Aufstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Fertigknopf { schliessen() }
                }
            }
            .alert("Umbenennen",
                   isPresented: Binding(get: { inArbeit != nil },
                                        set: { if !$0 { inArbeit = nil } })) {
                TextField("Name", text: $arbeitsname)
                Button("Sichern") { Task { await umbenennen() } }
                    .disabled(arbeitsname.trimmingCharacters(
                        in: .whitespaces).isEmpty)
                Button("Abbrechen", role: .cancel) { inArbeit = nil }
            }
            .alert("Aufstellung entfernen",
                   isPresented: Binding(get: { zumLoeschen != nil },
                                        set: { if !$0 { zumLoeschen = nil } }),
                   presenting: zumLoeschen) { formation in
                Button("Entfernen", role: .destructive) {
                    Task { await loeschen(formation) }
                }
                Button("Abbrechen", role: .cancel) { zumLoeschen = nil }
            } message: { formation in
                // Was NICHT passiert, gehört in den Satz: Eine gelöschte
                // Formation reißt keinen Play mit, weil an keinem Play
                // ein Verweis auf sie hängt.
                Text("""
                    „\(formation.name)“ ist danach weg. Plays, die aus ihr \
                    entstanden sind, bleiben unverändert.
                    """)
            }
            // DIE AUFSTELLUNG ANWENDEN FRAGT VORHER (R51).
            //
            // Sie überschreibt die Positionen aller Spieler in der
            // laufenden Zeichnung. Bis zum 02.09.2026 tat ein Tipp auf
            // die Zeile das sofort -- und die Zeile ist genau das, was
            // man antippt, wenn man nach dem Umbenennen oder Löschen
            // sucht und die Wischgeste nicht kennt.
            //
            // Rückgängig geht es (der Editor merkt sich den Schritt).
            // Das nützt aber nur dem, der überhaupt merkt, dass gerade
            // etwas passiert ist.
            .alert("Aufstellung anwenden",
                   isPresented: Binding(get: { zumAnwenden != nil },
                                        set: { if !$0 { zumAnwenden = nil } }),
                   presenting: zumAnwenden) { formation in
                Button("Anwenden") {
                    let genommen = formation
                    zumAnwenden = nil
                    anwenden(genommen)
                }
                Button("Abbrechen", role: .cancel) { zumAnwenden = nil }
            } message: { formation in
                Text("""
                    „\(formation.name)“ setzt alle Spieler auf ihre \
                    Positionen aus dieser Aufstellung. Die Linien bleiben, \
                    und Rückgängig nimmt es zurück.
                    """)
            }
            .sheet(item: $baut) { auftrag in
                Formationsbauer(playbook: playbook, feld: feld,
                                start: auftrag.start,
                                spielform: spielform,
                                startname: auftrag.name) { satz in
                    baut = nil
                    if let satz {
                        meldung = satz
                        // Neu laden: Der Server vergibt die Kennung und
                        // sagt, wie viele Figuren angekommen sind.
                        Task { await laden() }
                    }
                }
                .environmentObject(anmeldung)
            }
            .task { await laden() }
        }
    }

    /// Die eingebauten Aufstellungen (R110.5).
    ///
    /// **Nur, wenn geändert werden darf.** Ein Zuschauer kann sie nicht
    /// anwenden; ein Abschnitt voller Knöpfe, die nichts tun, ist einer
    /// zu viel (ADR-0007).
    @ViewBuilder
    private var vorlagenteil: some View {
        if darfAendern, vorlageAnwenden != nil,
           !(vorlagen.offense.isEmpty && vorlagen.defense.isEmpty) {
            if !vorlagen.offense.isEmpty {
                Section {
                    ForEach(vorlagen.offense) { vorlage in
                        vorlagenzeile(vorlage, seite: .offense)
                    }
                } header: {
                    Text("Angriff")
                } footer: {
                    Text("""
                        Setzt die Angreifer neu. Die Verteidigung bleibt \
                        stehen, und gezeichnete Wege bleiben an ihren \
                        Spielern.
                        """)
                }
            }
            if !vorlagen.defense.isEmpty {
                Section {
                    ForEach(vorlagen.defense) { vorlage in
                        vorlagenzeile(vorlage, seite: .defense)
                    }
                    if let defenseEntfernen {
                        Button(role: .destructive) {
                            defenseEntfernen()
                            schliessen()
                        } label: {
                            Label("Defense entfernen",
                                  systemImage: "person.badge.minus")
                        }
                        .listRowBackground(Farben.flaechePanel)
                    }
                } header: {
                    Text("Verteidigung")
                } footer: {
                    // WAS DABEI VERLOREN GEHT, GEHOERT IN DEN SATZ. Die
                    // Kennungen einer Deckung sind andere als die der
                    // vorigen; eine Zone, die an einem Safety hing,
                    // gehoert danach niemandem.
                    Text("""
                        Ersetzt die Verteidigung. Wege, die an einem \
                        Verteidiger hingen, gehen dabei mit.
                        """)
                }
            }
        }
    }

    private func vorlagenzeile(_ vorlage: Modell.Vorlage,
                               seite: Zeichnung.Spieler.Seite) -> some View {
        Button {
            vorlageAnwenden?(vorlage, seite)
            schliessen()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(vorlage.name)
                    .font(.headline)
                    .foregroundStyle(Farben.ink)
                // DER SATZ DAZU GEHOERT DANEBEN. „Bunch rechts" sagt
                // einem Trainer, der zehn Jahre dabei ist, alles -- und
                // dem, der im ersten Jahr eine Jugend uebernommen hat,
                // nichts.
                Text(vorlage.hinweis)
                    .font(.caption)
                    .foregroundStyle(Farben.inkStill)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .listRowBackground(Farben.flaechePanel)
    }

    @ViewBuilder
    private var inhalt: some View {
        if laedt {
            ProgressView().tint(Farben.akzent)
        } else if let fehler {
            Hinweis(zeichen: "exclamationmark.triangle",
                    titel: String(localized: "Das hat nicht geklappt"),
                    text: fehler) {
                Button("Nochmal versuchen") { Task { await laden() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
            }
        } else {
            liste
        }
    }

    private var liste: some View {
        List {
            // DIE EINGEBAUTEN ZUERST (R110.5).
            //
            // Wer ein Playbook neu anlegt, hat noch keine gesicherte
            // Aufstellung -- und die Liste begann bis zum 10.09.2026
            // mit „Noch keine Aufstellung gesichert." Das ist der
            // Bildschirm, auf dem jemand seinen ersten Play zeichnen
            // will, und er sagte ihm: hier gibt es nichts.
            vorlagenteil

            if let meldung {
                Section {
                    Text(meldung)
                        .font(.footnote)
                        .foregroundStyle(Farben.inkStill)
                }
                .listRowBackground(Farben.flaechePanel)
            }

            Section {
                if formationen.isEmpty {
                    Text("Noch keine Aufstellung gesichert.")
                        .font(.subheadline)
                        .foregroundStyle(Farben.inkStill)
                        .listRowBackground(Farben.flaechePanel)
                }
                ForEach(formationen) { formation in
                    Button {
                        zumAnwenden = formation
                    } label: {
                        HStack {
                            Text(formation.name)
                                .font(.headline)
                                .foregroundStyle(Farben.ink)
                            Spacer()
                            Text(formation.anzahl == 1
                                 ? String(localized: "1 Spieler")
                                 : String(localized:
                                    "\(formation.anzahl) Spieler"))
                                .font(.caption)
                                .foregroundStyle(Farben.inkStill)
                        }
                        // Trefferfläche: Die Mitte der Zeile ist sonst
                        // Luft, und `.plain` macht es nicht besser.
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // DER SICHTBARE WEG (B1). Als Auflage am rechten
                    // Rand und nicht in einem `HStack`: Die ganze Zeile
                    // ist hier ein Knopf, der die Aufstellung anwendet.
                    // Ein zweiter Knopf DARIN bekäme den Tipp nicht.
                    .overlay(alignment: .trailing) {
                        if darfAendern {
                            Zeilenmenue {
                                Button {
                                    zumAnwenden = formation
                                } label: {
                                    Label("Anwenden",
                                          systemImage: "square.on.square")
                                }
                                Button {
                                    arbeitsname = formation.name
                                    inArbeit = formation
                                } label: {
                                    Label("Umbenennen", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    zumLoeschen = formation
                                } label: {
                                    Label("Entfernen", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listRowBackground(Farben.flaechePanel)
                    .swipeActions(edge: .trailing) {
                        if darfAendern {
                            Button(role: .destructive) {
                                zumLoeschen = formation
                            } label: {
                                Label("Entfernen", systemImage: "trash")
                            }
                            Button {
                                arbeitsname = formation.name
                                inArbeit = formation
                            } label: {
                                Label("Umbenennen", systemImage: "pencil")
                            }
                            .tint(Farben.akzent)
                        }
                    }
                    // Auch auf langes Drücken (R51).
                    .contextMenu {
                        Button {
                            zumAnwenden = formation
                        } label: {
                            Label("Anwenden", systemImage: "square.on.square")
                        }
                        if darfAendern {
                            Button {
                                arbeitsname = formation.name
                                inArbeit = formation
                            } label: {
                                Label("Umbenennen", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                zumLoeschen = formation
                            } label: {
                                Label("Entfernen", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("Anwenden")
            } footer: {
                Text("""
                    Übernimmt nur die Positionen. Die Linien im Play bleiben \
                    stehen, und ein Rückgängig bringt die alte Aufstellung \
                    zurück.
                    """)
            }

            if darfAendern {
                // DER BAUER (R46). Niklas: „Formationen Builder wäre
                // auch sehr cool."
                //
                // Er steht VOR „Was jetzt auf dem Feld steht": Wer
                // eine Formation als solche bauen will, will nicht
                // erst einen Play zurechtschieben. Die andere Hälfte
                // bleibt daneben -- sie ist der schnellere Weg, wenn
                // die Aufstellung ohnehin schon steht.
                Section {
                    Button {
                        baut = Bauauftrag(start: aufstellung, name: "")
                    } label: {
                        Label("Aufstellung bauen", systemImage: "hammer")
                    }
                } footer: {
                    Text("""
                        Ein eigener Bildschirm nur für die Figuren, ohne \
                        Linien und ohne dass ein Play dafür entsteht.
                        """)
                }

                Section {
                    TextField("Name der Aufstellung", text: $neuerName)
                        .autocorrectionDisabled()
                    Button("Aufstellung sichern") {
                        Task { await aufstellungSichern() }
                    }
                    .disabled(neuerName.trimmingCharacters(in: .whitespaces)
                                .isEmpty || sichert || aufstellung.isEmpty)
                } header: {
                    Text("Was jetzt auf dem Feld steht")
                } footer: {
                    // Der Hinweis auf das Ersetzen steht VORHER da, nicht
                    // erst in der Quittung. Ein Name, den es schon gibt,
                    // überschreibt die alte Aufstellung -- genau wie im
                    // Browser, und das soll niemanden überraschen.
                    Text(aufstellung.isEmpty
                         ? String(localized: "Auf dem Feld steht niemand.")
                         : String(localized: """
                             \(aufstellung.count) Spieler. Ein Name, den es \
                             schon gibt, ersetzt die vorhandene Aufstellung.
                             """))
                }
                .listRowBackground(Farben.flaechePanel)
            }
        }
        .scrollContentBackground(.hidden)
    }

    // --- Netz -------------------------------------------------------------

    private func laden() async {
        laedt = true
        fehler = nil
        defer { laedt = false }
        do {
            let liste = try await Laden(anmeldung: anmeldung)
                .formationsliste(playbook: playbook)
            formationen = liste.formationen
            vorlagen = liste.eingebaut
        } catch {
            fehler = Fehlertext.von(error)
        }
    }

    private func aufstellungSichern() async {
        let name = neuerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !aufstellung.isEmpty else { return }
        sichert = true
        defer { sichert = false }
        do {
            let fertig = try await Laden(anmeldung: anmeldung)
                .formationSichern(playbook: playbook, name: name,
                                  aufstellung: aufstellung)
            neuerName = ""
            meldung = fertig.ersetzt
                ? String(localized: """
                    „\(fertig.name)“ ersetzt, jetzt mit \(fertig.anzahl) \
                    Spielern.
                    """)
                : String(localized:
                    "Aufstellung „\(fertig.name)“ gesichert.")
            await laden()
        } catch {
            meldung = Fehlertext.von(error)
        }
    }

    private func umbenennen() async {
        guard let formation = inArbeit else { return }
        let name = arbeitsname.trimmingCharacters(in: .whitespaces)
        inArbeit = nil
        guard !name.isEmpty, name != formation.name else { return }
        do {
            let neu = try await Laden(anmeldung: anmeldung)
                .formationUmbenennen(formation.id, name: name)
            meldung = String(localized: "Heißt jetzt „\(neu.name)“.")
            await laden()
        } catch {
            // Der Satz des Servers: Er weiß, ob der Name schon vergeben
            // ist.
            meldung = Fehlertext.von(error)
            await laden()
        }
    }

    private func loeschen(_ formation: Modell.Formation) async {
        zumLoeschen = nil
        do {
            try await Laden(anmeldung: anmeldung)
                .formationLoeschen(formation.id)
            meldung = String(localized:
                "Aufstellung „\(formation.name)“ entfernt.")
            await laden()
        } catch {
            meldung = Fehlertext.von(error)
        }
    }
}
