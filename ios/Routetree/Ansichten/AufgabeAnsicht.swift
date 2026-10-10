import SwiftUI

/// Plays für einen Spieler aufgeben (A7, jetzt auch in der App).
///
/// **Die Entscheidung, an der alles hängt: eine Absendung bedeutet den
/// VOLLSTÄNDIGEN Stand.** Was nicht angehakt ist, ist nicht aufgegeben.
/// Deshalb schickt die App eine Liste und nicht zwei (`dazu`, `weg`):
/// Zwei Listen wären zwei Gelegenheiten, das Wegnehmen zu vergessen, und
/// dann sammeln sich Aufträge an, die niemand mehr loswird. Lautlos,
/// denn eine Kreuzchenliste zeigt nicht, was sie nicht zeigt.
///
/// **Gerechnet wird in `Aufgabenblock`**, nicht hier. Es gibt keinen
/// Mac: Eine Regel in einer SwiftUI-Ansicht lässt sich nicht messen,
/// sondern nur behaupten. Dieselbe Entscheidung wie bei `Zeichenblock`
/// (B4) und `Uebungsblock` (B8).
struct AufgabeAnsicht: View {
    let team: Int
    let mitglied: Int
    let name: String
    /// Wird gerufen, wenn wirklich etwas gesichert wurde.
    let geaendert: () -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen
    @State private var blatt: Modell.Aufgabenblatt?
    @State private var auswahl: Aufgabenblock?
    @State private var laeuft = false
    @State private var fehler: String?
    @State private var meldung: String?

    var body: some View {
        ZStack {
            Farben.flaeche.ignoresSafeArea()
            inhalt
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Fertigknopf(name: String(localized: "Sichern")) {
                    Task { await sichern() }
                }
                    .disabled(!(auswahl?.geaendert ?? false) || laeuft)
            }
        }
        .task { await laden() }
        // NEU LADEN GEHT ÜBERALL, WO GELADEN WIRD (02.09.2026).
        //
        // Gezählt: Fünf Ansichten hatten weder `.refreshable` noch einen
        // Knopf dafür -- man kam nur heraus und wieder herein. Am
        // Spielfeldrand, wo der Empfang kommt und geht, ist das der
        // häufigste Handgriff überhaupt.
        .refreshable { await laden() }
        .alert("Hinweis",
               isPresented: Binding(get: { meldung != nil },
                                    set: { if !$0 { meldung = nil } })) {
            Button("Verstanden", role: .cancel) {
                meldung = nil
                schliessen()
            }
        } message: {
            Text(meldung ?? "")
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        if let fehler, blatt == nil {
            Hinweis(zeichen: "exclamationmark.triangle",
                    titel: String(localized: "Das hat nicht geklappt"),
                    text: fehler) {
                Button("Nochmal versuchen") { Task { await laden() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
            }
        } else if let blatt, let stand = auswahl {
            if blatt.hefte.isEmpty {
                // Eine leere Liste mit einem Sichern-Knopf sieht aus wie
                // ein Fehler. Sie ist keiner: Es gibt schlicht noch
                // nichts aufzugeben.
                Hinweis(zeichen: "checklist",
                        titel: String(localized: "Noch keine Plays"),
                        text: String(localized: """
                            Sobald in einem Playbook dieser Mannschaft Plays \
                            stehen, lassen sie sich hier aufgeben.
                            """))
            } else {
                liste(blatt, stand)
            }
        } else {
            ProgressView().tint(Farben.akzent)
        }
    }

    private func liste(_ blatt: Modell.Aufgabenblatt,
                       _ stand: Aufgabenblock) -> some View {
        List {
            Section {
                Text(kopfsatz(stand))
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
                    .listRowBackground(Farben.flaechePanel)
                if stand.anzahl > 0 {
                    Button("Alles abwählen") { auswahl?.alleAus() }
                        .listRowBackground(Farben.flaechePanel)
                }
            }
            ForEach(blatt.hefte) { heft in
                Section {
                    ForEach(heft.plays) { eintrag in
                        Button {
                            auswahl?.umschalten(eintrag.id)
                        } label: {
                            HStack {
                                Text(eintrag.titel)
                                    .foregroundStyle(Farben.ink)
                                Spacer()
                                if stand.istAngehakt(eintrag.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Farben.akzent)
                                }
                            }
                            // Trefferfläche: Die Mitte der Zeile ist sonst Luft.
                            .contentShape(Rectangle())
                        }
                        .listRowBackground(Farben.flaechePanel)
                    }
                } header: {
                    HStack {
                        Text(heft.name)
                        Spacer()
                        // NUR DIESES HEFT. Der Reflex wäre, „alles"
                        // auf die ganze Liste zu legen; dann nähme ein
                        // Coach, der bei der Offense aufräumt, nebenbei
                        // die Defense-Aufgaben mit weg.
                        // BEIDE WÖRTER DURCH DIE ÜBERSETZUNG.
                        // Ein Literal im Fragezeichenausdruck sammelt
                        // `appsprache.py` nicht ein; „Alle" lag nur
                        // zufällig durch eine andere Stelle im
                        // Katalog, „Keins" in keinem. Auf einem
                        // englischen Telefon hiess derselbe Knopf
                        // deshalb einmal „All" und einmal „Keins".
                        Button(stand.heftIstGanzAn(heft)
                               ? String(localized: "Keins")
                               : String(localized: "Alle")) {
                            auswahl?.heft(heft, an: !stand.heftIstGanzAn(heft))
                        }
                        .font(.caption)
                    }
                }
            }
            if let fehler {
                Section {
                    Text(fehler)
                        .foregroundStyle(Farben.fehler)
                        .listRowBackground(Farben.flaechePanel)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    /// Was die Auswahl gerade bedeutet, in einem Satz.
    ///
    /// Ausdrücklich auch der Fall „nichts angehakt": Er heißt nicht
    /// „keine Aufgabe eingetragen", sondern „geübt wird aus dem ganzen
    /// Playbook", und das ist etwas anderes.
    private func kopfsatz(_ stand: Aufgabenblock) -> String {
        if stand.anzahl == 0 {
            return String(localized:
                "Nichts angehakt. \(name) übt dann aus dem ganzen Playbook.")
        }
        // Ganze Sätze statt eines eingesetzten Stücks (R22).
        return stand.anzahl == 1
            ? String(localized: """
                1 Play angehakt. Er steht im Playbook oben und kommt im \
                Übungsmodus zuerst dran.
                """)
            : String(localized: """
                \(stand.anzahl) Plays angehakt. Sie stehen im Playbook oben \
                und kommen im Übungsmodus zuerst dran.
                """)
    }

    private func laden() async {
        do {
            let neu = try await Laden(anmeldung: anmeldung)
                .aufgabe(team: team, mitglied: mitglied)
            blatt = neu
            auswahl = Aufgabenblock(blatt: neu)
            fehler = nil
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            fehler = Fehlertext.von(error)
        }
    }

    private func sichern() async {
        guard let stand = auswahl else { return }
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            let ergebnis = try await Laden(anmeldung: anmeldung).aufgabeSetzen(
                team: team, mitglied: mitglied, plays: stand.alsListe)
            if ergebnis.geaendert { geaendert() }
            // Der Satz kommt vom Server (`kader.Ergebnis`). In Swift
            // nachgebaut wäre er beim nächsten Wort ein anderer als im
            // Browser.
            meldung = ergebnis.meldung
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}
