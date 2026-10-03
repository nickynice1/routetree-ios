// Einen fremden Bogen in ein Playbook einlesen (R141.1).
//
// **Zwei Schritte, und der erste legt nichts an.** Niklas, 25.09.2026:
// „wenn ein play nicht genau erkannt wird muss das gesagt werden und
// nachbearbeitet werden vom mensch." Das geht nur, wenn er es SIEHT,
// bevor es in seinem Heft steht.
//
// Deshalb: Datei wählen, lesen lassen, Liste ansehen, dann übernehmen.
// Und in der Liste steht bei den unsicheren nicht nur DASS, sondern
// WAS -- ein Trainer soll wissen, wo er nachzeichnen muss.
//
// **Die unsicheren kommen mit.** Nachbearbeiten kann er nur, was da
// ist; ein Import, der sie wegliesse, gäbe ihm 31 von 36 und sagte
// nicht, welche fünf fehlen.

import SwiftUI
import UniformTypeIdentifiers

struct EinleseBlatt: View {

    let playbook: Modell.Playbook
    /// Wird gerufen, wenn wirklich etwas angelegt wurde.
    let fertig: () async -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen

    @State private var stand: Stand = .warten
    @State private var waehlt = false
    @State private var datei: Datei?
    @State private var meldung: String?
    @State private var arbeitet = false

    enum Stand: Equatable {
        case warten
        case gelesen(Bogenfund)
    }

    /// Die gewählte Datei, schon eingelesen.
    ///
    /// **Der Inhalt wird gleich beim Wählen geholt**, nicht erst beim
    /// Schicken: Was der Dateiwähler zurückgibt, ist eine Adresse mit
    /// befristetem Zugriff. Wer sie aufhebt und später öffnet, bekommt
    /// je nach Herkunft nichts mehr.
    struct Datei: Equatable {
        let name: String
        let inhalt: Data
        var typ: String {
            Einleser.medientyp(fuer: (name as NSString).pathExtension)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                quelle
                if case .gelesen(let fund) = stand {
                    ergebnis(fund)
                }
            }
            .navigationTitle("Playbook einlesen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Abbruchknopf { schliessen() }
                }
            }
            .fileImporter(isPresented: $waehlt,
                          allowedContentTypes: Self.formate) { ergebnis in
                waehlen(ergebnis)
            }
            .alert("Das hat nicht geklappt",
                   isPresented: Binding(get: { meldung != nil },
                                        set: { if !$0 { meldung = nil } })) {
                Button("Verstanden", role: .cancel) { meldung = nil }
            } message: {
                Text(meldung ?? "")
            }
        }
    }

    /// Welche Formate der Dateiwähler zulässt.
    ///
    /// **Dieselben wie auf dem Server**, und auch dort steht die Liste
    /// nur einmal (`einfuhr.FORMATE`). Eine App, die mehr zulässt,
    /// schickt Dateien, die abgelehnt werden -- und der Trainer hält
    /// die Absage für einen Fehler.
    private static let formate: [UTType] = [.pdf, .svg, .png, .jpeg]

    // MARK: - Die Teile

    @ViewBuilder
    private var quelle: some View {
        Section {
            Button {
                waehlt = true
            } label: {
                Label(datei == nil
                      ? String(localized: "Datei wählen")
                      : (datei?.name ?? ""),
                      systemImage: "doc.badge.plus")
            }
            .disabled(arbeitet)

            if datei != nil, case .warten = stand {
                Button {
                    Task { await lesen() }
                } label: {
                    if arbeitet {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Wird gelesen …")
                        }
                    } else {
                        Text("Datei lesen")
                    }
                }
                .disabled(arbeitet)
            }
        } header: {
            Text("Die Datei")
        } footer: {
            Text("""
                PDF, SVG, PNG oder JPEG. Ein Wristcoach, ein Callsheet, \
                ein Spielblatt: was du hast.
                """)
        }
    }

    @ViewBuilder
    private func ergebnis(_ fund: Bogenfund) -> some View {
        Section {
            ForEach(fund.plays) { play in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Play \(play.nummer)").font(.headline)
                        Spacer()
                        Text("\(play.spieler)/\(play.routen)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ForEach(play.bedenken, id: \.self) { satz in
                        Label(satz, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(Farben.gold)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Das haben wir gefunden")
        } footer: {
            if fund.nachzuarbeiten > 0 {
                Text("""
                    \(fund.nachzuarbeiten) davon sollten nachgezeichnet \
                    werden. Sie werden trotzdem angelegt.
                    """)
            } else {
                Text("Bei keinem gab es etwas zu beanstanden.")
            }
        }

        Section {
            Button {
                Task { await uebernehmen() }
            } label: {
                Text("Diese Plays übernehmen")
            }
            .disabled(arbeitet || fund.plays.isEmpty)
        }
    }

    // MARK: - Der Ablauf

    private func waehlen(_ ergebnis: Result<URL, Error>) {
        switch ergebnis {
        case .failure(let fehler):
            meldung = fehler.localizedDescription
        case .success(let adresse):
            // **Der Zugriff muss ausdrücklich geöffnet werden.** Was
            // der Dateiwähler liefert, liegt ausserhalb der App; ohne
            // diesen Rahmen schlägt das Lesen mit „keine Berechtigung"
            // fehl -- und zwar nur bei Dateien aus fremden Apps, nicht
            // bei denen aus „Auf meinem iPhone". Ein Fehler, der beim
            // Ausprobieren nicht auftritt.
            let offen = adresse.startAccessingSecurityScopedResource()
            defer { if offen { adresse.stopAccessingSecurityScopedResource() } }
            do {
                datei = Datei(name: adresse.lastPathComponent,
                              inhalt: try Data(contentsOf: adresse))
                stand = .warten
            } catch {
                meldung = error.localizedDescription
            }
        }
    }

    private func lesen() async {
        guard let datei else { return }
        arbeitet = true
        defer { arbeitet = false }
        do {
            let fund = try await Einleser.vorschau(
                playbook: playbook.id, datei: datei.inhalt,
                name: datei.name, typ: datei.typ,
                token: try await anmeldung.gueltigesToken())
            stand = .gelesen(fund)
        } catch {
            meldung = error.localizedDescription
        }
    }

    private func uebernehmen() async {
        guard let datei else { return }
        arbeitet = true
        defer { arbeitet = false }
        do {
            _ = try await Einleser.uebernehmen(
                playbook: playbook.id, datei: datei.inhalt,
                name: datei.name, typ: datei.typ,
                token: try await anmeldung.gueltigesToken())
            // EIN EINGELESENES PLAYBOOK IST DER GROESSTE ERFOLG, den
            // diese App einem Trainer verschafft: Dreissig Jahre
            // Ordner sind in einer Minute drin. Gefragt wird
            // trotzdem erst beim dritten Erfolg -- die Regel steht in
            // `Bewertungsfrage`.
            Bewertungsfrage.merken(.eingelesen)
            await fertig()
            schliessen()
        } catch {
            meldung = error.localizedDescription
        }
    }
}
