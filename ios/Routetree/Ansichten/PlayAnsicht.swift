import SwiftUI

/// Ein Play, gezeichnet.
///
/// **EIN ZEICHNER, NICHT ZWEI.** Bis zum 01.09.2026 hat diese Ansicht ein
/// fertiges SVG vom Server gezeigt (`/api/v1/plays/<id>/?svg=1`), der
/// Editor daneben hat nativ gezeichnet. Zwei Zeichner fuer dieselbe
/// Zeichnung laufen auseinander, und sie sind auseinandergelaufen:
///
/// > „bei mir im editor die eine route drauf aber in der ansicht davor
/// > ist es nicht drauf das ist auch ganz komisch" -- „ja und bei weissen
/// > svg ist die ganze linke route geht ausserhalb des feldes obwohl es
/// > in dem editor nicht so ist" -- „Ich glaub es fehlt allgemein super
/// > viel das es in der app 1:1 dasselbe ist wie im web"
///
/// Dazu kam das Sichtbare: Das Server-SVG ist fuer PAPIER gemacht, also
/// weiss. In einer dunklen App leuchtet es wie ein Fremdkoerper.
///
/// Seitdem zeichnet hier dieselbe `Feldansicht` mit derselben
/// `Projektion` wie im Editor. Die beiden KOENNEN nicht mehr
/// verschiedene Bilder zeigen -- nicht weil jemand aufpasst, sondern
/// weil es nur noch eine Stelle gibt, an der gezeichnet wird.
///
/// Das SVG kommt weiter mit (`voll.svg`), fuer den Druck und fuer das
/// Web. Hier wird es nicht mehr gebraucht: Die Zeichnung selbst liegt in
/// derselben Antwort, und die liegt seit R14 auch auf dem Geraet.
///
/// WARUM DAS KEIN WIDERSPRUCH ZU ADR-0002 IST: Dort ist eine WebView
/// verworfen worden. Genau die ist hier jetzt weg.
///
/// **UND MAN KANN DURCHBLÄTTERN.** Niklas am 01.09.2026: „man sollte auch
/// bevor man auf bearbeiten geht die ansicht auf das play denn
/// durchscrollen können weißt du?" Am Spielfeldrand geht es selten um
/// einen einzigen Play; man sucht den, der jetzt passt. Wer dafuer jedes
/// Mal zurueck in die Liste muss, macht es nicht.
///
/// Geblaettert wird durch GENAU DIE Liste, die vorher zu sehen war --
/// mit Suche und Kategoriefilter, so wie sie dasteht. Eine eigene
/// Reihenfolge waere eine zweite Wahrheit.
struct PlayAnsicht: View {
    let play: Modell.PlayKurz
    /// Die Liste, aus der er aufgemacht wurde. Leer heisst: nur dieser.
    var nachbarn: [Modell.PlayKurz] = []

    @EnvironmentObject private var anmeldung: Anmeldung
    /// Welcher Play gerade oben liegt. Gehalten als Kennung und nicht als
    /// Wert: Beim Umbenennen aendert sich der Wert, die Kennung nicht.
    @State private var gewaehlt: Int
    /// Was schon geladen ist, je Play. Ein gemeinsamer Vorrat statt einer
    /// Ladung je Blatt: Wer vor- und zurueckblaettert, soll nicht jedes
    /// Mal wieder auf den Server warten.
    @State private var geladen: [Int: Modell.PlayVoll] = [:]
    /// Wann die Zeichnung entstanden ist, wenn sie vom GERÄT kommt (R14).
    @State private var staende: [Int: Date] = [:]
    @State private var fehler: [Int: String] = [:]
    /// Der Spielzug, der gerade gemeldet wird -- `nil`, solange keiner
    /// gemeldet wird. Als Wert und nicht als Wahrheitswert: Das Blatt
    /// nennt den Namen, und nach dem Weiterblättern wäre „der aktuelle"
    /// ein anderer als der, auf den getippt wurde.
    @State private var meldet: Modell.PlayKurz?

    init(play: Modell.PlayKurz, nachbarn: [Modell.PlayKurz] = []) {
        self.play = play
        self.nachbarn = nachbarn
        _gewaehlt = State(initialValue: play.id)
    }

    /// Die Blaetter, durch die geblaettert wird.
    ///
    /// Steht der aufgemachte Play nicht in der mitgegebenen Liste (etwa
    /// weil sie sich inzwischen geaendert hat), bleibt es bei ihm allein.
    /// Ein Blaettern, das den gezeigten Play nicht enthaelt, waere eine
    /// Ansicht, die sofort woandershin springt.
    private var seiten: [Modell.PlayKurz] {
        nachbarn.contains(where: { $0.id == play.id }) ? nachbarn : [play]
    }

    private var oben: Modell.PlayKurz {
        seiten.first(where: { $0.id == gewaehlt }) ?? play
    }

    var body: some View {
        TabView(selection: $gewaehlt) {
            ForEach(seiten, id: \.id) { seite in
                blatt(seite).tag(seite.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: seiten.count > 1
                            ? .automatic : .never))
        .background(Farben.flaeche.ignoresSafeArea())
        .navigationTitle(oben.titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Das Blatt und das Bild dieses einen Plays (B10) -- im
            // Browser sind das „Als PDF" und „Als Bild" im Editor. Fuer
            // jeden, der den Play sehen darf: Ein Spieler, der sich sein
            // Blatt selbst ausdruckt, nimmt dem Trainer Arbeit ab.
            //
            // Erst wenn der Play geladen ist. Vorher waere sein Heft
            // unbekannt, und der Hinweis auf den Streifen der Demo
            // fehlte ausgerechnet beim ersten Ausdruck.
            if let voll = geladen[gewaehlt] {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Drucken(kennung: voll.id,
                                                  heft: voll.playbook,
                                                  titel: oben.titel)) {
                        Label("Drucken", systemImage: "printer")
                    }
                }
            }
            // Der Knopf steht nur da, wenn der SERVER es sagt. Ein Knopf,
            // der beim Druecken 403 bekommt, ist ein toter Knopf
            // (ADR-0007) -- und ein Zuschauer soll gar nicht erst
            // ausprobieren, ob er darf.
            if geladen[gewaehlt]?.darfAendern == true {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Bearbeiten(play: oben)) {
                        Bearbeitenzeichen()
                    }
                }
            }
            // MELDEN (Apple-Richtlinie 1.2). Steht bewusst NICHT hinter
            // `darfAendern`: Wer einen Spielzug nur ansehen darf -- ein
            // Zuschauer, ein Spieler -- ist genau der, dem etwas
            // auffällt und der nichts dagegen tun kann. Ein Meldeweg,
            // den nur der Coach sieht, wäre keiner.
            //
            // In einem Menü und nicht als eigener Knopf: Die Leiste
            // trägt schon Drucken und Bearbeiten, und „Melden" ist
            // nichts, was man beim Blättern aus Versehen treffen soll.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        meldet = oben
                    } label: {
                        Label("Melden", systemImage: "flag")
                    }
                } label: {
                    Label("Mehr", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("playmenue")
            }
        }
        .sheet(item: $meldet) { welcher in
            MeldeBlatt(play: welcher) { meldet = nil }
                .environmentObject(anmeldung)
        }
        .navigationDestination(for: Bearbeiten.self) { ziel in
            EditorAnsicht(play: ziel.play)
                // ZURÜCK AUS DEM EDITOR HEISST: NEU HOLEN (R98).
                //
                // Die Fassungsnummer in `seite` stammt aus der Liste von
                // vorhin und ist nach dem Bearbeiten alt -- ein
                // Vergleich mit ihr merkt die Änderung also nicht. Was
                // hier liegt, ist von vor der Bearbeitung; es wird
                // weggeworfen und einmal frisch geholt.
                //
                // Nur DIESER Play, nicht die ganze Ansicht: Der Rest
                // des Blätterstapels hat sich nicht geändert, und am
                // Platz ohne Empfang wäre jedes Neuladen ein Ladekreis
                // mehr.
                .onDisappear {
                    geladen[ziel.play.id] = nil
                    Task { await laden(ziel.play) }
                }
        }
        .navigationDestination(for: Drucken.self) { ziel in
            DruckAnsicht(playTitel: ziel.titel, play: ziel.kennung,
                         heft: ziel.heft)
        }
    }

    // MARK: - Ein Blatt

    @ViewBuilder
    private func blatt(_ seite: Modell.PlayKurz) -> some View {
        ZStack {
            Farben.flaeche.ignoresSafeArea()

            if let text = fehler[seite.id] {
                Hinweis(zeichen: "exclamationmark.triangle",
                        titel: String(localized: "Das hat nicht geklappt"),
                        text: text) {
                    Button("Nochmal versuchen") {
                        Task { await laden(seite) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
                }
            } else if let voll = geladen[seite.id] {
                VStack(spacing: 0) {
                    if let stand = staende[seite.id] {
                        Vorratsleiste(stand: stand)
                    }
                    GeometryReader { rahmen in
                        Feldansicht(
                            zeichnung: voll.zeichnung,
                            // ERST PASSEND, DANN GEDEHNT (R48).
                            //
                            // `passendFuer` weitet den Ausschnitt, bis
                            // der ganze Play hineinpasst -- sonst läuft
                            // eine Go-Route über dreissig Yards aus dem
                            // Bild, und das fällt niemandem auf, weil
                            // das Bild an der Kante einfach aufhört.
                            // `gedehnt` füllt danach den Rest des
                            // Bildschirms.
                            //
                            // Andersherum wäre es falsch: Was `gedehnt`
                            // dazugegeben hat, würde von `passendFuer`
                            // nicht mehr angesehen, und ein langer Weg
                            // bliebe abgeschnitten.
                            projektion: Projektion.fuerDieApp(
                                feld: voll.feld, los: voll.los,
                                richtung: voll.richtung,
                                spielform: voll.spielform)
                                .passendFuer(voll.zeichnung)
                                // QUER NUR SO BREIT WIE NÖTIG (T9,
                                // in der App seit 08.09.2026). Auf
                                // 53,33 Yards war eine Figur vier
                                // Punkte gross und ihr Kürzel drei.
                                .querPassendFuer(voll.zeichnung)
                                .gedehnt(auf: rahmen.size))
                    }
                    if let hinweise = voll.hinweise, !hinweise.isEmpty {
                        ScrollView {
                            Text(hinweise)
                                .font(.callout)
                                .foregroundStyle(Farben.inkStill)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        }
                        .frame(maxHeight: 140)
                        .background(Farben.flaechePanel)
                    }
                }
            } else {
                ProgressView().tint(Farben.akzent)
            }
        }
        // MIT DER FASSUNG ALS KENNUNG (R98): So läuft die Aufgabe noch
        // einmal, sobald der Play eine neue hat.
        .task(id: seite.version) { await laden(seite) }
    }

    /// Der Weg zur Druckseite dieses Plays. Eigener Typ aus demselben
    /// Grund wie `Bearbeiten` darunter.
    private struct Drucken: Hashable {
        let kennung: Int
        let heft: Int?
        let titel: String
    }

    /// Eigener Typ statt `Modell.PlayKurz`: Die Liste benutzt denselben
    /// Wert schon fuer das ANSEHEN. Zweimal derselbe Typ im selben
    /// Navigationsstapel heisst, dass der Editor die Ansicht ersetzt --
    /// und der Zurueck-Knopf dann nicht mehr dahin fuehrt, wo man
    /// hergekommen ist.
    private struct Bearbeiten: Hashable {
        let play: Modell.PlayKurz
    }

    private func laden(_ seite: Modell.PlayKurz) async {
        // Was schon dasteht, wird nicht noch einmal geholt. Sonst laedt
        // jedes Zurueckblaettern neu, und am Platz ohne Empfang blitzt
        // dabei jedes Mal der Ladekreis auf.
        //
        // GEGEN DIE FASSUNG (R98). Niklas am 09.09.2026: „Hab das Play
        // gerade im Editor bearbeitet und die Änderungen sind nicht
        // sofort zu sehen wenn ich zurück gehe." Hier stand `== nil`,
        // dieselbe Stelle wie in der Vorschauliste (R96) -- nur eine
        // Ansicht weiter. Wer aus dem Editor zurückkommt, sah seine
        // eigene Änderung nicht und musste sie für verloren halten.
        guard geladen[seite.id]?.version != seite.version else { return }
        fehler[seite.id] = nil
        do {
            // Die Fassung aus der Liste geht als Marke mit: Damit
            // erkennt der Vorrat beim nächsten Mal, ob seine Kopie noch
            // die richtige ist -- genau, statt nach dem Alter geschätzt
            // (R14).
            let ausgabe = try await Laden(anmeldung: anmeldung)
                .playMitVorrat(seite.id, version: seite.version)
            geladen[seite.id] = ausgabe.wert
            staende[seite.id] = ausgabe.stand
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            fehler[seite.id] = Fehlertext.von(error)
        }
    }
}
