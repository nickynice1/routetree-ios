import PhotosUI
import SwiftUI
import UIKit

/// Das Vereinswappen ändern -- in der App (R30, Rest).
///
/// **Der Auftrag** stammt aus R30, entschieden von Niklas am
/// 28.08.2026: „das erst mannschaft logo steht denn beim verein. sollte
/// aber änderbar sein." Der erste Halbsatz war gebaut, der zweite nur im
/// Browser -- in der App gab es diesen Bildschirm nicht.
///
/// **Warum hier NUR das Wappen steht.** Der Name eines Vereins steht in
/// Angeboten, in der Anschrift und auf jedem Ausdruck; ihn am Telefon
/// änderbar zu machen hiesse, dass ein Verein sich zwischen zwei
/// Rechnungen umbenennt. Dieselbe Entscheidung wie bei `VereinForm` im
/// Browser, und deshalb dieselbe Auswahl an Feldern.
///
/// **„Geliehen" ist ein eigener Zustand und nicht nur eine Verzierung.**
/// Ein Verein ohne eigenes Wappen zeigt das seiner ältesten Mannschaft.
/// Wer das nicht weiss, sucht das Ändern an der falschen Stelle -- er
/// geht in die Mannschaft, tauscht dort das Bild und wundert sich, dass
/// der Verein mitwandert.
struct VereinBlatt: View {
    let verein: Modell.Verein
    /// `true`, wenn sich etwas geändert hat -- dann lädt die
    /// Konto-Ansicht neu. Was gilt, steht auf dem Server.
    let fertig: (Bool) -> Void

    @EnvironmentObject private var anmeldung: Anmeldung

    /// Was gerade zu sehen ist. Startet mit dem, was die Liste sagt, und
    /// wird durch die Antwort des Servers ersetzt -- nicht durch eine
    /// eigene Rechnung.
    @State private var wappen: URL?
    @State private var geliehen: Bool
    @State private var auswahl: PhotosPickerItem?
    @State private var laeuft = false
    @State private var fehler: String?
    /// Hat sich etwas geändert? Nur dann muss die Seite dahinter neu laden.
    @State private var etwasGetan = false

    init(verein: Modell.Verein, fertig: @escaping (Bool) -> Void) {
        self.verein = verein
        self.fertig = fertig
        // `Modell.Verein.logo` ist ein `String?`, kein `URL?` --
        // anders als bei der Mannschaft. Hier umgewandelt und nicht
        // an fünf Stellen im Rumpf.
        _wappen = State(initialValue: verein.logo
            .flatMap(URL.init(string:)))
        // Die Liste sagt nicht, ob das Bild geliehen ist -- sie liefert
        // nur das Ergebnis der Rückfallregel. Bis der Server das erste
        // Mal antwortet, wird deshalb nichts behauptet.
        _geliehen = State(initialValue: false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    bildzeile
                    PhotosPicker(selection: $auswahl, matching: .images) {
                        if wappen == nil {
                            Text("Bild wählen")
                        } else {
                            Text("Anderes Bild wählen")
                        }
                    }
                    .disabled(laeuft)
                    if wappen != nil, !geliehen {
                        Button("Eigenes Logo entfernen", role: .destructive) {
                            Task { await entfernen() }
                        }
                        .disabled(laeuft)
                    }
                } header: {
                    Text("Vereinslogo")
                } footer: {
                    Text(fusstext)
                }
                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            // HIER wird hochgeladen, nicht beim Schliessen. Anders als
            // im Mannschaftsblatt gibt es auf diesem Bildschirm nichts
            // sonst zu speichern -- ein „Speichern" für ein einziges
            // Bild wäre ein Knopf, der nichts erklärt.
            .task(id: auswahl) { await hochladen(auswahl) }
            .navigationTitle(verein.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Fertigknopf { fertig(etwasGetan) }
                        .disabled(laeuft)
                }
            }
        }
    }

    private var fusstext: String {
        if laeuft {
            return String(localized: "Wird hochgeladen …")
        }
        if geliehen {
            return String(localized: """
                Das ist das Logo eurer ältesten Mannschaft. Ladet hier \
                eines hoch, wenn der Verein ein eigenes hat.
                """)
        }
        if wappen == nil {
            return String(localized: """
                Noch kein Bild, weder beim Verein noch bei einer \
                Mannschaft.
                """)
        }
        return String(localized: """
            Euer eigenes Vereinslogo. Nehmt ihr es weg, gilt wieder das \
            eurer ältesten Mannschaft.
            """)
    }

    @ViewBuilder
    private var bildzeile: some View {
        HStack(spacing: 12) {
            if let wappen {
                Netzbild(adresse: wappen) { ProgressView() }
                    .frame(width: 44, height: 44)
            } else {
                // Initialen statt eines leeren Platzes -- dieselbe
                // Leiter wie in der Kachel. Ein Loch sähe aus wie ein
                // Fehler der App.
                Text(verein.initialen)
                    .font(.headline)
                    .foregroundStyle(Farben.inkStill)
                    .frame(width: 44, height: 44)
            }
            if geliehen {
                Text("Von einer Mannschaft übernommen")
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
            }
            Spacer()
        }
    }

    private func hochladen(_ was: PhotosPickerItem?) async {
        guard let was else { return }
        fehler = nil
        guard let roh = try? await was.loadTransferable(type: Data.self),
              let klein = Bildpaket.alsLogo(roh) else {
            fehler = String(localized:
                "Dieses Bild ließ sich nicht lesen. Nimm ein anderes.")
            return
        }
        await tun { laden in
            try await laden.vereinLogoSetzen(verein.id, bild: klein)
        }
    }

    private func entfernen() async {
        await tun { laden in
            try await laden.vereinLogoEntfernen(verein.id)
        }
    }

    /// Eine Änderung ausführen und ÜBERNEHMEN, was der Server sagt.
    ///
    /// **Nicht selbst rechnen, was danach gilt.** Nach dem Entfernen
    /// steht womöglich sofort wieder ein Bild da (das der ältesten
    /// Mannschaft). Wer das in Swift nachbaut, hat die Rückfallregel
    /// zweimal -- und die zweite Fassung ist die, die beim nächsten
    /// Umbau stehen bleibt.
    private func tun(
        _ arbeit: (Laden) async throws -> Vereinsspeicher.Wappenstand
    ) async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            let stand = try await arbeit(Laden(anmeldung: anmeldung))
            wappen = stand.logo
            geliehen = stand.vonMannschaft
            etwasGetan = true
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}
