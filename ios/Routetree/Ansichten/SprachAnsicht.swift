import SwiftUI

/// Die Sprachwahl -- beim ersten Start und später in den Einstellungen (R31).
///
/// **Ein Bildschirm für zwei Gelegenheiten.** Beim ersten Öffnen als
/// Blatt, das sich von selbst zeigt; danach über die Konto-Ansicht.
/// Zwei Fassungen wären zwei Listen, und die zweite bekäme die sechste
/// Sprache nie.
///
/// **„Die des Systems" steht oben und ist vorausgewählt.** Für die
/// meisten ist es die richtige Antwort, und wer beim ersten Start
/// nichts ändern will, drückt einmal und ist durch. Ein Bildschirm, der
/// eine Entscheidung erzwingt, wo keine nötig ist, ist eine Hürde.
struct SprachAnsicht: View {
    /// Was gerade gilt. `nil` heißt „die des Systems".
    @State private var wahl: String? = Sprachwahl.gewaehlt
    @Environment(\.dismiss) private var schliessen

    /// Beim ersten Start steht ein anderer Satz oben: Dort erklärt sich
    /// der Bildschirm selbst, in den Einstellungen nicht.
    let erstesMal: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    zeile(nil)
                    ForEach(Sprachwahl.verfuegbar, id: \.self) { code in
                        zeile(code)
                    }
                } header: {
                    if erstesMal {
                        Text("In welcher Sprache soll Routetree mit dir reden?")
                            .font(.subheadline)
                            .foregroundStyle(Farben.inkStill)
                            .textCase(nil)
                            .padding(.bottom, 6)
                    }
                } footer: {
                    // DER HINWEIS GEHÖRT DAZU. `AppleLanguages` greift
                    // erst beim nächsten Start; eine Einstellung, die
                    // das verschweigt, hält man für kaputt und drückt
                    // sie noch dreimal.
                    //
                    // Beim ERSTEN Start steht er nicht da: Dort ist der
                    // nächste Start ohnehin gleich, weil die App noch
                    // nichts anzeigt, was sich ändern müsste.
                    if !erstesMal, wahl != Sprachwahl.gewaehlt {
                        Text(Sprachwahl.hinweis)
                    }
                }
                .listRowBackground(Farben.flaechePanel)
            }
            .scrollContentBackground(.hidden)
            .background(Farben.flaeche)
            .navigationTitle(Text("Sprache"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // EIN SICHTBARER AUSGANG (B2).
                //
                // HIG „Modality": „Always give people an obvious way to
                // dismiss a modal view." Hier stand bis zum 10.09.2026
                // nur „Fertig" -- und das ist auf DIESEM Blatt kein
                // Ausgang, sondern eine Zusage: Es SETZT die Sprache.
                // Wer sich vertippt hatte, kam nur heraus, indem er die
                // falsche Sprache übernahm und danach zurückging -- in
                // einer Oberfläche, die er dann nicht mehr liest.
                //
                // BEIM ERSTEN START NICHT. Dort gibt es nichts, wohin
                // ein Abbrechen führen würde: Das Blatt zeigt sich von
                // selbst, und dahinter steht noch nichts. Ein Knopf,
                // der ins Leere führt, ist schlechter als keiner.
                if !erstesMal {
                    ToolbarItem(placement: .cancellationAction) {
                        Abbruchknopf { schliessen() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Beide Wörter durch die Übersetzung, siehe
                    // `KategorieListe`: Im Fragezeichenausdruck ist
                    // die Überladung ohne Compiler nicht zu
                    // entscheiden, und der Sammler zählt die Stelle
                    // nicht mit. Gerade dieses Blatt ist das erste,
                    // das ein Trainer sieht.
                    Button(erstesMal ? String(localized: "Los geht's")
                                     : String(localized: "Fertig")) {
                        Sprachwahl.setzen(wahl)
                        schliessen()
                    }
                    // Sprachunabhaengig fuer den Bilderlauf (R120):
                    // Die Beschriftung heisst je nach Sprache anders,
                    // und genau hier faengt jeder Durchgang an.
                    .accessibilityIdentifier("sprachwahl-weiter")
                }
            }
        }
    }

    private func zeile(_ code: String?) -> some View {
        Button {
            wahl = code
        } label: {
            HStack {
                Text(code.map(Sprachwahl.name)
                     ?? String(localized: "Die Sprache meines Telefons"))
                    .foregroundStyle(Farben.ink)
                Spacer()
                if wahl == code {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Farben.akzent)
                }
            }
            // Trefferfläche: Die Mitte der Zeile ist sonst Luft.
            .contentShape(Rectangle())
        }
    }
}
