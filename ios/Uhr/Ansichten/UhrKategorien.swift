// Die Kategorien eines Hefts (R140).
//
// „auch nach kategorien sortiert" -- Niklas am 25.09.2026. Das ist die
// Ebene, die den Unterschied macht: Ein Heft hat vierzig Plays, ein
// Trainer sucht zwischen zwei Spielzügen einen aus „3rd & long". Ohne
// diese Ebene scrollt er vierzig Zeilen.
//
// Die Reihenfolge ist die des Playbooks, nicht das Alphabet. Wer seine
// Kategorien im Browser sortiert hat, hat das aus einem Grund getan --
// meist steht vorn, was am häufigsten gebraucht wird.

import SwiftUI

struct UhrKategorien: View {

    let heft: Uhrpaket.Heft

    var body: some View {
        List {
            ForEach(heft.kategorien) { kategorie in
                NavigationLink {
                    UhrPlays(heft: heft, kategorie: kategorie)
                } label: {
                    HStack(spacing: 8) {
                        Kategoriepunkt(farbe: kategorie.farbe)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(kategorie.name)
                                .font(.headline)
                                .lineLimit(2)
                            // VERBATIM: Eine blosse Zahl ist kein Satz.
                            // Ohne das landet "%lld" als eigener
                            // Eintrag in jedem der fuenf Kataloge und
                            // will uebersetzt werden.
                            Text(verbatim: "\(kategorie.plays.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(heft.name)
    }
}

/// Der farbige Punkt vor einer Kategorie.
///
/// **Ohne Farbe kein Punkt**, und kein grauer Ersatz: Grau sieht aus
/// wie eine Farbe, die jemand gewählt hat. Was ohne Farbe gezeichnet
/// wird, entscheidet die Ansicht -- hier: nichts.
struct Kategoriepunkt: View {

    let farbe: String?

    var body: some View {
        Group {
            if let farbe, let wert = Color(hexwert: farbe) {
                Circle().fill(wert)
            } else {
                Circle().strokeBorder(Farben.inkStill, lineWidth: 1)
            }
        }
        .frame(width: 10, height: 10)
    }
}
