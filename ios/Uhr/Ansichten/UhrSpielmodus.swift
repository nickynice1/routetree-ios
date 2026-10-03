// Der Spielmodus am Handgelenk (R140.3).
//
// **Niklas, 25.09.2026:** „ich kann wieder mit Crown oder per Touch
// die Plays wechseln."
//
// ## Was ihn vom Ansehen unterscheidet
//
// Nicht die Darstellung -- ein Play sieht hier aus wie überall. Drei
// Dinge sind anders, und alle drei folgen daraus, dass der Träger
// gerade auf dem Feld steht:
//
// 1. **Die Uhr bleibt vorne.** Eine Workout-Sitzung hält sie beim Play,
//    auch wenn der Arm zwischendurch sinkt (siehe `Spielsitzung`).
// 2. **Die Crown läuft über das GANZE Heft**, nicht nur über eine
//    Kategorie -- so entschieden von Niklas am 25.09.2026. Kategorie
//    für Kategorie durch, ohne dass etwas unerreichbar ist. Zwischen
//    zwei Spielzügen weiß niemand mehr, in welcher Kategorie der Play
//    stand, den er sucht.
// 3. **Keine Werkzeuge.** Kein Umschalter für Routennamen, keine
//    Liste. Was am Platz nicht gebraucht wird, ist am Platz im Weg.
//
// ## Warum die Crown und das Wischen dasselbe tun
//
// Weil beides dieselbe Frage beantwortet -- „der nächste" -- und weil
// man am Platz nicht überlegt, welche Geste gerade gilt. Die Crown ist
// da, wo Handschuhe sind; der Finger ist da, wo es schnell gehen muss.

import SwiftUI

struct UhrSpielmodus: View {

    let heft: Uhrpaket.Heft

    @StateObject private var sitzung = Spielsitzung()
    @Environment(\.dismiss) private var schliessen

    @State private var stelle = 0
    /// Der Wert, an dem die Crown dreht. Kommastellen mit Absicht:
    /// Eine ganzzahlige Bindung springt bei jedem Rastpunkt und
    /// fühlt sich an wie ein Zahnrad ohne Zähne.
    @State private var kroneWert: Double = 0
    @State private var hoertAuf = false
    /// Ob der Ausgangshinweis noch steht.
    @State private var zeigeAusgang = true

    private var plays: [Uhrpaket.Play] { heft.plays }

    var body: some View {
        TabView(selection: $stelle) {
            ForEach(Array(plays.enumerated()), id: \.offset) {
                nummer, play in
                Uhrfeld(play: play, feld: heft.feld,
                        spielform: heft.spielform,
                        zeigeNamen: false)
                    .tag(nummer)
            }
        }
        .tabViewStyle(.verticalPage)
        // **`.focusable` MUSS dabei sein.** Ohne den Fokus bekommt die
        // Ansicht keine Crown-Ereignisse -- der Regler ist da, dreht
        // aber ins Leere. Das fällt im Simulator nicht auf, weil man
        // dort ohnehin mit der Maus scrollt.
        .focusable()
        .digitalCrownRotation(
            $kroneWert, from: 0, through: Double(max(plays.count - 1, 0)),
            by: 1, sensitivity: .medium,
            isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: kroneWert) { _, neu in
            let ziel = Int(neu.rounded())
            if ziel != stelle, plays.indices.contains(ziel) {
                stelle = ziel
            }
        }
        // Wischen und Drehen müssen einander nachziehen, sonst springt
        // die Crown beim nächsten Dreh zurück auf ihren alten Wert.
        .onChange(of: stelle) { _, neu in
            if Int(kroneWert.rounded()) != neu {
                kroneWert = Double(neu)
            }
        }
        .navigationTitle(titel)
        .navigationBarBackButtonHidden(true)
        // **KEIN STOP-KNOPF MEHR, sondern ein langer Druck.**
        //
        // Niklas am 25.09.2026: „so ein stop button, der muss weg, und
        // der soll durch langes Drücken beendet werden."
        //
        // Der Knopf sass in der Werkzeugleiste und war dort der
        // einzige -- also genau das, was man am Platz streift. Ein
        // langer Druck lässt sich nicht versehentlich auslösen, und er
        // nimmt keinen Bildschirmrand weg.
        //
        // **Die Crown geht dafür NICHT.** Ihren langen Druck hat Apple
        // für Siri reserviert, so wie den Seitenknopf für den Notruf;
        // eine App bekommt ihn nicht. Der Bildschirm ist dieselbe
        // Geste an der nächstgelegenen Stelle.
        //
        // Eine Sekunde ist bewusst lang: Ein halbes Wischen dauert
        // weniger, und das soll weiterhin blättern.
        .onLongPressGesture(minimumDuration: 1.0) {
            hoertAuf = true
        }
        .overlay(alignment: .top) { kopfzeile }
        .overlay(alignment: .bottom) { hinweis }
        .task {
            await sitzung.anfangen()
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.5)) { zeigeAusgang = false }
        }
        // **Nachfragen und nicht gleich beenden.** Der Knopf sitzt in
        // der Werkzeugleiste, und die ist am Platz schnell gestreift.
        // Ein versehentliches Ende hiesse: Uhr fällt aufs Zifferblatt,
        // mitten im Drive.
        .confirmationDialog("Spielmodus beenden?", isPresented: $hoertAuf) {
            Button("Beenden", role: .destructive) {
                Task {
                    await sitzung.aufhoeren()
                    schliessen()
                }
            }
            Button("Weiterspielen", role: .cancel) { }
        }
    }

    /// Wie man wieder herauskommt -- kurz, und dann nie wieder.
    ///
    /// **Ein Modus ohne sichtbaren Ausgang ist eine Falle.** Der
    /// Stop-Knopf war zu sehen; ein langer Druck ist es nicht. Also
    /// steht es einmal da, in den ersten Sekunden, und verschwindet
    /// dann -- wer den Spielmodus zum zweiten Mal benutzt, weiss es.
    @ViewBuilder
    private var hinweis: some View {
        if zeigeAusgang {
            Text("Lang drücken zum Beenden")
                .font(.system(size: 10))
                .foregroundStyle(Uhrfarben.schrift)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(.black.opacity(0.65), in: Capsule())
                .padding(.bottom, 4)
                .transition(.opacity)
        }
    }

    /// Ein schmaler Streifen mit der Nummer und dem Zustand.
    ///
    /// **Nummer statt Name.** Der Name steht ohnehin im Titel; was am
    /// Platz fehlt, ist die Auskunft, wo man im Heft ist -- „7 von 28"
    /// sagt, ob noch viel kommt.
    @ViewBuilder
    private var kopfzeile: some View {
        if case .verweigert = sitzung.lage {
            Text("Ohne Gesundheitszugriff fällt die Uhr aufs Zifferblatt zurück.")
                .font(.system(size: 9))
                .multilineTextAlignment(.center)
                .foregroundStyle(Uhrfarben.schrift)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.black.opacity(0.65), in: Capsule())
                .padding(.top, 2)
        }
    }

    private var titel: String {
        guard plays.indices.contains(stelle) else { return heft.name }
        return plays[stelle].name
    }
}
