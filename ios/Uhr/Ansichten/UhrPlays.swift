// Die Plays einer Kategorie, und ein einzelner Play (R140).
//
// **Blättern statt zurückgehen.** Wer am Platz den nächsten Play sehen
// will, wischt -- er navigiert nicht zurück in die Liste und wieder
// hinein. Deshalb ist das Play-Blatt ein `TabView` über die ganze
// Kategorie und nicht ein Ziel je Zeile.
//
// (Und deshalb liegt der Umschalter für die Routennamen NICHT im
// Wischbereich, sondern in der Werkzeugleiste: Ein Knopf in einer
// Wischgeste ist tot -- auf dem Telefon zweimal passiert, R134.)

import SwiftUI

struct UhrPlays: View {

    let heft: Uhrpaket.Heft
    let kategorie: Uhrpaket.Kategorie

    var body: some View {
        List {
            ForEach(Array(kategorie.plays.enumerated()), id: \.element.id) {
                stelle, play in
                NavigationLink {
                    UhrPlayblatt(heft: heft, kategorie: kategorie,
                                 beginnBei: stelle)
                } label: {
                    HStack(spacing: 8) {
                        Kategoriepunkt(farbe: kategorie.farbe)
                        Text(play.name)
                            .font(.headline)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(kategorie.name)
    }
}

/// Ein Play, groß -- und die Nachbarn eine Wischgeste entfernt.
struct UhrPlayblatt: View {

    let heft: Uhrpaket.Heft
    let kategorie: Uhrpaket.Kategorie
    let beginnBei: Int

    @State private var stelle: Int

    init(heft: Uhrpaket.Heft, kategorie: Uhrpaket.Kategorie,
         beginnBei: Int) {
        self.heft = heft
        self.kategorie = kategorie
        self.beginnBei = beginnBei
        _stelle = State(initialValue: beginnBei)
    }

    var body: some View {
        TabView(selection: $stelle) {
            ForEach(Array(kategorie.plays.enumerated()), id: \.offset) {
                nummer, play in
                // KEINE ROUTENNAMEN AUF DER UHR (Niklas, 25.09.2026:
                // „die ABC Button kann weg bitte komplett bei der
                // Apple Watch").
                //
                // Der Umschalter sass in der Werkzeugleiste und war
                // der einzige Knopf dort. Auf einem Bildschirm, der im
                // Vorbeigehen gelesen wird, ist ein Play mit
                // Routennamen ueberladen -- und ein Knopf, der ihn
                // ueberladen KANN, ist einer, den man versehentlich
                // trifft.
                Uhrfeld(play: play, feld: heft.feld,
                        spielform: heft.spielform,
                        zeigeNamen: false)
                    .tag(nummer)
            }
        }
        .tabViewStyle(.verticalPage)
        .navigationTitle(name)
    }

    private var name: String {
        guard kategorie.plays.indices.contains(stelle) else {
            return kategorie.name
        }
        return kategorie.plays[stelle].name
    }
}
