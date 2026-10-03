// Die Hilfe in der App -- und zwar OHNE NETZ (B6).
//
// Niklas am 02.09.2026: „ich finde sie sollte auch inapp zusätzlich
// sein, damit sie auch offline verfügbar ist weißt du?" Genau dort
// braucht man sie: Wer am Spielfeldrand nicht weiterkommt, hat oft auch
// kein Netz.
//
// KEIN EINZIGES WORT DER HILFE STEHT IN DIESER DATEI. Sie kommt aus
// `/api/v1/hilfe/`, und dort setzt `hilfe.alles()` sie aus `druck.py`,
// `render.py`, `schema.py`, `regelwerk.py`, `abo.py` und den Formularen
// zusammen -- dieselbe Quelle wie die Webseite. Eine abgeschriebene
// Fassung wäre die zweite Wahrheit, vor der R28 warnt: Sie beschriebe
// drei Umbauten später ein Produkt, das es nicht mehr gibt, und nichts
// würde rot.
//
// Hier stehen deshalb nur die ÜBERSCHRIFTEN -- also das, was ein Mensch
// braucht, um die Abschnitte auseinanderzuhalten.
//
// UND SIE HAT EINEN SICHTBAREN AUSGANG (B2). Apples Richtlinie zu
// Sheets sagt wörtlich: „Always give people an obvious way to dismiss a
// modal view."

import SwiftUI

struct HilfeAnsicht: View {

    @Environment(\.dismiss) private var schliessen
    // Die Adresse ist offen -- der Zugang wird nicht gebraucht. `Laden`
    // verlangt ihn trotzdem, weil jede andere Adresse ihn braucht.
    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var hilfe: Modell.Hilfe?
    @State private var stand: Date?
    @State private var fehler: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                inhalt
            }
            .navigationTitle("Hilfe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        schliessen()
                    } label: {
                        Label("Schließen", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .task { await laden() }
            .refreshable { await laden() }
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        if let hilfe {
            List {
                if let stand { Section { Vorratsleiste(stand: stand) } }

                // JEDE FUNKTION ZUERST (R70). Niklas am 03.09.2026:
                // „wirklich alle funktionen perfekt erklären aber halt
                // nicht übertrieben verstehst." Sie steht oben, weil sie
                // die Frage beantwortet, mit der jemand die Hilfe
                // öffnet -- die Linienarten schlägt man nach, die
                // Funktionen sucht man.
                ForEach(hilfe.funktionen) { bereich in
                    Section(bereich.bereich) {
                        ForEach(bereich.eintraege) { eintrag in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(eintrag.titel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Farben.ink)
                                Text(eintrag.was)
                                    .foregroundStyle(Farben.inkStill)
                                Text(eintrag.wo)
                                    .foregroundStyle(Farben.inkLeise)
                                if !eintrag.denk.isEmpty {
                                    Text(eintrag.denk)
                                        .foregroundStyle(Farben.inkLeise)
                                }
                            }
                            .font(.footnote)
                            .padding(.vertical, 2)
                            .listRowBackground(Farben.flaechePanel)
                        }
                    }
                }

                if !hilfe.editorgriffe.isEmpty {
                    Section("Werkzeuge im Editor") {
                        ForEach(hilfe.editorgriffe, id: \.self) { griff in
                            Text(griff)
                                .font(.footnote)
                                .foregroundStyle(Farben.inkLeise)
                                .listRowBackground(Farben.flaechePanel)
                        }
                    }
                }

                abschnitt("Ausdrucke", hilfe.ausdrucke)

                // DIE FIGUREN, VOR DEN LINIEN (09.09.2026). Wer ein
                // Play zum ersten Mal liest, sieht zuerst Figuren und
                // dann Striche.
                //
                // Der Abschnitt ist dazugekommen, weil sich die
                // Notation geändert hat: Die Defense war ein Kreuz und
                // ist jetzt ein Viereck. Eine Notation, die sich
                // ändert, muss erklärt werden -- sonst sucht der
                // nächste Trainer nach dem Kreuz aus seinem alten
                // Playbook.
                if !hilfe.spielersymbole.isEmpty {
                    Section("Die Figuren im Play") {
                        ForEach(hilfe.spielersymbole) { zeile in
                            HStack(spacing: 12) {
                                Spielerprobe(seite: zeile.seite)
                                Text(zeile.name)
                                    .font(.footnote)
                                    .foregroundStyle(Farben.inkStill)
                                    .fixedSize(horizontal: false,
                                               vertical: true)
                            }
                            .listRowBackground(Farben.flaechePanel)
                        }
                    }
                }

                // MIT PROBE, UND ZWAR SELBST GEZEICHNET. Der Server
                // schickt zwar ein SVG mit, aber SwiftUI zeigt keines --
                // und ein Bild nachzuladen hiesse, dass die Hilfe ohne
                // Netz keine Bilder hat, also genau da nicht, wo sie
                // gebraucht wird (B6). `Linienprobe` zeichnet aus
                // demselben erzeugten `Linienstil.swift`, aus dem auch
                // der Editor zeichnet.
                if !hilfe.linien.isEmpty {
                    Section("Linien im Play") {
                        ForEach(hilfe.linien) { zeile in
                            HStack(spacing: 12) {
                                if let art = zeile.art {
                                    Linienprobe(art: art)
                                }
                                zweizeilerOhneGrund(zeile.name, zeile.text)
                            }
                            .listRowBackground(Farben.flaechePanel)
                        }
                    }
                }
                if !hilfe.linienenden.isEmpty {
                    Section("Was am Ende einer Linie steht") {
                        ForEach(hilfe.linienenden, id: \.self) { name in
                            Text(name)
                                .foregroundStyle(Farben.inkLeise)
                                .listRowBackground(Farben.flaechePanel)
                        }
                    }
                }
                abschnitt("Spielsituationen", hilfe.situationen)
                abschnitt("Regelwerke", hilfe.regelwerke)

                ForEach(hilfe.formulare) { block in
                    Section(block.titel) {
                        ForEach(block.zeilen) { zeile in
                            zweizeiler(zeile.name, zeile.text)
                        }
                    }
                }

                if !hilfe.abo.isEmpty {
                    Section("Demo und Abo") {
                        ForEach(hilfe.abo) { zeile in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(zeile.was)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Farben.ink)
                                // Zwei Zeilen und keine Tabelle: Drei
                                // Spalten auf einem Telefon sind je
                                // zwanzig Zeichen breit.
                                Text("Demo: \(zeile.demo)")
                                    .font(.footnote)
                                    .foregroundStyle(Farben.inkStill)
                                // EINE ZEILE JE STUFE, wo sie sich
                                // unterscheiden (R119). „Mit Abo" steht
                                // nur da, wo Standard und Premium
                                // wirklich dasselbe sagen.
                                if let gemeinsam = zeile.abo {
                                    Text("Mit Abo: \(gemeinsam)")
                                        .font(.footnote)
                                        .foregroundStyle(Farben.inkStill)
                                } else {
                                    ForEach(zeile.spalten ?? []) { spalte in
                                        // `verbatim`: Hier steht kein
                                        // Satz, sondern zwei Werte vom
                                        // Server mit einem Doppelpunkt
                                        // dazwischen. Als Literal wäre
                                        // „%@: %@" ein Eintrag, den
                                        // vier Sprachen übersetzen
                                        // müssten, ohne dass ein Wort
                                        // darin steht.
                                        Text(verbatim:
                                            "\(spalte.name): \(spalte.wert)")
                                            .font(.footnote)
                                            .foregroundStyle(Farben.inkStill)
                                    }
                                }
                            }
                            .listRowBackground(Farben.flaechePanel)
                        }
                    }
                }

                // DER WEG ZUM MENSCHEN, ganz unten und beschriftet.
                // WCAG 3.2.6 zählt neben der Selbsthilfe ausdrücklich
                // einen menschlichen Kontaktweg als Hilfsmechanismus.
                Section {
                    Link(destination: URL(string: "/rueckmeldung/",
                                          relativeTo: Server.basis)!) {
                        Label("Etwas melden", systemImage: "exclamationmark.bubble")
                    }
                    .listRowBackground(Farben.flaechePanel)
                }
            }
            .scrollContentBackground(.hidden)
        } else if let fehler {
            Hinweis(zeichen: "questionmark.circle",
                    titel: String(localized: "Die Hilfe ließ sich nicht laden"),
                    text: fehler) {
                Button("Nochmal versuchen") { Task { await laden() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
            }
        } else {
            ProgressView().tint(Farben.akzent)
        }
    }

    @ViewBuilder
    private func abschnitt(_ titel: LocalizedStringKey,
                           _ zeilen: [Modell.Hilfe.Zeile]) -> some View {
        if !zeilen.isEmpty {
            Section(titel) {
                ForEach(zeilen) { zeile in
                    zweizeiler(zeile.name, zeile.text)
                }
            }
        }
    }

    /// Wie `zweizeiler`, aber ohne den Zeilenhintergrund.
    ///
    /// **Warum das ein zweiter ist.** `listRowBackground` gilt für die
    /// ZEILE, nicht für die Ansicht darin. Steht es an einem Teilstück
    /// mitten in einem `HStack`, ist es wirkungslos -- und die Zeile
    /// hätte dann als einzige der Liste einen anderen Grund, ohne dass
    /// sichtbar wäre, warum.
    private func zweizeilerOhneGrund(_ oben: String,
                                     _ unten: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(oben)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Farben.ink)
            if !unten.isEmpty {
                Text(unten)
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func zweizeiler(_ oben: String, _ unten: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(oben)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Farben.ink)
            if !unten.isEmpty {
                Text(unten)
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .listRowBackground(Farben.flaechePanel)
    }

    private func laden() async {
        fehler = nil
        do {
            // JE SPRACHE abgelegt: Der Server übersetzt die Hilfe, bevor
            // er sie herausgibt. Eine einzige Ablage hieße, dass ein
            // Sprachwechsel offline nichts ändert -- und niemand wüsste,
            // warum.
            //
            // `Sprachwahl.gewaehlt` ist `nil`, solange niemand etwas
            // gewählt hat; dann gilt die des Geräts.
            let sprache = Sprachwahl.gewaehlt
                ?? Locale.current.language.languageCode?.identifier ?? "de"
            let ausgabe = try await Laden(anmeldung: anmeldung)
                .hilfeMitVorrat(sprache: sprache)
            hilfe = ausgabe.wert
            stand = ausgabe.stand
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}
