// Was der Coach ruft, am Handgelenk (R143).
//
// **Niklas am 01.10.2026:** „denn soll es so sein wie in spielmodus nur
// das mein coach auf seinem handy das play auswählt, und bei mir wird es
// automatisch auf der uhr angezeigt."
//
// ## Was sie vom Spielmodus übernimmt, und was nicht
//
// Übernommen ist alles, was mit dem Platz zu tun hat: Die Uhr bleibt
// vorne (`Spielsitzung`), der Play füllt den Schirm, keine Werkzeuge.
//
// Weg ist die Crown. Im Spielmodus blättert der Träger selbst; hier
// bestimmt der Coach, und zwei Stellen, die denselben Play setzen,
// wären ein Wettlauf -- der Spieler dreht weiter, der nächste Ruf
// springt zurück, und niemand versteht, warum.
//
// ## Was dazukommt: der Weg ins Netz
//
// Der Spielmodus braucht kein Netz, sein Heft liegt auf der Uhr. Dieser
// hier lebt davon. Deshalb steht ganz oben, WORÜBER die Uhr gerade
// angebunden ist -- und bei einer Uhr ohne Mobilfunk steht da der Satz,
// auf den es ankommt: Das Telefon muss beim Träger bleiben.
//
// Ein Spieler, der sein Telefon beim Coach an der Bank lässt, steht
// sonst auf dem Feld mit einer Uhr, die nichts mehr bekommt, und hält
// sie für kaputt.

import SwiftUI

struct UhrCoaching: View {

    /// Das Heft liefert Feld und Spielform -- die Antwort des Servers
    /// trägt nur die Zeichnung. Genommen wird das Heft, das der
    /// Träger ohnehin auf der Uhr hat.
    let heft: Uhrpaket.Heft

    let schluessel: String

    @StateObject private var sitzung = Spielsitzung()
    @StateObject private var leitung = Uhrleitung()
    @StateObject private var empfang: Coachingempfang
    @Environment(\.dismiss) private var schliessen

    @State private var hoertAuf = false

    init(heft: Uhrpaket.Heft, schluessel: String) {
        self.heft = heft
        self.schluessel = schluessel
        _empfang = StateObject(
            wrappedValue: Coachingempfang(schluessel: schluessel))
    }

    var body: some View {
        ZStack {
            if let play = empfang.play {
                Uhrfeld(play: play.alsUhrplay, feld: heft.feld,
                        spielform: heft.spielform,
                        zeigeNamen: false)
            } else {
                warten
            }
            VStack {
                kopfzeile
                Spacer()
                if empfang.wartend > 0 { reihenzeile }
            }
        }
        // EINMAL TIPPEN HOLT DEN NAECHSTEN (R143.2).
        //
        // **Niklas am 01.10.2026:** „denn brauch der qb nur einmal auf
        // die uhr tippen und das play wechselt automatisch."
        //
        // Auf dem GANZEN Bildschirm und nicht auf einem Knopf: Der
        // Quarterback tippt mit einem Handschuh, im Laufen, ohne
        // hinzusehen. Ein Ziel von zwei Zentimetern trifft er nicht.
        //
        // `weiterschalten` tut nichts, wenn die Reihe leer ist -- ein
        // Tippen darf den laufenden Play nicht wegnehmen.
        .onTapGesture {
            Task { await empfang.weiterschalten() }
        }
        .task {
            await sitzung.anfangen()
            empfang.anfangen()
        }
        .onDisappear {
            empfang.aufhoeren()
            Task { await sitzung.aufhoeren() }
        }
    }

    // MARK: - Teile

    /// Die Zeile über dem Play: Name der Uhr, Weg ins Netz.
    ///
    /// **Klein und oben**, nicht als eigener Bildschirm. Wer sie
    /// wegklicken müsste, sähe sie genau einmal -- und gebraucht wird
    /// sie in dem Moment, in dem nichts mehr ankommt.
    private var kopfzeile: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(leitung.erreichbar ? Farben.gut : Farben.warnung)
                .frame(width: 6, height: 6)
            Text(leitung.kurz)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            if let name = empfang.name {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    /// Wie viele vorbereitet sind -- und dass Tippen etwas bringt.
    ///
    /// **Unten und nicht oben.** Oben steht, ob die Verbindung hält;
    /// das liest man, wenn etwas fehlt. Diese Zeile liest man im
    /// Spiel, und der Daumen liegt unten.
    ///
    /// Sie verschwindet, sobald die Reihe leer ist. Eine Zeile „0
    /// warten" wäre eine Aufforderung zu tippen, die nichts tut.
    private var reihenzeile: some View {
        HStack(spacing: 4) {
            if empfang.schaltet {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: "hand.tap")
                    .font(.system(size: 10))
            }
            Text(empfang.wartend == 1
                 ? String(localized: "1 wartet")
                 : String(localized: "\(empfang.wartend) warten"))
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Uhrfarben.fuer(.gold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.black.opacity(0.55), in: Capsule())
        .padding(.bottom, 2)
    }

    /// Was dasteht, solange nichts gerufen wurde.
    private var warten: some View {
        VStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text("Warte auf den Coach")
                .font(.system(size: 15, weight: .semibold))
            Text(leitung.hinweis)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let hinweis = empfang.hinweis {
                Text(hinweis)
                    .font(.system(size: 11))
                    .foregroundStyle(Farben.warnung)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 8)
    }
}
