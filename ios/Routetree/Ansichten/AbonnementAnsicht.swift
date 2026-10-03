import SwiftUI

/// Das Abonnement -- am Konto, nicht am Verein (R134).
///
/// **Niklas, 23.09.2026:** „das abonnent verhalten gilt ja eh auf den
/// account nicht auf das team. das heisst es sollte nicht unter den
/// teams auffindbar sein, sondern bei konto ein extra reiter für
/// abonnent verwalten geben."
///
/// ## Warum er recht hat, und zwar strenger, als es klingt
///
/// Alle vier Abos liegen bei Apple in EINER Abo-Gruppe. Apples eigener
/// Satz dazu steht in App Store Connect: „Users can only subscribe to
/// one subscription in a group at a time." Eine Apple-ID kann also
/// **genau ein** Routetree-Abo halten.
///
/// Auf unserer Seite steht in `kasse.apple_verarbeiten`: „`verein` gibt
/// es nur beim ERSTEN Mal. Danach steht die Zuordnung am Vertrag, und
/// sie wird nicht mehr angerührt."
///
/// Zusammen: **Eine Apple-ID trägt ein Abo, und das gehört dauerhaft zu
/// einem Verein.**
///
/// Bis heute stand in der Kontoansicht unter „Verein" JEDER Verein mit
/// eigener Abo-Zeile -- als könnte man je Verein eines kaufen. Genau
/// das kann man nicht. Dieselbe Sorte Falschaussage wie „Du bezahlst
/// diese Stufe bereits" (18.09.), nur eine Ebene höher, und derselbe
/// Nährboden: Am 18.09. landete ein Kauf beim falschen Verein.
///
/// ## Was hier steht
///
/// Läuft ein Vertrag, steht er da -- Stufe, Laufzeit und **für welchen
/// Verein**. Der Verein gehört dazu: Ohne ihn ist es wieder Raten.
///
/// Läuft keiner, steht der Kaufstapel da. Bei mehreren Vereinen wird
/// vorher gefragt, für welchen -- die Zuordnung ist dauerhaft, und eine
/// dauerhafte Entscheidung stellt man nicht schweigend her.
struct AbonnementAnsicht: View {
    let vereine: [Modell.Verein]
    var gekauft: ((Modell.Abo) -> Void)?

    @Environment(\.dismiss) private var schliessen
    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var gewaehlt: Int?

    /// Apples Seite für laufende Abos. Kündigen, Stufe wechseln und das
    /// Ablaufdatum stehen dort -- und NUR dort: Richtlinie 3.1.2
    /// verlangt, dass die App dorthin führt, statt es selbst zu
    /// behaupten.
    private static let apple = URL(
        string: "https://apps.apple.com/account/subscriptions")!

    /// Der Verein, für den gerade bezahlt wird -- wenn einer bezahlt.
    private var bezahlt: Modell.Verein? {
        vereine.first { $0.abo?.vertrag != nil }
    }

    /// Die Vereine, für die dieses Konto überhaupt etwas bestellen darf.
    ///
    /// **Der Server sagt es** (`darf_bestellen`), die App rechnet es
    /// nicht. Aus `rolle` geschlossen wäre falsch: `darf_bestellen`
    /// lässt auch den Head Coach einer Mannschaft dieses Vereins
    /// bestellen, und der steht in `rolle` als „team". Zwei Regeln für
    /// dieselbe Frage laufen auseinander -- in diesem Projekt der
    /// häufigste Fehler überhaupt.
    private var bestellbar: [Modell.Verein] {
        vereine.filter(\.darfBestellen)
    }

    /// Der Verein, für den gekauft wird -- wenn die Frage entschieden
    /// ist. Bei genau einem Verein gibt es nichts zu fragen.
    private var zuKaufen: Modell.Verein? {
        if bestellbar.count == 1 { return bestellbar.first }
        return bestellbar.first { $0.id == gewaehlt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                inhalt
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("abonnementseite")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Fertigknopf { schliessen() }
                }
                // DER VEREINSWECHSEL GEHÖRT IN DIE LEISTE, nicht über
                // den Stapel. Dort stand er zuerst als nackte Zeile
                // („Für Strelitz Dukes" / „Anderer Verein") und sah aus
                // wie eine Überschrift, nicht wie ein Weg zurück.
                if bestellbar.count > 1, zuKaufen != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(String(localized: "Verein")) {
                            gewaehlt = nil
                        }
                    }
                }
            }
        }
    }

    /// Was oben steht. Beim Kaufen der Vereinsname: Es ist die eine
    /// Angabe, die auf dieser Seite fehlen würde, und sie hat oben
    /// Platz, ohne dem Stapel welchen wegzunehmen.
    private var titel: String {
        if bezahlt == nil, let verein = zuKaufen, bestellbar.count > 1 {
            return verein.name
        }
        return String(localized: "Abonnement")
    }

    /// **EIN BILDSCHIRM JE ZUSTAND, und keiner davon schachtelt.**
    ///
    /// Hier stand alles untereinander in EINER `ScrollView`: die
    /// Vereinswahl, darunter der `StufenStapel` mit `minHeight: 520`,
    /// darunter zwei Fußnoten. Der Stapel ist aber eine blätternde
    /// `TabView`, die je Seite selbst scrollt -- zwei Scroll-Ebenen
    /// ineinander.
    ///
    /// Niklas am 23.09.2026 mit Bildschirmfoto: „das sieht jetzt alles
    /// so gequetscht und auch null attraktiv aus." Auf dem Bild liegen
    /// die Blätterpunkte mitten im Wort, rechts stehen zwei
    /// Scrollbalken übereinander, und der Satz darunter klebt am
    /// Stapel.
    ///
    /// Jetzt bekommt jeder Zustand den ganzen Bildschirm: entweder der
    /// laufende Vertrag, oder die Vereinswahl, oder der Stapel. Nie
    /// zwei davon übereinander.
    @ViewBuilder
    private var inhalt: some View {
        if let verein = bezahlt, let vertrag = verein.abo?.vertrag {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    laufenderVertrag(verein, vertrag)
                    einKontoEinAbo
                }
                .padding(22)
            }
        } else if bestellbar.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("""
                        Für dieses Konto lässt sich kein Abonnement \
                        buchen. Bestellen kann, wer einen Verein \
                        verwaltet.
                        """)
                        .foregroundStyle(Farben.inkStill)
                    einKontoEinAbo
                }
                .padding(22)
            }
        } else if let verein = zuKaufen, let abo = verein.abo {
            // DER STAPEL BEKOMMT DIE GANZE FLÄCHE. Er bringt seine
            // eigene Blätterleiste und sein „Käufe wiederherstellen"
            // mit; alles, was man daneben stellt, nimmt ihm Platz weg
            // und schiebt seine Punkte in den Text.
            StufenStapel(abo: abo, verein: verein.id, gekauft: gekauft)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    vereinswahl
                    einKontoEinAbo
                }
                .padding(22)
            }
        }
    }

    // --- Es läuft eines ---------------------------------------------------

    private func laufenderVertrag(_ verein: Modell.Verein,
                                  _ vertrag: Modell.Vertragsstand) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            karte(verein, vertrag)
            // KÜNDIGEN GEHT NUR BEI APPLE, und deshalb steht hier ein
            // Weg dorthin statt eines Knopfes, der es verspricht.
            Link(destination: Self.apple) {
                Text("Bei Apple verwalten oder kündigen")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .contentShape(Rectangle())
            }
            .paarung(Paare.knopfHaupt)
        }
    }

    private func karte(_ verein: Modell.Verein,
                       _ vertrag: Modell.Vertragsstand) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(stufenname(vertrag.stufe, laut: verein.abo))
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Farben.ink)
            Text(vertrag.istJahr ? String(localized: "Jährlich")
                                 : String(localized: "Monatlich"))
                .foregroundStyle(Farben.inkStill)
            // DER VEREIN STEHT DRAN. Ohne ihn wäre es wieder die
            // Auskunft, bei der man raten muss -- und am 18.09.2026
            // landete genau deshalb ein Kauf beim falschen.
            Text(String(localized: "Freigeschaltet: \(verein.name)"))
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Farben.flaechePanel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Farben.linie))
    }

    // --- Die Wahl --------------------------------------------------

    /// Bei mehreren Vereinen wird gefragt, für welchen.
    ///
    /// **Und zwar vorher.** Die Zuordnung eines App-Store-Abos an einen
    /// Verein ist dauerhaft; sie lässt sich danach nicht umhängen. Eine
    /// dauerhafte Entscheidung schweigend zu treffen, war der Fehler vom
    /// 18.09.2026.
    private var vereinswahl: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Für welchen Verein?")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Farben.ink)
            Text("""
                Ein Abonnement gehört dauerhaft zu einem Verein und \
                lässt sich später nicht umhängen.
                """)
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)
            ForEach(bestellbar) { verein in
                Button {
                    gewaehlt = verein.id
                } label: {
                    HStack {
                        Text(verein.name).foregroundStyle(Farben.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Farben.inkStill)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .background(Farben.flaechePanel,
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Farben.linie))
            }
        }
    }

    // --- Der Satz, der die Regel erklärt ----------------------------------

    /// **Die Absage, die man lieber liest als sucht.**
    ///
    /// Wer zwei Vereine führt, kann mit einem Apple-Konto genau einen
    /// freischalten. Das ist keine Entscheidung von uns, sondern Apples
    /// Abo-Gruppe -- und es ungesagt zu lassen hiesse, jemanden suchen
    /// zu lassen, was es nicht gibt.
    private var einKontoEinAbo: some View {
        Text("""
            Ein Apple-Konto trägt ein Abonnement. Für einen weiteren \
            Verein geht der Kauf über routetree.de, auf Rechnung.
            """)
            .font(.footnote)
            .foregroundStyle(Farben.inkStill)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Der Name der Stufe -- **vom Server**, wenn er ihn schickt.
    ///
    /// Dieselbe Regel und derselbe Grund wie in `StufenAnsicht.name`:
    /// Dieselben zwei Stufen hiessen an drei Stellen verschieden, bis
    /// der Server den Namen mitschickte.
    private func stufenname(_ stufe: String, laut abo: Modell.Abo?) -> String {
        if let vomServer = abo?.kaufbareStufen.first(where: {
            $0.stufe == stufe })?.name, !vomServer.isEmpty {
            return vomServer
        }
        switch stufe {
        case "basis": return String(localized: "Standard")
        case "unbegrenzt": return String(localized: "Premium")
        default: return stufe
        }
    }
}
