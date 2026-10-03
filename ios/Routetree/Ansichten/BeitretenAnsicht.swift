import SwiftUI

/// Mit einem Teamcode beitreten (A4, A5) -- in zwei Schritten.
///
/// **Ein Code allein tritt niemandem bei.** Nachsehen und beitreten sind
/// zwei Handlungen und zwei Adressen. Wer einen Code eintippt, hat noch
/// nichts entschieden; wer beitritt, steht danach im Kader eines fremden
/// Vereins. Deshalb steht zwischen beidem ein Bildschirm, der die
/// Mannschaft beim NAMEN nennt und nicht bei ihrem Code.
///
/// **Ohne gültigen Namen entsteht keine Mitgliedschaft.** Das Feld steht
/// im Beitrittsformular selbst und nicht auf einer Seite danach: Die
/// klickt man weg, und dann steht eine Mitgliedschaft ohne Namen in der
/// Datenbank.
///
/// Geprüft wird hier nur die FORM des Codes (`Teamcodeblock`, gegen den
/// Server gemessen). Ob es ihn gibt, weiß nur der Server -- ein Feld,
/// das erst nach einer Anfrage sagt „so sieht kein Code aus", macht aus
/// einem Tippfehler eine Wartezeit, und in der Umkleide gibt es kein
/// WLAN.
struct BeitretenAnsicht: View {
    let fertig: (Bool) -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var eingabe = ""
    @State private var auskunft: Modell.Codeauskunft?
    @State private var name = ""
    @State private var laeuft = false
    @State private var fehler: String?
    @State private var meldung: String?
    /// `true`, wenn der Beitritt geklappt hat. Erst wenn die Meldung
    /// weggetippt ist, geht das Blatt zu -- sonst läse sie niemand.
    @State private var erledigt = false

    private var code: String { Teamcodeblock.normalisieren(eingabe) }

    var body: some View {
        NavigationStack {
            Form {
                if let auskunft {
                    bestaetigung(auskunft)
                } else {
                    codefeld
                }
                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            .navigationTitle(auskunft == nil
                             ? String(localized: "Teamcode eingeben")
                             : String(localized: "Beitreten"))
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
                    if let auskunft {
                        Fertigknopf(name: String(localized: "Beitreten")) {
                            Task { await beitreten() }
                        }
                            // WAS DASTEHEN MUSS, ENTSCHEIDET
                            // `Kadernameblock` (R24) -- in einer Schule
                            // darf das Feld leer bleiben. Die Bedingung
                            // stand hier ausgeschrieben und hätte den
                            // Knopf ausgerechnet dort gesperrt, wo der
                            // ganze Punkt ist, dass man nichts angeben
                            // muss.
                            .disabled(auskunft.schonDabei || laeuft
                                      || !Kadernameblock.darfAbsenden(
                                            name,
                                            feld: Kadernameblock.feld(
                                                fuer: auskunft)))
                    } else {
                        Button("Weiter") { Task { await nachsehen() } }
                            .disabled(code.isEmpty || laeuft)
                    }
                }
            }
            .alert("Hinweis",
                   isPresented: Binding(get: { meldung != nil },
                                        set: { if !$0 { meldung = nil } })) {
                Button("Verstanden", role: .cancel) {
                    meldung = nil
                    if erledigt { fertig(true) }
                }
            } message: {
                Text(meldung ?? "")
            }
        }
    }

    private var codefeld: some View {
        Section {
            TextField("P7QK-3MRW-9XTB", text: $eingabe)
                .font(.title3.monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
        } header: {
            Text("Der Code deines Trainers")
        } footer: {
            // Kein „ungültig" bei jedem Zeichen: Wer tippt, ist noch
            // nicht fertig. Der Hinweis kommt erst, wenn zwölf Zeichen
            // dastehen und trotzdem nichts stimmt.
            Text(hinweis)
                .foregroundStyle(hinweisIstFehler ? Farben.fehler
                                                  : Farben.inkStill)
        }
    }

    /// Wie viele Zeichen ohne Trenner dastehen. Danach entscheidet sich,
    /// ob ein Hinweis schon fällig ist.
    private var gestrafft: Int {
        eingabe.filter { !Teamcodeblock.trenner.contains($0) }.count
    }

    private var hinweisIstFehler: Bool {
        gestrafft >= Teamcodeblock.laenge && code.isEmpty
    }

    private var hinweis: String {
        if hinweisIstFehler {
            return String(localized: """
                So sieht kein Code aus. Zwölf Zeichen, ohne die Null und ohne \
                das große i. Bindestriche sind egal.
                """)
        }
        return String(localized: """
            Zwölf Zeichen, Bindestriche sind egal. Du siehst zuerst, um \
            welche Mannschaft es geht.
            """)
    }

    private func bestaetigung(_ auskunft: Modell.Codeauskunft) -> some View {
        Group {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(auskunft.team.name)
                        .font(.headline)
                        .foregroundStyle(Farben.ink)
                    if !auskunft.team.verein.isEmpty {
                        Text(auskunft.team.verein)
                            .font(.caption)
                            .foregroundStyle(Farben.inkStill)
                    }
                }
                .padding(.vertical, 2)
            } header: {
                Text("Diese Mannschaft")
            } footer: {
                Text(was(auskunft))
            }
            if !auskunft.schonDabei {
                namensfeld(Kadernameblock.feld(fuer: auskunft))
            }
        }
    }

    /// Das eine Feld über dem Beitritt: Name oder Kürzel.
    ///
    /// Ein Feld und nicht zwei: Wer „van der Berg" in Vorname und
    /// Nachname zwingt, bekommt beides falsch. Was darin steht, sagt
    /// `Kadernameblock` -- die Ansicht entscheidet es nicht selbst.
    private func namensfeld(_ feld: Kadernameblock.Feld) -> some View {
        Section {
            TextField(feld.aufschrift, text: $name)
                // KEIN `.textContentType(.name)` BEIM KÜRZEL. Das Telefon
                // böte sonst den vollen Namen an, den es vom Konto kennt
                // -- ein Feld, das die Namensfreiheit aushebelt, indem es
                // hilfsbereit ist. Dieselbe Entscheidung wie
                // `autocomplete="off"` im Browser.
                .textContentType(feld.pflicht ? .name : .none)
                .autocorrectionDisabled(!feld.pflicht)
        } header: {
            Text(feld.aufschrift)
        } footer: {
            Text(feld.hilfe)
        }
    }

    /// Was ein Beitritt bedeutet, in einem Satz.
    ///
    /// Als eigene Funktion und nicht als Ausdruck in der Ansicht:
    /// Dieselbe Lehre wie aus `PlaybookListe.loeschfrage` (B6) -- eine
    /// Textzusammensetzung mit Bedingung und Interpolation gehört nicht
    /// in einen `Text(...)`-Aufruf.
    private func was(_ auskunft: Modell.Codeauskunft) -> String {
        if auskunft.schonDabei {
            let rolle = auskunft.meineRolle ?? ""
            return String(localized: """
                Du bist schon dabei, als „\(rolle)“. Daran ändert der Code \
                nichts.
                """)
        }
        return String(localized: """
            Du wirst „\(auskunft.rolleText)“ und siehst alle Playbooks. \
            Zeichnen darf dich der Coach später freischalten.
            """)
    }

    private func nachsehen() async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            let neu = try await Laden(anmeldung: anmeldung).codeAnsehen(code)
            auskunft = neu
            // Vorbelegt mit dem Kontonamen, wo es einen gibt. Abtippen
            // soll nur, wer wirklich etwas anderes im Kader haben will
            // -- in einer Schulmannschaft bleibt es leer, und das
            // entscheidet `Kadernameblock` und nicht diese Zeile.
            if name.isEmpty {
                name = Kadernameblock.feld(fuer: neu).vorbelegung
            }
        } catch {
            fehler = Fehlertext.von(error)
        }
    }

    private func beitreten() async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            let ergebnis = try await Laden(anmeldung: anmeldung).beitreten(
                code: code,
                anzeigename: name.trimmingCharacters(in: .whitespaces))
            erledigt = true
            meldung = ergebnis.meldung
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}
