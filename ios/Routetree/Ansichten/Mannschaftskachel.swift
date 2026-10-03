import SwiftUI

/// Die Mannschaft als Kachel: Wappen oben, Name darunter (R13).
///
/// **Der Auftrag, wörtlich** (Niklas, 25.08.2026, per Telegram, mit
/// Skizze):
///
///   „Ich würde gerne das bei Mannschaft das in so einer schwebenden
///   gläsernen Kachel ist die ins Design passt. Mit Logo und Name und
///   man denn rauf tippt."
///
/// **Warum das mehr ist als Geschmack.** Ein Trainer erkennt seine
/// Mannschaft am Wappen und nicht an einer Zeile Text -- und dieser
/// Bildschirm ist der erste nach dem Anmelden. Bis heute stand hier eine
/// flache Listenzeile, und das Logo, das der Verein hochgeladen hat, kam
/// gar nicht vor: Der Server hat es nie mitgeschickt.
///
/// **Was hier NICHT entschieden wird:** was auf der Kachel steht. Das
/// sagt `Kachelblock` -- dort lässt es sich ohne Bildschirm messen.
struct Mannschaftskachel: View {
    let team: Modell.Mannschaft

    /// Die Vereinsfarbe, oder das Petrol des Systems, wenn der Server
    /// etwas schickt, das keine Farbe ist. Geraten wird nichts.
    private var ton: Color { Color(hex: team.farbe) ?? Farben.akzent }

    var body: some View {
        VStack(spacing: 20) {
            Wappen(team: team, groesse: 132)
            VStack(spacing: 6) {
                Text(team.name)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Farben.ink)
                    .multilineTextAlignment(.center)
                Text(Kachelblock.untertitel(team))
                    .font(.footnote)
                    .foregroundStyle(Farben.inkLeise)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 34)
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity)
        .background { glas }
        .clipShape(RoundedRectangle(cornerRadius: Masse.r4,
                                    style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Masse.r4, style: .continuous)
                .strokeBorder(ton.opacity(0.45), lineWidth: 1)
        )
        // „Schwebend" ist der Schatten. Ohne ihn liegt die Kachel auf
        // dem Grund auf, und der Unterschied zur alten Listenzeile wäre
        // nur die Größe.
        .shadow(color: .black.opacity(0.55), radius: 26, x: 0, y: 14)
        .contentShape(RoundedRectangle(cornerRadius: Masse.r4,
                                       style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(team.name), \(Kachelblock.untertitel(team))")
    }

    /// Das Glas: die Vereinsfarbe, darüber eine milchige Schicht.
    ///
    /// Die Farbe steht UNTER dem Material und nicht daneben -- ein
    /// `Material` trübt, was hinter ihm liegt. Nebeneinander wären es
    /// zwei Flächen und kein Glas.
    private var glas: some View {
        ZStack {
            LinearGradient(
                colors: [ton.opacity(0.55), ton.opacity(0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Das Wappen

/// Logo, Initialen oder Zeichen -- in dieser Reihenfolge.
///
/// Welches von dreien, entscheidet `Kachelblock.wappen`. Hier steht nur,
/// wie es aussieht.
struct Wappen: View {
    let team: Modell.Mannschaft
    var groesse: CGFloat = 132

    private var ton: Color { Color(hex: team.farbe) ?? Farben.akzent }

    var body: some View {
        ZStack {
            // KEIN KREIS UM EIN WAPPEN (R54).
            //
            // Niklas am 02.09.2026 mit einem Kringel um das Wappen der
            // Strelitz Dukes: „denn muss da auch kein Kreis rum weißt
            // du?" Er hat recht: Ein Wappen ist selbst eine Form. Ein
            // Kreis darum macht daraus ein Abzeichen, und bei einem
            // quadratischen Bild sieht es aus, als wäre etwas
            // abgeschnitten.
            //
            // DER KREIS BLEIBT FÜR DIE INITIALEN. Wer kein Bild
            // hinterlegt hat, bekommt zwei Buchstaben -- und die
            // brauchen eine Fläche, sonst schweben sie im Nichts. Das
            // entscheidet `inhalt` selbst; hier steht nur noch der
            // gemeinsame Rahmen.
            inhalt
        }
        .frame(width: groesse, height: groesse)
    }

    /// Die Scheibe hinter den Initialen. Nur dort, nicht hinter Bildern.
    private var scheibe: some View {
        Circle()
            .fill(ton.opacity(0.22))
            .overlay(Circle().strokeBorder(ton.opacity(0.5), lineWidth: 1))
    }

    @ViewBuilder
    private var inhalt: some View {
        switch Kachelblock.wappen(team) {
        case .bild(let quelle):
            // OHNE Scheibe und ohne Innenabstand: Das Wappen soll so
            // gross sein, wie die Kachel hergibt.
            //
            // KEIN LEERER KREIS, WENN DAS NETZ FEHLT. Am Spielfeldrand
            // ist genau das der Normalfall, und eine leere Fläche sieht
            // aus wie ein Fehler der App. Dann eben die Initialen --
            // die stehen schon in der Antwort und brauchen keine zweite
            // Anfrage. Und weil `Netzbild` einen Treffer sofort zeigt,
            // blinkt beim Scrollen auch kein Ladekreis mehr.
            Netzbild(adresse: quelle) { ersatz }
            .accessibilityLabel("Logo von \(team.name)")
        default:
            ersatz
        }
    }

    /// Was ohne Bild dasteht: die Initialen vom Server, sonst ein
    /// Sinnbild. Dieselbe Regel für „kein Logo hochgeladen" und „Logo
    /// kam nicht an" -- sie steht in `Kachelblock.ohneBild`.
    @ViewBuilder
    private var ersatz: some View {
        // MIT SCHEIBE, anders als beim Bild (R54): Zwei Buchstaben
        // brauchen eine Fläche, sonst schweben sie im Nichts. Ein
        // Wappen bringt seine Form selbst mit.
        ZStack {
            scheibe
            switch Kachelblock.ohneBild(team) {
            case .initialen(let kurz):
                Text(kurz)
                    .font(.system(size: groesse * 0.34, weight: .semibold,
                                  design: .rounded))
                    .foregroundStyle(Farben.ink)
            default:
                Image(systemName: "person.3.fill")
                    .font(.system(size: groesse * 0.32))
                    .foregroundStyle(Farben.inkLeise)
            }
        }
    }
}

// MARK: - Die Kachel hinter der letzten Mannschaft

/// Das Plus als eigene Kachel, nicht als Knopf in der Ecke.
///
/// **Zwei Wege, und beide gehören hierhin:** Wer eine Mannschaft
/// gründet, legt sie an. Wer zu einer eingeladen wurde, hat einen Code.
/// Nur einen davon anzubieten macht aus der Hälfte der Leute eine
/// Sackgasse -- dieselbe Entscheidung wie im leeren Zustand.
struct Hinzufuegekachel: View {
    let anlegen: () -> Void
    let beitreten: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1,
                                                     dash: [6, 5]))
                    .foregroundStyle(Farben.linieStark)
                Image(systemName: "plus")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Farben.akzent)
            }
            .frame(width: 132, height: 132)

            Text("Noch eine Mannschaft")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Farben.ink)

            VStack(spacing: 10) {
                Button("Mannschaft anlegen", action: anlegen)
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
                Button("Mit Teamcode beitreten", action: beitreten)
                    .foregroundStyle(Farben.akzent)
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity)
        .background(Farben.flaechePanel.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: Masse.r4,
                                    style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Masse.r4, style: .continuous)
                .strokeBorder(Farben.linie, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 10)
    }
}
