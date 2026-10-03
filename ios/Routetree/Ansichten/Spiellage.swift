import SwiftUI

/// Wo der Ball liegt und wohin angegriffen wird (R110.3).
///
/// **Die App konnte es bis zum 10.09.2026 gar nicht.** Ein Play, der
/// nicht an der Mittellinie beginnt, liess sich am Telefon nicht
/// anlegen -- und die Mittellinie ist die Ausnahme, nicht die Regel:
/// Ein Call Sheet gliedert sich nach 3rd & lang, Red Zone und
/// No-Run-Zone, also nach der LAGE des Balls. Der Browser hat den
/// Regler seit dem ersten Tag.
///
/// **Was hier NICHT gerechnet wird.** Wohin die LOS darf, sagt
/// `Zeichenblock.losBereich`; was die Lage bedeutet, sagt
/// `Spiellageblock`. Diese Datei zeichnet -- dieselbe Trennung wie bei
/// `Kaderblock` (B9) und `Stufenblock` (R117), und aus demselben Grund:
/// Es gibt keinen Mac.
struct Spiellage: View {

    @Binding var block: Zeichenblock
    let darfAendern: Bool
    let schliessen: () -> Void

    /// Der Stand beim Aufmachen -- fuer „Abbrechen".
    @State private var vorher: (los: Double, richtung: Int)?

    private var feld: Feld { block.projektion.feld }
    private var lage: Spiellageblock.Lage {
        Spiellageblock.lage(los: block.projektion.los,
                            richtung: block.projektion.richtung,
                            feld: feld)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                Form {
                    Section {
                        Feldkarte(los: block.projektion.los,
                                  richtung: block.projektion.richtung,
                                  feld: feld)
                            .frame(height: 78)
                            .listRowBackground(Farben.flaechePanel)
                    }

                    Section {
                        // DER REGLER IN GANZEN YARDS. Halbe Yards gibt
                        // es beim Snap nicht: Der Ball liegt auf einer
                        // Linie, und die Linien sind ganzzahlig.
                        Slider(
                            value: Binding(
                                get: { block.projektion.los },
                                set: { block.losSetzen($0.rounded()) }),
                            in: block.losBereich, step: 1)
                            .disabled(!darfAendern)
                            .accessibilityLabel(Text("Wo liegt der Ball?"))
                            .accessibilityValue(Text(lage.ort))
                        HStack {
                            Text("Ball")
                                .foregroundStyle(Farben.inkStill)
                            Spacer()
                            Text(lage.ort)
                                .foregroundStyle(Farben.ink)
                                .monospacedDigit()
                        }
                    } header: {
                        Text("Wo liegt der Ball?")
                    } footer: {
                        Text(lage.satz)
                    }
                    .listRowBackground(Farben.flaechePanel)

                    Section {
                        Button {
                            block.richtungWechseln()
                        } label: {
                            HStack {
                                Label(lage.richtungstext,
                                      systemImage: block.projektion.richtung > 0
                                        ? "arrow.right" : "arrow.left")
                                    .foregroundStyle(Farben.ink)
                                Spacer()
                                Text("wechseln")
                                    .font(.footnote)
                                    .foregroundStyle(Farben.akzent)
                            }
                            // Trefferfläche: Die Mitte der Zeile ist
                            // sonst Luft.
                            .contentShape(Rectangle())
                        }
                        .disabled(!darfAendern)
                    } header: {
                        Text("Angriffsrichtung")
                    } footer: {
                        // DER UNTERSCHIED ZUM SPIEGELN GEHOERT DAZU.
                        // Wer beides verwechselt, bekommt eine
                        // Formation, die falsch herum steht.
                        Text("""
                            Dreht die Richtung um, in die dieser Play \
                            läuft. Die Zeichnung bleibt, wie sie ist – \
                            „Spiegeln" in der Leiste tauscht dagegen \
                            links und rechts.
                            """)
                    }
                    .listRowBackground(Farben.flaechePanel)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Spielsituation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // EIN SICHTBARER AUSGANG (B2). „Fertig" allein genuegt
                // nicht: Der Regler wirkt sofort, es gibt also etwas
                // zurueckzunehmen.
                ToolbarItem(placement: .cancellationAction) {
                    Abbruchknopf {
                        if let vorher {
                            block.losSetzen(vorher.los)
                            if block.projektion.richtung != vorher.richtung {
                                block.richtungWechseln()
                            }
                        }
                        schliessen()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Fertigknopf { schliessen() }
                }
            }
            .onAppear {
                if vorher == nil {
                    vorher = (block.projektion.los,
                              block.projektion.richtung)
                }
            }
        }
    }
}

/// Das Feld von oben, mit dem Ball darauf.
///
/// **Klein und ohne Beschriftung der Yards.** Sie beantwortet eine
/// einzige Frage -- „wo ungefähr?" --, und eine Karte mit zwanzig
/// Zahlen darauf beantwortet sie schlechter. Der genaue Wert steht als
/// Text daneben.
struct Feldkarte: View {
    let los: Double
    let richtung: Int
    let feld: Feld

    var body: some View {
        GeometryReader { raum in
            let breite = raum.size.width
            let hoehe = raum.size.height
            let proYard = breite / max(feld.gesamtLaenge, 1)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Farben.flaecheTief)
                // Die Endzonen.
                zone(x: 0, w: feld.torlinieLinks * proYard,
                     h: hoehe, farbe: Farben.petrolHell)
                zone(x: feld.torlinieRechts * proYard,
                     w: breite - feld.torlinieRechts * proYard,
                     h: hoehe, farbe: Farben.petrolHell)
                // Die No-Run-Zonen, wo es sie gibt.
                if feld.keinLauf > 0 {
                    zone(x: feld.torlinieLinks * proYard,
                         w: feld.keinLauf * proYard,
                         h: hoehe, farbe: Farben.goldHell)
                    zone(x: feld.keinLaufRechts * proYard,
                         w: feld.keinLauf * proYard,
                         h: hoehe, farbe: Farben.goldHell)
                }
                // Die Mittellinie.
                zone(x: feld.mitte * proYard - 0.5, w: 1,
                     h: hoehe, farbe: Farben.linie)
                // Und der Ball.
                zone(x: los * proYard - 1, w: 2,
                     h: hoehe, farbe: Farben.akzent)
                // Wohin es geht.
                Image(systemName: richtung > 0
                      ? "arrow.right" : "arrow.left")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Farben.akzent)
                    .position(x: richtung > 0 ? breite - 12 : 12,
                              y: hoehe / 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityHidden(true)
    }

    private func zone(x: Double, w: Double, h: Double,
                      farbe: Color) -> some View {
        Rectangle()
            .fill(farbe)
            .frame(width: max(w, 0), height: h)
            .offset(x: x)
    }
}
