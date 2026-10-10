// Wie man einen Spielzug ansagt -- in vier Schritten (R143).
//
// **Niklas am 07.10.2026:** „beim coaching modus starten auch kurze
// anleitung wie man denn ein play ansagt."
//
// ## Warum sie beim Starten aufgeht und nicht in der Hilfe steht
//
// Der Coaching-Modus wird einmal vor dem Training eingeschaltet. In
// genau diesem Moment stellt sich die Frage „und jetzt?", und in
// genau diesem Moment hat jemand noch Zeit, eine Antwort zu lesen.
// Zwanzig Minuten später steht er an der Seitenlinie, und dann liest
// niemand mehr etwas.
//
// ## Warum sie wieder verschwindet
//
// Sie geht auf, solange dieser Mensch noch nie einen Play gerufen
// hat (`Coachingmodus.schonGerufen`). Danach nie wieder. Eine
// Anleitung, die bei jedem Training aufgeht, ist ab dem dritten Mal
// eine Tür, die man zumachen muss.
//
// Und der Schalter fällt erst, wenn ein Ruf WIRKLICH angekommen ist.
// Wer dreimal auf eine tote Uhr tippt, hat es nicht verstanden.

import SwiftUI

struct Coachinganleitung: View {

    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    kopf
                    schritt(1, Text("Uhren wählen"),
                            Text("Oben rechts im Menü. Angetippt heisst: bekommt die Spielzüge. Der grüne Punkt sagt, wer gerade erreichbar ist."))
                    schritt(2, Text("Play antippen"),
                            Text("In der Liste auf die drei Punkte neben dem Spielzug."))
                    schritt(3, Text("„Nächster Spielzug“"),
                            Text("Der Play steht sofort auf dem Handgelenk."))
                    schritt(4, Text("Oder „In die Warteschlange“"),
                            Text("Leg mehrere vor. Dein Quarterback tippt einmal auf die Uhr und bekommt den nächsten."))
                    fuss
                }
                .padding(16)
            }
            .background(Farben.flaeche.ignoresSafeArea())
            .navigationTitle(Text("Spielzug ansagen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Fertigknopf(name: String(localized: "Los geht's")) {
                        schliessen()
                    }
                }
            }
        }
    }

    private var kopf: some View {
        HStack(spacing: 12) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.largeTitle)
                .foregroundStyle(Farben.akzent)
            Text("Der Coaching-Modus läuft. So sagst du einen Spielzug an:")
                .font(.subheadline)
                .foregroundStyle(Farben.inkLeise)
        }
    }

    /// Eine nummerierte Zeile mit Überschrift und Satz.
    ///
    /// **Die Zahl in fester Breite**, sonst fangen die Zeilen nicht
    /// untereinander an und die Liste liest sich wie ein Fehler.
    ///
    /// **`Text` und nicht `String`**, und das ist kein Geschmack. Ein
    /// `String` in `Text(…)` wird NICHT uebersetzt -- SwiftUI nimmt
    /// nur ein Literal als Schluessel. Und `appsprache.py` sammelt nur
    /// Literale, die direkt in `Text(`, `Button(` und Verwandten
    /// stehen; eines, das an eine eigene Funktion geht, sieht es gar
    /// nicht. Mit `String` waeren diese vier Schritte in jeder
    /// Sprache deutsch geblieben, ohne dass irgendetwas rot wird.
    private func schritt(_ nummer: Int, _ titel: Text,
                         _ satz: Text) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // VERBATIM, weil eine blanke Ziffer kein Satz ist.
            // Ohne das sammelt `appsprache.py` sie als zu
            // uebersetzenden Text ein und verlangt fuer „1"
            // vier Fassungen.
            Text(verbatim: "\(nummer)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Farben.aufPetrol)
                .frame(width: 22, height: 22)
                .background(Farben.petrol, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                titel
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Farben.ink)
                satz
                    .font(.footnote)
                    .foregroundStyle(Farben.inkLeise)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Was sonst noch gilt.
    ///
    /// **Der Playbookwechsel steht hier und nicht als Schritt 5.** Er
    /// ist keine Handlung, sondern eine Beruhigung: Niklas hat beim
    /// Entwurf ausdrücklich gefragt, ob der Modus das übersteht
    /// („denn kann zwischen playbooks switchen"). Wer es nicht weiss,
    /// traut sich nicht und schaltet vorsichtshalber aus und wieder
    /// ein.
    private var fuss: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Du kannst zwischendurch das Playbook wechseln. Der Coaching-Modus bleibt an.")
                .font(.footnote)
                .foregroundStyle(Farben.inkLeise)
            Text("Die Leiste über der Liste zeigt, wie viele Uhren wirklich erreichbar sind und was zuletzt rausging.")
                .font(.footnote)
                .foregroundStyle(Farben.inkLeise)
        }
    }
}
