import SwiftUI

/// Was jemand sieht, der die App zum ersten Mal öffnet.
///
/// **Warum es das gibt.** Vorher stand dort sofort die Anmeldemaske.
/// Für einen Trainer, der einen Zugang hat, ist das richtig -- für jeden
/// anderen ist es eine Wand: kein Wort dazu, was das Ding tut, und ein
/// Formular, das er nicht ausfüllen kann. Wer die App im Store findet,
/// entscheidet in zehn Sekunden, ob er sie behält.
///
/// **SEIT B12 GIBT ES HIER DREI WEGE HEREIN**, und das ist kein
/// Schmuck, sondern die Berichtigung eines falschen Satzes. Bis dahin
/// stand hier „Zugänge vergibt der Verein" -- seit A1 (21.08.) legt sich
/// ein Verein selbst an, und wer die App im Store fand, las das
/// Gegenteil davon, was das Produkt tut. Apple lehnt irreführende
/// Beschreibungen ab (Richtlinie 2.3.1), und zu Recht.
///
/// Die drei Wege sind drei verschiedene Menschen, und sie kommen in
/// dieser Reihenfolge: der Trainer ohne Konto (ausprobieren), der
/// Spieler mit einem Code aus der Mannschaftsgruppe, und der, der schon
/// dabei ist. Der letzte weiß, was er will, und braucht keinen großen
/// Knopf.
struct WillkommenAnsicht: View {
    @State private var zeigtAnmeldung = false
    @State private var zeigtRegistrierung = false
    @State private var zeigtTeamcode = false
    @StateObject private var fremd = Fremdanmeldung()
    @EnvironmentObject private var anmeldung: Anmeldung

    /// Ein Fingertipp, zwei Schritte: Fenster auf, Code eintauschen.
    ///
    /// Bricht jemand ab, kommt `nil` zurück und hier passiert nichts --
    /// keine Meldung, kein Zustand. Wer das Fenster zumacht, hat sich
    /// entschieden.
    private func fremdAnmelden(_ welcher: Fremdanmeldung.Anbieter) async {
        guard let code = await fremd.anmelden(bei: welcher) else { return }
        await anmeldung.anmelden(mit: code)
    }

    var body: some View {
        ZStack {
            Farben.flaeche.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    kopf
                    punkte
                    schluss
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $zeigtAnmeldung) {
            AnmeldeAnsicht()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $zeigtRegistrierung) {
            RegistrierAnsicht()
        }
        .sheet(isPresented: $zeigtTeamcode) {
            BeitretenNeuAnsicht()
        }
    }

    // --- Kopf ------------------------------------------------------------

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 18) {
            RouteTreeZeichen()
                .frame(width: 64, height: 64)
                .padding(.top, 48)

            Text("Das Playbook, das am\nSpielfeldrand funktioniert.")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Farben.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("""
                Routetree ist ein Play-Designer für Flag und Tackle \
                Football. Diese App hat das Playbook deiner Mannschaft \
                dabei, jeden Play so, wie er gezeichnet wurde.
                """)
                .font(.callout)
                .foregroundStyle(Farben.inkStill)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                zeigtRegistrierung = true
            } label: {
                Text("Kostenlos ausprobieren")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .contentShape(Rectangle())
            }
            // Fläche UND Schrift in einem Griff, aus `.knopf.haupt` im
            // Web. Hier stand bis B13 eine getippte Zahl, im
            // Anmeldeformular `.black` und im Abo-Vorschlag die
            // Grundfläche: drei Hauptknöpfe, drei Schriftfarben.
            .paarung(Paare.knopfHaupt)
            .padding(.top, 6)

            // ANMELDEN MIT GOOGLE UND APPLE (R19).
            //
            // BEIDE ODER KEINER, und das ist keine Geschmacksfrage:
            // Apples Richtlinie 4.8 verlangt, dass eine App, die
            // Anmeldung über einen Drittanbieter anbietet, „Sign in
            // with Apple" gleichwertig anbietet. Ein Google-Knopf ohne
            // Apple-Knopf kostet die App eine Ablehnung -- nach Tagen
            // Wartezeit. Deshalb steht hier keine Liste, sondern ein
            // Paar.
            //
            // Sie stehen HINTER dem Hauptknopf: Wer neu ist, soll
            // „Kostenlos ausprobieren" zuerst sehen. Wer schon ein
            // Google-Konto hat, findet den kürzeren Weg trotzdem.
            ForEach(Fremdanmeldung.Anbieter.allCases, id: \.rawValue) { welcher in
                Button {
                    Task { await fremdAnmelden(welcher) }
                } label: {
                    Text(welcher.knopf)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        // OHNE TREFFERFLAECHE IST NUR DER TEXT TIPPBAR,
                        // und zwar genau die Buchstaben. Der Knopf sieht
                        // ueber die ganze Breite aus und reagiert in der
                        // Mitte -- gemeldet von Niklas am 28.09.2026.
                        //
                        // SIE GEHOERT INS LABEL, nicht an den Button:
                        // Die Trefferflaeche entscheidet die BESCHRIFTUNG.
                        // Am Button davor stand sie beim Uhr-Knopf schon,
                        // und der war trotzdem tot.
                        .contentShape(Rectangle())
                }
                .background(Farben.flaechePanel,
                            in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13)
                    .stroke(Farben.linie))
                .foregroundStyle(Farben.ink)
                .disabled(fremd.laeuft)
            }

            if let satz = fremd.fehler {
                Text(satz)
                    .font(.footnote)
                    .foregroundStyle(Farben.warnung)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Der zweite Weg steht gleichberechtigt daneben und nicht
            // unten: Ein Spieler mit einem Code in der Hand ist kein
            // Sonderfall, sondern die Mehrzahl der Leute in einer
            // Mannschaft.
            Button {
                zeigtTeamcode = true
            } label: {
                Text("Ich habe einen Teamcode")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
            }
            .background(Farben.flaechePanel, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Farben.linie))
            .foregroundStyle(Farben.ink)

            Button {
                zeigtAnmeldung = true
            } label: {
                Text("Ich habe schon einen Zugang")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Farben.akzent)
                    .frame(maxWidth: .infinity)
                    // Ohne senkrechte Polsterung ist die Flaeche hier nur
                    // so hoch wie die Schrift -- unter der Apple-Regel
                    // von 44 Punkten. Beides gehoert zusammen.
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            // Sprachunabhaengig fuer den Bilderlauf (R120).
            .accessibilityIdentifier("zum-anmelden")
            .padding(.top, 2)
        }
        .padding(.bottom, 40)
    }

    // --- Was es kann -----------------------------------------------------

    private struct Punkt: Identifiable {
        let id = UUID()
        let zeichen: String
        let titel: String
        let text: String
    }

    // WAS HIER STEHT, MUSS DIE APP KOENNEN.
    //
    // Bis zum 20.08. warben diese vier Punkte mit „Papier, das mitmacht"
    // und „Ohne Netz am Platz". Beides konnte damals nur das Web, und
    // Apple lehnt irrefuehrende Beschreibungen ab (Richtlinie 2.3.1).
    //
    // SEIT B12 STIMMT DIE ANDERE HAELFTE NICHT MEHR. „Gezeichnet wird am
    // Rechner" und „Diese App ist zum Nachschlagen dabei" waren richtig,
    // solange die App nur las -- seit B3 zeichnet sie, seit B8 uebt sie,
    // seit B9 verwaltet sie den Kader und seit B10 druckt sie. Eine
    // Beschreibung, die das Produkt kleiner macht, als es ist, ist
    // genauso falsch wie eine, die es groesser macht; sie kostet nur
    // anders, naemlich den, der die App deshalb nicht laedt.
    //
    // Versprochen wird, was die App HEUTE tut. Was fehlt, steht nicht da.
    private let inhalte: [Punkt] = [
        .init(zeichen: "list.bullet.rectangle",
              titel: String(localized: "Das Playbook in der Tasche"),
              text: String(localized: """
                  Alle Playbooks der Mannschaft, nach Kategorie gruppiert und \
                  durchsuchbar. Am Spielfeldrand ist das schneller als jeder \
                  Ordner.
                  """)),
        .init(zeichen: "hand.draw",
              titel: String(localized: "Zeichnen, wo es passiert"),
              text: String(localized: """
                  Routen, Motion, Zonen und Passwege mit dem Finger, auf \
                  halbe Yards gefangen. Spiegeln und Abspielen sind dabei.
                  """)),
        .init(zeichen: "brain.head.profile",
              titel: String(localized: "Üben, bis es sitzt"),
              text: String(localized: """
                  Der Übungsmodus fragt die Plays ab, der Coach gibt \
                  einzelnen Spielern welche auf, und im Kader steht, wer wie \
                  weit ist.
                  """)),
        .init(zeichen: "printer",
              titel: String(localized: "Playcards und Wristcoach"),
              text: String(localized: """
                  Call Sheet, Playcards und die Einlage fürs Armband kommen \
                  aus derselben Satzmaschine wie am Rechner. Zum Drucken oder \
                  Teilen.
                  """)),
    ]

    private var punkte: some View {
        VStack(spacing: 14) {
            ForEach(inhalte) { p in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: p.zeichen)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Farben.akzent)
                        .frame(width: 26, height: 22)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.titel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Farben.ink)
                        Text(p.text)
                            .font(.footnote)
                            .foregroundStyle(Farben.inkStill)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Farben.flaechePanel,
                            in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Farben.linie))
            }
        }
    }

    // --- Was die Demo hergibt --------------------------------------------

    private var schluss: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(Farben.linie).padding(.vertical, 26)

            Text("Was kostet das?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Farben.ink)

            // KEINE ZAHLEN HIER. Der Umfang der Demo und der Preis sind
            // im Betrieb aenderbar; eine App, die sie mitbringt, wirbt
            // nach der ersten Aenderung mit Zahlen von vorgestern -- so
            // lange, bis jemand eine neue Fassung in den Store bringt.
            // Beides steht im Formular, geholt vom Server.
            Text("""
                Ausprobieren kostet nichts. Der Umfang ist dabei begrenzt und \
                jeder Ausdruck trägt einen Streifen; was genau, steht beim \
                Anlegen. Später zahlt der Verein einen Preis, egal wie \
                groß die Mannschaft ist, und wer nur zuschaut kostet nichts.
                """)
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)
                .fixedSize(horizontal: false, vertical: true)

            // Kein Bezahlformular in der App: Apple untersagt Hinweise auf
            // externe Kaufwege (Richtlinie 3.1.1), und ein Verein schliesst
            // ohnehin nicht am Handy ab. Eine Mailadresse ist beides nicht.
            Link(destination: URL(string: "mailto:kontakt@routetree.de")!) {
                Text("kontakt@routetree.de")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Farben.akzent)
            }
            .padding(.top, 2)
        }
    }
}

/// Das Zeichen der Marke, als Vektor statt als Bild.
///
/// Nicht das PNG aus dem Katalog: Das ist fuer den Startbildschirm des
/// Systems da und hat einen eigenen Grund. Hier soll es frei stehen und
/// mit der Schrift mitwachsen.
///
/// DIE GEOMETRIE STEHT IN `scripts/marke.mjs` und ist hier von Hand
/// nachgezogen, weil Swift keine Javascript-Datei liest. Es sind
/// dieselben Zahlen auf demselben 100er-Raster: der Punkt bei (28, 86),
/// der Weg hoch auf 62, der Break nach (60, 48), dann hoch auf 14.
///
/// Es ist eine Route, kein Baum. Der Punkt ist der Receiver an der
/// Line, der Strich ist ein Post-Corner.
struct RouteTreeZeichen: View {
    var body: some View {
        Canvas { grund, groesse in
            // Vom 100er-Raster auf die tatsaechliche Groesse.
            let s = min(groesse.width, groesse.height) / 100
            let p = { (x: Double, y: Double) in
                CGPoint(x: x * s, y: y * s)
            }

            var weg = Path()
            weg.move(to: p(28, 86))
            weg.addLine(to: p(28, 62))
            weg.addLine(to: p(60, 48))
            weg.addLine(to: p(60, 14))
            grund.stroke(weg, with: .color(Farben.akzent),
                         style: StrokeStyle(lineWidth: 17 * s,
                                            lineCap: .round,
                                            lineJoin: .round))

            let r = 13 * s
            grund.fill(Path(ellipseIn: CGRect(x: 28 * s - r, y: 86 * s - r,
                                              width: r * 2, height: r * 2)),
                       with: .color(Farben.ink))
        }
    }
}
