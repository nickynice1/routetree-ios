// Welche Uhren mitlaufen -- und wer eine neue anmeldet (R143).
//
// **Niklas am 01.10.2026**, auf die Frage, ob ein Ruf an alle geht
// oder je Uhr: „je uhr wählbar". Offense und Defense tragen
// verschiedene Uhren, und nicht jeder Spielzug gilt allen.
//
// ## Was hier NICHT passiert: der Schlüssel auf eine fremde Uhr
//
// Ein iPhone erreicht über WatchConnectivity ausschliesslich SEINE
// eigene gekoppelte Uhr. Es gibt keinen Weg, mit der Uhr eines anderen
// Menschen zu sprechen -- weder über Bluetooth noch sonstwie.
//
// Deshalb steht hier beides getrennt:
//
//   * **Anmelden** legt eine Sitzung an und zeigt den Schlüssel. Das
//     darf nur, wer die Mannschaft führt.
//   * **Auf meine Uhr** schickt ihn an das eigene Handgelenk -- der
//     Fall, in dem der Coach selbst eine Uhr trägt.
//
// Für fremde Uhren braucht es den Weg über das Telefon des Spielers.
// Der kommt als Nächstes (Multipeer, so entschieden am 01.10.2026).

import SwiftUI

struct UhrenAnsicht: View {

    let team: Int

    @EnvironmentObject private var anmeldung: Anmeldung
    @EnvironmentObject private var coaching: Coachingmodus
    @Environment(\.dismiss) private var schliessen

    @StateObject private var bruecke = Uhrbruecke()
    @StateObject private var funk = Schluesselsender()

    @State private var legtAn = false
    @State private var neuerName = ""
    @State private var frischerSchluessel: Frischling?
    @State private var arbeitet = false

    /// Wie der Coach auf dem Funk heisst -- der Spieler liest es.
    @State private var meinName = ""

    /// Ein gerade angelegter Schlüssel.
    ///
    /// **Er steht genau einmal zur Verfügung** -- danach kann ihn
    /// niemand mehr nachschlagen, auch der Server nicht. Deshalb ein
    /// eigenes Blatt, das man wegtippen muss, und kein Hinweis, der
    /// nach drei Sekunden verschwindet.
    private struct Frischling: Identifiable {
        let id: Int
        let name: String
        let schluessel: String
    }

    var body: some View {
        NavigationStack {
            List {
                if coaching.uhren.isEmpty {
                    leer
                } else {
                    Section {
                        ForEach(coaching.uhren) { uhr in zeile(uhr) }
                    } header: {
                        Text("Uhren dieser Mannschaft")
                    } footer: {
                        Text("Angetippt heisst: bekommt die gerufenen Plays.")
                    }
                }

                Section {
                    Button {
                        neuerName = ""
                        legtAn = true
                    } label: {
                        Label("Uhr anmelden", systemImage: "plus")
                    }
                    .accessibilityIdentifier("uhr-anmelden")
                    .disabled(arbeitet)
                }
            }
            .navigationTitle(Text("Uhren"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Fertigknopf { schliessen() }
                }
            }
            .alert("Uhr anmelden", isPresented: $legtAn) {
                TextField("Name", text: $neuerName)
                Button("Abbrechen", role: .cancel) {}
                Button("Anmelden") { Task { await anmelden() } }
            } message: {
                Text("Zum Beispiel „Nummer 7“ oder „Quarterback“.")
            }
            .sheet(item: $frischerSchluessel) { neu in
                schluesselBlatt(neu)
            }
            .task { await laden() }
            .refreshable { await laden() }
        }
    }

    // MARK: - Teile

    private var leer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Noch keine Uhr angemeldet.")
                .font(.headline)
            Text("Melde für jeden Spieler, der eine Uhr trägt, eine an. Den Schlüssel bekommst du genau einmal zu sehen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func zeile(_ uhr: Coachinguhr) -> some View {
        Button {
            if coaching.gewaehlt.contains(uhr.id) {
                coaching.gewaehlt.remove(uhr.id)
            } else {
                coaching.gewaehlt.insert(uhr.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: coaching.gewaehlt.contains(uhr.id)
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(coaching.gewaehlt.contains(uhr.id)
                                     ? Farben.akzent : Farben.inkStill)
                VStack(alignment: .leading, spacing: 2) {
                    Text(uhr.name)
                        .foregroundStyle(Farben.ink)
                    Text(uhr.zeile)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // DER PUNKT SAGT, OB JEMAND DAHINTERSTEHT. Eine Uhr,
                // die sich seit anderthalb Minuten nicht gemeldet
                // hat, ist in der Tasche, im Funkloch oder leer --
                // und ein Ruf an sie verschwindet lautlos.
                Circle()
                    .fill(uhr.lebt ? Farben.gut : Farben.inkStill)
                    .frame(width: 8, height: 8)
            }
            // SONST IST NUR DER TEXT TIPPBAR.
            //
            // Der `Spacer` ist leer, und Leeres nimmt keine Berührung
            // an -- wer rechts neben den Namen tippt, trifft nichts.
            // Gemeldet von Niklas am 28.09.2026 am Übertragen-Knopf;
            // `test_trefferflaeche.py` hält es seither fest, und es
            // hat genau hier wieder zugeschlagen.
            //
            // Am LABEL und nicht am Knopf: Die Trefferfläche
            // entscheidet die Beschriftung.
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("uhr-\(uhr.id)")
    }

    private func schluesselBlatt(_ neu: Frischling) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Der Schlüssel für „\(neu.name)“")
                    .font(.headline)
                Text(neu.schluessel)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Farben.flaechePanel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Du siehst ihn genau einmal. Danach kann ihn niemand mehr nachschlagen, auch der Server nicht.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if bruecke.uhrVorhanden {
                    Button {
                        bruecke.coachingschluessel(neu.schluessel)
                    } label: {
                        Label("Auf meine Uhr schicken",
                              systemImage: "applewatch")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("schluessel-auf-meine-uhr")
                }

                Divider()
                funkteil(neu)
                Spacer()
            }
            .padding()
            .navigationTitle(Text("Schlüssel"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Fertigknopf {
                        funk.aufhoeren()
                        frischerSchluessel = nil
                    }
                }
            }
            // AUFHOEREN, WENN DAS BLATT ZUGEHT. Ein Sucher, der
            // weiterläuft, hält Bluetooth und das lokale Netz offen --
            // auf einem Telefon, das am Spieltag vier Stunden halten
            // muss, ist das kein Detail.
            .onDisappear { funk.aufhoeren() }
        }
    }

    /// Die Übergabe per Funk (R143, Multipeer).
    ///
    /// **So entschieden von Niklas am 01.10.2026**, auf die Frage, wie
    /// der Schlüssel zum Spieler kommt: Telefon zu Telefon.
    ///
    /// Der Spieler zeigt sich an, der Coach sucht und tippt den
    /// richtigen Namen an -- die Begründung dieser Richtung steht in
    /// `Schluesselfunk.swift`.
    @ViewBuilder
    private func funkteil(_ neu: Frischling) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("An den Spieler übergeben")
                .font(.headline)

            if !funk.sucht {
                Text("Der Spieler öffnet auf SEINEM iPhone Routetree, dann Konto, „Coach zu Spieler“ und „Vom Coach empfangen“. Danach steht er hier in der Liste.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    funk.anfangen(schluessel: neu.schluessel, name: meinName)
                } label: {
                    Label("Spieler in der Nähe suchen",
                          systemImage: "dot.radiowaves.left.and.right")
                }
                .accessibilityIdentifier("funk-suchen")
            } else if funk.gefunden.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Sucht …")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(funk.gefunden) { geraet in
                    Button {
                        funk.schicken(an: geraet)
                    } label: {
                        HStack(spacing: 8) {
                            // **DAS HÄKCHEN IST DIE GANZE AUSKUNFT.**
                            // Bei zwölf Spielern hintereinander ist die
                            // einzige Frage, die der Coach wirklich hat:
                            // Wen habe ich schon? Ohne diese Spalte
                            // schickt er dem einen zweimal und dem
                            // anderen nie.
                            Image(systemName: funk.versorgt.contains(geraet.id)
                                  ? "checkmark.circle.fill"
                                  : "arrow.up.circle")
                                .foregroundStyle(funk.versorgt.contains(geraet.id)
                                                 ? Farben.gut : Farben.akzent)
                            Text(geraet.name)
                                .foregroundStyle(Farben.ink)
                            Spacer()
                        }
                        // Wie oben in `zeile`: Der Spacer nimmt keine
                        // Berührung an, und ein Name ist ein schmales
                        // Ziel für einen Daumen am Spielfeldrand.
                        .contentShape(Rectangle())
                    }
                }
                Button {
                    funk.aufhoeren()
                } label: {
                    Text("Suche beenden")
                        .font(.footnote)
                }
            }

            if let hinweis = funk.hinweis {
                Text(hinweis)
                    .font(.footnote)
                    .foregroundStyle(Farben.warnung)
            }

            Text("Oder du liest ihm den Schlüssel vor. Er kann ihn auch von Hand eintragen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Handgriffe

    private func laden() async {
        guard let marke = try? await anmeldung.gueltigesToken() else { return }
        await coaching.uhrenHolen(token: marke)
        // DER EIGENE NAME FÜR DEN FUNK. Er steht auf dem Telefon des
        // Spielers, wenn der Schlüssel ankommt -- „von Niklas
        // Bergmann" statt „von iPhone". Scheitert es, bleibt der Name
        // leer und `funkname` setzt „Unbenannt" ein; das ist kein
        // Grund, die Uhrenliste nicht zu zeigen.
        if meinName.isEmpty,
           let stand = try? await Kontodaten.setzen(token: marke) {
            meinName = stand.anzeigename
        }
    }

    private func anmelden() async {
        let name = neuerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard let marke = try? await anmeldung.gueltigesToken() else { return }
        arbeitet = true
        defer { arbeitet = false }
        do {
            let (uhr, schluessel) = try await Coaching.uhrAnmelden(
                team: team, name: name, token: marke)
            frischerSchluessel = Frischling(
                id: uhr.id, name: uhr.name, schluessel: schluessel)
            await coaching.uhrenHolen(token: marke)
            // NEU ANGEMELDETE SIND GLEICH DABEI. Wer eine Uhr
            // anmeldet, will sie benutzen.
            coaching.gewaehlt.insert(uhr.id)
        } catch {
            coaching.hinweis = String(localized: "Die Uhr liess sich nicht anmelden.")
        }
    }
}
