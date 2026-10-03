// Standardplays übernehmen (B11).
//
// Ausgearbeitete Konzepte, fertig gezeichnet, passend zur Spielform des
// Playbooks. Im Browser gibt es das seit Langem; in der App sah man bis
// hierher ein leeres Raster und einen Knopf „Play zeichnen".
//
// „Zehn für fünf gegen fünf" stand hier bis zum Audit am 07.09.2026 --
// richtig, solange es nur Flag gab. Der Server schickt seit T10 die
// Konzepte der jeweiligen Form, und das sind je nach Form zehn, vier,
// zwei oder noch keine.
//
// JEDER EINTRAG MIT ZEICHNUNG, und das ist der ganze Punkt. Eine Liste
// aus Namen wäre wertlos: „Snag" sagt niemandem etwas, der es nicht
// schon kennt, und genau die sollen es kennenlernen. Gezeichnet wird mit
// `Feldansicht` aus den Yards des Servers -- dasselbe Bild wie im
// Editor, und beim zweiten Ansehen auch ohne Netz.
//
// WAS ANDERS IST ALS IM BROWSER. Dort stehen die zehn nebeneinander in
// einem Raster, jedes mit Häkchen, und ein Knopf am Fuß übernimmt alle
// angehakten. Auf einem Telefon ist ein Raster aus zehn Diagrammen
// unlesbar: Eine Liste, ein Eintrag je Zeile, Zeichnung groß genug zum
// Erkennen.
//
// WAS NICHT ANDERS IST: was dabei herauskommt. Angelegt wird über
// `uebernahme.py`, dieselbe Stelle, die auch der Browser ruft -- gleiche
// Demo-Grenze, gleiche Namensvergabe, gleiche Reihenfolge. Ein Test
// misst beide Wege gegeneinander, Play für Play.

import SwiftUI

struct BibliothekAnsicht: View {

    let playbook: Modell.Playbook
    /// Wird gerufen, wenn etwas übernommen wurde -- die Playliste dahinter
    /// muss dann neu laden.
    var beiUebernahme: (() -> Void)?

    @EnvironmentObject private var anmeldung: Anmeldung

    @State private var bibliothek: Modell.Bibliothek?
    @State private var gewaehlt: Set<String> = []
    @State private var laedt = true
    @State private var uebernimmt = false
    @State private var fehler: String?
    /// Der Satz in der Fusszeile: was zuletzt herauskam.
    @State private var meldung: String?
    /// Ein Teilerfolg, der einen eigenen Kasten verdient. NICHT `fehler`:
    /// Über „Das hat nicht geklappt" gelesen, hält ein Coach die drei
    /// Plays, die er gerade bekommen hat, für nicht angelegt.
    @State private var teilerfolg: String?

    var body: some View {
        ZStack {
            Farben.flaeche.ignoresSafeArea()
            inhalt
        }
        .navigationTitle("Bibliothek")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(uebernimmt ? String(localized: "Übernimmt…")
                                  : String(localized: "Übernehmen")) {
                    Task { await uebernehmen() }
                }
                .disabled(gewaehlt.isEmpty || uebernimmt || laedt)
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
        .alert("Das hat nicht geklappt",
               isPresented: Binding(get: { fehler != nil },
                                    set: { if !$0 { fehler = nil } })) {
            Button("Verstanden", role: .cancel) { fehler = nil }
        } message: {
            Text(fehler ?? "")
        }
        .alert("Übernommen",
               isPresented: Binding(get: { teilerfolg != nil },
                                    set: { if !$0 { teilerfolg = nil } })) {
            Button("Verstanden", role: .cancel) { teilerfolg = nil }
        } message: {
            Text(teilerfolg ?? "")
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        if laedt {
            ProgressView().tint(Farben.akzent)
        } else if let b = bibliothek {
            List {
                Section {
                    // WEDER ZEHN NOCH FÜNF GEGEN FÜNF (Audit
                    // 07.09.2026). Der Server schickt seit T10 nur die
                    // Konzepte DIESER Spielform -- vier beim Elfer,
                    // zwei beim Neuner, zehn im Flag. Die Website ist
                    // damals umgestellt worden, die App nicht: Sie
                    // behauptete unter jeder Liste eine Zahl und eine
                    // Sportart, die beide nicht stimmten.
                    Text("""
                        Fertig gezeichnete Konzepte für eure Spielform. \
                        Übernehmen, umbenennen, an die eigene Mannschaft \
                        anpassen.
                        """)
                        .font(.footnote)
                        .foregroundStyle(Farben.inkLeise)
                        .listRowBackground(Color.clear)
                }
                if b.eintraege.isEmpty {
                    // DERSELBE LEERFALL WIE IM BROWSER. Eine leere
                    // Liste ohne Satz sieht aus wie ein Ladefehler.
                    Section {
                        Text("""
                            Für diese Spielform ist noch nichts dabei. Die \
                            Bibliothek wächst; bis dahin zeichnest du deinen \
                            ersten Play selbst.
                            """)
                            .font(.footnote)
                            .foregroundStyle(Farben.inkStill)
                            .listRowBackground(Color.clear)
                    }
                }
                ForEach(b.eintraege) { eintrag in
                    zeile(eintrag, feld: b.feld)
                        .listRowBackground(Farben.flaechePanel)
                }
                if let satz = Bibliotheksblock.freiText(b.playsFrei) {
                    Section {
                        // Der Satz kommt aus dem Block, damit ihn ein
                        // Test lesen kann. Die Grenze STEHT DA, bevor
                        // jemand anhakt.
                        Text(satz)
                            .font(.footnote)
                            .foregroundStyle(b.playsFrei == 0
                                             ? Farben.warnung
                                             : Farben.inkStill)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) { fusszeile }
        } else {
            Hinweis(zeichen: "books.vertical",
                    titel: String(localized:
                        "Die Bibliothek ließ sich nicht laden"),
                    text: String(localized:
                        "Ohne Netz geht es hier nicht weiter.")) {
                Button("Nochmal versuchen") { Task { await laden() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
            }
        }
    }

    private func zeile(_ eintrag: Modell.Bibliothekseintrag,
                       feld: Feld) -> some View {
        Button {
            gewaehlt = Bibliotheksblock.umschalten(eintrag.schluessel,
                                                   in: gewaehlt)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: gewaehlt.contains(eintrag.schluessel)
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(gewaehlt.contains(eintrag.schluessel)
                                         ? Farben.akzent : Farben.inkStill)
                        .imageScale(.large)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(eintrag.name)
                            .font(.headline)
                            .foregroundStyle(Farben.ink)
                        if !eintrag.kategorie.isEmpty {
                            Text(eintrag.kategorie)
                                .font(.caption)
                                .foregroundStyle(Farben.inkStill)
                        }
                    }
                    Spacer()
                    if eintrag.schonDa {
                        // HINWEIS, KEINE SPERRE. Wer denselben Play ein
                        // zweites Mal will (etwa gespiegelt), soll ihn
                        // bekommen -- er heißt dann „… (2)".
                        Text("schon drin")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Farben.flaecheHoch,
                                        in: Capsule())
                            .foregroundStyle(Farben.inkStill)
                    }
                }

                // ÜBER DIE GANZE BREITE, nicht auf 190 Punkte Höhe
                // geklemmt. Cyell am 01.09.2026: „Vorschau Bilder haben
                // zu große Positionen." Eine feste Höhe zwingt die
                // Zeichnung in einen schmalen Streifen in der Mitte, und
                // die Figuren darin wirken riesig, weil ringsum nichts
                // ist. Das Seitenverhältnis der Zeichnung sagt selbst,
                // wie hoch sie sein will.
                // EINMAL GERECHNET, ZWEIMAL GEBRAUCHT. Vorher stand
                // derselbe Ausdruck zweimal da -- einmal fürs Zeichnen
                // und einmal fürs Seitenverhältnis. Seit `passendFuer`
                // (R48) dazukommt, wären das zwei Rechnungen für
                // dieselbe Frage, und die Vorschau bekäme irgendwann
                // ein Verhältnis, das nicht zu ihrem Inhalt passt.
                let sicht = Projektion
                    .fuerDieApp(feld: feld, los: feld.mitte, richtung: 1,
                                spielform: playbook.spielform)
                    .passendFuer(eintrag.zeichnung)
                    // Und quer nur so breit wie nötig: In einer
                    // Vorschauzeile ist ein Elfer-Play sonst eine
                    // Reihe gleicher Punkte.
                    .querPassendFuer(eintrag.zeichnung)
                Feldansicht(zeichnung: eintrag.zeichnung, projektion: sicht)
                    .aspectRatio(sicht.seitenverhaeltnis, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if !eintrag.hinweis.isEmpty {
                    Text(eintrag.hinweis)
                        .font(.footnote)
                        .foregroundStyle(Farben.inkLeise)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 6)
            // Trefferfläche: Ohne sie reagiert die Kachel nur dort, wo
            // sie zeichnet -- der Platz neben dem Namen ist Luft.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var fusszeile: some View {
        HStack {
            Text(gewaehlt.isEmpty
                 ? String(localized: "Nichts ausgewählt")
                 : String(localized: "\(gewaehlt.count) ausgewählt"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(gewaehlt.isEmpty ? Farben.inkStill
                                                  : Farben.ink)
            Spacer()
            if let meldung {
                Text(meldung)
                    .font(.footnote)
                    .foregroundStyle(Farben.inkLeise)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Farben.flaechePanel)
    }

    // MARK: - Netz

    private func laden() async {
        laedt = true
        do {
            bibliothek = try await Laden(anmeldung: anmeldung)
                .bibliothek(playbook: playbook.id)
        } catch {
            fehler = Fehlertext.von(error)
        }
        laedt = false
    }

    private func uebernehmen() async {
        guard !gewaehlt.isEmpty else { return }
        uebernimmt = true
        defer { uebernimmt = false }

        // In der Reihenfolge der LISTE, nicht in der des Anhakens --
        // gerechnet im Block, damit ein Test es misst.
        let reihe = Bibliotheksblock.reihenfolge(
            gewaehlt: gewaehlt, eintraege: bibliothek?.eintraege ?? [])
        guard !reihe.isEmpty else { return }

        do {
            let ergebnis = try await Laden(anmeldung: anmeldung)
                .bibliothekUebernehmen(playbook: playbook.id,
                                       schluessel: reihe)
            let wieviele = ergebnis.angelegt.count
            let satz = Bibliotheksblock.ergebnisText(
                angelegt: wieviele, uebergangen: ergebnis.uebergangen)
            meldung = satz
            if !Bibliotheksblock.vollstaendig(
                angelegt: wieviele, uebergangen: ergebnis.uebergangen) {
                // Die Grenze gehört in einen Kasten, den man wegtippt --
                // eine Fusszeile übersieht, wer auf die Liste schaut.
                teilerfolg = satz
            }
            gewaehlt.removeAll()
            beiUebernahme?()
            await laden()
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}
