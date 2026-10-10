// Üben: Diagramm sehen, Namen nennen (B8).
//
// Ein Playbook nützt nichts, das nur der Trainer kennt. Auf dem Feld
// fällt eine Ansage, und wer dann überlegen muss, kommt zu spät an die
// Stelle. Geübt wird deshalb genau das.
//
// BEWUSST OHNE ZEITDRUCK UND OHNE PUNKTESTAND GEGEN ANDERE. Das hier
// sollen Vierzehnjährige freiwillig aufmachen, und ein Ranking hat den
// Nebeneffekt, dass die hinteren aufhören. Dieselbe Entscheidung wie im
// Browser.
//
// DIESE ANSICHT ENTSCHEIDET NICHTS. Was gefragt wird, sagt der Server;
// was ein Fingertipp auslöst, steht in `Uebungsblock`. Hier wird
// gezeichnet und sonst nichts -- deshalb lässt sich der Rest auf einem
// Läufer ohne Bildschirm messen.

import SwiftUI

struct UebenAnsicht: View {
    let playbook: Modell.Playbook

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var block = Uebungsblock()

    // --- Ohne Empfang (R14) ----------------------------------------------
    //
    // Der Übungsmodus sieht am Platz aus wie am Schreibtisch, und das
    // ist Absicht: Niemand soll einen zweiten Übungsmodus lernen. Der
    // Unterschied steht in EINER Leiste darüber.

    /// Das vorausberechnete Paket, sobald ohne Netz geübt wird.
    @State private var paket: Modell.Uebungspaket?
    /// Die Frage aus dem Paket, die gerade dasteht.
    @State private var ausPaket: Modell.Paketfrage?
    /// Wie viele Antworten auf Netz warten. `0` blendet die Leiste aus.
    @State private var wartend = 0

    var body: some View {
        ZStack {
            Farben.flaeche.ignoresSafeArea()
            inhalt
        }
        .navigationTitle("Üben")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Nur beim ersten Mal. Ein zweiter Anlauf beim Zurückkehren
            // verwürfe die offene Frage -- und die Antwort, die dann
            // käme, zählte nicht mehr.
            if case .laedt = block.zustand { await naechsteFrage() }
        }
    }

    @ViewBuilder private var inhalt: some View {
        switch block.zustand {
        case .laedt:
            ProgressView().tint(Farben.akzent)

        case .fehler(let text):
            Hinweis(zeichen: "exclamationmark.triangle",
                    titel: String(localized: "Das hat nicht geklappt"),
                    text: text) {
                Button("Nochmal versuchen") { Task { await naechsteFrage() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
            }

        case .zuWenige(let noetig, let hat):
            // Kein Fehler, sondern eine Auskunft: Mit zwei Plays wäre
            // jede Frage geraten. Derselbe Satz wie im Browser.
            Hinweis(zeichen: "questionmark.square.dashed",
                    titel: String(localized: "Zum Üben fehlen noch Plays"),
                    // Zwei ganze Sätze statt eines Rumpfes mit angehängtem
                    // „s" (R22): Die Einzahl steckt in mehr Sprachen im
                    // Verb als in der Endung.
                    text: (hat == 1
                           ? String(localized:
                                "Mit 1 Play wäre jede Frage geraten.")
                           : String(localized:
                                "Mit \(hat) Plays wäre jede Frage geraten."))
                        + " "
                        + String(localized: "Ab \(noetig) Plays geht es los."))

        case .frage(let runde):
            frageAnsicht(runde)
        }
    }

    private func frageAnsicht(_ runde: Modell.Uebungsstand.Runde) -> some View {
        VStack(spacing: 0) {
            kopf(runde)
            // Nativ gezeichnet, mit derselben Projektion wie der Editor.
            // Kein Webview: Was der Browser als SVG ausgibt, entsteht
            // hier mit `Canvas` aus denselben Yards.
            // Und über die ganze Fläche, ohne schwarze Balken: Geübt
            // wird am Platz, oft in der Sonne, und je größer das Feld
            // ist, desto eher erkennt man den Play.
            GeometryReader { rahmen in
                Feldansicht(
                    zeichnung: runde.frage.zeichnung,
                    // Erst passend, dann gedehnt (R48): Beim Üben
                    // wird der Play ERKANNT -- ein abgeschnittener Weg
                    // macht aus der Frage eine andere.
                    projektion: Projektion.fuerDieApp(
                        feld: runde.frage.feld, los: runde.frage.los,
                        richtung: runde.frage.richtung,
                        spielform: runde.frage.spielform)
                        .passendFuer(runde.frage.zeichnung)
                        // Beim Üben wird der Play ERKANNT. Auf einem
                        // Elferfeld sind elf gleich grosse Punkte
                        // keine Frage, sondern ein Ratespiel.
                        .querPassendFuer(runde.frage.zeichnung)
                        .gedehnt(auf: rahmen.size))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            antwortknoepfe(runde)
        }
    }

    /// **Die eine Leiste, die den Unterschied ausmacht (R14).**
    ///
    /// Der Übungsmodus sieht am Platz aus wie am Schreibtisch. Was
    /// jemand aber wissen MUSS: Seine Antworten sind noch nirgends
    /// angekommen. Ohne diesen Satz sähe es aus, als wäre das Üben
    /// folgenlos gewesen -- und niemand übt gern ins Leere.
    ///
    /// Dazu, wie weit er im Paket ist. Der Fortschritt darüber zählt
    /// den LERNSTAND und bewegt sich ohne Netz nicht; diese Zahl
    /// bewegt sich.
    @ViewBuilder
    private var wartendleiste: some View {
        if wartend > 0 {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(Farben.inkStill)
                VStack(alignment: .leading, spacing: 2) {
                    Text(wartendsatz)
                    if let paket {
                        let stand = Paketblock.stand(
                            paket,
                            beantwortet: Uebungsvorrat.offeneAntworten(
                                playbook: playbook.id))
                        Text("Frage \(stand.fertig) von \(stand.gesamt)")
                            .font(.caption)
                    }
                }
                .foregroundStyle(Farben.inkStill)
                Spacer()
            }
            .font(.footnote)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    /// Ein GANZER Satz je Fall, kein eingesetztes Wort.
    ///
    /// „1 Antworten" wäre der Fehler, den man auf jedem zweiten
    /// Bildschirm sieht -- und in anderen Sprachen steht die Mehrzahl
    /// ohnehin woanders.
    private var wartendsatz: String {
        wartend == 1
            ? String(localized: "Eine Antwort wartet auf Netz.")
            : String(localized: "\(wartend) Antworten warten auf Netz.")
    }

    private func kopf(_ runde: Modell.Uebungsstand.Runde) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            wartendleiste
            Text("Welcher Play ist das?")
                .accessibilityIdentifier("uebenfrage")
                .font(.headline)
                .foregroundStyle(Farben.ink)
            Text("""
                \(runde.serieFuerSitzt)× richtig hintereinander, dann sitzt \
                er
                """)
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)

            balken(runde.fortschritt)

            if runde.frage.aufgabe {
                // Die Marke am Play, nicht die Lösung: Sie sagt, DASS
                // die Aufgabe drankommt, nicht welcher Play es ist.
                Marke(text: String(localized: "Deine Aufgabe"))
            }
            if let meldung = block.meldung {
                Text(meldung.text)
                    .font(.subheadline)
                    .foregroundStyle(meldung.richtig ? Farben.akzent
                                                     : Farben.fehler)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Farben.flaechePanel)
    }

    private func balken(_ fortschritt: Modell.Fortschritt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Derselbe Balken wie im Lernstand. Zwei Balken über
            // dieselbe Zahl sähen irgendwann verschieden aus.
            Balken(anteil: fortschritt.anteil)
            Text(fortschrittstext(fortschritt))
                .font(.caption)
                .foregroundStyle(Farben.inkStill)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("""
            \(fortschritt.sitzen) von \(fortschritt.gesamt) Plays sitzen
            """)
    }

    /// Derselbe Satz wie im Browser, in derselben Reihenfolge.
    private func fortschrittstext(_ f: Modell.Fortschritt) -> String {
        var text = String(localized: "\(f.sitzen) von \(f.gesamt) sitzen")
        if f.ausAuftrag { text += String(localized: " · aus deiner Aufgabe") }
        if f.angefangen > 0 {
            text += String(localized: " · \(f.angefangen) angefangen")
        }
        if f.offen > 0 {
            text += String(localized: " · \(f.offen) noch nie gesehen")
        }
        return text
    }

    private func antwortknoepfe(_ runde: Modell.Uebungsstand.Runde) -> some View {
        VStack(spacing: 8) {
            // IN DIESER REIHENFOLGE. Der Server hat gemischt; wer hier
            // sortiert, stellt die richtige Antwort irgendwann an eine
            // berechenbare Stelle.
            ForEach(runde.auswahl) { kandidat in
                Button {
                    Task { await antworten(kandidat.id) }
                } label: {
                    Text(kandidat.name)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(Farben.akzent)
                .disabled(!block.darfAntworten)
                // Der angetippte Knopf zeigt, dass etwas passiert. Ohne
                // das wirkt die App auf einem langsamen Netz kaputt --
                // und genau dann tippt jemand ein zweites Mal.
                .overlay(alignment: .trailing) {
                    if block.unterwegs == kandidat.id {
                        ProgressView()
                            .tint(Farben.inkStill)
                            .padding(.trailing, 12)
                    }
                }
            }
        }
        .padding(16)
        .background(Farben.flaechePanel)
    }

    // MARK: - Netz

    private func naechsteFrage() async {
        let laden = Laden(anmeldung: anmeldung)

        // ERST NACHTRAGEN, WAS WARTET. Wer wieder Netz hat, soll seine
        // Antworten loswerden, bevor irgendetwas anderes passiert --
        // sonst übt er weiter und die Schlange wächst.
        //
        // Scheitert es, ist das kein Grund, das Üben abzubrechen: Die
        // Antworten bleiben liegen und gehen beim nächsten Mal.
        _ = try? await laden.uebungNachtragen(playbook: playbook.id)

        // VORSORGLICH NACHFÜLLEN, solange Netz da ist. Wer erst am
        // Platz merkt, dass das Paket leer ist, hat nichts davon.
        await paketPflegen(laden)

        do {
            block.uebernimm(
                try await laden.uebungsfrage(playbook: playbook.id))
            ausPaket = nil
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            // OHNE NETZ AUS DEM PAKET. Jeder andere Fehler bleibt ein
            // Fehler -- dieselbe enge Grenze wie im Vorrat: Eine 401
            // heisst, dass die Anmeldung nicht mehr gilt, eine 500,
            // dass etwas kaputt ist. Wer die hinter einem Paket
            // versteckt, merkt sie nie.
            if Vorratsblock.ausDemVorrat(bei: error), ausPaketZeigen() {
                return
            }
            block.fehlgeschlagen(text(zu: error))
        }
        wartendZaehlen()
    }

    /// Das Paket holen oder nachfüllen -- nur wenn es sich lohnt.
    private func paketPflegen(_ laden: Laden) async {
        let vorhanden = Uebungsvorrat.paket(playbook: playbook.id)
        let offen = Uebungsvorrat.offeneAntworten(playbook: playbook.id)
        guard Paketblock.brauchtNachschub(vorhanden, beantwortet: offen)
        else {
            paket = vorhanden
            return
        }
        // Scheitert es, ist nichts verloren: Dann gilt weiter, was
        // schon da liegt.
        paket = (try? await laden.uebungspaketHolen(playbook: playbook.id))
            ?? vorhanden
    }

    /// Die nächste offene Frage aus dem Paket zeigen. `false`, wenn
    /// keine mehr da ist.
    private func ausPaketZeigen() -> Bool {
        let vorrat = paket ?? Uebungsvorrat.paket(playbook: playbook.id)
        guard let vorrat else { return false }
        paket = vorrat
        let offen = Uebungsvorrat.offeneAntworten(playbook: playbook.id)
        wartend = Paketblock.wartend(offen)
        guard let frage = Paketblock.naechste(vorrat, beantwortet: offen)
        else {
            block.paketLeer(String(localized: """
                Die vorbereiteten Fragen sind durch. Sobald du wieder Netz \
                hast, kommen neue.
                """))
            return true
        }
        ausPaket = frage
        block.uebernimm(frage, fortschritt: frage.fortschritt)
        return true
    }

    private func antworten(_ id: Int) async {
        // Der Block entscheidet, ob überhaupt geschickt wird -- ein
        // zweiter Fingertipp darf nicht zweimal zählen.
        guard block.antworten(id) else { return }

        // AM PLATZ: örtlich verbuchen, sofort bewerten, weiter.
        if let frage = ausPaket {
            Uebungsvorrat.antwortMerken(
                Modell.OffeneAntwort(marke: frage.marke, gewaehlt: id,
                                     wann: Date()),
                playbook: playbook.id)
            block.meldeAusPaket(frage, gewaehlt: id)
            let weiter = block.meldung
            _ = ausPaketZeigen()
            // Die Meldung gehört zur VORIGEN Frage und muss die neue
            // überleben -- `uebernimm` setzt sie sonst zurück.
            if let weiter { block.meldungSetzen(weiter) }
            return
        }

        do {
            let runde = try await Laden(anmeldung: anmeldung)
                .uebungAntwort(playbook: playbook.id, antwort: id)
            // EIN PLAY, DAS JETZT SITZT, IST DER ERFOLG -- nicht eine
            // richtige Antwort. Wer dreimal richtig raet, hat nichts
            // gelernt; wer einen Play durchbekommt, schon. Gezaehlt
            // wird deshalb am Fortschritt und nicht am Ergebnis (R154).
            let vorher = sitzenJetzt
            block.uebernimm(runde)
            if let nun = sitzenJetzt, let alt = vorher, nun > alt {
                Bewertungsfrage.merken(.geuebt)
            }
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            if Vorratsblock.ausDemVorrat(bei: error), ausPaketZeigen() {
                return
            }
            block.fehlgeschlagen(text(zu: error))
        }
    }

    /// Wie viele Plays gerade sitzen -- `nil`, wenn keine Frage laeuft.
    private var sitzenJetzt: Int? {
        if case let .frage(runde) = block.zustand {
            return runde.fortschritt.sitzen
        }
        return nil
    }

    private func wartendZaehlen() {
        wartend = Paketblock.wartend(
            Uebungsvorrat.offeneAntworten(playbook: playbook.id))
    }

    private func text(zu fehler: Error) -> String {
        Fehlertext.von(fehler)
    }
}

/// Eine kleine Marke, wie „Deine Aufgabe" im Browser.
struct Marke: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            // Dieselbe Paarung wie `.aufgabenmarke` im Browser. Bis B13
            // stand hier das dunkle Petrol des LOGOS mit heller Schrift
            // darauf. Mit dem Petrol der Oberfläche -- und das ist ein
            // helles -- wäre daraus Hell auf Hell geworden: 1,9 zu 1.
            .paarung(Paare.aufgabenmarke, in: Capsule())
    }
}
