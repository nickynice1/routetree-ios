// Eine Aufstellung bauen, ohne einen Play dafür anzulegen (R46).
//
// Niklas: „Formationen Builder wäre auch sehr cool."
//
// WAS ES VORHER GAB. Gespeicherte Aufstellungen (B7) und die acht
// Vorlagen des Browsers. Beides setzt aber einen Play voraus: Man legte
// einen an, schob die Figuren zurecht, sicherte die Aufstellung unter
// einem Namen und hatte danach einen Play zu viel im Heft. Wer nur eine
// Formation festhalten wollte, musste sie über einen Umweg bauen und
// den Umweg hinterher wegräumen.
//
// WAS EINE FORMATION IST UND WAS NICHT. Sie ist die Aufstellung, ohne
// Linien. Deshalb gibt es hier keine Zeichenwerkzeuge: Der Block bleibt
// im Auswahlmodus, und was jemand laufen soll, entscheidet er im Play.
// Dieselbe Trennung wie auf dem Server -- `Formation.data` kennt nur
// `players`.
//
// WARUM DER FINGER NICHT NOCH EINMAL GESCHRIEBEN IST. `Zeichenfeld`
// wurde für genau diesen Zweck aus dem Editor herausgezogen: dieselbe
// Fangregel, dieselbe Seitenregel, derselbe Griffvorrang. Zwei
// Fassungen davon wären zwei Antworten auf die Frage, ob eine Figur
// über die Line of Scrimmage darf.

import SwiftUI

struct Formationsbauer: View {
    let playbook: Int
    let feld: Feld
    /// Was hier gespielt wird. Ohne die Angabe zeichnet der Bauer in
    /// Flaggroesse, und elf Figuren auf einem Elfer-Feld kleben
    /// ineinander.
    let spielform: String
    /// Womit angefangen wird. Beim Bauen aus dem Nichts ist das die
    /// Startaufstellung; wer eine vorhandene ändern will, bekommt
    /// deren Figuren.
    let start: [Zeichnung.Spieler]
    /// Der Name, unter dem gesichert wird. Leer beim Neubauen.
    let startname: String
    let fertig: (String?) -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var block: Zeichenblock
    @State private var flaeche: CGSize = .zero
    @State private var name: String
    @State private var sichert = false
    @State private var fehler: String?

    init(playbook: Int, feld: Feld, start: [Zeichnung.Spieler],
         spielform: String = Spielform.standard,
         startname: String = "", fertig: @escaping (String?) -> Void) {
        self.playbook = playbook
        self.feld = feld
        self.spielform = spielform
        self.start = start
        self.startname = startname
        self.fertig = fertig
        var zeichnung = Zeichnung()
        zeichnung.spieler = start
        // MIT DER MITTE ALS LINE OF SCRIMMAGE. Eine Formation hat keine
        // eigene LOS -- sie wird auf jeden Play angewandt, wo immer der
        // steht. Die Mitte ist die Lage, in der beide Seiten gleich viel
        // Platz haben.
        _block = State(initialValue: Zeichenblock(
            zeichnung: zeichnung,
            projektion: Projektion.fuerDieApp(feld: feld, los: feld.mitte,
                                              richtung: 1,
                                              spielform: spielform)))
        _name = State(initialValue: startname)
    }

    private var bereit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !block.zeichnung.spieler.isEmpty && !sichert
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                VStack(spacing: 0) {
                    Zeichenfeld(block: $block, flaeche: $flaeche,
                                darfZeichnen: true,
                                // Ohne Linien gibt es keine Namen zu
                                // zeigen. Der Schalter wäre einer, der
                                // nichts tut (ADR-0007).
                                zeigeNamen: false)
                    leiste
                }
            }
            .navigationTitle(startname.isEmpty
                             ? String(localized: "Aufstellung bauen")
                             : String(localized: "Aufstellung ändern"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        fertig(nil)
                    } label: {
                        // Ein X statt „Ab…" (R57).
                        Label("Abbrechen", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Fertigknopf(name: String(localized: "Sichern")) {
                        Task { await sichern() }
                    }
                        .disabled(!bereit)
                }
            }
        }
    }

    /// Der Streifen unter dem Feld: rückgängig, spiegeln, Name.
    ///
    /// **Kein Werkzeugkasten.** Eine Formation hat keine Linien, also
    /// gibt es nichts zu zeichnen. Was bleibt, sind die Handgriffe am
    /// Bild -- und der Name, ohne den nichts gesichert wird.
    private var leiste: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                knopf("arrow.uturn.backward",
                      name: String(localized: "Rückgängig"),
                      an: block.kannRueckgaengig) { block.rueckgaengig() }
                knopf("arrow.uturn.forward",
                      name: String(localized: "Wiederholen"),
                      an: block.kannWiederherstellen) {
                    block.wiederherstellen()
                }
                knopf("arrow.left.and.right",
                      name: String(localized: "Spiegeln"), an: true) {
                    block.spiegeln()
                }
                Spacer(minLength: 0)
                Text(block.fang
                     ? String(localized: "Raster: halbe Yards")
                     : String(localized: "Fang aus"))
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
            }

            TextField("Name der Aufstellung", text: $name)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .paarung(Paare.knopf, ecke: Masse.r1)

            // DER LEERZUSTAND NENNT DEN HANDGRIFF (B14). Hier gibt es
            // nur einen, und ohne ihn sähe das Feld aus wie ein Bild.
            Text(hinweistext)
                .font(.footnote)
                .foregroundStyle(fehler == nil ? Farben.inkStill
                                               : Farben.fehler)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Farben.flaechePanel)
    }

    private var hinweistext: String {
        if let fehler { return fehler }
        return String(localized: "Figuren anfassen und schieben. Ein Name, dann sichern.")
    }

    private func knopf(_ zeichen: String, name: String, an: Bool,
                       tun: @escaping () -> Void) -> some View {
        Button(action: tun) {
            Image(systemName: zeichen)
                .font(.body)
                .frame(width: 40, height: 34)
                .background(Farben.linie,
                            in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(an ? Farben.ink
                                    : Farben.inkStill.opacity(0.5))
        }
        .buttonStyle(.plain)
        .disabled(!an)
        .accessibilityLabel(name)
    }

    private func sichern() async {
        let sauber = name.trimmingCharacters(in: .whitespaces)
        guard !sauber.isEmpty else { return }
        sichert = true
        fehler = nil
        defer { sichert = false }
        do {
            let ergebnis = try await Laden(anmeldung: anmeldung)
                .formationSichern(playbook: playbook, name: sauber,
                                  aufstellung: block.zeichnung.spieler)
            // ERSETZT ODER NEU -- das sind zwei Nachrichten. Der
            // Server sagt, welche gilt; ein einheitliches „Gesichert"
            // liesse jemanden im Glauben, er habe eine zweite
            // Aufstellung, wo er die alte überschrieben hat.
            //
            // Dieselben zwei Sätze wie im `Formationsblatt`, und zwar
            // absichtlich wörtlich dieselben: Es ist derselbe Vorgang,
            // und derselbe Vorgang soll nicht je nach Bildschirm
            // anders klingen.
            fertig(ergebnis.ersetzt
                   ? String(localized: """
                       „\(ergebnis.name)“ ersetzt, jetzt mit \
                       \(ergebnis.anzahl) Spielern.
                       """)
                   : String(localized:
                       "Aufstellung „\(ergebnis.name)“ gesichert."))
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}
