// Lernstand: wer im Team welchen Play sicher kennt (B8).
//
// Für den Trainerstab. Das ist die Übersicht, aus der hervorgeht, welche
// Plays die Mannschaft noch nicht kann -- und damit die Antwort auf die
// Frage, was im nächsten Training drankommt.
//
// AUSDRÜCKLICH KEINE RANGLISTE. Sortiert wird nach Namen, nicht nach
// Fortschritt, und die App sortiert nicht um: Eine Liste, die von „kann
// alles" nach „kann nichts" sortiert, ist ein Aushang, und ein Aushang
// gehört nicht in eine Jugendmannschaft. Die Ordnung kommt vom Server,
// damit es nicht von der Oberfläche abhängt, ob sie eingehalten wird.
//
// WER SIE SEHEN DARF, sagt der Server: Ohne Schreibrecht antwortet er
// mit 404, genau wie die Seite im Browser. Der Knopf hierher steht
// deshalb nur, wenn `darf_lernstand` es sagt (ADR-0007).

import SwiftUI

struct LernstandAnsicht: View {
    let playbook: Modell.Playbook

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var liste: Modell.Lernstandsliste?
    @State private var fehler: String?

    var body: some View {
        ZStack {
            Farben.flaeche.ignoresSafeArea()
            inhalt
        }
        .navigationTitle("Lernstand")
        .navigationBarTitleDisplayMode(.inline)
        .task { await laden() }
        // NEU LADEN GEHT ÜBERALL, WO GELADEN WIRD (02.09.2026).
        //
        // Gezählt: Fünf Ansichten hatten weder `.refreshable` noch einen
        // Knopf dafür -- man kam nur heraus und wieder herein. Am
        // Spielfeldrand, wo der Empfang kommt und geht, ist das der
        // häufigste Handgriff überhaupt.
        .refreshable { await laden() }
    }

    @ViewBuilder private var inhalt: some View {
        if let fehler {
            Hinweis(zeichen: "exclamationmark.triangle",
                    titel: String(localized: "Das hat nicht geklappt"),
                    text: fehler) {
                Button("Nochmal versuchen") { Task { await laden() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
            }
        } else if let liste {
            if liste.zeilen.isEmpty {
                Hinweis(zeichen: "person.2",
                        titel: String(localized: "Noch niemand im Kader"),
                        text: String(localized: """
                            Sobald jemand über den Teamcode oder eine \
                            Einladung dazukommt, steht hier, wie weit er ist.
                            """))
            } else {
                List {
                    kaderteil(liste)
                    schwierigteil(liste)
                }
                .scrollContentBackground(.hidden)
            }
        } else {
            ProgressView().tint(Farben.akzent)
        }
    }

    private func kaderteil(_ liste: Modell.Lernstandsliste) -> some View {
        Section {
            ForEach(liste.zeilen) { zeile in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(zeile.name)
                            .foregroundStyle(Farben.ink)
                        Spacer()
                        Text("""
                            \(zeile.fortschritt.sitzen) von \
                            \(zeile.fortschritt.gesamt)
                            """)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(Farben.inkStill)
                    }
                    Balken(anteil: zeile.fortschritt.anteil)
                    HStack(spacing: 6) {
                        Text(zeile.rolle)
                            .font(.caption)
                            .foregroundStyle(Farben.inkStill)
                        // Steht die Zahl gegen einen Lernauftrag, gehört
                        // das dabei: „3 von 6" und „3 von 40" sehen
                        // sonst nach einem Fehler aus (A7).
                        if zeile.fortschritt.ausAuftrag {
                            Marke(text: String(localized: "gegen die Aufgabe"))
                        }
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Farben.flaechePanel)
            }
        } header: {
            Text("Kader")
        } footer: {
            Text("""
                Ein Play sitzt nach \(liste.serieFuerSitzt)× richtig \
                hintereinander. Sortiert nach Namen.
                """)
        }
    }

    @ViewBuilder
    private func schwierigteil(_ liste: Modell.Lernstandsliste) -> some View {
        if !liste.schwierig.isEmpty {
            Section {
                ForEach(liste.schwierig) { play in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(titel(play))
                                .foregroundStyle(Farben.ink)
                            if play.falsch > 0 {
                                Text("\(play.falsch)× danebengegriffen")
                                    .font(.caption)
                                    .foregroundStyle(Farben.inkStill)
                            }
                        }
                        Spacer()
                        Text("\(play.sitzen) von \(play.von)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(Farben.inkStill)
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(Farben.flaechePanel)
                }
            } header: {
                Text("Was noch nicht sitzt")
            } footer: {
                Text("""
                    Oben steht, was die wenigsten können. Das ist die Liste, \
                    nach der ein Training geplant wird.
                    """)
            }
        }
    }

    private func titel(_ play: Modell.Lernstandsliste.Schwieriger) -> String {
        guard let nummer = play.nummer, nummer > 0 else { return play.name }
        return "#\(nummer) \(play.name)"
    }

    private func laden() async {
        fehler = nil
        do {
            liste = try await Laden(anmeldung: anmeldung)
                .lernstand(playbook: playbook.id)
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}

/// Ein Fortschrittsbalken, wie ihn Übungsmodus und Kader zeichnen.
struct Balken: View {
    let anteil: Double

    var body: some View {
        GeometryReader { raum in
            ZStack(alignment: .leading) {
                Capsule().fill(Farben.linie)
                Capsule().fill(Farben.akzent)
                    .frame(width: raum.size.width * min(max(anteil, 0), 1))
            }
        }
        .frame(height: 6)
    }
}
