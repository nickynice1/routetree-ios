// Die Uhr, vom Telefon aus gesehen (R140).
//
// **Warum es diesen Bildschirm überhaupt gibt.** Die Übertragung läuft
// von selbst: Wer die App aufmacht, schickt den aktuellen Stand
// hinüber. Trotzdem braucht es eine Stelle, an der ein Trainer SIEHT,
// was auf seiner Uhr liegt -- und einen Knopf, der es sofort tut.
//
// Der Grund ist derselbe wie bei der Standzeile auf der Uhr: Wer nicht
// weiß, ob er den Stand von heute früh oder den von letzter Woche am
// Handgelenk hat, traut dem Ding nicht. Und wer ihm nicht traut,
// benutzt es am Platz nicht.

import SwiftUI

struct UhrBlatt: View {

    @ObservedObject var bruecke: Uhrbruecke
    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    kopf
                    if bruecke.uhrVorhanden {
                        zustand
                        knopf
                    } else {
                        keineUhr
                    }
                    erklaerung
                }
                .padding(16)
            }
            .background(Farben.flaeche.ignoresSafeArea())
            .task {
                // WOHER DIE HEFTE KOMMEN. Ohne diese Zeile packt die
                // Brücke nichts -- sie weiss dann nicht, wen sie
                // fragen soll, und meldet auch nichts, weil es kein
                // Fehler ist, sondern eine fehlende Angabe.
                bruecke.laden = Laden(anmeldung: anmeldung)
            }
            .navigationTitle(String(localized: "Apple Watch"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Fertigknopf { schliessen() }
                }
            }
        }
    }

    private var kopf: some View {
        HStack(spacing: 12) {
            Image(systemName: "applewatch")
                .font(.largeTitle)
                .foregroundStyle(Farben.akzent)
            Text("Deine Plays am Handgelenk: Heft, Kategorie, Play. Zum Ansehen, nicht zum Zeichnen.")
                .font(.subheadline)
                .foregroundStyle(Farben.inkLeise)
        }
    }

    private var zustand: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !bruecke.appInstalliert {
                Text("Die Uhr-App ist noch nicht installiert. Öffne auf dem iPhone die Watch-App und installiere Routetree.")
                    .font(.footnote)
                    .foregroundStyle(Farben.warnung)
            } else if let stand = bruecke.letzterStand {
                // DER ZEITPUNKT ALS EIGENER WERT, nicht als Ausdruck im
                // Satz: Was in einem übersetzten Text interpoliert wird,
                // braucht beim Bauen einen Platzhalter, und
                // `appsprache.py` ordnet den zu, statt ihn zu raten.
                Text("Zuletzt übertragen: \(zeitpunkt(stand))")
                    .font(.footnote)
                    .foregroundStyle(Farben.inkLeise)
            } else {
                Text("Noch nichts übertragen.")
                    .font(.footnote)
                    .foregroundStyle(Farben.inkLeise)
            }
            if let meldung = bruecke.meldung {
                Text(meldung)
                    .font(.footnote)
                    .foregroundStyle(Farben.fehler)
            }
        }
    }

    private var knopf: some View {
        Button {
            Task { await bruecke.uebertragen() }
        } label: {
            HStack {
                if bruecke.laeuft {
                    ProgressView().tint(Farben.aufPetrol)
                }
                Text(bruecke.laeuft
                     ? String(localized: "Überträgt …")
                     : String(localized: "Jetzt übertragen"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            // SIE STEHT IM LABEL UND NICHT AM BUTTON.
            //
            // Vorher stand sie eine Zeile tiefer, hinter der
            // schliessenden Klammer -- also am Button. Der Kommentar
            // dort war richtig („ohne contentShape ist nur der Text
            // tippbar"), die Stelle war es nicht: Die Trefferflaeche
            // entscheidet die BESCHRIFTUNG, nicht der Knopf.
            //
            // Gemeldet von Niklas am 28.09.2026: „der Playbook auf Uhr
            // uebertragen Button ist auch nur am Text tippbar."
            .contentShape(Rectangle())
        }
        .background(Farben.petrol)
        .foregroundStyle(Farben.aufPetrol)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(bruecke.laeuft || !bruecke.appInstalliert)
    }

    private func zeitpunkt(_ stand: Date) -> String {
        stand.formatted(date: .abbreviated, time: .shortened)
    }

    private var keineUhr: some View {
        Text("An diesem iPhone ist keine Apple Watch gekoppelt.")
            .font(.footnote)
            .foregroundStyle(Farben.inkLeise)
    }

    private var erklaerung: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wie es funktioniert")
                .font(.headline)
            // EHRLICH UEBER DIE GRENZE. Die Uhr bekommt, was auf dem
            // Telefon offline liegt -- nicht mehr. Wer das nicht weiß,
            // sucht am Platz ein Heft, das nie übertragen wurde, und
            // hält die App für kaputt.
            Text("Die Uhr bekommt die Hefte vom iPhone, nicht vom Server. Übertragen wird, was auf dem iPhone auch offline verfügbar ist. Am Spielfeldrand braucht die Uhr danach kein Netz und kein iPhone.")
                .font(.footnote)
                .foregroundStyle(Farben.inkLeise)
        }
    }
}
