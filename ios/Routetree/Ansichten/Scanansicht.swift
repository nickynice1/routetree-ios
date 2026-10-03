// Ein Play vom Papier abfotografieren (R142).
//
// **Niklas, 25.09.2026:** „das stell ich mir so vor, dass wenn man auf
// Play anlegen auf das Kreuz geht, dass man da Namen anlegen kann oder
// die Möglichkeit hat Kamera scan. Dann scannt man das ein und kann
// danach den Namen vergeben."
//
// Die Reihenfolge ist umgedreht, und das mit Absicht: **erst die
// Zeichnung, dann der Name.** Wer ein Blatt abfotografiert, weiß oft
// noch gar nicht, wie der Play heißen soll -- und wenn doch, tippt er
// den Namen lieber, während er das Ergebnis schon sieht.
//
// **Und: „ich möchte das der scanner auch richtig wie ein scanner
// animiert ist das muss richtig geil aussehen."**
//
// Das ist kein Schmuck. Der Scanner ist das erste, was ein fremder
// Trainer von Routetree zu sehen bekommt, wenn er sein altes Playbook
// mitbringt. Was dabei passiert, ist echte Arbeit -- ausrichten,
// entzerren, Farben trennen, Linien nachziehen -- und die Leiste zeigt
// sie in genau der Reihenfolge, in der sie wirklich geschieht: erst
// die Line of Scrimmage, dann die Figuren, dann die Routen.
//
// Eine Fortschrittsanzeige wäre die Verschwendung dieses Moments.

import SwiftUI
import UIKit

struct Scanansicht: View {

    let feld: Feld
    let los: Double
    let richtung: Int
    let spielform: String
    /// Wird mit der fertigen Zeichnung und dem Namen aufgerufen.
    let uebernehmen: (Zeichnung, String) async -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen
    @StateObject private var kamera = Kamerafuehrung()

    @State private var lage: Stand = .ausrichten
    @State private var rahmen = Rahmenlage.vorgabe
    @State private var aufnahme: UIImage?
    @State private var leiste: Double = 0
    @State private var name = ""
    @State private var uebergibt = false
    /// Wie gross der Sucher gerade ist. Gebraucht wird das erst
    /// beim Ausloesen -- ohne diese Groesse laesst sich nicht
    /// ausrechnen, welcher Teil des Fotos zu sehen war.
    @State private var sucher: CGSize = .zero
    /// Wie lange der erste Durchgang der Leiste laeuft.
    ///
    /// Kein Zufallswert: Kuerzer wirkt hektisch, laenger laesst
    /// warten, obwohl der Server meist laengst fertig ist.
    private static let lesedauer: TimeInterval = 1.2

    enum Stand: Equatable {
        case ausrichten
        case liest
        case fertig(Scanfund)
        case nichts(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                inhalt
                if case .ausrichten = lage {
                    Scanrahmen(lage: rahmen)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Play scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // DER BAUSTEIN UND KEIN WORT (R97). Neben einem
                    // Titel wie „Play scannen" bleibt fuer „Abbrechen"
                    // kein Platz; das Telefon macht daraus „Ab…".
                    // `Abbruchknopf` traegt das Wort im Vorleser
                    // weiter, das Zeichen aber im Bild.
                    Abbruchknopf { schliessen() }
                }
            }
            .safeAreaInset(edge: .bottom) { fussleiste }
        }
        .task { await kamera.starten() }
        .onDisappear { kamera.anhalten() }
    }

    // MARK: - Was gerade zu sehen ist

    @ViewBuilder
    private var inhalt: some View {
        switch lage {
        case .ausrichten:
            sucherbild
        case .liest, .fertig, .nichts:
            gescanntesBild
        }
    }

    /// Das laufende Kamerabild.
    ///
    /// **Heisst `sucherbild` und nicht `sucher`**: Der Zustand
    /// darueber traegt schon diesen Namen, und Swift erlaubt
    /// keine zwei Eigenschaften gleichen Namens. Der Bau beim
    /// Apple-Laeufer ist am 25.09.2026 genau daran gescheitert
    /// -- „invalid redeclaration of 'sucher'".
    ///
    /// **Und die Beschreibung steht VOR `@ViewBuilder`.** Dazwischen
    /// gehoerte das Attribut der uebernaechsten Deklaration --
    /// derselbe Bau ist beim zweiten Anlauf daran gescheitert.
    @ViewBuilder
    private var sucherbild: some View {
        switch kamera.lage {
        case .laeuft:
            GeometryReader { raum in
                Kamerabild(sitzung: kamera.sitzung)
                    .onAppear { sucher = raum.size }
                    .onChange(of: raum.size) { _, neu in sucher = neu }
            }
            .ignoresSafeArea()
        case .verweigert:
            Hinweistafel(
                zeichen: "camera.fill",
                titel: String(localized: "Die Kamera ist gesperrt"),
                satz: String(localized: """
                    Routetree darf die Kamera nicht benutzen. Du kannst \
                    das in den Einstellungen deines Geräts ändern.
                    """))
        case .geht_nicht(let grund):
            Hinweistafel(zeichen: "exclamationmark.triangle",
                         titel: String(localized: "Das geht hier nicht"),
                         satz: grund)
        case .aus:
            ProgressView().tint(.white)
        }
    }

    /// Das eingefrorene Foto mit der Leiste darüber.
    @ViewBuilder
    private var gescanntesBild: some View {
        GeometryReader { raum in
            ZStack {
                if let aufnahme {
                    Image(uiImage: aufnahme)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: raum.size.width,
                               height: raum.size.height)
                        .clipped()
                        .overlay(Color.black.opacity(0.45))
                }

                // Das Erkannte erscheint HINTER der Leiste -- also nur
                // da, wo sie schon gewesen ist. Deshalb eine Maske und
                // kein Ein- und Ausblenden: Es soll so aussehen, als
                // hätte die Leiste es freigelegt.
                if case .fertig(let fund) = lage {
                    Feldansicht(
                        zeichnung: fund.zeichnung,
                        projektion: Projektion
                            .fuerDieApp(feld: feld, los: los,
                                        richtung: richtung,
                                        spielform: spielform)
                            .passendFuer(fund.zeichnung)
                            .querPassendFuer(fund.zeichnung)
                            .gedehnt(auf: raum.size))
                    .mask(alignment: .top) {
                        Rectangle()
                            .frame(height: raum.size.height * leiste)
                    }
                }

                Scanleiste(hoehe: raum.size.height, stelle: leiste,
                           laeuft: lage == .liest)
                    .id(lage == .liest ? 0 : 1)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Der Fuß

    @ViewBuilder
    private var fussleiste: some View {
        VStack(spacing: 12) {
            switch lage {
            case .ausrichten:
                Text("""
                    Leg das Blatt so hin, dass die Line of Scrimmage auf \
                    der weißen Linie liegt. Die gestrichelten sind fünf \
                    und zehn Yard.
                    """)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal)

                Ausloeser { Task { await scannen() } }
                    .disabled(kamera.lage != .laeuft)

            case .liest:
                Text("Wird gelesen …")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))

            case .fertig(let fund):
                Fundleiste(fund: fund, name: $name,
                           uebergibt: uebergibt,
                           nochmal: { zurueckAufAnfang() },
                           sichern: {
                               uebergibt = true
                               Task {
                                   await uebernehmen(fund.zeichnung, name)
                                   uebergibt = false
                                   schliessen()
                               }
                           })

            case .nichts(let grund):
                Text(grund)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal)
                Button("Noch einmal") { zurueckAufAnfang() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.75))
    }

    // MARK: - Der Ablauf

    private func zurueckAufAnfang() {
        aufnahme = nil
        leiste = 0
        name = ""
        lage = .ausrichten
        Task { await kamera.starten() }
    }

    private func scannen() async {
        guard let daten = await kamera.aufnehmen(),
              let bild = UIImage(data: daten) else {
            lage = .nichts(String(localized: """
                Die Aufnahme hat nicht geklappt. Versuch es noch einmal.
                """))
            return
        }
        aufnahme = bild
        kamera.anhalten()
        lage = .liest

        // **ZWEI DURCHGÄNGE, und das ist der Kern der Animation.**
        //
        // Der erste läuft, WÄHREND gelesen wird -- er wartet nicht auf
        // den Server, er begleitet ihn. Der zweite läuft, wenn die
        // Antwort da ist, und legt hinter sich die erkannte Zeichnung
        // frei.
        //
        // Ein Durchgang ginge nicht: Die Leiste wäre durch, bevor es
        // etwas freizulegen gibt, und der Play erschiene auf einen
        // Schlag. Genau so stand es hier zuerst.
        let begonnen = Date()
        withAnimation(.easeInOut(duration: Self.lesedauer)) { leiste = 1 }

        // Die Bildpunkte des FOTOS, nicht des Suchers: Der Rahmen lag
        // auf der Vorschau, hochgeschickt wird die Aufnahme.
        let groesse = CGSize(width: bild.size.width * bild.scale,
                             height: bild.size.height * bild.scale)
        do {
            let fund = try await Scanner.lesen(
                bild: daten,
                felder: rahmen.fuerServer(bildgroesse: groesse,
                                          sucher: sucher),
                token: try await anmeldung.gueltigesToken())
            // **Den ERSTEN Durchgang abwarten, nicht eine feste
            // Wartezeit.** Hier stand eine feste Zahl -- bei einem
            // Server, der schneller antwortet, liefe der zweite
            // Durchgang mitten im ersten los, und die Leiste spraenge.
            let offen = Self.lesedauer - Date().timeIntervalSince(begonnen)
            if offen > 0 {
                try? await Task.sleep(for: .seconds(offen))
            }
            guard let erster = fund else {
                lage = .nichts(String(localized: """
                    Auf dem Blatt war kein Play zu erkennen. Achte \
                    darauf, dass die Spieler und die Routen gut zu \
                    sehen sind.
                    """))
                return
            }
            // Zurueck auf null OHNE Animation -- sonst laeuft die
            // Leiste sichtbar rueckwaerts, bevor sie wieder losgeht.
            var ohne = Transaction()
            ohne.disablesAnimations = true
            withTransaction(ohne) {
                leiste = 0
                lage = .fertig(erster)
            }
            withAnimation(.easeOut(duration: 1.0)) { leiste = 1 }
        } catch {
            lage = .nichts(error.localizedDescription)
        }
    }
}

// MARK: - Bausteine

/// Die Leiste, die über das Blatt läuft.
///
/// **Ein Verlauf und keine Linie.** Eine harte Kante sieht aus wie ein
/// Bildfehler; der Schimmer davor und dahinter macht daraus eine
/// Bewegung. Die helle Linie sitzt am unteren Rand, also da, wo die
/// Leiste gerade ankommt -- sie zieht den Blick mit.
private struct Scanleiste: View {

    let hoehe: CGFloat
    let stelle: Double
    let laeuft: Bool

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, Farben.gold.opacity(0.35)],
                startPoint: .top, endPoint: .bottom)
            .frame(height: 90)
            Rectangle()
                .fill(Farben.gold)
                .frame(height: 2)
                .shadow(color: Farben.gold.opacity(0.9), radius: 8)
        }
        // **`.offset` in einem oben ausgerichteten Rahmen, nicht
        // `.position`.** `.position` nimmt eine Ansicht aus dem Layout
        // und setzt ihren MITTELPUNKT auf die angegebene Stelle -- mit
        // x: 0 haengt die halbe Leiste links aus dem Bild. Genau das
        // stand hier zuerst; auf einem Geraet waere es sofort zu sehen
        // gewesen, ohne eins nur beim Lesen.
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .offset(y: hoehe * stelle - 92)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(stelle > 0 && stelle < 1 ? 1 : (laeuft ? 1 : 0))
        .allowsHitTesting(false)
    }
}

/// Der Auslöser -- ein Ring mit einer Scheibe darin.
private struct Ausloeser: View {

    let tippen: () -> Void
    @Environment(\.isEnabled) private var geht

    var body: some View {
        Button(action: tippen) {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 3)
                    .frame(width: 68, height: 68)
                Circle().fill(.white).frame(width: 56, height: 56)
            }
        }
        .buttonStyle(.plain)
        .opacity(geht ? 1 : 0.4)
        .accessibilityLabel(Text("Scannen"))
    }
}

/// Was nach dem Lesen unten steht.
private struct Fundleiste: View {

    let fund: Scanfund
    @Binding var name: String
    let uebergibt: Bool
    let nochmal: () -> Void
    let sichern: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // **Die Bedenken stehen VOR dem Namensfeld.** Wer gerade
            // tippt, liest nichts mehr -- und was hier steht, soll er
            // lesen, bevor er auf „Übernehmen" geht.
            if !fund.bedenken.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(fund.bedenken, id: \.self) { satz in
                        Label(satz, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(Farben.gold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            } else {
                Text("\(fund.spieler) Spieler, \(fund.routen) Routen erkannt.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }

            TextField("Name des Plays", text: $name)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            HStack {
                Button("Noch einmal", action: nochmal)
                    .buttonStyle(.bordered)
                Button("Übernehmen", action: sichern)
                    .buttonStyle(.borderedProminent)
                    .disabled(uebergibt || name.trimmingCharacters(
                        in: .whitespaces).isEmpty)
            }
        }
    }
}

private struct Hinweistafel: View {

    let zeichen: String
    let titel: String
    let satz: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: zeichen)
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.7))
            Text(titel).font(.headline).foregroundStyle(.white)
            Text(satz)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(24)
    }
}
