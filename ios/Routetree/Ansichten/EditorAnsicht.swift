// Der Editor: Aufstellung ziehen (Stufe 1) und Linien zeichnen (Stufe 2).
//
// Das ist die Antwort auf die Frage, mit der Strecke B angefangen hat:
// „kann ich in der app keine play designen?????" Ab hier ja -- die
// Aufstellung UND die Notation: Route, Motion, Abschirmen, Ballabgabe,
// Passweg, Zone, jede mit ihrem Ende.
//
// KEIN WEBVIEW. Gezeichnet wird mit `Feldansicht`, gerechnet mit
// `Projektion`, entschieden in `Zeichenblock`, gespeichert über
// `Playspeicher`. Alles in Yards, alles dieselben Zahlen wie im Browser
// und im Ausdruck.
//
// Dazu Stufe 3: Rückgängig, Wiederholen, Spiegeln, Abspielen.
//
// WAS HIER ABSICHTLICH NICHT STEHT: das TIMING einer Linie (`delay`,
// `speed`) lässt sich in der App noch nicht einstellen. Es geht beim
// Speichern NICHT verloren, `Zeichnung.swift` trägt es durch, und der
// Ablauf rechnet damit -- eine Verzögerung aus dem Browser wirkt sich
// hier also aus, nur ändern kann man sie noch nicht.
//
// DIE BESCHRIFTUNG STAND BIS ZUM 27.08.2026 AUCH IN DIESEM SATZ, und
// das war seit B4 falsch: `linienleiste` hat ein Feld dafür, und
// `Zeichenblock.beschriftungSetzen` schreibt es. Ein Kommentar, der ein
// Fehlen behauptet, das es nicht mehr gibt, ist teurer als gar keiner:
// Er lässt jemanden bauen, was schon da ist. Gefunden beim Abarbeiten
// von Runde 4, wo „Routennamen änderbar machen" auf der Liste stand. Das GIF vom Ablauf fehlt ebenfalls; es entsteht auf dem Server
// und gehört zu B10, wo Teilen und Drucken drankommen.
//
// DIE BEDIENUNG, und warum sie so ist:
//
//   Werkzeug wählen, auf einen Spieler tippen, weitertippen, „Fertig".
//
// Ein Finger ist kein Mauszeiger. Im Browser sieht man am Zeiger, wohin
// der Fang den nächsten Punkt legt; hier zeigt die Vorschau es erst,
// während der Finger aufliegt und noch verschoben werden kann. Deshalb
// zählt der Punkt beim LOSLASSEN und nicht beim Aufsetzen.

import SwiftUI

struct EditorAnsicht: View {

    let play: Modell.PlayKurz

    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen
    /// Wer weniger Bewegung eingestellt hat, bekommt den Ablauf
    /// angehalten und spult von Hand. Die Einstellung wird respektiert,
    /// ohne die Funktion wegzunehmen -- genau wie im Browser.
    @Environment(\.accessibilityReduceMotion) private var wenigerBewegung
    /// Wie viel HÖHE da ist (R49). `.compact` heißt: Telefon im
    /// Querformat -- und dort gehören die Leisten an die Seite.
    @Environment(\.verticalSizeClass) private var hoehenklasse

    /// Zeichnung, Werkzeug, Entwurf und Auswahl -- alles an einer Stelle,
    /// und alles gemessen in `ZeichenblockTests`.
    @State private var block = Zeichenblock(
        zeichnung: Zeichnung(),
        projektion: Projektion.fuerDieApp(feld: Feld.afvd,
                                          los: Feld.afvd.mitte,
                                          richtung: 1))
    /// Routennamen an den Linien (R25).
    ///
    /// `@AppStorage` und nicht `@State`: Es ist eine Gewohnheit des
    /// Menschen und keine Eigenschaft des Plays -- genau wie der Fang
    /// im Browser, und dort liegt er aus demselben Grund im Gerät.
    /// Stünde der Schalter in der Zeichnung, sähe die halbe Mannschaft
    /// etwas anderes als die andere, je nachdem wer zuletzt
    /// gespeichert hat.
    @AppStorage("rt-namen") private var zeigeNamen = true

    @State private var version = 0

    /// Wie groß die Zeichenfläche zuletzt war.
    ///
    /// Gebraucht, weil ein NEUER Block den Bildschirm nicht kennt: Nach
    /// dem Laden ändert sich die Größe nicht mehr, `onChange` meldet sich
    /// also nicht -- und das Feld säße wieder klein in der Mitte statt an
    /// den Rändern (R34).
    @State private var flaeche: CGSize = .zero

    @State private var laedt = true
    @State private var fehler: String?
    @State private var sichert = false
    @State private var konflikt: Modell.PlayVoll?
    /// Steht die Rückfrage „ungesichert zurück?" gerade an? Siehe
    /// `zurueck()`.
    @State private var fragtBeimVerlassen = false

    /// Das Heft dieses Plays und ob hier geändert werden darf -- beides
    /// sagt der Server beim Laden (B7). Die gespeicherten Aufstellungen
    /// hängen am Heft, nicht am Play.
    @State private var playbookId: Int?
    @State private var darfAendern = false
    /// Ob das Meldeblatt offen ist. Als Wahrheitswert und nicht als
    /// Wert: Der Editor zeigt genau EINEN Spielzug, es kann kein
    /// anderer gemeint sein.
    @State private var meldet = false
    /// Was am zuletzt geladenen oder gesicherten Stand dem Regelwerk
    /// widerspricht. Vom Server gerechnet, nicht in Swift nachgebaut.
    @State private var anmerkungen: [Modell.Anmerkung] = []
    @State private var zeigtFormationen = false

    // --- Die Angaben am Play (B7, R41) ---------------------------------
    //
    // ZWEI STÄNDE UND NICHT EINER. `angaben` ist, was auf dem Blatt
    // steht; `angabenGesichert` ist, was zuletzt beim Server ankam. Der
    // Unterschied zwischen beiden ist gleichzeitig die Antwort auf drei
    // Fragen: Was muss mitgeschickt werden, ist der Sichern-Knopf an,
    // und muss beim Zurückgehen gefragt werden.
    //
    // Ein einzelner Stand mit einem `geaendert`-Schalter daneben täte es
    // scheinbar auch -- bis ein Trainer den Namen ändert und wieder
    // zurücktippt. Dann stünde der Schalter auf „geändert", und die App
    // fragte beim Verlassen nach etwas, das es nicht gibt.
    // SEIT R110.7 LIEGT DER ARBEITSSTAND IM BLOCK. Hier stand
    // `@State private var angaben`; der Verlauf liegt aber im Block,
    // und ein Rückgängig, das die Zeichnung zurücknimmt und die
    // Umbenennung stehen lässt, ist das halbe Rückgängig, gegen das
    // `Verlauf.swift` seit dem ersten Tag anschreibt.
    //
    // `angabenGesichert` bleibt hier: Das ist kein Arbeitsstand,
    // sondern die Marke „so weit war der Server" -- dieselbe Sorte
    // Wissen wie `version`, und die gehört der Ansicht.
    @State private var angabenGesichert = Playangaben.Stand()
    /// Der Stand der Angaben, als das Blatt aufging (R110.7). `nil`
    /// heisst: Es ist gerade zu.
    @State private var angabenBeimOeffnen: Playangabenstand?
    /// Ein ungesicherter Stand, der auf dem Geraet lag (R110.4). `nil`
    /// heisst: Es liegt nichts, oder es ist entschieden.
    @State private var offenerEntwurf: Entwurfslager.Entwurf?
    /// Und ob inzwischen jemand anderes gespeichert hat. Dann ist es
    /// ein Konflikt und keine Wiederherstellung.
    @State private var entwurfVeraltet = false
    @State private var zeigtAngaben = false
    /// Ob das Blatt mit Ball und Angriffsrichtung offen ist (R110.3).
    @State private var zeigtLage = false
    /// Die Kategorien des Heftes, für die Auswahl im Blatt. Leer, solange
    /// sie nicht geladen sind -- dann steht der Abschnitt nicht da, und
    /// das ist ehrlicher als eine Auswahl, die noch nichts enthält.
    @State private var kategorien: [Modell.Kategorie] = []

    /// Das Schloss am Play (R6). Cyell, 25.08.2026: „dafür lieber ein
    /// Lock mit einbauen, dass man das play entsperren muss, um zu
    /// bearbeiten."
    ///
    /// Getrennt von `darfAendern` gehalten und nicht damit verrechnet:
    /// Wer nicht ändern darf, sieht keinen Knopf; wer darf und einen
    /// gesperrten Play vor sich hat, sieht „Entsperren". Das sind zwei
    /// verschiedene Antworten, und eine Variable kann nur eine geben.
    @State private var gesperrt = false
    @State private var gesperrtVon: String?
    @State private var sperrtGerade = false

    /// Die EINE Frage, die der Rest der Ansicht stellt -- so wie `DARF`
    /// im Browser. Jeder Handgriff, der die Zeichnung anfasst, hängt
    /// hieran; ein vergessener wäre ein Bedienelement, das an einem
    /// gesperrten Play noch etwas tut.
    private var darfZeichnen: Bool { darfAendern && !gesperrt }

    /// Was oben steht: „#12 Spread Mesh".
    ///
    /// Solange geladen wird, der Titel aus der Liste -- sonst stünde
    /// dort für einen Wimpernschlag nichts, und ein leerer Kopf sieht
    /// aus wie ein Fehler.
    private var titel: String {
        guard !laedt, !block.angaben.name.isEmpty else { return play.titel }
        let nummer = block.angaben.nummer.trimmingCharacters(in: .whitespaces)
        return nummer.isEmpty ? block.angaben.name
                      : "#\(nummer) \(block.angaben.name)"
    }

    /// Der laufende Ablauf, `nil` heißt: kein Abspielen.
    /// Welches Textfeld gerade die Tastatur hat (R63).
    ///
    /// **Ein Aufzählungstyp und kein `Bool`.** Ein einzelnes `Bool` an
    /// vier Feldern hiesse „irgendeines schreibt gerade", und beim
    /// Zurücksetzen wüsste SwiftUI nicht, welches es loslassen soll.
    /// Mit einem Wert je Feld ist die Frage eindeutig -- und `nil`
    /// heisst „keines", also: Tastatur zu.
    private enum Schreibfeld: Hashable {
        case beschriftung, position, kuerzel, notiz
    }
    @FocusState private var schreibfeld: Schreibfeld?

    @State private var ablauf: Ablauf?
    /// Die Uhr dazu. Sie läuft nur, solange auch der Ablauf läuft -- ein
    /// Zeitgeber, der immer tickt, hält das Telefon wach.
    @State private var uhr: Timer?
    /// Die laufende Wartezeit vor dem Sichern von selbst (R91).
    ///
    /// Als `Task` und nicht als `Timer`: Sichern ist `async`, und ein
    /// `Timer` müsste dafür wieder eine Aufgabe starten -- zwei Uhren
    /// für eine Wartezeit.
    @State private var sicherWarten: Task<Void, Never>?
    /// Wann der letzte Takt war. Gerechnet wird mit der VERSTRICHENEN
    /// Zeit und nicht mit einem festen Sechzigstel: Fällt ein Bild aus,
    /// liefe der Play sonst langsamer statt ruckeliger.
    @State private var letzterTakt: Date?

    // WAS AM FINGER HÄNGT, WEISS SEIT R46 `Zeichenfeld`.
    //
    // Hier standen vier Zustandswerte: die angefasste Figur, ihr
    // Ausgangspunkt, der Stützpunkt am Finger und dessen Ausgangspunkt.
    // Sie sind mit der Geste umgezogen. Stehengeblieben wären sie tot
    // -- und Swift warnt bei gespeicherten Eigenschaften nicht, also
    // hätte es niemand gemerkt.

    var body: some View {
        ZStack {
            Farben.flaeche.ignoresSafeArea()

            if laedt {
                ProgressView().tint(Farben.akzent)
            } else if let fehler {
                Hinweis(zeichen: "exclamationmark.triangle",
                        titel: String(localized: "Das hat nicht geklappt"),
                        text: fehler) {
                    Button("Nochmal versuchen") { Task { await laden() } }
                        .buttonStyle(.borderedProminent)
                        .tint(Farben.akzent)
                }
            } else {
                zeichenflaeche
            }
        }
        // DIE MELDUNG GEHT VON SELBST WIEDER WEG (R75).
        //
        // Sie blieb stehen, bis zufällig etwas anderes passierte -- und
        // seit R62 bricht sie um, steht auf einem Telefon also über bis
        // zu drei Zeilen. Das sind vierundfünfzig Punkte, die dem Feld
        // dauerhaft fehlen, für eine Auskunft, die einmal galt.
        //
        // AN `meldungsstand` UND NICHT AN `block.meldung`: Zwei gleiche
        // Sätze hintereinander sind für SwiftUI derselbe Wert; die
        // Aufgabe liefe nicht neu an, und die zweite Meldung verschwände
        // mit dem Wecker der ersten -- unter Umständen sofort.
        //
        // Die Dauer rechnet `Zeichenblock.lesedauer` aus der Länge. Eine
        // feste Zahl wäre für den kurzen Satz zu lang und für den langen
        // zu kurz, und ausgerechnet der lange ist der, der erklärt,
        // warum gerade nichts passiert.
        .task(id: block.meldungsstand) {
            guard let text = block.meldung else { return }
            let dauer = Zeichenblock.lesedauer(text)
            try? await Task.sleep(for: .seconds(dauer))
            // `isCancelled` ist der Unterschied zwischen „abgelaufen"
            // und „es kam eine neue Meldung". Ohne die Abfrage löschte
            // der alte Wecker den neuen Satz.
            guard !Task.isCancelled else { return }
            block.melden(nil)
        }
        // DER TITEL FOLGT DEM BLATT (B7). Wer den Namen im Blatt
        // ändert und zurückkommt, sähe sonst oben weiter den alten --
        // und der stammt aus der Liste, nicht vom Server. Es wäre also
        // nicht einmal „noch nicht gespeichert", sondern schlicht die
        // falsche Auskunft.
        .navigationTitle(titel)
        .navigationBarTitleDisplayMode(.inline)
        // EIGENER ZURÜCK-KNOPF, damit die Rückfrage überhaupt eine
        // Gelegenheit hat. Der eingebaute Knopf schließt die Ansicht
        // sofort, und `onDisappear` kommt zu spät: Dort lässt sich nichts
        // mehr fragen und eine Speicheranfrage stirbt mit der Ansicht.
        //
        // DER PREIS: Mit verstecktem Zurück-Knopf fällt auch die
        // Wischgeste zum Zurückgehen weg. Das ist bewusst getauscht --
        // ein Wisch, der eine halbe Stunde Zeichnen wegwirft, ohne zu
        // fragen, ist der schlechtere Handel. Es betrifft nur DIESE
        // Ansicht; überall sonst wischt man weiter.
        .navigationBarBackButtonHidden(true)
        // DIE REITER UNTEN GEHEN IM EDITOR WEG (R90).
        //
        // Niklas am 09.09.2026: „Oder einfach größer vorher machen
        // irgend so. Weil theoretisch kann diese Mannschaften und
        // playbooks ja unten im Editor komplett weg sein."
        //
        // Er hat recht: Wer zeichnet, wechselt nicht nebenbei zur
        // Mannschaftsverwaltung -- und der Weg zurück steht oben links.
        // Die Leiste kostet rund fünfzig Punkte Höhe, und die fehlen
        // genau dort, wo das Feld steht.
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    spur("editor", "zurueck_knopf")
                    zurueck()
                } label: {
                    Label("Zurück", systemImage: "chevron.backward")
                }
                // EINE KENNUNG FUER DEN BILDERLAUF (R120).
                //
                // `navigationBarBackButtonHidden(true)` ersetzt den
                // System-Zurueckknopf durch diesen hier -- und damit
                // faellt weg, worauf sich XCUITest sonst verlaesst.
                // `app.navigationBars.buttons.element(boundBy: 0)` traf
                // am 30.09.2026 das Dreipunktmenue statt des Pfeils:
                // Der Durchgang blieb im Editor und bekam ein Menue mit
                // einem einzigen Eintrag („Melden").
                //
                // Ueber die Beschriftung geht es nicht -- sie heisst je
                // nach Sprache „Zurück", „Atrás", „Indietro".
                .accessibilityIdentifier("zurueck")
            }
            // R63. Niklas am 03.09.2026: „Wenn man hier drin ist kann
            // man die Tastatur nicht schließen." Sie nimmt zwei Drittel
            // des Schirms, das Feld schrumpft auf einen Streifen, und
            // heraus kam nur, wer den Tipp ins Leere kannte. Eine
            // Eingabe ohne sichtbares Ende ist eine Sackgasse -- derselbe
            // Befund wie bei der Anmeldemaske (B2).
            //
            // ÜBER DER TASTATUR UND NICHT IN DER LEISTE OBEN: Dort ist
            // der Daumen, wenn er gerade getippt hat. Und `.keyboard`
            // zeigt die Gruppe nur, solange die Tastatur steht; ein
            // eigener Zustand, den man mitführen müsste, entsteht nicht.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Fertigknopf(name: String(localized: "Tastatur schließen")) {
                    schreibfeld = nil
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                // „SICHERN" ALS ZEICHEN, NICHT ALS GEKUERZTES WORT (R57).
                //
                // Auf Niklas' Bildschirmfoto vom 02.09.2026 stand
                // „Sic…" -- die Werkzeugleiste von iOS 26 gibt weniger
                // Platz her, und deutsche Woerter sind lang. Eine
                // abgeschnittene Beschriftung sagt weniger als ein
                // Zeichen: „Sic…" heisst nichts, eine Diskette heisst
                // sichern.
                //
                // DER TEXT BLEIBT FUER DEN VORLESER (`Label` mit
                // beidem, `iconOnly` nur fuers Auge) -- und er nennt
                // weiter beide Zustaende, damit „Sichert…" auch dort
                // ankommt.
                Button {
                    spur("editor", "sichern")
                    Task { await sichern() }
                } label: {
                    Label(sichert ? String(localized: "Sichert…")
                                  : String(localized: "Sichern"),
                          systemImage: sichert
                          ? "arrow.trianglehead.2.clockwise"
                          : "square.and.arrow.down")
                        .labelStyle(.iconOnly)
                }
                .disabled(!darfZeichnen || !etwasOffen || sichert || laedt)
                // „Fertig" aus R6: sichern UND festhalten, in dieser
                // Reihenfolge. Der Knopf steht nur da, wenn dieser
                // Mensch überhaupt ändern darf -- sonst wäre er ein
                // toter Knopf (ADR-0007). Aufgemacht wird über die
                // Sperrleiste, nicht hier: Wer entsperren will, sieht
                // zuerst, wer zugemacht hat.
                if darfAendern && !gesperrt {
                    Button {
                        Task { await fertigUndSperren() }
                    } label: {
                        Label("Fertig und sperren", systemImage: "lock")
                    }
                    .disabled(sichert || sperrtGerade || laedt)
                }
                // MELDEN -- UND WARUM ES AUSGERECHNET HIER FEHLTE.
                //
                // Wer ändern darf, kommt beim Tippen auf eine Kachel in
                // den EDITOR und nicht in die Spielzug-Ansicht
                // (`PlayListe`, `Kachelziel.editor`). Das Meldemenü sass
                // nur in `PlayAnsicht` -- also genau dort, wo ein Coach
                // nie landet. In einem Verein mit zwei Trainern konnte
                // damit keiner den Spielzug des anderen melden, und im
                // Browser ging es längst.
                //
                // Aufgefallen ist es erst an Niklas' Bildschirmaufnahme
                // für Apple: Er tippte einen Play an, landete im Editor,
                // und das „Melden", das die Prüfnotiz zusagt, war nicht
                // da. Ein Wortlaut gegenüber Apple, den die App nicht
                // einlöst, ist derselbe Fehler wie eine Zusage ohne
                // Maschinerie.
                Menu {
                    Button {
                        meldet = true
                    } label: {
                        Label("Melden", systemImage: "flag")
                    }
                } label: {
                    Label("Mehr", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("editormenue")
            }
        }
        .sheet(isPresented: $meldet) {
            MeldeBlatt(play: play) { meldet = false }
                .environmentObject(anmeldung)
        }
        .confirmationDialog("Ungesicherte Änderungen",
                            isPresented: $fragtBeimVerlassen,
                            titleVisibility: .visible) {
            Button("Sichern und zurück") {
                Task {
                    await sichern()
                    // NUR ZURÜCK, WENN ES GEKLAPPT HAT. Bei einem Konflikt
                    // oder einem Netzfehler bliebe sonst genau die Arbeit
                    // liegen, für die diese Frage da ist.
                    if !etwasOffen { schliessen() }
                }
            }
            Button("Verwerfen", role: .destructive) { schliessen() }
            Button("Hierbleiben", role: .cancel) { }
        } message: {
            Text("""
                Was du gezeichnet hast, ist noch nicht beim Server. Zurück \
                heißt: weg.
                """)
        }
        .task { await laden() }
        // SICHERN GEHT VON SELBST (R91).
        //
        // Niklas am 09.09.2026: „Routen sollten sofort gespeichert
        // werden ohne das man darauf gehen muss."
        //
        // Der Browser macht das seit jeher (`geaendert()` in
        // `editor.js`, 1,1 Sekunden nach der letzten Änderung); die App
        // hatte als einzige einen Knopf dafür. Dieselbe Zeichnung, zwei
        // Verhalten -- und wer am Platz zeichnet, hat den Kopf beim
        // Play und nicht bei einer Diskette.
        //
        // DER KNOPF BLEIBT. Er zeigt jetzt an, dass gerade gesichert
        // wird, und er ist der Weg für den, der es sofort will oder dem
        // eine Sicherung fehlgeschlagen ist.
        .onChange(of: block.stand) { _, _ in spaeterSichern() }
        .onChange(of: block.angaben) { _, _ in spaeterSichern() }
        // Ohne das tickte die Uhr weiter, nachdem die Seite zu ist: ein
        // Zeitgeber, der eine Ansicht am Leben hält, die niemand mehr
        // sieht.
        .onDisappear {
            uhr?.invalidate()
            uhr = nil
            sicherWarten?.cancel()
        }
        .sheet(isPresented: $zeigtFormationen) {
            if let heft = playbookId {
                Formationsblatt(
                    playbook: heft,
                    aufstellung: block.zeichnung.spieler,
                    feld: block.projektion.feld,
                    spielform: block.projektion.spielform,
                    darfAendern: darfAendern,
                    anwenden: { formation in
                        zeigtFormationen = false
                        // Was das mit der Zeichnung macht, entscheidet
                        // `Zeichenblock` und nicht diese Ansicht: ein
                        // Schritt im Verlauf, die Linien bleiben.
                        block.formationAnwenden(formation.data.spieler,
                                                name: formation.name)
                    },
                    // DIE EINGEBAUTEN VORLAGEN (R110.5). Auch hier
                    // entscheidet der `Zeichenblock`, was mit der
                    // Zeichnung passiert -- die Ansicht reicht durch.
                    vorlageAnwenden: { vorlage, seite in
                        zeigtFormationen = false
                        block.vorlageAnwenden(vorlage, seite: seite)
                    },
                    defenseEntfernen: {
                        zeigtFormationen = false
                        block.defenseEntfernen()
                    },
                    schliessen: { zeigtFormationen = false })
            }
        }
        .sheet(isPresented: $zeigtLage) {
            Spiellage(block: $block, darfAendern: darfZeichnen,
                      schliessen: { zeigtLage = false })
        }
        .sheet(isPresented: $zeigtAngaben) {
            Playangaben(stand: $block.angaben, kategorien: kategorien,
                        spielform: block.projektion.spielform,
                        darfAendern: darfZeichnen,
                        schliessen: { zeigtAngaben = false })
                // EIN SCHRITT JE BEARBEITUNG (R110.7), und zwar beim
                // SCHLIESSEN. Das Blatt schreibt laufend in
                // `block.angaben`; ein Verlauf, der jeden Buchstaben
                // aufnimmt, ist beim Zurueckgehen nutzlos -- man
                // drueckt zwanzigmal und ist beim ersten Buchstaben
                // des Namens.
                //
                // Beim Aufgehen wird der Stand gemerkt, beim Zugehen
                // verglichen. „Abbrechen" setzt ihn ohnehin selbst
                // zurueck; dann sind beide gleich, und es entsteht
                // kein Schritt.
                .onAppear { angabenBeimOeffnen = block.angaben }
                .onDisappear {
                    if let vorher = angabenBeimOeffnen {
                        block.angabenGemerkt(vorher: vorher)
                    }
                    angabenBeimOeffnen = nil
                }
        }
        .alert(entwurfVeraltet
               ? Text("Hier liegt eine Änderung, und jemand anderes war schneller")
               : Text("Hier liegt eine Änderung, die nie beim Server ankam"),
               isPresented: Binding(get: { offenerEntwurf != nil },
                                    set: { if !$0 { offenerEntwurf = nil } })) {
            Button("Verwerfen", role: .destructive) {
                Entwurfslager.vergessen(play: play.id)
                offenerEntwurf = nil
                entwurfVeraltet = false
            }
            Button("Wiederherstellen") {
                if let e = offenerEntwurf {
                    block.entwurfUebernehmen(zeichnung: e.zeichnung, los: e.los,
                                             richtung: e.richtung,
                                             angaben: e.angaben)
                }
                offenerEntwurf = nil
                entwurfVeraltet = false
                spaeterSichern()
            }
        } message: {
            // WANN, UND ZWAR IN WORTEN. Die Uhrzeit beantwortet die
            // eigentliche Frage -- ist das noch meins? --, eine blosse
            // Meldung „es liegt etwas" nicht.
            let entwurfszeit = EditorAnsicht.wann(offenerEntwurf?.zeit)
            if entwurfVeraltet {
                Text("""
                    \(entwurfszeit) hast du hier etwas geändert, das nie \
                    beim Server ankam. Inzwischen hat jemand anderes \
                    gespeichert: Wiederherstellen überschreibt seine \
                    Fassung, sobald du das nächste Mal sicherst.
                    """)
            } else {
                Text("""
                    \(entwurfszeit) hast du hier etwas geändert, das nie \
                    beim Server ankam.
                    """)
            }
        }
        .alert("Jemand anderes war schneller",
               isPresented: Binding(get: { konflikt != nil },
                                    set: { if !$0 { konflikt = nil } })) {
            Button("Fremde Fassung übernehmen", role: .destructive) {
                if let fremd = konflikt {
                    block = Zeichenblock(zeichnung: fremd.zeichnung,
                                         projektion: projektion(fremd))
                    block.flaecheSetzen(flaeche)
                    version = fremd.version
                    // DIE ANGABEN GEHÖREN DAZU (B7). „Fremde Fassung
                    // übernehmen" heißt: ganz, und nicht die Zeichnung
                    // des Kollegen mit meinem Namen darüber. Beide
                    // Stände gleich, also ist danach nichts mehr offen
                    // -- was auch stimmt.
                    block.angaben = Playangaben.Stand(von: fremd)
                    angabenGesichert = block.angaben
                }
                konflikt = nil
            }
            // EIN DRITTER WEG, UND ER IST DER WICHTIGSTE.
            //
            // Vorher gab es nur zwei: die fremde Fassung nehmen (eigene
            // Arbeit weg) oder „Meine behalten" -- und das war eine
            // Falle. Die Fassungsnummer blieb stehen, jeder weitere
            // Speicherversuch scheiterte an derselben Nummer, und die
            // Zeichnung lag nur im Speicher. App zu, Arbeit weg.
            //
            // Der Kommentar darunter hat die Falle sogar beschrieben:
            // Ein zweiter Versuch scheitert wieder, ein Versuch mit der
            // neuen Nummer überschreibt den anderen. Beides stimmt --
            // und daraus folgt nicht „dann eben gar nichts", sondern:
            // Es braucht einen Ausgang, bei dem NIEMAND etwas verliert.
            //
            // Das ist dieser hier. Die eigene Zeichnung wird ein
            // eigener Play daneben. Der Kollege behält seinen, der
            // Trainer behält seinen, und die beiden lassen sich in Ruhe
            // vergleichen.
            if playbookId != nil {
                Button("Als neuen Play sichern") {
                    Task { await alsNeuenPlaySichern() }
                }
            }
            Button("Meine behalten", role: .cancel) { konflikt = nil }
        } message: {
            // Was hier NICHT steht: „Erneut versuchen". Ein zweiter
            // Versuch mit derselben alten Fassungsnummer scheitert wieder,
            // und ein Versuch mit der neuen überschreibt genau das, wovor
            // der Server gerade gewarnt hat.
            //
            // Und was hier seit dem 02.09.2026 sehr wohl steht: dass
            // „Meine behalten" das Sichern nicht wieder freischaltet.
            // Wer das nicht weiß, zeichnet weiter und verliert alles.
            Text("""
                Dieser Play wurde inzwischen woanders gespeichert. Deine \
                Änderungen sind noch da, aber sie passen nicht mehr auf die \
                Fassung, die auf dem Server liegt.

                „Meine behalten“ lässt dich weiterzeichnen, aber Sichern \
                bleibt gesperrt, bis du dich für einen der beiden anderen \
                Wege entscheidest.
                """)
        }
    }

    // MARK: - Die Fläche

    /// Feld und Leisten -- im Hochformat übereinander, im Querformat
    /// nebeneinander (R49).
    ///
    /// **Warum das nötig ist.** Auf einem Telefon im Querformat sind
    /// keine 400 Punkte Höhe da. Die drei Leisten darunter nehmen
    /// zusammen rund 150 -- also mehr als ein Drittel, und übrig
    /// bleibt ein Feldstreifen. Genau darum ging es Niklas bei R49:
    /// „Querformat, mit der Werkzeugleiste an der Seite."
    ///
    /// **Gemessen an `verticalSizeClass` und nicht an der Breite.** Ein
    /// iPad im Hochformat ist breit und hat trotzdem Höhe; ein iPhone
    /// im Querformat ist breit und hat keine. Die Frage ist die Höhe,
    /// also fragt der Code danach.
    ///
    /// Die Leisten bleiben dieselben -- sie stehen nur in einer Spalte
    /// und die scrollt. Zwei Fassungen derselben Werkzeugleiste liefen
    /// auseinander, und dann hätte dasselbe Werkzeug im Querformat
    /// einen anderen Namen.
    private var zeichenflaeche: some View {
        Group {
            if wenigHoehe {
                HStack(spacing: 0) {
                    feldflaeche
                    Divider().background(Farben.linie)
                    ScrollView {
                        VStack(spacing: 0) { leisten }
                    }
                    // Breit genug für die Aktionsknöpfe (vier mal 40
                    // plus Abstände) und schmal genug, dass das Feld
                    // die Mehrheit behält.
                    .frame(width: 232)
                    .background(Farben.flaechePanel)
                }
            } else {
                VStack(spacing: 0) {
                    feldflaeche
                    leisten
                }
            }
        }
    }

    /// Wenig Höhe heißt: Telefon im Querformat.
    private var wenigHoehe: Bool { hoehenklasse == .compact }

    @ViewBuilder
    private var leisten: some View {
        if ablauf != nil {
            abspielleiste
        } else {
            aktionsleiste
            // ANSTELLE der Werkzeugleiste, nicht darüber: Werkzeuge,
            // die nichts mehr tun, sind schlimmer als keine.
            // Abspielen bleibt daneben stehen -- einen fertigen Play
            // ansehen ist genau das, wofür er fertig ist.
            if gesperrt {
                sperrleiste
            } else {
                werkzeugleiste
            }
            fusszeile
        }
    }

    /// Die Zeichenfläche.
    ///
    /// **Der Finger sitzt seit R46 in `Zeichenfeld`.** Er wird dort
    /// gebraucht wie hier -- der Formationen-Builder schiebt dieselben
    /// Figuren mit derselben Fangregel. Zwei Fassungen davon wären zwei
    /// Antworten auf die Frage, ob eine Figur über die Line of
    /// Scrimmage darf.
    private var feldflaeche: some View {
        Zeichenfeld(block: $block, flaeche: $flaeche,
                    darfZeichnen: darfZeichnen,
                    zeigeNamen: zeigeNamen, ablauf: ablauf)
    }

    /// Ist irgendetwas ungesichert -- Zeichnung ODER Angaben?
    ///
    /// **Eine Stelle, an der diese Frage beantwortet wird.** Vor B7
    /// stand überall `block.geaendert`, und das hieß „die Zeichnung ist
    /// geändert". Seit die App auch Name, Nummer, Seite, Kategorie,
    /// Situationen und Hinweise setzt, ist das nur noch die halbe
    /// Frage: Wer den Namen ändert und zurückgeht, verlöre ihn
    /// schweigend -- dieselbe Falle, gegen die `zurueck()` überhaupt
    /// gebaut wurde.
    ///
    /// Sechs Stellen fragen danach (Sichern-Knopf, Rückfrage beim
    /// Verlassen, deren „Sichern und zurück", die Fußzeile,
    /// „Fertig und sperren" und dessen Nachprüfung). Alle sechs fragen
    /// hier, damit nicht die eine etwas anderes meint als die andere.
    private var etwasOffen: Bool {
        block.geaendert || block.angaben != angabenGesichert
    }

    // WELCHE FIGUR HERVORGEHOBEN WIRD, entscheidet seit R46
    // `Zeichenfeld` -- dort, wo auch der Finger sitzt. Hier stand
    // dieselbe Zeile noch einmal, und zwei Stellen, die dieselbe Frage
    // beantworten, geben irgendwann verschiedene Antworten.

    // MARK: - Rückgängig, Spiegeln, Abspielen

    /// Die vier Handgriffe aus Stufe 3, in einer festen Zeile.
    ///
    /// NICHT in der scrollbaren Werkzeugleiste: Rückgängig ist der Knopf,
    /// den man im Schreck drückt, und einer, den man erst herscrollen
    /// muss, ist im Schreck nicht da.
    private var aktionsleiste: some View {
        HStack(spacing: 6) {
            // Überall `darfZeichnen &&`: Rückgängig ist eine Änderung
            // wie jede andere, und an einem gesperrten Play lehnt der
            // Server sie ab (R6).
            aktion("arrow.uturn.backward",
                   name: String(localized: "Rückgängig"),
                   an: darfZeichnen && block.kannRueckgaengig) {
                block.rueckgaengig()
            }
            aktion("arrow.uturn.forward",
                   name: String(localized: "Wiederholen"),
                   an: darfZeichnen && block.kannWiederherstellen) {
                block.wiederherstellen()
            }
            aktion("arrow.left.and.right",
                   name: String(localized: "Spiegeln"),
                   an: darfZeichnen) {
                block.spiegeln()
            }
            // WO DER BALL LIEGT (R110.3). Neben „Spiegeln", weil es
            // dieselbe Sorte Frage ist -- wie steht dieser Play auf dem
            // Feld -- und weil die beiden am leichtesten zu verwechseln
            // sind: Spiegeln tauscht links und rechts, hier wandert der
            // Ball. Nebeneinander sieht man den Unterschied.
            aktion("figure.american.football",
                   name: String(localized: "Spielsituation"),
                   an: true) {
                block.abbrechen()
                zeigtLage = true
            }
            // DER SICHTBARE WEG ZURUECK AUS DEM ZOOM (R110.6, B1).
            //
            // Kneifen ist eine Geste, und eine Geste, die man nur mit
            // einer Geste rueckgaengig machen kann, ist eine Sackgasse
            // fuer jeden, der die zweite nicht kennt. Sadana 2018: 1
            // von 16 findet eine Geste ohne sichtbaren Hinweis.
            //
            // Der Knopf steht nur da, wenn es etwas zurueckzusetzen
            // gibt -- einer, der nichts tut, ist einer zu viel
            // (ADR-0007).
            if block.ausschnittVerstellt {
                aktion("arrow.up.left.and.down.right.magnifyingglass",
                       name: String(localized: "Ganzes Feld"),
                       an: true) {
                    block.ausschnittZuruecksetzen()
                }
            }
            // Die gespeicherten Aufstellungen. Der Knopf steht nur da,
            // wenn das Heft bekannt ist -- ohne Heft gibt es nichts zu
            // laden, und ein Knopf, der ins Leere führt, ist einer zu
            // viel (ADR-0007).
            if playbookId != nil {
                aktion("person.3",
                       name: String(localized: "Aufstellungen"),
                       an: darfZeichnen) {
                    block.abbrechen()
                    zeigtFormationen = true
                }
            }
            // ROUTENNAMEN AN ODER AUS (R25) -- SEIT R60 HIER UNTEN.
            //
            // Oben standen Zurück, Titel, „Abc", „Sichern" und das
            // Schloss nebeneinander; auf Niklas' Bildschirmfoto vom
            // 02.09.2026 blieb von „Sichern" ein „Sic…". Die
            // Werkzeugleiste von iOS 26 gibt weniger Platz her, und
            // deutsche Wörter sind lang.
            //
            // WARUM AUSGERECHNET DIESER. Von den fünf Dingen oben ist
            // er der einzige, der nichts VERÄNDERT: Er schaltet eine
            // Anzeige um. Zurück, Sichern und das Schloss müssen dort
            // stehen, wo man sie ohne Suchen findet.
            //
            // Hier unten steht er bei seinesgleichen -- Rückgängig,
            // Spiegeln, Aufstellungen sind auch Handgriffe am Bild und
            // nicht am Play. Und er ist nicht mehr an `darfZeichnen`
            // gebunden: Namen ansehen darf auch, wer einen gesperrten
            // Play nur aufmacht, um ihn zu zeigen.
            aktion(zeigeNamen ? "textformat.abc"
                              : "textformat.abc.dottedunderline",
                   name: zeigeNamen
                   ? String(localized: "Routennamen ausblenden")
                   : String(localized: "Routennamen anzeigen"),
                   an: true) {
                zeigeNamen.toggle()
            }
            Spacer(minLength: 0)
            Button {
                spur("editor", "abspielen", "start")
                abspielen()
            } label: {
                Label("Abspielen", systemImage: "play.fill")
                    .accessibilityIdentifier("abspielen")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Farben.linie, in: Capsule())
                    .foregroundStyle(Farben.ink)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .background(Farben.flaechePanel)
    }

    private func aktion(_ zeichen: String, name: String, an: Bool,
                        tun: @escaping () -> Void) -> some View {
        // JEDER KNOPF DIESER LEISTE WIRD GEZAEHLT (R86), und zwar hier
        // an einer Stelle statt an jeder Aufrufstelle. Angeschrieben
        // wird das Zeichen und nicht der Name: Der Name ist uebersetzt,
        // und eine Auswertung, in der derselbe Knopf in fuenf Sprachen
        // fuenfmal auftaucht, zaehlt nichts zusammen.
        Button {
            spur("editor", "knopf", zeichen)
            tun()
        } label: {
            Image(systemName: zeichen)
                .font(.body)
                .frame(width: 40, height: 34)
                .background(Farben.linie, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(an ? Farben.ink : Farben.inkStill.opacity(0.5))
        }
        .buttonStyle(.plain)
        .disabled(!an)
        .accessibilityLabel(name)
    }

    // MARK: - Der Ablauf

    /// Die Leiste beim Abspielen. Sie ERSETZT Werkzeuge und Fußzeile:
    /// Wer zusieht, zeichnet nicht, und zwei Leisten übereinander nähmen
    /// dem Feld die Höhe, auf die es ankommt.
    @ViewBuilder private var abspielleiste: some View {
        if let lauf = ablauf {
            VStack(spacing: 6) {
                // Die Meldung gehört hierher und nicht in die Fußzeile:
                // Die ist gerade nicht da. „Weniger Bewegung eingestellt,
                // spule von Hand" käme sonst nirgends an, und der Ablauf
                // sähe für diese Leute einfach kaputt aus.
                if let meldung = block.meldung {
                    Text(meldung)
                        .font(.footnote)
                        .foregroundStyle(Farben.inkStill)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 10) {
                    // DER ABSPIELKNOPF GANZ LINKS UND MIT ZEICHEN (R85).
                    //
                    // Niklas am 09.09.2026: „Play und Pause Button
                    // links, also wenn es abspielt Pause Button wenn es
                    // pausiert ist play". Vorher stand „Zurück an den
                    // Anfang" davor und der Knopf trug nur ein Wort --
                    // „Weiter" oder „Nochmal". Beides ist genauer als
                    // „Play", und beides hilft nicht: Ein Abspielknopf
                    // wird am Dreieck erkannt und nicht gelesen, schon
                    // gar nicht am Spielfeldrand.
                    Button {
                        spur("editor", "abspielen",
                             lauf.laeuft ? "pause" : "weiter")
                        aendern { stand in
                            if stand.laeuft {
                                stand.anhalten()
                            } else {
                                stand.weiter()
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: lauf.knopfzeichen)
                            Text(lauf.knopf)
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)

                    Button {
                        spur("editor", "abspielen", "anfang")
                        aendern { stand in stand.anfang() }
                    } label: {
                        Image(systemName: "backward.end.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Farben.ink)
                    .accessibilityLabel("Zurück an den Anfang")

                    Text(lauf.zeittext)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Farben.inkStill)

                    Spacer(minLength: 0)

                    Menu {
                        ForEach(Ablauf.tempoStufen, id: \.self) { stufe in
                            Button(EditorAnsicht.tempoName(stufe)) {
                                spur("editor", "tempo", "\(stufe)")
                                aendern { stand in stand.tempoSetzen(stufe) }
                            }
                        }
                    } label: {
                        Text("Tempo \(EditorAnsicht.tempoName(lauf.tempo))")
                            .font(.footnote)
                            .foregroundStyle(Farben.ink)
                    }

                    // ALS PFEIL UND NICHT ALS SATZ (R85, Rest).
                    //
                    // Niklas am 09.09.2026: „rechts statt abspielen
                    // beenden vielleicht ein Button statt Schrift
                    // zurück zurück so ein Pfeil". „Abspielen beenden"
                    // sind achtzehn Zeichen in einer Leiste, in der
                    // links schon Knopf, Anfang, Uhr und Tempo stehen
                    // -- auf einem Telefon in Hochkant bleibt für den
                    // Rest nichts übrig. Der Text bleibt für den
                    // Vorleser stehen.
                    Button {
                        spur("editor", "abspielen", "beenden")
                        abspielenBeenden()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Farben.akzent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Abspielen beenden")
                }

                // Spulen. Derselbe Weg wie das Abspielen selbst: Der
                // Regler setzt die Zeit, und gezeichnet wird, was dabei
                // herauskommt.
                Slider(value: Binding(
                    get: { lauf.zeit },
                    set: { neu in aendern { stand in stand.spulen(zu: neu) } }),
                       in: 0...max(lauf.plan.gesamt, 1))
                    .tint(Farben.akzent)
                    .accessibilityLabel("Stelle im Ablauf")
                    .accessibilityValue(lauf.zeittext)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Farben.flaechePanel)
        }
    }

    /// „1×", „0,5×". Deutsches Komma, wie im Browser.
    static func tempoName(_ wert: Double) -> String {
        let text = wert == wert.rounded()
            ? String(Int(wert))
            : String(format: "%g", wert).replacingOccurrences(of: ".",
                                                              with: ",")
        return text + "×"
    }

    /// Eine Änderung am Ablauf, samt Uhr.
    ///
    /// Alles, was den Ablauf anfasst, geht hier durch: Sonst läuft die
    /// Uhr weiter, obwohl angehalten wurde, und die Zeit springt beim
    /// nächsten Takt um die Pause nach vorn.
    private func aendern(_ tun: (inout Ablauf) -> Void) {
        guard var lauf = ablauf else { return }
        tun(&lauf)
        ablauf = lauf
        uhrStellen()
    }

    private func abspielen() {
        block.abbrechen()
        let plan = Laufplan(linien: block.zeichnung.linien)
        guard !plan.istLeer else {
            block.melden(String(localized:
                "Dieser Play hat noch keine Linien zum Abspielen."))
            return
        }
        var lauf = Ablauf(plan: plan)
        if wenigerBewegung {
            block.melden(String(localized:
                "Weniger Bewegung eingestellt, spule von Hand."))
        } else {
            // Dieselbe Ansage wie im Browser. Wer sie gelesen hat, sucht
            // die erste Bewegung nicht beim falschen Spieler.
            if plan.hatMotion {
                block.melden(String(localized:
                    "Motion, Snap, dann die Routen."))
            }
            lauf.weiter()
        }
        ablauf = lauf
        uhrStellen()
    }

    private func abspielenBeenden() {
        ablauf = nil
        uhrStellen()
    }

    /// Stellt die Uhr auf den Ablauf ein: Läuft er, tickt sie; sonst nicht.
    private func uhrStellen() {
        uhr?.invalidate()
        uhr = nil
        letzterTakt = nil
        guard ablauf?.laeuft == true else { return }
        letzterTakt = Date()
        uhr = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0,
                                   repeats: true) { _ in takt() }
    }

    private func takt() {
        guard var lauf = ablauf, lauf.laeuft else {
            uhrStellen()
            return
        }
        let jetzt = Date()
        lauf.schritt(jetzt.timeIntervalSince(letzterTakt ?? jetzt) * 1000)
        letzterTakt = jetzt
        ablauf = lauf
        // Am Ende hält der Ablauf sich selbst an. Dann darf auch die Uhr
        // gehen, sonst tickt sie bis zum Verlassen der Seite weiter.
        if !lauf.laeuft { uhrStellen() }
    }

    // MARK: - Werkzeuge

    private var werkzeugleiste: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // `name` ist ein `String` und kein
                // `LocalizedStringKey` -- `Text(name)` uebersetzt
                // deshalb NICHT. Die anderen Knoepfe fallen nicht auf,
                // weil `art.stil.kurz` schon englisch ist („Route",
                // „Zone", „Curve"); dieser eine stand auf jedem
                // Telefon der Welt auf Deutsch.
                werkzeugKnopf(.auswahl, name: String(localized: "Auswahl"),
                              art: nil)
                // DREI WERKZEUGE STATT ZEHN (R83, 09.09.2026).
                // Route und Zone; alles andere wird an der ausgewaehlten
                // Linie umgestellt. Siehe `Art.inDerLeiste`.
                ForEach(Zeichnung.Linie.Art.inDerLeiste, id: \.rawValue) { art in
                    werkzeugKnopf(.linie(art), name: art.stil.kurz, art: art)
                }
                Divider()
                    .frame(height: 22)
                    .padding(.horizontal, 2)
                zonenformKnopf
                kurvenKnopf
                fangKnopf
                Divider()
                    .frame(height: 22)
                    .padding(.horizontal, 2)
                spielerKnopf(.offense)
                spielerKnopf(.defense)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Farben.flaechePanel)
    }

    /// Einen Spieler dazustellen.
    ///
    /// **Die App konnte das bis zum 08.09.2026 gar nicht.** Nachgezählt:
    /// kein `append`, kein `remove`, keine Funktion, die die Länge der
    /// Aufstellung ändert. Die Figuren kamen fertig vom Server und
    /// ließen sich danach nur schieben.
    ///
    /// Solange jede Mannschaft fünf Leute hatte, fiel das nicht auf. Mit
    /// Tackle sofort: Wer eine Mannschaft von Elfer auf Neuner
    /// umstellt, behält in vorhandenen Plays elf Figuren und wird zwei
    /// davon in der App nicht los.
    ///
    /// **Hinter dem Trenner, bei den Schaltern und nicht bei den
    /// Werkzeugen.** Es wählt nichts aus; es ändert die Aufstellung.
    private func spielerKnopf(_ seite: Zeichnung.Spieler.Seite) -> some View {
        let voll = block.anzahl(seite) >= block.hoechstensJeSeite
        return Button {
            block.spielerDazu(seite)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                Text(EditorAnsicht.seitenname(seite))
                    .font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .paarung(Paare.knopf, ecke: Masse.r1)
            .opacity(voll || !darfZeichnen ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(voll || !darfZeichnen)
        .accessibilityLabel(Text("Spieler dazustellen"))
    }

    /// Die Form einer neuen Zone: Vieleck, rund oder eckig (R48).
    ///
    /// Er steht nur da, wenn die Zone das gewählte Werkzeug ist. Ein
    /// Formschalter neben dem Routenwerkzeug wäre ein Knopf, der nichts
    /// tut, und ein Knopf, der nichts tut, sieht aus wie ein Programm,
    /// das klemmt.
    ///
    /// Hinter demselben Trenner wie Kurve und Fang und aus demselben
    /// Grund: Er wählt kein Werkzeug, er ändert, wie das gewählte
    /// zeichnet.
    @ViewBuilder
    private var zonenformKnopf: some View {
        if block.werkzeug == .linie(.zone) {
            let naechste: Zeichnung.Linie.Zonenform =
                block.zonenform == .linie ? .kreis
                : block.zonenform == .kreis ? .rechteck : .linie
            // AUSGESCHRIEBEN UND NICHT IM BEDINGUNGSAUSDRUCK. Ein
            // Literal hinter einem `?` oder `:` steht nicht direkt
            // hinter `Text(`, und `appsprache._ist_stelle` erkennt es
            // dort nicht als uebersetzbaren Satz. Die App uebersetzte
            // dann alles ausser diesen drei Woertern -- und niemandem
            // faellt ein fehlender Satz auf, der auf Deutsch lesbar ist.
            let name = block.zonenform == .kreis ? String(localized: "Rund")
                     : block.zonenform == .rechteck ? String(localized: "Eckig")
                     : String(localized: "Vieleck")
            Button {
                block.zonenformSetzen(naechste)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: block.zonenform == .kreis ? "circle"
                                    : block.zonenform == .rechteck ? "rectangle"
                                    : "pentagon")
                    Text(name).font(.footnote.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .paarung(block.zonenform == .linie ? Paare.knopf : Paare.knopfHaupt,
                         ecke: Masse.r1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Form der Zone: Vieleck, Kreis oder Rechteck")
            .accessibilityAddTraits(block.zonenform == .linie ? [] : [.isSelected])
        }
    }

    /// Der Schalter für gerundete Linien (R7/R12).
    ///
    /// Er steht hinter einem Trenner, weil er KEIN Werkzeug ist: Er
    /// wählt nichts aus, er ändert, wie das gewählte Werkzeug zeichnet.
    /// Im Browser steht er an derselben Stelle und aus demselben Grund.
    private var kurvenKnopf: some View {
        let an = block.kurveAktiv
        return Button {
            block.kurveUmschalten()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: an ? "point.topleft.down.curvedto.point.bottomright.up"
                                     : "line.diagonal")
                Text("Kurve").font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .paarung(an ? Paare.knopfHaupt : Paare.knopf, ecke: Masse.r1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Linien weich runden")
        .accessibilityAddTraits(an ? [.isSelected] : [])
    }

    /// Der Schalter für den Zeichenfang (R5).
    ///
    /// Gemeldet von Cyell: „man kann nicht frei eingeben. Sie werden oft
    /// zu einem Punkt gezogen, wo man ihn nicht hin haben möchte." Der
    /// Browser hat diesen Schalter seit jeher (Taste F) und dazu die
    /// Umschalttaste, die ihn für einen Zug aufhebt. Am Telefon gibt es
    /// keine Umschalttaste -- hier ist der Knopf der einzige Weg, und
    /// deshalb steht er in der Leiste und nicht in einem Menü.
    ///
    /// Neben dem Kurvenknopf und aus demselben Grund hinter dem Trenner:
    /// Er wählt kein Werkzeug, er ändert, wie jedes zeichnet.
    private var fangKnopf: some View {
        let an = block.fang
        return Button {
            block.fangUmschalten()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: an ? "grid" : "scribble")
                Text("Fang").font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .paarung(an ? Paare.knopfHaupt : Paare.knopf, ecke: Masse.r1)
        }
        .buttonStyle(.plain)
        // Nicht „auf halbe Yards einrasten": Seit Runde 4 zieht der Fang
        // nur, was ohnehin knapp an einer Marke sitzt. Wer die Ansage
        // vorgelesen bekommt, statt den Knopf zu sehen, hat sonst als
        // Einziger noch die alte Beschreibung im Ohr.
        .accessibilityLabel("Fang: nah an halben Yards und 45 Grad einrasten")
        .accessibilityAddTraits(an ? [.isSelected] : [])
    }

    private func werkzeugKnopf(_ werkzeug: Zeichenblock.Werkzeug,
                               name: String,
                               art: Zeichnung.Linie.Art?) -> some View {
        let gewaehlt = block.werkzeug == werkzeug
        return Button {
            block.werkzeugSetzen(werkzeug)
        } label: {
            HStack(spacing: 6) {
                if let art { Linienprobe(art: art) }
                Text(name).font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .paarung(gewaehlt ? Paare.knopfHaupt : Paare.knopf, ecke: Masse.r1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(art?.stil.lang ?? name)
        .accessibilityAddTraits(gewaehlt ? [.isSelected] : [])
    }

    // MARK: - Die Fußzeile

    /// Was an dieser Aufstellung dem Regelwerk widerspricht.
    ///
    /// **ANMERKUNGEN, KEINE VERBOTE.** Wer eine Übungsform mit sieben
    /// Spielern zeichnet, soll das können -- er soll nur sehen, dass es
    /// keine Spielform ist. Deshalb steht es als Satz da und hält
    /// nichts auf.
    ///
    /// **Der Browser zeigt das seit T7, die App bis zum 08.09.2026
    /// nicht.** Wer dort einen Spieler von der Linie ins Backfield zog,
    /// hatte fünf Backs und kein Wort dazu. Gerechnet wurde es die
    /// ganze Zeit -- der Server schickte es nur nicht mit, und die App
    /// hätte es auch nicht gelesen.
    ///
    /// Vom SERVER und nicht in Swift nachgebaut: Die Regel steht an
    /// einer Stelle. Sie kommt beim Laden und nach jedem Sichern.
    @ViewBuilder private var regelleiste: some View {
        let saetze = anmerkungen.compactMap(\.satz)
        if !saetze.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .accessibilityHidden(true)
                Text(saetze.joined(separator: " "))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(.footnote)
            .foregroundStyle(Farben.warnung)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Farben.warnung.opacity(0.10))
        }
    }

    /// Drei Zustände, und immer nur einer: Wer zeichnet, braucht „Fertig".
    /// Wer eine Linie angetippt hat, braucht ihr Ende. Sonst zählt, ob
    /// etwas ungesichert ist.
    @ViewBuilder private var fusszeile: some View {
        VStack(spacing: 0) {
            regelleiste
            if let meldung = block.meldung {
                // R62. `.fixedSize(vertical:)` UND NICHT `.lineLimit(nil)`:
                // Niklas am 03.09.2026 mit einem Strich durch die Zeile
                // („Da fehlt der halbe Text"). Der Text stand schon ohne
                // Zeilengrenze da -- gestaucht hat ihn der Aufbau. In
                // einem Stapel neben Leisten bekommt ein `Text` die Höhe
                // einer Zeile zugeteilt und kürzt, statt umzubrechen.
                // `fixedSize` dreht das um: Die Breite gibt der Stapel
                // vor, die Höhe nimmt sich der Text.
                Text(meldung)
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            if block.entwurf != nil {
                entwurfsleiste
            } else if let linie = block.ausgewaehlteLinie {
                linienleiste(linie)
            } else if let spieler = block.ausgewaehlterSpieler {
                // R9. Die beiden schließen einander aus, weil `auswahl`
                // EIN Wert ist -- entweder eine Linie oder eine Figur.
                // Diese Leiste steht trotzdem hinter der Linienleiste,
                // damit die Reihenfolge dieselbe bleibt, wenn `auswahl`
                // einmal mehr tragen sollte als heute.
                spielerleiste(spieler)
            } else {
                ruheleiste
            }
        }
        .background(Farben.flaechePanel)
    }

    /// Das Menü für die Linienart -- an EINER Stelle, für zwei Leisten.
    ///
    /// Es steht an der ausgewählten Linie UND an der, die gerade
    /// entsteht (R92). Niklas am 09.09.2026: „ich finde man sollte schon
    /// beim punkte einzeichen auf das dropdown menü zugriff haben welche
    /// linienart". Er hat recht: Ob ein Weg eine Motion ist, weiss man
    /// beim Zeichnen und nicht erst danach -- und wer es erst danach
    /// umstellen kann, zeichnet zweimal.
    ///
    /// Zwei Fassungen desselben Menüs wären zwei Gelegenheiten, in der
    /// einen eine Art zu vergessen.
    private func artmenue(aktuell: Zeichnung.Linie.Art,
                          tun: @escaping (Zeichnung.Linie.Art) -> Void)
        -> some View {
        Menu {
            Section(String(localized: "Art ändern")) {
                ForEach(Zeichnung.Linie.Art.umstellbar, id: \.rawValue) { art in
                    Button {
                        tun(art)
                    } label: {
                        Label {
                            // Das Häkchen steht IM Wort und nicht als
                            // zweites Zeichen: Ein Eintrag trägt genau
                            // ein Bild, und das ist hier die Linie.
                            Text(art == aktuell ? "✓ \(art.stil.lang)"
                                                : art.stil.lang)
                        } icon: {
                            Linienprobe(art: art)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Linienprobe(art: aktuell)
                Text(aktuell.stil.kurz)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Farben.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            // DER RAHMEN IST DIE AUSSAGE „hier kann man tippen". Ohne
            // ihn stand dort ein Wort neben zwei Zeichen, und ein Wort
            // sieht in dieser Leiste aus wie eine Beschriftung.
            .background(Farben.linie.opacity(0.5),
                        in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Farben.linie))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(!darfZeichnen)
        .accessibilityLabel(String(localized: "Art ändern"))
    }

    private var entwurfsleiste: some View {
        HStack(spacing: 10) {
            // DIE ART SCHON BEIM ZEICHNEN (R92). Der Name der Art steht
            // damit im Menü und nicht mehr im Text daneben -- zweimal
            // dasselbe Wort in einer Leiste, die auf dem Telefon ohnehin
            // eng ist.
            if let laufend = block.entwurf, laufend.art != .zone {
                artmenue(aktuell: laufend.art) {
                    block.werkzeugSetzen(.linie($0))
                }
            }
            Text(entwurfstext)
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Punkt zurück") { block.punktZurueck() }
                .font(.footnote)
                .foregroundStyle(Farben.ink)
            Button("Abbrechen") { block.abbrechen() }
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)
            // EIN HÄKCHEN (R65). Niklas am 03.09.2026 mit einem
            // Kringel um genau diesen Knopf: „Mach doch ein häckchen
            // als Button." Auf seinem Bild bricht „Linie fertig" auf
            // zwei Zeilen um und drückt die Leiste auseinander.
            //
            // ES BLEIBT DER HERVORGEHOBENE KNOPF: Ein Häkchen in einer
            // Reihe grauer Wörter wäre eines von dreien. Die Füllung
            // sagt, welcher der Abschluss ist.
            Button { block.abschliessen() } label: {
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.bold))
                    .frame(minWidth: 30, minHeight: 30)
            }
            .buttonStyle(.borderedProminent)
            .tint(Farben.akzent)
            .disabled(block.fehlendePunkte > 0)
            .accessibilityLabel(Text("Linie fertig"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var entwurfstext: String {
        guard let entwurf = block.entwurf else { return "" }
        let fehlt = block.fehlendePunkte
        // DIE ART STEHT SEIT R92 IM MENUE DANEBEN und nicht mehr hier:
        // Zweimal dasselbe Wort in einer Leiste, die auf dem Telefon
        // ohnehin eng ist.
        if fehlt > 0 {
            // Ein ganzer Satz je Fall (R22): „noch ein Punkt" und „noch
            // 2 Punkte" gehen in anderen Sprachen nicht durch dieselbe
            // Fuge.
            return fehlt == 1
                ? String(localized: "noch ein Punkt")
                : String(localized: "noch \(fehlt) Punkte")
        }
        return String(localized: "\(entwurf.punkte.count) Punkte")
    }

    /// Die Leiste für eine ausgewählte Linie.
    ///
    /// **Das Namensfeld ist die zweite Hälfte von R25.** Die erste war,
    /// die Beschriftung überhaupt zu zeigen -- eintippen ließ sie sich
    /// danach immer noch nur im Browser. Wer am Spielfeldrand merkt, dass
    /// die Route falsch heißt, musste bis an den Schreibtisch.
    ///
    /// Es steht LINKS neben Ende und Papierkorb, nicht rechts: Es ist das
    /// einzige Feld hier, in das man schreibt, und die beiden anderen sind
    /// Griffe. Ein Textfeld zwischen zwei Knopfreihen wäre die Stelle, an
    /// der man den Papierkorb trifft, während man tippen wollte.
    /// Die Leiste für eine ausgewählte Linie.
    ///
    /// **DREI GRUPPEN, JEDE MIT IHRER ÜBERSCHRIFT (R61).** Niklas am
    /// 02.09.2026: „Die Linienleiste zeigt Sachen, die nicht
    /// zusammengehören." Auf einer Zeile standen die Beschriftung (ein
    /// Textfeld), drei Linienenden (eine Auswahl) und ein Papierkorb
    /// (eine unumkehrbare Handlung). Drei verschiedene Dinge, und das
    /// Textfeld war so schmal, dass sein eigenes Wort nicht
    /// hineinpasste.
    ///
    /// Jetzt: was die Linie IST, was sie HEISST, wie sie ENDET -- in
    /// dieser Reihenfolge, weil man sie so beantwortet.
    ///
    /// **Der Papierkorb steht oben rechts und nicht neben dem
    /// Textfeld.** Dieselbe Begründung wie in der Spielerleiste: Ein
    /// Feld, in das man tippt, direkt neben einem Knopf, der löscht,
    /// ist die Stelle, an der man den Papierkorb trifft, während man
    /// schreiben wollte.
    ///
    /// **Und er trägt ein Wort** (B1). Ein Papierkorb allein ist ein
    /// Zeichen ohne Hinweis, und die Untersuchung von Sadana,
    /// Agnihotri und Stasko (2018) misst dafür 1 von 16 gegen 14 von
    /// 16 für einen beschrifteten Weg.
    private func linienleiste(_ linie: Zeichnung.Linie) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // DIE ART WIRD HIER UMGESTELLT (R83). Vorher stand sie
                // als Text da und war nur beim ZEICHNEN waehlbar -- wer
                // sich vertan hatte, musste die Linie loeschen und neu
                // ziehen.
                //
                // Eine Zone bleibt Text: Sie ist eine Flaeche und laesst
                // sich nicht in einen Strich umstellen.
                if linie.art == .zone {
                    Text(linie.art.stil.lang)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Farben.ink)
                        .lineLimit(1)
                        .fixedSize()
                } else {
                    // JEDER EINTRAG ZEIGT SEINE LINIE (R90).
                    //
                    // Niklas am 09.09.2026, mit einem Bild des offenen
                    // Menüs: „sieht man nicht wie die Routen dann
                    // aussehen also so Vorschau mäßig. Zweitens ist das
                    // Menü jetzt nicht wirklich erkennbar".
                    //
                    // Beides stimmte. „Abschirmen" und „Passweg" sind
                    // Wörter; dass das eine mit einem Querstrich endet
                    // und das andere gepunktet ist, stand nur im
                    // Ausdruck. Und der zugeklappte Knopf sah aus wie
                    // Text, weil ihn nichts umgab.
                    //
                    // Das Bild kommt aus `Linienbild` und ist ein
                    // gerendertes `UIImage`: Ein Menüeintrag in iOS
                    // trägt einen Titel und ein BILD, eine gezeichnete
                    // Ansicht wird dabei plattgemacht.
                    artmenue(aktuell: linie.art) { block.artSetzen($0) }
                }
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    block.ausgewaehlteLinieLoeschen()
                } label: {
                    Label("Löschen", systemImage: "trash")
                        .font(.footnote)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Farben.fehler)
                .disabled(!darfZeichnen)
            }

            // „Beschriftung" heißt es auch im Browser (`linienName` in
            // editor.html). Ein kürzeres Wort wäre auf der schmalen
            // Leiste bequemer, und es wäre falsch: Dasselbe Feld unter
            // zwei Namen ist für den, der zwischen Schreibtisch und
            // Spielfeldrand wechselt, zweimal dasselbe Suchen.
            //
            // ÜBER DIE GANZE BREITE (R61): Bei 110 Punkten passte das
            // Wort „Beschriftung" nicht einmal als Platzhalter hinein.
            feldchen(name: String(localized: "Beschriftung"),
                     text: linie.beschriftung, breite: nil,
                     feld: .beschriftung,
                     erklaerung: String(localized: "steht an der Linie"),
                     // AUSDRÜCKLICH NICHT `.characters` wie bei Rolle und
                     // Kürzel (R9). Die beiden sind Codes -- „QB", „X".
                     // Eine Beschriftung ist ein Wort, das der Trainer
                     // ruft, und „GO DEEP" schreit auf dem Schirm.
                     gross: .words) {
                block.beschriftungSetzen($0)
            }

            // R75. DIE DREI GRUPPEN STEHEN NEBENEINANDER, NICHT
            // UNTEREINANDER.
            //
            // **Nachgerechnet, nicht geschätzt.** Untereinander kostete
            // jede Gruppe 58 Punkte (Überschrift 14, Knopf 44), die
            // Leiste zusammen über 300. Auf einem iPhone SE bleiben
            // nach Statusleiste, Titelzeile, Aktionsleiste und
            // Werkzeugleiste dann 187 Punkte fürs Feld -- genau
            // Niklas' Befund vom 03.09.2026: „Hast vielleicht ne Idee
            // wie wir das noch bisschen intuitiver machen können?"
            //
            // Nebeneinander in einer schiebbaren Zeile kostet die
            // Leiste 58 statt 174. Das Feld bekommt 116 Punkte zurück,
            // ohne dass etwas verschwindet: Was rechts hinausragt,
            // schiebt man heran, und der Überstand ist zu sehen.
            //
            // **UND AUSDRÜCKLICH KEIN AUFKLAPPEN.** Ein „Mehr"-Knopf
            // hätte dasselbe gespart und die Motion versteckt -- bei
            // Sadana, Agnihotri und Stasko (2018) findet ein
            // sichtbares Menü 14 von 16, eine verborgene Geste 1 von
            // 16. Geschoben wird sichtbar, geklappt nicht.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    // DER MOTION-VORLAUF (R45). Cyell: „Route in
                    // Segmente einteilen das man eine Motion haben kann
                    // + normale Route."
                    //
                    // Nur bei Linien mit mindestens drei Punkten und nie
                    // bei einer Zone -- sonst wäre es ein Menü ohne
                    // Einträge (ADR-0007). `linie.teilstellen`
                    // beantwortet beides an einer Stelle.
                    if linie.teilstellen > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            gruppentitel(String(localized: "Motion davor"),
                                         String(localized:
                                            "läuft vor dem Snap"))
                            motionmenue(linie)
                        }
                    }

                    // DIE OPTION AN EINEM PUNKT DER ROUTE (R68). Nur wo
                    // sie Sinn hat: eine Zone hat keine Punkte in
                    // diesem Sinn, und am ersten Punkt steht die Figur
                    // -- dort wäre es keine Option, sondern eine zweite
                    // Route.
                    if !block.optionstellen.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            gruppentitel(String(localized: "Option ab Punkt"),
                                         String(localized:
                                            "zweiter Weg von hier"))
                            optionsmenue
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        gruppentitel(String(localized: "Ende"),
                                     String(localized:
                                        "Pfeil, Strich oder offen"))
                        endeWahl(linie)
                    }
                }
                .padding(.trailing, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// Das Menü für den Motion-Vorlauf (R45).
    ///
    /// **Als eigene Eigenschaft, seit die drei Gruppen nebeneinander
    /// stehen (R75).** Drei verschachtelte Menüs in einer `HStack` in
    /// einer `ScrollView` sind für den Swift-Übersetzer ein einziger
    /// Ausdruck; er braucht dafür Minuten oder gibt auf („unable to
    /// type-check this expression in reasonable time"). Auf einem
    /// Läufer, den man nicht anfassen kann, ist das ein roter Bau ohne
    /// erkennbaren Grund.
    private func motionmenue(_ linie: Zeichnung.Linie) -> some View {
        Menu {
            Button {
                block.motionSetzen(0)
            } label: {
                if linie.motionBis == 0 {
                    Label("keine", systemImage: "checkmark")
                } else {
                    Text("keine")
                }
            }
            ForEach(1...max(1, linie.teilstellen), id: \.self) { bis in
                Button {
                    block.motionSetzen(bis)
                } label: {
                    // GEZÄHLT WIRD FÜR MENSCHEN: Intern ist es ein
                    // Index, im Menü steht die Nummer des Punktes, wie
                    // man sie auf dem Schirm abzählt.
                    if linie.motionBis == bis {
                        Label("bis Punkt \(bis + 1)",
                              systemImage: "checkmark")
                    } else {
                        Text("bis Punkt \(bis + 1)")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(linie.motionBis == 0
                     ? String(localized: "keine")
                     : String(localized: "bis Punkt \(linie.motionBis + 1)"))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .paarung(Paare.knopf, ecke: Masse.r1)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!darfZeichnen)
        .accessibilityLabel(Text("Motion davor"))
    }

    /// Das Menü, das eine Option an einem Punkt ansetzt (R68).
    private var optionsmenue: some View {
        Menu {
            ForEach(block.optionstellen, id: \.self) { stelle in
                Button {
                    block.optionAnsetzen(ab: stelle)
                } label: {
                    // GEZÄHLT WIRD FÜR MENSCHEN, wie beim
                    // Motion-Vorlauf.
                    Text("ab Punkt \(stelle + 1)")
                }
            }
        } label: {
            HStack(spacing: 4) {
                // „Option-Route" und nicht „Option ansetzen" (Niklas,
                // 08.09.2026). Der Name der Sache steht schon im
                // Regelwerk des Servers (`schema.LINIENARTEN`), und
                // zwei Namen für dieselbe Linie sind einer zu viel.
                Text("Option-Route")
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption2)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .paarung(Paare.knopf, ecke: Masse.r1)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!darfZeichnen)
        .accessibilityLabel(Text("Option ab Punkt"))
    }

    /// Die Leiste für eine ausgewählte Figur (R9).
    ///
    /// Gemeldet hat es Cyell am 25.08.2026: „man kann die Spieler nicht
    /// umbenennen, wenn man doch mal einen anderen Spieler haben
    /// möchte". Der Browser hat das seit dem 25.08.; die App hatte
    /// überhaupt keine Leiste für einen ausgewählten Spieler -- nur eine
    /// für eine ausgewählte Linie.
    ///
    /// **Zwei Felder, weil es zwei Dinge sind.** Die Rolle sagt, WER da
    /// steht; das Kürzel sagt, was im Kreis steht. Meistens sind sie
    /// gleich, und genau deshalb genügt das Kürzel allein nicht: Cyells
    /// Fall ist der andere. Die Rolle steht links, weil sie die Frage
    /// ist, die man zuerst beantwortet -- dieselbe Reihenfolge wie im
    /// Positionsblock des Browsers.
    private func spielerleiste(_ spieler: Zeichnung.Spieler) -> some View {
        // ZWEI ZEILEN SEIT R41. Die Notiz ist ein Satz und kein Code;
        // neben zwei Kürzelfeldern und der Farbe hätte sie die Breite
        // eines Wortes gehabt.
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(EditorAnsicht.seitenname(spieler.seite))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Farben.inkStill)
                    .accessibilityHidden(true)
                feldchen(name: String(localized: "Position"),
                         text: spieler.rolle, breite: 74,
                         feld: .position) {
                    block.rolleSetzen($0)
                }
                .overlay(alignment: .topTrailing) { rollenmenue(spieler) }
                feldchen(name: String(localized: "Kürzel"),
                         text: spieler.kuerzel, breite: 52,
                         feld: .kuerzel) {
                    block.kuerzelSetzen($0)
                }
                Spacer(minLength: 0)
                farbwahl(spieler)
                // WEGNEHMEN STEHT BEIM SPIELER und nicht in der
                // Werkzeugleiste: Es betrifft genau den einen, der
                // gerade ausgewählt ist. Ein Papierkorb oben wäre eine
                // Frage („welchen?"), die niemand stellen will.
                if darfZeichnen {
                    Button(role: .destructive) {
                        block.spielerWeg(spieler.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.footnote)
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Farben.fehler)
                    .accessibilityLabel(Text("Spieler entfernen"))
                }
            }
            // DIE NOTIZ JE SPIELER (R41). Cyell am 01.09.2026: „sowie
            // Player Notizen zu jedem Spieler (Route etc.)."
            //
            // `.sentences` und nicht `.characters`: Rolle und Kürzel
            // sind Codes, das hier ist ein Satz.
            feldchen(name: String(localized: "Notiz"),
                     text: spieler.notiz, breite: nil,
                     feld: .notiz,
                     erklaerung: String(localized:
                        "nur zu diesem Spieler"),
                     gross: .sentences) {
                block.notizSetzen($0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// Die Farbe der ausgewählten Figur (R43).
    ///
    /// Niklas am 01.09.2026: „Farben der Spieler noch änderbar machen."
    /// Das Modell trug sie durch, gezeichnet wurde sie -- nur setzen
    /// liess sie sich allein im Browser.
    ///
    /// **EIN MENÜ UND KEINE REIHE VON TUPFERN.** Daneben stehen schon
    /// zwei Textfelder; fünfzehn Tupfer à 28 Punkte drängten sie auf
    /// einem iPhone SE aus der Zeile. Ein Menü ist ausserdem der Weg,
    /// den Menschen von selbst finden: 14 von 16 bei Sadana, Agnihotri
    /// und Stasko (2018), gegen 1 von 16 für eine Wischgeste.
    ///
    /// **DER TUPFER STEHT DAVOR**, damit man ohne Öffnen sieht, was
    /// gilt. Bei „Standard" trägt er die Farbe der SEITE und nicht Grau:
    /// Was ohne eigene Farbe gezeichnet wird, ist nicht farblos.
    private func farbwahl(_ spieler: Zeichnung.Spieler) -> some View {
        Menu {
            // EIN `Picker` UND KEINE REIHE VON KNÖPFEN (R66). Der Haken
            // sagt, was gilt -- ein Menü ohne ihn ist eine Liste von
            // Angeboten, aus der man den eigenen Stand nicht ablesen
            // kann. Vom System gesetzt sitzt er dort, wo iOS ihn in
            // jedem anderen Menü setzt, UND die Zeile behält daneben
            // ihren Platz fürs Symbol. Genau den braucht der Farbpunkt:
            // Von Hand gesetzt belegte der Haken ihn.
            Picker(String(localized: "Farbe der Figur"),
                   selection: Binding(
                    get: { spieler.farbe ?? "" },
                    set: { block.farbeSetzen($0) })) {
                ForEach(Positionsfarbe.alle) { farbe in
                    Label {
                        Text(farbe.name)
                    } icon: {
                        // ÜBER `figurfarbe` wie der Tupfer am Knopf:
                        // Der Punkt im Menü verspricht, was gleich auf
                        // dem Feld steht. Bei „Standard" ist das die
                        // Farbe der Seite und nicht Grau.
                        Image(uiImage: Farbtupfer.bild(
                            Feldansicht.figurfarbe(wert: farbe.wert,
                                                   seite: spieler.seite)))
                    }
                    .tag(farbe.wert)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                // ÜBER `Feldansicht.figurfarbe` und nicht über eine
                // eigene Rechnung: Der Tupfer muss zeigen, was auf dem
                // Feld steht. Zwei Rechnungen für dieselbe Frage geben
                // irgendwann zwei Antworten.
                Circle()
                    .fill(Feldansicht.figurfarbe(spieler))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Farben.linie, lineWidth: 1))
                Text("Farbe")
            }
            .font(.footnote)
            .foregroundStyle(Farben.ink)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!darfZeichnen)
        .accessibilityLabel(Text("Farbe der Figur"))
        .accessibilityValue(
            Text(Positionsfarbe.name(fuer: spieler.farbe)))
    }

    /// Ein kleines Textfeld mit seiner Beschriftung darüber.
    ///
    /// **Die Beschriftung steht da und ist nicht nur ein Platzhalter.**
    /// Ein Platzhalter verschwindet, sobald etwas drinsteht -- und dann
    /// stehen zwei kurze Felder nebeneinander, in denen „X" und „X"
    /// steht, ohne dass irgendwo sagt, welches welches ist.
    ///
    /// Geschrieben wird über den Block und nicht in den Spieler:
    /// `Zeichnung.Spieler` ist ein Wert, eine Kopie davon zu ändern
    /// änderte die Zeichnung nicht. Der Block kürzt dabei auf das Maß
    /// des Servers und zählt `stand` hoch, damit die Fußzeile
    /// „Ungesichert" sagt.
    ///
    /// `gross` sagt, wie die Tastatur groß schreibt. Rolle und Kürzel sind
    /// Codes und stehen in Versalien; eine Beschriftung ist ein Wort (R25).
    /// `breite: nil` heißt „nimm, was da ist" (R61). Die
    /// Beschriftung einer Linie braucht die ganze Zeile; Rolle und
    /// Kürzel sind Codes aus zwei Zeichen und stehen nebeneinander.
    /// Die Überschrift einer Gruppe, mit der kurzen Erklärung dahinter
    /// (R64).
    ///
    /// **In derselben Zeile und nicht darunter.** Niklas am 03.09.2026,
    /// mit einem Kringel um Beschriftung, „Motion davor" und Ende:
    /// „Sollte vielleicht ganz kurz erklärt werden." Drei zusätzliche
    /// Zeilen nähmen dem Feld genau die Höhe, um die es in R75 geht --
    /// also steht die Erklärung hinter dem Wort, stiller gesetzt, und
    /// bricht nur um, wenn sie muss.
    ///
    /// **Knapp heisst hier drei bis vier Wörter.** Was länger ist,
    /// gehört in die Hilfe (R70); was hier steht, muss man im Vorbeigehen
    /// lesen können.
    private func gruppentitel(_ name: String,
                              _ erklaerung: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Farben.inkStill)
            Text(erklaerung)
                .font(.caption2)
                .foregroundStyle(Farben.inkStill.opacity(0.7))
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// `feld` sagt, welcher Fokus dazugehört (R63). Ohne ihn liesse
    /// sich die Tastatur nur schliessen, indem man rät, wo „daneben"
    /// ist.
    ///
    /// `erklaerung` ist die kurze Zeile aus R64. Sie steht nur an den
    /// Feldern über die ganze Breite: Neben „Kürzel" auf 52 Punkten
    /// bräche sie um und kostete die Zeile, die sie sparen soll.
    /// Die Positionen dieser Spielform zum Antippen.
    ///
    /// **Der Browser bietet sie seit dem 07.09.2026 an, die App nicht**
    /// (Audit 08.09.). In einem Elfer-Playbook musste man LT, LG, RG,
    /// RT, TE, RB und SL von Hand tippen -- auf einem Telefon, am
    /// Spielfeldrand.
    ///
    /// **Ein Menü und kein Vorschlagsstreifen.** Ein `datalist` wie im
    /// Browser gibt es in SwiftUI nicht, und eine Chipreihe unter dem
    /// Feld hätte die Leiste um eine Zeile wachsen lassen -- die
    /// Zeichenfläche ist auf einem Telefon das Knappste, was es hier
    /// gibt. Das Menü sitzt IM Feld, oben rechts, und kostet nichts,
    /// solange niemand es öffnet.
    ///
    /// **Freier Text bleibt freier Text.** Wer seine Position anders
    /// nennt, tippt sie weiter; das Menü schlägt vor und erzwingt
    /// nichts. Deshalb steht auch die belegte Rolle noch darin: Zwei
    /// Spieler dürfen dieselbe tragen, wenn der Trainer das so will.
    @ViewBuilder
    private func rollenmenue(_ spieler: Zeichnung.Spieler) -> some View {
        let form = block.projektion.form
        let rollen = spieler.seite == .defense ? form.rollenDefense
                                               : form.rollenOffense
        if darfZeichnen, !rollen.isEmpty {
            Menu {
                ForEach(rollen, id: \.self) { rolle in
                    Button(rolle) { block.rolleSetzen(rolle) }
                }
            } label: {
                // `ellipsis.circle` UND NICHT `chevron.down`, und das
                // ist keine Geschmacksfrage: `test_sichtbare_wege`
                // führt eine Liste der Zeichen, die ohne Wort stehen
                // dürfen, jedes mit Begründung. Der Chevron steht nicht
                // darauf, `ellipsis.circle` schon -- „in iOS die
                // eingeführte Form für ein sichtbares Menü". Genau das
                // ist es hier.
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Farben.inkStill)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Position wählen"))
        }
    }

    private func feldchen(name: String, text: String, breite: CGFloat?,
                          feld: Schreibfeld,
                          erklaerung: String? = nil,
                          gross: TextInputAutocapitalization = .characters,
                          setzen: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Group {
                if let erklaerung {
                    gruppentitel(name, erklaerung)
                } else {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(Farben.inkStill)
                }
            }
            .accessibilityHidden(true)
            TextField(name, text: Binding(get: { text }, set: setzen))
                .font(.footnote.weight(.semibold))
                .textInputAutocapitalization(gross)
                .autocorrectionDisabled()
                .focused($schreibfeld, equals: feld)
                // ZWEI WEGE HERAUS, und der zweite kostet nichts: Die
                // Eingabetaste heisst „Fertig" und schliesst ebenfalls.
                // Wer sie drückt, meint genau das.
                .submitLabel(.done)
                .onSubmit { schreibfeld = nil }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .paarung(Paare.knopf, ecke: Masse.r1)
                .frame(width: breite, alignment: .leading)
                .frame(maxWidth: breite == nil ? .infinity : nil,
                       alignment: .leading)
                // R6: Ein gesperrter Play lässt sich nicht ändern, und
                // ein Feld, das man beschreiben kann, während der Server
                // mit 423 antwortet, ist ein Weg, Arbeit zu verlieren.
                .disabled(!darfZeichnen)
                .accessibilityLabel(name)
                // Die Erklärung ist für das Auge versteckt (sie steht
                // oben), für den Vorleser aber der Hinweis zum Feld --
                // sonst wäre sie für ihn gar nicht da.
                .accessibilityHint(erklaerung.map { Text($0) } ?? Text(""))
        }
        // AUSDRÜCKLICH KEIN `accessibilityElement(children: .combine)`.
        // Das fasst die Beschriftung und das Feld zu EINEM Element
        // zusammen -- und ein zusammengefasstes Element ist statischer
        // Text, den VoiceOver vorliest und nicht beschreiben lässt. Die
        // Beschriftung ist deshalb versteckt und steht statt dessen am
        // Feld selbst.
    }

    /// „Von 18:42" statt „vorhin" (R110.4).
    ///
    /// **Die Uhrzeit beantwortet die eigentliche Frage:** Ist das noch
    /// meins? Ein blosses „es liegt etwas" beantwortet sie nicht --
    /// und wer nicht weiss, wie alt der Stand ist, verwirft im
    /// Zweifel.
    ///
    /// `nil` gibt es hier nicht als Fall: Ohne Zeitpunkt steht ein Wort
    /// da und keine leere Stelle.
    static func wann(_ zeitpunkt: Date?) -> String {
        guard let zeitpunkt else { return String(localized: "Vorhin") }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        // IN EINE EIGENE VARIABLE. `appsprache.py` schlaegt jede
        // Interpolation in einer Liste nach -- geraten wird dort
        // nichts, weil ein falscher Platzhalter sich nirgends zeigt
        // ausser auf einem fremdsprachigen Telefon. Ein
        // `\(f.string(from:))` mitten im Satz ist kein Name.
        let zeitwort = f.string(from: zeitpunkt)
        return String(localized: "Am \(zeitwort)")
    }

    /// Offense oder Defense -- als ganzer Wert und nicht als
    /// Bedingungsausdruck mit zwei blanken Literalen (R22): Ein
    /// `bedingung ? "a" : "b"` ist ein `String`-Ausdruck und geht an der
    /// Übersetzung vorbei, ohne dass es irgendwo auffällt.
    static func seitenname(_ seite: Zeichnung.Spieler.Seite) -> String {
        switch seite {
        case .offense: return String(localized: "Offense")
        case .defense: return String(localized: "Defense")
        }
    }

    /// Das Ende ist der Unterschied zwischen einer Route und einem
    /// Abschirmen -- beide durchgezogen, nur Pfeil gegen Querstrich.
    private func endeWahl(_ linie: Zeichnung.Linie) -> some View {
        HStack(spacing: 6) {
            ForEach(Zeichnung.Linie.Ende.allCases, id: \.rawValue) { ende in
                let gewaehlt = linie.ende == ende
                Button {
                    block.endeSetzen(ende)
                } label: {
                    Text(EditorAnsicht.endeName(ende))
                        .font(.caption.weight(.semibold))
                        // NIE UMBRECHEN. Auch mit der zweiten Zeile
                        // darüber: Eine schmalere Sprache oder ein
                        // größerer Schriftgrad bringt die Enge zurück,
                        // und dann steht wieder „of-fen" da. Lieber
                        // schiebt die Zeile seitlich.
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .paarung(gewaehlt ? Paare.knopfHaupt : Paare.knopf,
                                 in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(gewaehlt ? [.isSelected] : [])
            }
        }
    }

    /// Die Namen aus `schema.LINE_ENDS`, auf die Kurzform gebracht: In
    /// einer Zeile ist kein Platz für „Pfeil -- Laufweg oder Route".
    ///
    /// **Die drei Namen gehen durch die Übersetzung.** Das Ergebnis ist
    /// ein `String`, und `endeWahl` zeigt es als
    /// `Text(EditorAnsicht.endeName(ende))`; `Text` schlägt bei einem
    /// `String` nichts nach. Die drei Knöpfe unter der ausgewählten
    /// Linie standen deshalb in jeder Sprache auf Deutsch. Die Wörter
    /// sind dieselben wie im Browser („Pfeil, Strich oder offen").
    static func endeName(_ ende: Zeichnung.Linie.Ende) -> String {
        switch ende {
        case .arrow: return String(localized: "Pfeil")
        case .tee: return String(localized: "Querstrich")
        case .none: return String(localized: "offen")
        }
    }

    /// Sie steht dort, wo sonst die Werkzeuge stehen (R6).
    ///
    /// Nicht als Meldung, die nach vier Sekunden verschwindet: Wer einen
    /// gesperrten Play aufmacht und nichts bewegen kann, muss jederzeit
    /// sehen, warum -- und wen er fragen kann.
    private var sperrleiste: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundStyle(Farben.warnung)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Fertig und gesperrt")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Farben.ink)
                if let wer = gesperrtVon {
                    Text("von \(wer)")
                        .font(.caption)
                        .foregroundStyle(Farben.inkStill)
                }
            }
            Spacer()
            if darfAendern {
                // Durch die Übersetzung: Im Fragezeichenausdruck
                // sammelt `appsprache.py` nichts ein, und „Entsperren"
                // stand in keinem Katalog. Der einzige Knopf, mit dem
                // ein fertiger Play wieder aufgeht, war damit in vier
                // Sprachen deutsch.
                Button(sperrtGerade ? "…" : String(localized: "Entsperren")) {
                    Task { await sperreSetzen(false) }
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(Farben.akzent)
                .disabled(sperrtGerade)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Farben.flaechePanel)
    }

    private var ruheleiste: some View {
        HStack(spacing: 12) {
            // AUSDRUECKLICH UEBERSETZT (30.09.2026). Hier stand
            // `Text(etwasOffen ? "Ungesichert" : "Gesichert")`. SwiftUI
            // nimmt dabei zwar den lokalisierenden Bauweg, aber der
            // Einsammler fand die beiden Woerter nie: Er sucht
            // `Text("…")` und `String(localized:)`, nicht die Zweige
            // eines Bedingungsausdrucks. Also standen sie in KEINEM
            // Katalog, und der englische Editor sagte „Gesichert".
            //
            // Aufgefallen auf einem Bildschirmfoto des englischen
            // Bilderlaufs -- daneben stand „Route", „Zone", „Curve".
            Text(etwasOffen ? String(localized: "Ungesichert")
                            : String(localized: "Gesichert"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(etwasOffen ? Farben.fehler : Farben.inkStill)
                .layoutPriority(1)
            Text(hinweis)
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            angabenknopf
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// Der Weg zu Name, Nummer, Seite, Kategorie, Situationen, Hinweise.
    ///
    /// **MIT WORT UND NICHT NUR MIT ZEICHEN**, und das ist hier der
    /// ganze Punkt. Die Untersuchung von Sadana, Agnihotri und Stasko
    /// (2018) hat gemessen, was Menschen in einer fremden App von
    /// selbst finden: einen Eintrag in einem sichtbaren Menü 14 von 16
    /// Mal, eine Wischgeste 1 von 16, eine zusammengesetzte Geste 0 von
    /// 16. Ein Zahnrad oder drei Punkte liegen dazwischen -- aber
    /// „Play" mit einem Winkel dahinter liest sich ohne Raten.
    ///
    /// **WARUM HIER UND NICHT IN DER WERKZEUGLEISTE OBEN.** Die ist
    /// voll; auf Niklas' Bildschirmfoto vom 02.09.2026 stand dort schon
    /// „Sic…" statt „Sichern" (R57). Ein sechster Knopf hätte den
    /// nächsten aus dem Bild gedrängt.
    ///
    /// **WARUM ER AUCH OHNE ÄNDERUNGSRECHT DASTEHT.** Er ist dann kein
    /// toter Knopf im Sinne von ADR-0007: Das Blatt ZEIGT die Angaben
    /// weiterhin, nur ändern lässt sich nichts. Für jemanden, der einen
    /// Play am Spielfeldrand nachschlägt, ist genau das der Zweck.
    private var angabenknopf: some View {
        Button {
            // Eine angefangene Linie erst zu Ende denken lassen: Das
            // Blatt legt sich sonst über eine halbe Route, und beim
            // Zurückkommen weiß niemand mehr, wo er war.
            block.abbrechen()
            zeigtAngaben = true
        } label: {
            HStack(spacing: 4) {
                Text("Play")
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Farben.linie, in: Capsule())
            .foregroundStyle(Farben.ink)
            // 44 Punkte in der Höhe, auch wenn die Kapsel kleiner
            // aussieht: WCAG 2.5.8 und Apples eigene Vorgabe. Getroffen
            // wird die Fläche, gesehen die Kapsel.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Angaben zum Play"))
        .accessibilityHint(
            Text("Name, Nummer, Seite, Kategorie, Situationen, Hinweise"))
    }

    /// Was gerade zu tun ist -- und was der Fang tut.
    ///
    /// Hier stand vorher unbedingt „Raster: halbe Yards". Das war schon
    /// damals der richtige Gedanke (R5: der Fang muss SICHTBAR sein,
    /// sonst hält man das Wandern des Punktes für einen Fehler), nur
    /// ließ sich nichts daran ändern. Jetzt sagt die Zeile den Stand des
    /// Schalters.
    /// Was in der Ruheleiste rechts steht.
    ///
    /// **DER LEERZUSTAND IST DIE BEDIENUNGSANLEITUNG (B14).** Von Flag
    /// Forge abgeschaut und in der Recherche vom 02.09.2026 als das
    /// billigste Mittel des ganzen Feldes bewertet: Wo noch nichts
    /// steht, ist Platz für den Satz, der sagt, wie etwas hinkommt.
    ///
    /// Ein frisch angelegter Play hat die Startaufstellung und keine
    /// einzige Linie. Bis hierher stand dort „Raster: halbe Yards" --
    /// eine Zustandsanzeige für jemanden, der noch gar nicht weiss,
    /// dass man auf eine Figur tippt.
    ///
    /// **Es verdrängt nichts.** Sobald die erste Linie steht, ist der
    /// Satz weg und die Rasteranzeige wieder da. Und er steht nur in
    /// der Ruhe: Wer gerade zeichnet, bekommt den Entwurfstext.
    private var hinweis: String {
        if block.zeichnung.linien.isEmpty, darfZeichnen,
           block.werkzeug == .auswahl {
            return String(localized: "Auf eine Figur tippen, dann den Weg")
        }
        let raster = block.fang
            ? String(localized: "Raster: halbe Yards")
            : String(localized: "Fang aus")
        switch block.werkzeug {
        case .auswahl:
            guard block.ausgewaehlteLinie != nil else { return raster }
            // Zwei fertige Angaben nebeneinander, kein Satz: Das „ · "
            // trennt, es fügt nicht.
            return raster + " · " + String(localized: "Punkte ziehen")
        case .linie(let art):
            return String(localized:
                "\(art.stil.kurz): auf eine Position tippen")
        }
    }

    // MARK: - Laden und Sichern

    /// Der Ausschnitt für DIESEN Play.
    ///
    /// **`passendFuer` genau einmal, beim Laden** (R48). Der Ausschnitt
    /// muss weit genug für den geladenen Play sein -- sonst zeichnet
    /// man eine Go-Route und sieht ihr Ende nicht.
    ///
    /// Er darf sich aber NICHT bei jedem Zug neu rechnen: Dann rückte
    /// das ganze Feld unter dem Finger weg, sobald ein Punkt über die
    /// bisherige Kante hinausgeht. Wer eine Linie zieht, will die Linie
    /// wandern sehen und nicht das Feld.
    private func projektion(_ voll: Modell.PlayVoll) -> Projektion {
        Projektion.fuerDieApp(feld: voll.feld, los: voll.los,
                              richtung: voll.richtung,
                              spielform: voll.spielform)
            .passendFuer(voll.zeichnung)
    }

    private func laden() async {
        spur("editor", "offen")
        laedt = true
        fehler = nil
        do {
            let voll = try await Laden(anmeldung: anmeldung).play(play.id)
            block = Zeichenblock(zeichnung: voll.zeichnung,
                                 projektion: projektion(voll))
            // Der neue Block kennt den Bildschirm noch nicht. Ohne diese
            // Zeile bliebe das Feld nach dem Laden ungedehnt: Die Groesse
            // aendert sich dabei ja nicht, also meldet sich `onChange`
            // nicht mehr -- und das Feld saesse wieder klein in der Mitte.
            block.flaecheSetzen(flaeche)
            anmerkungen = voll.anmerkungen
            version = voll.version
            playbookId = voll.playbook
            darfAendern = voll.darfAendern
            gesperrt = voll.gesperrt
            gesperrtVon = voll.gesperrtVon
            // BEIDE STÄNDE AUS DEMSELBEN PLAY (B7). Gleich heißt
            // „nichts offen", und genau das stimmt direkt nach dem
            // Laden.
            block.angaben = Playangaben.Stand(von: voll)
            angabenGesichert = block.angaben
            // ERST JETZT (R110.4). Vorher steht der Stand des Servers
            // noch nicht, und ohne ihn liesse sich nicht sagen, ob der
            // Entwurf ueberhaupt etwas Neues traegt.
            entwurfPruefen(voll)
        } catch Server.Fehler.abgemeldet {
            // ALS EINZIGE ANSICHT HAT DER EDITOR DAS NICHT GEFANGEN.
            // Gezaehlt am 02.09.2026: 15 Ansichten fangen
            // `Server.Fehler.abgemeldet` und melden sich ab, der Editor
            // nicht. Wessen Anmeldung ablaeuft, bekam hier „Nochmal
            // versuchen" -- und das klappt nie, weil das Token weg ist.
            await anmeldung.abmelden()
        } catch {
            // UEBER `Fehlertext`, nicht ueber `localizedDescription`.
            // Der Kopf von `Fehlertext.swift` erklaert, warum alles durch
            // diesen Trichter muss: Ein Entschluesselungsfehler kommt
            // sonst als englischer Foundation-Satz heraus, mitten in
            // einer deutschen App.
            fehler = Fehlertext.von(error)
        }
        laedt = false
        await kategorienLaden()
    }

    /// Die Kategorien des Heftes für das Angabenblatt.
    ///
    /// **Nach dem Play und nicht davor**, weil erst der Play sagt, in
    /// welchem Heft er steht. Und in einem eigenen `do`, das nichts
    /// meldet: Wer den Editor aufmacht, will zeichnen. Eine
    /// Fehlermeldung über Kategorien, die den ganzen Editor durch
    /// „Nochmal versuchen" ersetzt, wäre die falsche Antwort auf eine
    /// Nebensache -- der Abschnitt im Blatt fehlt dann eben, und alles
    /// andere geht weiter.
    private func kategorienLaden() async {
        guard let heft = playbookId else { return }
        kategorien = (try? await Laden(anmeldung: anmeldung)
            .kategorien(playbook: heft)) ?? []
    }

    /// Kurz warten, dann von selbst sichern (R91).
    ///
    /// **1,1 Sekunden, dieselbe Zahl wie im Browser.** Sie ist lang
    /// genug, dass ein Weg mit fünf Knicken EINE Sicherung ergibt und
    /// nicht fünf, und kurz genug, dass niemand das Telefon weglegt,
    /// bevor sie kommt.
    ///
    /// **Läuft schon eine Sicherung, wird nicht gedrängelt.** Zwei
    /// gleichzeitige Sicherungen tragen dieselbe Fassungsnummer, und die
    /// zweite käme als Konflikt zurück -- der Play stritte mit sich
    /// selbst. Stattdessen wird neu angeklopft.
    ///
    /// Wer nicht zeichnen darf, wessen Play gesperrt ist oder wer gerade
    /// einen Konflikt vor sich hat, sichert nicht von selbst: In allen
    /// drei Fällen ist die Frage, was gelten soll, noch offen.
    private func spaeterSichern() {
        guard darfZeichnen, !gesperrt, konflikt == nil, !laedt else { return }
        // ERST INS LAGER, DANN ZUM SERVER (R110.4).
        //
        // SOFORT und nicht nach den 1,1 Sekunden: Genau in dieser
        // Lücke geht Arbeit verloren -- die App wird weggewischt, der
        // Akku ist leer, das iPhone entlädt sie aus dem Speicher. Der
        // Browser legt seinen Entwurf aus demselben Grund vor dem
        // Absenden weg (R4).
        entwurfAblegen()
        sicherWarten?.cancel()
        sicherWarten = Task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            guard darfZeichnen, !gesperrt, konflikt == nil, !laedt,
                  etwasOffen else { return }
            if sichert {
                spaeterSichern()
                return
            }
            // AB HIER IST DIESE SICHERUNG NICHT MEHR ABBRECHBAR
            // (30.09.2026).
            //
            // **Der Fund bei einem echten Nutzer.** Im Protokoll stand
            // „PUT 200" und eine Sekunde spaeter „PUT 409" -- die App
            // schickte eine Fassungsnummer, die der Server schon
            // weitergezaehlt hatte.
            //
            // Der Grund steht zwei Zeilen weiter oben: Jede Aenderung
            // ruft `spaeterSichern()`, und das beginnt mit
            // `sicherWarten?.cancel()`. Solange die Aufgabe noch
            // schlaeft, ist das genau richtig -- das ist die
            // Entprellung. Ist sie aber schon INNEN, also mitten im
            // `await sichern()`, bricht der Abbruch die laufende
            // Netzanfrage ab: Der Server hat gespeichert und die
            // Fassung hochgezaehlt, die App erfaehrt die neue nie. Die
            // naechste Sicherung traegt die alte -- und bekommt 409.
            //
            // Die Handgriffe sind nicht verloren (die App liest neu und
            // macht weiter), aber der Inhalt GENAU DIESER Sicherung
            // wird verworfen. Beim naechsten Mal ist das vielleicht
            // einer, den niemand gleich darauf ueberschreibt.
            //
            // `sicherWarten = nil` gibt den Griff aus der Hand, bevor
            // die Anfrage losgeht. Ein spaeteres `cancel()` trifft dann
            // ins Leere und die Entprellung beginnt von vorn -- genau
            // so, wie es gemeint war.
            //
            // BEIDE ZEILEN LAUFEN AUF DEM HAUPTAKTOR und ohne `await`
            // dazwischen. Zwischen der Pruefung und dem Loslassen kann
            // sich also nichts dazwischenschieben.
            sicherWarten = nil
            await sichern()
        }
    }

    /// Den ungesicherten Stand auf dem Geraet ablegen (R110.4).
    ///
    /// **Alles, was der Verlauf traegt**, geht mit: Zeichnung, Lage des
    /// Balls, Angriffsrichtung und die Playangaben. Ein Entwurf, der
    /// nur die Zeichnung rettet, rettet die Haelfte -- und die andere
    /// fehlt danach, ohne dass es jemandem auffaellt.
    private func entwurfAblegen() {
        Entwurfslager.merken(Entwurfslager.Entwurf(
            play: play.id, version: version, zeit: Date(),
            zeichnung: block.zeichnung,
            los: block.projektion.los,
            richtung: block.projektion.richtung,
            angaben: block.angaben))
    }

    /// Liegt hier noch etwas, das nie beim Server ankam? (R110.4)
    ///
    /// **Gerechnet wird in `Entwurfslager.befund`** und nicht hier --
    /// es gibt keinen Mac, und eine Regel in einer SwiftUI-Ansicht
    /// laesst sich nicht ausprobieren, sondern nur behaupten.
    private func entwurfPruefen(_ voll: Modell.PlayVoll) {
        guard darfZeichnen else { return }
        switch Entwurfslager.befund(fuer: play.id, serverVersion: voll.version,
                                    serverZeichnung: voll.zeichnung) {
        case .nichts:
            // Nichts anzubieten heisst auch: nichts liegen lassen.
            Entwurfslager.vergessen(play: play.id)
        case .anbieten(let entwurf):
            offenerEntwurf = entwurf
        case .veraltet(let entwurf):
            // JEMAND ANDERES HAT INZWISCHEN GESPEICHERT. Das ist ein
            // Konflikt und keine Wiederherstellung: Wer den Entwurf
            // hier stillschweigend zurueckspielte, ueberschriebe fremde
            // Arbeit. Angeboten wird er trotzdem -- die Frage lautet
            // dann nur anders.
            offenerEntwurf = entwurf
            entwurfVeraltet = true
        }
    }

    private func sichern() async {
        // Eine angefangene Linie gehört noch nicht in den Play. Sie hier
        // stillschweigend mitzuspeichern hieße, eine halbe Anweisung ins
        // Playbook zu schreiben.
        sichert = true
        defer { sichert = false }
        // WELCHER STAND JETZT LOSGEHT -- gelesen VOR dem `await` und nicht
        // danach. Zwischen Absenden und Antwort liegt im Mobilfunk mehr
        // als eine Sekunde, und in dieser Zeit wird gezeichnet. Siehe
        // `Zeichenblock.stand` (R4, gemeldet 25.08.2026).
        let losgeschickt = block.stand
        // AUCH DIE ANGABEN VOR DEM `await` (B7), aus demselben Grund wie
        // der Zeichenstand: Zwischen Absenden und Antwort wird getippt,
        // und was danach als „gesichert" gilt, muss der Stand sein, der
        // wirklich losgeschickt wurde -- nicht der, der beim Eintreffen
        // der Antwort auf dem Bildschirm steht.
        let angabenLos = block.angaben
        // WO DER BALL LIEGT, GEHT IMMER MIT (R110.3).
        //
        // Nicht nur bei Aenderung: `los` und `richtung` stehen im
        // `Zeichenblock` und nicht in `angaben`, es gibt hier also
        // keinen „gesicherten" Vergleichsstand, an dem sich ein
        // Unterschied ablesen liesse. Den einen zu fuehren waere ein
        // zweiter Stand neben dem Block -- und der ist die Wahrheit
        // dieses Bildschirms.
        //
        // Ueberschrieben wird dabei nichts Fremdes: Die Version im
        // Rumpf ist die Zusicherung „ich habe genau das bearbeitet,
        // was ich gelesen habe", und der Server lehnt mit 409 ab, wenn
        // sie nicht mehr stimmt.
        var mitLage = angabenLos.unterschied(zu: angabenGesichert)
        mitLage.los = block.projektion.los
        mitLage.richtung = block.projektion.richtung
        do {
            switch try await Laden(anmeldung: anmeldung).sichern(
                play: play.id, zeichnung: block.zeichnung, version: version,
                eigenschaften: mitLage) {
            case .gespeichert(let neue, let neueAnmerkungen):
                version = neue
                block.gesichert(bis: losgeschickt)
                angabenGesichert = angabenLos
                // ERST JETZT RAEUMEN (R110.4), und nur hier. Ein
                // Lager, das beim Verlassen des Bildschirms raeumt,
                // raeumt genau im Funkloch auf -- also in dem Fall,
                // fuer den es da ist.
                if block.geaendert == false {
                    Entwurfslager.vergessen(play: play.id)
                }
                // NACH JEDEM SICHERN NEU, nicht nur beim Laden. Wer
                // einen Spieler ins Backfield zieht und sichert, soll
                // die Auskunft zu SEINER Aufstellung sehen und nicht
                // die von vorhin.
                anmerkungen = neueAnmerkungen
            case .konflikt(let fremd):
                konflikt = fremd
            case .gesperrt(let wer):
                // Jemand anderes hat den Play inzwischen fertig gemeldet.
                //
                // DIE ZEICHNUNG BLEIBT, WIE SIE IST. Dieselbe Lehre wie
                // aus R4: Was nicht am Server ist, wird nicht
                // weggeworfen, nur weil eine Anfrage abgelehnt wurde.
                // `etwasOffen` bleibt wahr, die Rückfrage beim
                // Zurückgehen greift also weiter.
                gesperrt = true
                gesperrtVon = wer
            }
        } catch Server.Fehler.abgemeldet {
            // ALS EINZIGE ANSICHT HAT DER EDITOR DAS NICHT GEFANGEN.
            // Gezaehlt am 02.09.2026: 15 Ansichten fangen
            // `Server.Fehler.abgemeldet` und melden sich ab, der Editor
            // nicht. Wessen Anmeldung ablaeuft, bekam hier „Nochmal
            // versuchen" -- und das klappt nie, weil das Token weg ist.
            await anmeldung.abmelden()
        } catch {
            // UEBER `Fehlertext`, nicht ueber `localizedDescription`.
            // Der Kopf von `Fehlertext.swift` erklaert, warum alles durch
            // diesen Trichter muss: Ein Entschluesselungsfehler kommt
            // sonst als englischer Foundation-Satz heraus, mitten in
            // einer deutschen App.
            fehler = Fehlertext.von(error)
        }
    }

    /// Die eigene Zeichnung als eigener Play daneben.
    ///
    /// **Der Ausgang aus dem Konflikt, bei dem niemand etwas verliert.**
    /// Zwei Schritte, beide über Wege, die es längst gibt: einen Play
    /// anlegen, dann die Zeichnung hineinschreiben. `anlegen` schickt
    /// bewusst keine Zeichnung mit -- der Server setzt dann die
    /// Startaufstellung, und die wird gleich darauf überschrieben.
    ///
    /// **Der Name sagt, was passiert ist.** „Spread Mesh (meine
    /// Fassung)" findet man wieder; „Spread Mesh (2)" sieht aus wie ein
    /// Versehen. Ist der Name schon vergeben, hängt der Server selbst
    /// eine Zahl an -- dann heißt er eben „… (meine Fassung) (2)", und
    /// auch das ist noch lesbar.
    private func alsNeuenPlaySichern() async {
        guard let heft = playbookId else { return }
        konflikt = nil
        sichert = true
        defer { sichert = false }
        let losgeschickt = block.stand
        do {
            let name = String(localized: "\(play.titel) (meine Fassung)")
            switch try await Laden(anmeldung: anmeldung)
                .playAnlegen(playbook: heft, name: name) {
            case .angelegt(let neu):
                // DIE ANGABEN GEHEN MIT, ZWEI AUSGENOMMEN (B7).
                //
                // Eine Kopie, die nur die Zeichnung trägt, verliert
                // Seite, Kategorie, Situationen und Hinweise -- und
                // dann steht der gerettete Play unsortiert im Heft, mit
                // leerem Feld auf dem Call Sheet.
                //
                // Der NAME nicht: Der ist gerade mit Absicht ein
                // anderer, „… (meine Fassung)". Die NUMMER auch nicht:
                // Sie ist am anderen Play vergeben, und der Server
                // lehnt sie mit „Die Nummer ist in diesem Playbook
                // vergeben." ab -- eine Absage mitten in einer Rettung.
                let mit = Playspeicher.Eigenschaften(
                    name: nil, nummer: nil,
                    seite: block.angaben.seite,
                    kategorie: .some(block.angaben.kategorie),
                    situationen: Situation.geordnet(
                        Array(block.angaben.situationen)),
                    hinweise: block.angaben.hinweise)
                switch try await Laden(anmeldung: anmeldung).sichern(
                    play: neu.id, zeichnung: block.zeichnung,
                    version: neu.version, eigenschaften: mit) {
                case .gespeichert:
                    // AB HIER GEHOERT DIE ZEICHNUNG DEM NEUEN PLAY.
                    // Die Ansicht bleibt trotzdem beim alten stehen:
                    // Sie mitten im Arbeiten auf einen anderen Play
                    // umzuhaengen waere ein Sprung, den niemand
                    // angefordert hat. Der neue steht in der Liste.
                    block.gesichert(bis: losgeschickt)
                    // Und die Angaben gelten damit auch als in
                    // Sicherheit -- sie stehen ja im neuen Play. Ohne
                    // diese Zeile fragte die App beim Zurückgehen nach
                    // etwas, das gerade gerettet wurde.
                    angabenGesichert = block.angaben
                    // ÜBER DEN BLOCK GEMELDET und nicht über ein eigenes
                    // Feld: Die Fußzeile zeigt `block.meldung` schon,
                    // und ein zweiter Meldekanal in derselben Ansicht
                    // wäre eine Stelle mehr, an der etwas hängenbleibt.
                    block.melden(String(localized: """
                        Als „\(name)“ gesichert. Der andere Play ist \
                        unverändert geblieben.
                        """))
                case .konflikt, .gesperrt:
                    // Bei einem frisch angelegten Play kann das
                    // eigentlich nicht sein. „Eigentlich" ist kein
                    // Grund, es zu verschweigen.
                    fehler = String(localized:
                        "Der neue Play ließ sich nicht beschreiben.")
                }
            case .grenze(let text, _):
                fehler = text
            }
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            fehler = Fehlertext.von(error)
        }
    }

    // MARK: - Das Schloss (R6)

    /// „Fertig": erst sichern, dann festhalten -- in dieser Reihenfolge.
    ///
    /// Andersherum sperrte man seine eigene Arbeit aus: Das Nachreichen
    /// käme danach an einem 423 an. Geht das Sichern schief, wird auch
    /// nicht gesperrt -- dann steht die Meldung des Sicherns da, und die
    /// ist die richtige.
    private func fertigUndSperren() async {
        if etwasOffen {
            await sichern()
            guard !etwasOffen, konflikt == nil, fehler == nil,
                  !gesperrt else { return }
        }
        await sperreSetzen(true)
    }

    private func sperreSetzen(_ zu: Bool) async {
        sperrtGerade = true
        defer { sperrtGerade = false }
        do {
            let stand = try await Laden(anmeldung: anmeldung)
                .sperre(play: play.id, gesperrt: zu)
            gesperrt = stand.gesperrt
            gesperrtVon = stand.gesperrtVon
            if gesperrt {
                // Was halb gezeichnet war, lässt sich nicht mehr
                // abschließen -- und ein Entwurf, der auf dem Feld
                // liegen bleibt, sieht aus wie ein Werkzeug, das klemmt.
                block.abbrechen()
            }
        } catch Server.Fehler.abgemeldet {
            // ALS EINZIGE ANSICHT HAT DER EDITOR DAS NICHT GEFANGEN.
            // Gezaehlt am 02.09.2026: 15 Ansichten fangen
            // `Server.Fehler.abgemeldet` und melden sich ab, der Editor
            // nicht. Wessen Anmeldung ablaeuft, bekam hier „Nochmal
            // versuchen" -- und das klappt nie, weil das Token weg ist.
            await anmeldung.abmelden()
        } catch {
            // UEBER `Fehlertext`, nicht ueber `localizedDescription`.
            // Der Kopf von `Fehlertext.swift` erklaert, warum alles durch
            // diesen Trichter muss: Ein Entschluesselungsfehler kommt
            // sonst als englischer Foundation-Satz heraus, mitten in
            // einer deutschen App.
            fehler = Fehlertext.von(error)
        }
    }

    /// Zurückgehen, ohne Arbeit zu verlieren.
    ///
    /// Die App hat KEINEN Autosave -- anders als der Browser, wo eine
    /// Änderung nach 1,1 Sekunden von selbst zum Server geht. Wer hier
    /// zeichnete und dann auf „Zurück" tippte, war seine Linien los, ohne
    /// dass etwas gefragt oder gesagt wurde. Das ist dieselbe Meldung wie
    /// R4 („Routen werden manchmal nicht gespeichert"), nur der billigere
    /// Weg dorthin.
    ///
    /// Gefragt wird nur, wenn wirklich etwas offen ist. Eine Rückfrage bei
    /// jedem Zurück wäre nach dem dritten Mal ein Knopf, den man
    /// wegtippt, ohne zu lesen.
    private func zurueck() {
        if etwasOffen {
            fragtBeimVerlassen = true
        } else {
            schliessen()
        }
    }
}
