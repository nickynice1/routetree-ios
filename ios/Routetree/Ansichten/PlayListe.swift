import SwiftUI

/// Die Plays eines Playbooks.
///
/// Seit B6 hat sie zwei Gesichter: die Leseliste, nach Kategorie
/// gruppiert, und den **Ordnen-Modus**, in dem sie flach in der
/// Reihenfolge des Servers steht und sich ziehen lässt.
///
/// **Warum flach und ohne Suche.** Eine Liste, die man gruppiert sieht
/// und ungruppiert sortiert, tut beim Loslassen etwas anderes, als sie
/// zeigt. Und wer eine gefilterte Liste umsortiert, würde nur die
/// gefilterten Plätze tauschen -- richtig, aber niemand rechnet damit.
struct PlayListe: View {
    let playbook: Modell.Playbook

    @EnvironmentObject private var anmeldung: Anmeldung
    @EnvironmentObject private var coaching: Coachingmodus
    @State private var zeigtUhren = false
    @State private var plays: [Modell.PlayKurz] = []
    @State private var zustand: PlaybookListe.Zustand = .laedt
    @State private var suche = ""
    /// Was der Server über dieses Heft sagt: Knopf ja/nein, Platz.
    @State private var kopf: Modell.PlayListe.HeftKopf?
    @State private var fragtNachNamen = false
    @State private var neuerName = ""
    @State private var legtAn = false
    /// R142: Der Kamerascanner. Er haengt am selben Kreuz wie das
    /// Die Absage des Servers, wenn die Demo voll ist. Sein Wortlaut,
    /// nicht meiner: Was die Demo hergibt, weiß er (A2, A3) -- und seit
    /// B12 kommt der Abo-Vorschlag mit, sodass daneben ein Weg weiter
    /// steht statt nur „Verstanden".
    @State private var grenze: Grenzmeldung?
    @State private var vorschlag: Abovorschlag?

    // --- Ordnen (B6) ------------------------------------------------------

    /// Der Stand im Ordnen-Modus. `nil` heißt: die Leseliste ist dran.
    @State private var ordnung: Ordnungsstand?
    @State private var nummernMitziehen = false
    @State private var sichertOrdnung = false

    // --- Umbenennen und Löschen (B6) --------------------------------------

    @State private var inArbeit: Modell.PlayKurz?
    @State private var arbeitsname = ""
    @State private var zumLoeschen: Modell.PlayKurz?
    @State private var meldung: String?

    // --- Kategorien (B7) --------------------------------------------------

    /// Wohin das Menü in der Leiste gerade führt. `nil` heißt: nirgends.
    @State private var ziel: Ziel?
    /// Der frisch angelegte Play, in den gleich gezeichnet wird (R40).
    @State private var gleichZeichnen: Zeichnen?

    /// Vorschau oder Liste (R42, Voreinstellung nach R95).
    ///
    /// **Gemerkt, aber nur auf diesem Gerät** (`@AppStorage`). Wer die
    /// Liste einmal gewählt hat, will sie beim nächsten Öffnen wieder --
    /// und niemand sonst muss davon wissen.
    ///
    /// **Die Vorschau ist seit dem 09.09.2026 der Anfang.** Niklas:
    /// „Vorschau als Standard und Liste nach rechts bitte." Ein Playbook
    /// ist eine Sammlung von Bildern; wer es aufmacht, sucht einen
    /// Spielzug und keinen Dateinamen.
    ///
    /// **Und mit einem neuen Schlüssel**, damit die Änderung auch auf
    /// Geräten ankommt, auf denen schon einmal umgeschaltet wurde. Der
    /// alte Wert bliebe sonst stehen, und die neue Voreinstellung wäre
    /// genau dort wirkungslos, wo jemand die App benutzt.
    @AppStorage("pd-playansicht-vorschau") private var zeigtVorschau = true
    /// Ob die Liste schon einmal stand (R96). Erst danach lädt ein
    /// Erscheinen neu -- sonst liefe der erste Aufbau doppelt.
    @State private var listeStand = false
    /// Die geladenen Zeichnungen der Kacheln, nach Playkennung.
    @State private var vorschauen: [Int: Modell.PlayVoll] = [:]

    /// Die Kategorien dieses Playbooks, in IHRER Reihenfolge.
    ///
    /// Zwei Dinge hängen daran: die Auswahl beim Einordnen und die
    /// Reihenfolge der Abschnitte. Vor B7 standen die Abschnitte
    /// alphabetisch -- die Kategorienreihenfolge ist aber die, in der
    /// auch die Wristcoach-Einlage druckt, und ein Coach, der „Red Zone"
    /// nach oben gezogen hat, findet sie sonst zwischen „Pass" und
    /// „Trick" wieder.
    @State private var kategorien: [Modell.Kategorie] = []
    /// Der Play, dem gerade eine Kategorie zugewiesen wird.
    @State private var ordnetEin: Modell.PlayKurz?

    // --- Ohne Netz (R14) --------------------------------------------------

    /// Wann diese Liste entstanden ist, wenn sie vom GERÄT kommt.
    /// `nil` heißt „frisch vom Server".
    @State private var vorratsstand: Date?

    /// Das Heft ausdrücklich mitnehmen (R69).
    ///
    /// **Warum das nicht schon da war.** Der Vorrat füllt sich seit R14
    /// nach jedem Laden der Liste von selbst -- aber still, und nur
    /// wenn gerade Netz da war. Niklas am 03.09.2026: Gemeint ist ein
    /// GRIFF, „dieses Heft mitnehmen", mit Anzeige, was schon da ist.
    /// Ohne den weiss vor dem Spieltag niemand, ob er offline etwas
    /// sehen wird oder eine leere Liste.
    ///
    /// `fehlend` ist der Stand beim letzten Laden; `laeuft` und
    /// `geholt` gelten nur, solange geholt wird.
    @State private var fehlend = 0
    @State private var mitnahmeLaeuft = false
    @State private var geholt = 0
    /// Wie viele beim Start dieses Durchgangs zu holen waren. NICHT
    /// `fehlend`: Das zählt während des Holens herunter, und ein Nenner,
    /// der mitwandert, ergibt „3 von 3" bei jedem Schritt.
    @State private var zuHolen = 0
    @State private var mitnahmeFehler = false

    private var darfAendern: Bool { kopf?.darfAendern == true }

    var body: some View {
        ZStack {
            Farben.flaeche.ignoresSafeArea()
            VStack(spacing: 0) {
                if let vorratsstand {
                    Vorratsleiste(stand: vorratsstand)
                }
                mitnahmeleiste
                // R143: Solange gerufen wird, steht es da.
                if coaching.laeuft { coachingleiste }
                // ÜBER DER LISTE UND NICHT IN DER WERKZEUGLEISTE (R42).
                //
                // Oben stehen schon Anlegen, Ordnen und das Menü neben
                // dem Playbooknamen; der Kommentar dort zählt nach,
                // dass beim sechsten Symbol das System entscheidet,
                // welches es wegkürzt. Und der Umschalter ist keine
                // Handlung am Playbook, sondern eine Einstellung dieser
                // Ansicht -- er gehört zu dem, was er umschaltet.
                ansichtswahl
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                inhalt
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(playbook.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { werkzeuge }
        .safeAreaInset(edge: .bottom) { ordnungsleiste }
        .alert("Neuer Play", isPresented: $fragtNachNamen) {
            TextField("Name", text: $neuerName)
            Button("Anlegen") { Task { await anlegen() } }
                .disabled(neuerName.trimmingCharacters(
                    in: .whitespaces).isEmpty)
            Button("Abbrechen", role: .cancel) { }
        } message: {
            // KEINE AUFSTELLUNG MEHR IM SATZ (Audit 07.09.2026). Hier
            // stand „Center am Ball, QB im Shotgun, drei Receiver" --
            // wörtlich die Flag-Aufstellung. Ein Elfer-Play beginnt mit
            // fünf Linemen, Tight End, zwei Receivern, Quarterback,
            // Running Back und Slot; „drei Receiver" stimmt in keiner
            // Tackle-Form. Der Satz stand in fünf Sprachen im Dialog
            // „Neuer Play" -- also genau dort, wo jemand zum ersten Mal
            // etwas in einem Tackle-Playbook anlegt.
            Text("""
                Der Play beginnt mit der Grundaufstellung eurer \
                Spielform. Du ziehst die Spieler an ihre Stelle und \
                zeichnest die Routen.
                """)
        }
        // R143: Welche Uhren mitlaufen. Als Blatt und nicht als eigene
        // Seite -- der Coach kommt mitten im Rufen hierher und will
        // danach zurück in die Liste, nicht einen Schritt im
        // Navigationsstapel suchen.
        .sheet(isPresented: $zeigtUhren) {
            UhrenAnsicht(team: playbook.team.id)
                .environmentObject(anmeldung)
                .environmentObject(coaching)
        }
        // R143: Die kurze Anleitung beim Starten. Sie geht nur auf,
        // solange dieser Mensch noch nie gerufen hat -- die Regel
        // steht in `Coachingmodus.schonGerufen`.
        .sheet(isPresented: $coaching.zeigtAnleitung) {
            Coachinganleitung()
        }
        .alert("Play umbenennen",
               isPresented: Binding(get: { inArbeit != nil },
                                    set: { if !$0 { inArbeit = nil } })) {
            TextField("Name", text: $arbeitsname)
            Button("Sichern") { Task { await umbenennen() } }
                .disabled(arbeitsname.trimmingCharacters(
                    in: .whitespaces).isEmpty)
            Button("Abbrechen", role: .cancel) { inArbeit = nil }
        }
        .alert("Play löschen",
               isPresented: Binding(get: { zumLoeschen != nil },
                                    set: { if !$0 { zumLoeschen = nil } }),
               presenting: zumLoeschen) { play in
            Button("Löschen", role: .destructive) {
                Task { await loeschen(play) }
            }
            Button("Abbrechen", role: .cancel) { zumLoeschen = nil }
        } message: { play in
            Text("""
                „\(play.name)“ und seine Zeichnung sind danach weg. Das lässt \
                sich nicht rückgängig machen.
                """)
        }
        // EINE GRENZE IST KEINE FEHLERMELDUNG, sondern ein Angebot.
        // Bis B12 stand hier ein Satz und der Knopf „Verstanden".
        .alert("Die Demo ist hier am Ende",
               isPresented: Binding(get: { grenze != nil },
                                    set: { if !$0 { grenze = nil } }),
               presenting: grenze) { angestossen in
            if let weiter = angestossen.vorschlag {
                Button("Was ein Abo kostet") {
                    grenze = nil
                    vorschlag = weiter
                }
            }
            Button("Verstanden", role: .cancel) { grenze = nil }
        } message: { angestossen in
            Text(angestossen.text)
        }
        .sheet(item: $vorschlag) { gezeigt in
            AboAnsicht(abo: gezeigt.abo, verein: gezeigt.verein,
                       titel: gezeigt.titel,
                       weiterText: gezeigt.weiterText)
        }
        .alert("Hinweis",
               isPresented: Binding(get: { meldung != nil },
                                    set: { if !$0 { meldung = nil } })) {
            Button("Verstanden", role: .cancel) { meldung = nil }
        } message: {
            Text(meldung ?? "")
        }
        .sheet(item: $ordnetEin) { play in
            KategorieWahl(play: play, kategorien: kategorien) { satz in
                ordnetEin = nil
                if let satz {
                    meldung = satz
                    Task { await laden() }
                }
            }
        }
        // DIE WEGE ZU EINEM PLAY -- AN DER AUSSENSEITE (R95).
        //
        // **Sie standen an der Leseliste, und das war ein Fehler, den
        // man nur in der Vorschau sieht.** Ein `navigationDestination`
        // gilt nur, solange die Ansicht, an der es hängt, auch
        // dasteht. In der Vorschau steht die Leseliste NICHT da --
        // ein Tipp auf eine Kachel lief damit ins Leere. Genau das
        // hat Niklas am 09.09.2026 gemeldet: „wenn man bei Vorschau
        // auf ein Play tippt sollte man es auch gleich in den Editor
        // kommen."
        //
        // Hier oben gelten sie für beide Listen, und dieselbe Falle
        // kann beim nächsten Umbau nicht wiederkommen.
        //
        // DER WEG IN DEN EDITOR (R40), gleich nach dem Anlegen. Eigener
        // Typ und nicht `Modell.PlayKurz`: Dieselbe Liste führt mit
        // `PlayKurz` bereits in die ANSICHT. Zwei Ziele am selben Wert
        // liessen sich nicht auseinanderhalten.
        .navigationDestination(item: $gleichZeichnen) { wohin in
            EditorAnsicht(play: wohin.play)
        }
        .navigationDestination(for: Kachelziel.self) { wohin in
            switch wohin {
            case .editor(let play):
                EditorAnsicht(play: play)
            case .ansehen(let play):
                PlayAnsicht(play: play, nachbarn: geblaettert)
            }
        }
        .navigationDestination(for: Modell.PlayKurz.self) { play in
            // Die Ansicht bekommt die Liste MIT, damit man von einem Play
            // zum nächsten wischen kann, ohne zurückzugehen (Niklas,
            // 01.09.2026). Und zwar genau die Liste, die hier steht: in
            // ihrer Reihenfolge, mit Suche und Kategorien.
            PlayAnsicht(play: play, nachbarn: geblaettert)
        }
        .navigationDestination(item: $ziel) { wohin in
            switch wohin {
            case .ueben:      UebenAnsicht(playbook: playbook)
            case .lernstand:  LernstandAnsicht(playbook: playbook)
            case .kategorien: KategorieListe(playbook: playbook)
            case .drucken:    DruckAnsicht(playbook: playbook)
            case .bibliothek:
                BibliothekAnsicht(playbook: playbook) {
                    // Nach dem Übernehmen die Liste neu holen. Sie
                    // fortzuschreiben hiesse Nummer und Reihenfolge
                    // erraten, und die vergibt der Server.
                    Task { await laden() }
                }
            }
        }
        .task {
            await laden()
            listeStand = true
        }
        // NACH DER RÜCKKEHR NEU LADEN (R96). `.task` läuft genau einmal
        // je Ansicht; wer aus dem Editor zurückkommt, sähe sonst
        // dieselbe Liste mit denselben Fassungsnummern -- und damit
        // dieselben alten Kacheln.
        //
        // Beim ERSTEN Erscheinen tut das hier nichts: `.onAppear` läuft
        // vor `.task`, und solange die Liste noch nie stand, lädt
        // `.task` ohnehin gleich.
        .onAppear {
            guard listeStand else { return }
            Task { await laden() }
        }
        .refreshable { await laden() }
    }

    @ToolbarContentBuilder
    private var werkzeuge: some ToolbarContent {
        if ordnung != nil {
            ToolbarItem(placement: .topBarTrailing) {
                // EIGENER NAME (R65): Das hier beendet einen MODUS
                // und schliesst kein Blatt. „Fertig" wäre für einen
                // Vorleser dasselbe Wort an zwei verschiedenen Dingen.
                Fertigknopf(name: String(localized: "Ordnen beenden")) {
                    ordnung = nil
                }
                .disabled(sichertOrdnung)
            }
        } else {
            // Nur wenn der SERVER es sagt. Und bewusst AUCH dann, wenn
            // kein Platz mehr ist: Ein Knopf, der bei acht Plays
            // verschwindet, erklärt nichts -- die Absage samt
            // Abo-Vorschlag schon.
            if kopf?.darfAnlegen == true {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        neuerName = ""
                        fragtNachNamen = true
                    } label: {
                        Label("Play anlegen", systemImage: "plus")
                    }
                    .disabled(legtAn)
                }
            }
            // Ordnen erst ab zwei Plays. Bei einem gibt es nichts zu
            // ordnen, und ein Knopf, der nichts tun kann, ist einer zu
            // viel.
            if darfAendern && plays.count > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        nummernMitziehen = false
                        ordnung = Ordnungsstand(plays.map(\.alsPlatz))
                    } label: {
                        Label("Ordnen", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
            // ALLES WEITERE STEHT IN EINEM MENÜ, seit mit dem Drucken
            // (B10) das sechste Symbol dazugekommen wäre.
            //
            // Fünf Symbole neben einem Playbooknamen waren schon eng;
            // beim sechsten entscheidet das System, welches es
            // wegkürzt, und ausgerechnet der neue Knopf wäre der, den
            // niemand findet. Anlegen und Ordnen bleiben draußen: Das
            // sind die beiden Handgriffe, die man mitten in der Arbeit
            // macht.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Üben (B8). Für JEDEN, der das Heft sehen darf --
                    // ein Playbook nützt nichts, das nur der Trainer
                    // kennt.
                    //
                    // Erst ab so vielen Plays, wie der SERVER nennt: Mit
                    // zweien wäre jede Frage eine Münze, und ein Knopf,
                    // der beim Drücken „zu wenige Plays" sagt, ist ein
                    // toter Knopf (ADR-0007). Die Zahl steht nicht in
                    // Swift, sonst wäre sie irgendwann eine andere als
                    // im Browser.
                    // DER COACHING-MODUS GANZ OBEN (R143). Er ist
                    // der einzige Eintrag, den jemand mitten im
                    // Training sucht -- der Rest hat Zeit.
                    //
                    // Nur fuer wen das Heft aendern darf: Rufen setzt
                    // dieselben Rechte voraus wie Anlegen, und ein
                    // Knopf, der beim Druecken 403 sagt, ist ein
                    // toter Knopf.
                    if darfAendern {
                        Button {
                            Task { await coachingUmschalten() }
                        } label: {
                            // Beide Beschriftungen durch die
                            // Übersetzung: Im Fragezeichenausdruck
                            // sammelt `appsprache.py` nichts ein, und
                            // keiner der zwei Sätze stand in einem
                            // Katalog. Der Einstieg in den
                            // Coaching-Modus war damit in vier
                            // Sprachen deutsch.
                            Label(coaching.laeuft
                                  ? String(localized: "Coaching-Modus beenden")
                                  : String(localized: "Coaching-Modus starten"),
                                  systemImage: coaching.laeuft
                                  ? "stop.circle" : "applewatch.radiowaves.left.and.right")
                        }
                        .accessibilityIdentifier("coaching-umschalten")

                        if coaching.laeuft {
                            Button { zeigtUhren = true } label: {
                                Label("Uhren wählen", systemImage: "list.bullet")
                            }
                            .accessibilityIdentifier("uhren-waehlen")
                        }
                        Divider()
                    }

                    if plays.count >= (kopf?.uebungAb ?? Int.max) {
                        Button { ziel = .ueben } label: {
                            Label("Üben", systemImage: "graduationcap")
                                .accessibilityIdentifier("ueben")
                        }
                    }
                    // Der Lernstand der Mannschaft. Nur für den
                    // Trainerstab, und auch das sagt der Server.
                    if kopf?.darfLernstand == true {
                        Button { ziel = .lernstand } label: {
                            Label("Lernstand", systemImage: "chart.bar")
                        }
                    }
                    // Die Kategorien. Auch für Zuschauer erreichbar --
                    // die Seite zeigt dann nur, was es gibt, und bietet
                    // keinen Knopf an. Wer wissen will, was „Red Zone"
                    // in diesem Heft bedeutet, muss nicht Head Coach
                    // sein.
                    Button { ziel = .kategorien } label: {
                        Label("Kategorien", systemImage: "tag")
                    }
                    // Drucken (B10). Ebenfalls für jeden, der das Heft
                    // sehen darf, genau wie im Browser: Ein Spieler, der
                    // sich sein Armband selbst ausdruckt, nimmt dem
                    // Trainer Arbeit ab.
                    Button { ziel = .drucken } label: {
                        Label("Drucken", systemImage: "printer")
                            .accessibilityIdentifier("drucken")
                    }
                    // Die Bibliothek (B11). Nur für den, der auch
                    // anlegen darf -- sie führt zu nichts anderem, und
                    // ein Knopf, der beim Absenden 403 gibt, ist ein
                    // toter Knopf (ADR-0007).
                    if kopf?.darfAnlegen == true {
                        Button { ziel = .bibliothek } label: {
                            Label("Bibliothek", systemImage: "books.vertical")
                        }
                    }
                    // DAS HEFT MITNEHMEN (R69). Erst ab einem Play --
                    // ein Knopf, der nichts holen kann, ist einer zu
                    // viel (ADR-0007).
                    if !plays.isEmpty {
                        Divider()
                        Button {
                            Task { await mitnehmen() }
                        } label: {
                            // DER STAND STEHT IM WORT. „Heft mitnehmen"
                            // allein liesse offen, ob es schon da ist --
                            // und genau das ist die Frage, die man sich
                            // am Abend vor dem Spieltag stellt.
                            Label(fehlend == 0
                                  ? String(localized: "Ganz auf dem Gerät")
                                  : String(localized:
                                      "Heft mitnehmen · \(fehlend) offen"),
                                  systemImage: fehlend == 0
                                  ? "checkmark.icloud" : "arrow.down.circle")
                        }
                        .disabled(mitnahmeLaeuft)
                    }
                } label: {
                    // R72. Niklas am 03.09.2026, an drei Stellen
                    // nacheinander: „Ohne „mehr" nur die 3 Punkte
                    // bitte". Die Vorlese-Beschriftung bleibt.
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                }
                .accessibilityLabel(Text("Mehr"))
                // DIE KENNUNG IST FÜR DEN BILDERLAUF (R120.5).
                //
                // „Mehr" steht ELFMAL auf diesem Bildschirm: einmal
                // hier und einmal an jeder Kachel (`Zeilenmenue` trägt
                // dieselbe Vorlese-Beschriftung, und das ist richtig so
                // -- es tut dasselbe). Eine Suche danach ist deshalb
                // mehrdeutig, und der Durchgang fand am 15.09.2026
                // keinen einzigen Treffer statt elf.
                //
                // Die Kennung ist NICHT die Beschriftung: Was VoiceOver
                // vorliest, bleibt „Mehr".
                .accessibilityIdentifier("mehrmenue")
            }
        }
    }

    /// Wohin das Menü führt.
    ///
    /// **Über einen Zustand und nicht über `NavigationLink` im Menü.**
    /// Beides gibt es, aber nur das hier ist derselbe Weg, den diese
    /// Ansicht schon für die Plays benutzt. Es gibt keinen Mac: Was sich
    /// hier nicht ausprobieren lässt, sollte wenigstens der Weg sein,
    /// der im Rest der App nachweislich läuft.
    /// Ein frisch angelegter Play, auf dem Weg in den Editor (R40).
    /// Den Coaching-Modus an- oder ausschalten.
    private func coachingUmschalten() async {
        if coaching.laeuft {
            coaching.beenden()
            return
        }
        guard let marke = try? await anmeldung.gueltigesToken() else {
            coaching.hinweis = String(localized: "Nicht mehr angemeldet.")
            return
        }
        await coaching.starten(team: playbook.team.id, token: marke)
        // **GLEICH DIE LISTE ZEIGEN, wenn keine Uhr lebt.** Sonst
        // startet der Coach den Modus, tippt auf einen Play und
        // bekommt „Keine Uhr ausgewaehlt" -- ohne zu wissen, wo er
        // eine auswaehlt.
        if coaching.lebendig == 0 { zeigtUhren = true }
    }

    /// Einen Play an die gewaehlten Uhren schicken.
    ///
    /// **Der Name geht mit**, damit die Leiste „zuletzt: Mesh" zeigen
    /// kann, ohne ihn nachzuschlagen -- am Spielfeldrand zaehlt, dass
    /// der Coach sieht, ob sein Tipp angekommen ist.
    private func rufen(_ play: Modell.PlayKurz, einreihen: Bool) async {
        // **`gueltigesToken()` und kein gespeichertes.** Das
        // Zugriffstoken laeuft nach dreissig Minuten ab; ein Coach,
        // der eine Halbzeit lang nichts ruft, haette sonst beim
        // naechsten Tipp einen 401 -- und zwar genau dann, wenn es
        // eilt.
        guard let marke = try? await anmeldung.gueltigesToken() else {
            coaching.hinweis = String(localized: "Nicht mehr angemeldet.")
            return
        }
        if einreihen {
            await coaching.einreihen(play: play.id, name: play.name,
                                     token: marke)
        } else {
            await coaching.rufen(play: play.id, name: play.name,
                                 token: marke)
        }
    }

    private struct Zeichnen: Hashable, Identifiable {
        let play: Modell.PlayKurz
        var id: Int { play.id }
    }

    /// Wohin ein Tipp auf einer KACHEL führt (R95).
    ///
    /// Eigener Wert und nicht `Modell.PlayKurz`: Den Weg für die Zeile
    /// gibt es schon, und er führt in die Spieleransicht. Zwei Ziele für
    /// denselben Wert liessen sich nicht auseinanderhalten.
    private enum Kachelziel: Hashable {
        case editor(Modell.PlayKurz)
        case ansehen(Modell.PlayKurz)
    }

    private enum Ziel: Hashable, Identifiable {
        case ueben, lernstand, kategorien, drucken, bibliothek
        var id: Self { self }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch zustand {
        case .laedt:
            ProgressView().tint(Farben.akzent)

        case .leer:
            // DIE WICHTIGSTE STELLE FÜR B11. Wer hier landet, hat ein
            // leeres Heft -- und genau dagegen gibt es die Bibliothek.
            // Sie erst im Menü unter „Mehr" anzubieten hiesse, den
            // Ausweg dort zu verstecken, wo niemand sucht.
            Hinweis(zeichen: "square.dashed",
                    titel: String(localized: "Noch keine Plays"),
                    text: kopf?.darfAnlegen == true
                        ? String(localized: """
                            In diesem Playbook steht noch nichts. Zehn \
                            ausgearbeitete Konzepte liegen in der Bibliothek, \
                            oder du zeichnest selbst.
                            """)
                        : String(localized:
                            "In diesem Playbook steht noch nichts.")) {
                if kopf?.darfAnlegen == true {
                    Button("Standardplays ansehen") { ziel = .bibliothek }
                        .buttonStyle(.borderedProminent)
                        .tint(Farben.akzent)
                }
            }

        case .fehler(let text):
            Hinweis(zeichen: "exclamationmark.triangle",
                    titel: String(localized: "Das hat nicht geklappt"),
                    text: text) {
                Button("Nochmal versuchen") { Task { await laden() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
            }

        case .da:
            if ordnung != nil {
                // BEIM SORTIEREN GIBT ES NUR DIE LISTE. Kacheln
                // ziehen sich zwar auch, aber die Nummern stehen in
                // der Liste, und genau um sie geht es beim Umsortieren.
                ordnenliste
            } else if zeigtVorschau {
                vorschauliste
            } else {
                leseliste
            }
        }
    }

    /// Liste oder Vorschau (R42).
    ///
    /// **Ein beschrifteter Umschalter und kein stummes Zeichenpaar.**
    /// Ein `Picker` im Segmentstil zeigt beide Möglichkeiten
    /// gleichzeitig und sagt dabei, welche gerade gilt -- das ist der
    /// Unterschied zu einem Knopf, der sein Aussehen wechselt und den
    /// man erst antippen muss, um zu erfahren, was er tut.
    ///
    /// Er steht nur da, wenn es überhaupt etwas anzusehen gibt: Bei
    /// einem leeren Heft wäre er ein Umschalter zwischen zwei leeren
    /// Bildschirmen (ADR-0007).
    @ViewBuilder
    private var ansichtswahl: some View {
        if case .da = zustand, ordnung == nil {
            // VORSCHAU LINKS, LISTE RECHTS (R95). Niklas: „Vorschau
            // als Standard und Liste nach rechts bitte." Das Erste
            // links ist das Übliche -- die Reihenfolge sagt mit, was
            // gemeint ist.
            Picker("Ansicht", selection: $zeigtVorschau) {
                Label("Vorschau", systemImage: "square.grid.2x2").tag(true)
                Label("Liste", systemImage: "list.bullet").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    /// Die drei Handgriffe an einem Play -- an EINER Stelle.
    ///
    /// **Der Kommentar sagte es schon, der Code tat es nicht.** Am
    /// Zeilenmenü stand „DIESELBEN DREI HANDGRIFFE, aus demselben
    /// Zustand gebaut. Zwei Listen mit denselben Namen liefen
    /// irgendwann auseinander" -- und darunter standen sie dreimal
    /// ausgeschrieben: im Menü, in der Wischgeste und im Kontextmenü.
    /// Eine Begründung ist keine Schranke.
    ///
    /// Seit R42 gibt es einen vierten Ort (die Vorschaukachel), und
    /// spätestens vier Kopien laufen auseinander.
    ///
    /// **Die Wischgeste bleibt trotzdem eigen** (`wischhandgriffe`):
    /// Dort zählt die Reihenfolge von aussen nach innen, und sie trägt
    /// Farben. Ein gemeinsamer Baustein für beides müsste beides
    /// halbherzig tun.
    @ViewBuilder
    private func handgriffe(_ play: Modell.PlayKurz) -> some View {
        // **GANZ OBEN, solange der Modus laeuft** (R143). Am
        // Spielfeldrand ist Rufen der einzige Handgriff, der unter
        // Zeitdruck passiert -- Umbenennen und Loeschen haben Zeit bis
        // nach dem Spiel. Wer ihn unten anhaengte, liesse den Coach in
        // einem Menue suchen, waehrend die Uhr ablaeuft.
        if coaching.laeuft {
            Button {
                Task { await rufen(play, einreihen: false) }
            } label: {
                Label("Nächster Spielzug", systemImage: "paperplane.fill")
            }
            .accessibilityIdentifier("naechster-spielzug")

            Button {
                Task { await rufen(play, einreihen: true) }
            } label: {
                Label("In die Warteschlange", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            .accessibilityIdentifier("in-die-warteschlange")

            Divider()
        }

        Button {
            arbeitsname = play.name
            inArbeit = play
        } label: {
            Label("Umbenennen", systemImage: "pencil")
        }
        // Nur wenn es überhaupt Kategorien gibt. Ein Blatt mit einer
        // einzigen Zeile „ohne Kategorie" beantwortet keine Frage.
        if !kategorien.isEmpty {
            Button {
                ordnetEin = play
            } label: {
                Label("Kategorie", systemImage: "tag")
            }
        }
        // Zuletzt und rot: Was nicht rückgängig zu machen ist, steht
        // nicht neben dem, was man oft will.
        Button(role: .destructive) {
            zumLoeschen = play
        } label: {
            Label("Löschen", systemImage: "trash")
        }
    }

    /// Dieselben drei für die Wischgeste.
    ///
    /// Eigene Reihenfolge: Beim Wischen von rechts kommt zuerst, was am
    /// weitesten aussen liegt, und das soll das Löschen sein.
    @ViewBuilder
    private func wischhandgriffe(_ play: Modell.PlayKurz) -> some View {
        Button(role: .destructive) {
            zumLoeschen = play
        } label: {
            Label("Löschen", systemImage: "trash")
        }
        Button {
            arbeitsname = play.name
            inArbeit = play
        } label: {
            Label("Umbenennen", systemImage: "pencil")
        }
        .tint(Farben.akzent)
        if !kategorien.isEmpty {
            Button {
                ordnetEin = play
            } label: {
                Label("Kategorie", systemImage: "tag")
            }
            .tint(Farben.petrol)
        }
    }

    // --- Die Vorschauliste (R42) ------------------------------------------

    /// Kacheln mit dem Play darauf, zwei nebeneinander.
    ///
    /// Cyell am 01.09.2026: „wäre eine Switch von Vorschau Ansicht zur
    /// listenansicht cool Mit Hamburger Menü für einstellen der
    /// Formation oder Kategorie."
    ///
    /// **Was eine Liste kann und eine Vorschau nicht:** viele Plays auf
    /// einen Blick, sortiert, mit Nummer. Was die Vorschau kann und die
    /// Liste nicht: zeigen, WELCHER Play das ist. Am Schreibtisch sucht
    /// man nach dem Namen, am Spielfeldrand nach der Form.
    ///
    /// **Die Zeichnungen kommen aus dem Vorrat.** `vorratFuellen` legt
    /// nach jedem Laden der Liste ohnehin jeden Play ab (B6, für den
    /// Platz ohne Empfang); die Vorschau liest daraus und holt nur, was
    /// fehlt. Ohne das wären zwanzig Anfragen fällig, sobald jemand
    /// umschaltet.
    private var vorschauliste: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(gruppen) { gruppe in
                    Text(gruppe.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Farben.inkStill)
                        .padding(.horizontal, 16)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)],
                              spacing: 12) {
                        ForEach(gruppe.plays) { play in
                            kachel(play)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 12)
        }
    }

    /// Eine Kachel. Ein Tipp darauf geht in den EDITOR (R95).
    ///
    /// Niklas am 09.09.2026: „wenn man bei Vorschau auf ein Play tippt
    /// sollte man es auch gleich in den Editor kommen".
    ///
    /// **Die Liste bleibt der Leseweg, die Vorschau ist der
    /// Arbeitsweg.** Wer ein Bild des Spielzugs vor sich hat und darauf
    /// tippt, will daran arbeiten; wer eine Zeile mit Nummer und Namen
    /// antippt, will ihn ansehen -- dort führt der Weg weiter in die
    /// Spieleransicht, in der man von Play zu Play wischen kann.
    ///
    /// **Wer nicht ändern darf, kommt weiter in die Spieleransicht.**
    /// Ein Editor mit Schloss wäre für einen Spieler ein Bildschirm
    /// voller Werkzeuge, die er nicht benutzen kann.
    private func kachel(_ play: Modell.PlayKurz) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: darfAendern ? Kachelziel.editor(play)
                                              : Kachelziel.ansehen(play)) {
                ZStack {
                    Farben.flaeche
                    if let voll = vorschauen[play.id] {
                        Feldansicht(
                            zeichnung: voll.zeichnung,
                            projektion: Projektion
                                .fuerDieApp(feld: voll.feld, los: voll.los,
                                            richtung: voll.richtung,
                                            spielform: voll.spielform)
                                .querPassendFuer(voll.zeichnung)
                                .passendFuer(voll.zeichnung))
                    } else {
                        // KEIN DREHENDES RÄDCHEN JE KACHEL. Zwanzig
                        // davon nebeneinander sehen aus, als hinge die
                        // App. Ein ruhiges Feld sagt dasselbe und
                        // schreit nicht.
                        Image(systemName: "square.dashed")
                            .font(.title2)
                            .foregroundStyle(Farben.inkStill.opacity(0.5))
                    }
                }
                .aspectRatio(1.1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            // DIE KENNUNG IST FÜR DEN BILDERLAUF (R120.5).
            //
            // Der Durchgang muss WARTEN können, bis die Kacheln da
            // sind. Am 15.09.2026 knipste er sofort nach dem Tippen und
            // lieferte ein Bild mit einem drehenden Rädchen in der
            // Mitte -- der Bildschirm war richtig, nur noch nicht
            // fertig. Nach dem Namen eines Spielzugs zu suchen hiesse,
            // den Inhalt eines bestimmten Playbooks in eine Prüfung zu
            // schreiben.
            .accessibilityIdentifier("playkachel")
            // MIT DER FASSUNG ALS KENNUNG (R96): So läuft die Aufgabe
            // noch einmal, sobald sich der Play geändert hat. Ohne die
            // Kennung liefe sie genau einmal je Kachel -- und danach
            // nie wieder.
            .task(id: play.version) { await vorschauLaden(play) }

            HStack(spacing: 6) {
                if let farbe = play.kategorieFarbe {
                    Circle()
                        .fill(Farbvorschlaege.farbe(farbe))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
                Text(play.titel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Farben.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                // DASSELBE MENÜ WIE IN DER ZEILE (B1). Eine Kachel
                // ohne sichtbaren Weg wäre ein Rückschritt hinter das,
                // was die Liste seit dem 02.09.2026 kann.
                if darfAendern {
                    Zeilenmenue { handgriffe(play) }
                }
            }
            .padding(.top, 6)
        }
        .contextMenu {
            if darfAendern { handgriffe(play) }
        }
    }

    /// Die Zeichnung einer Kachel -- aus dem Vorrat, sonst vom Netz.
    ///
    /// Ohne Fehlerbild: Eine Kachel, die nicht kommt, bleibt ein leeres
    /// Feld. Die Liste daneben funktioniert weiter, und ein rotes
    /// Dreieck auf zwanzig Kacheln wäre schlimmer als eine leere.
    private func vorschauLaden(_ play: Modell.PlayKurz) async {
        // GEGEN DIE FASSUNG UND NICHT GEGEN „ist schon da" (R96).
        //
        // Niklas am 09.09.2026: „Vorschauliste muss auch immer sofort
        // mitaktualisieren." Hier stand `== nil`: Einmal geladen, blieb
        // die Kachel für immer stehen -- wer einen Play änderte und
        // zurückging, sah das alte Bild und hielt die Änderung für
        // verloren.
        guard vorschauen[play.id]?.version != play.version else { return }
        if let ausgabe = try? await Laden(anmeldung: anmeldung)
            .playMitVorrat(play.id, version: play.version) {
            vorschauen[play.id] = ausgabe.wert
        }
    }

    // --- Die Leseliste ----------------------------------------------------

    private var leseliste: some View {
        List {
            ForEach(gruppen) { gruppe in
                Section(gruppe.name) {
                    ForEach(gruppe.plays) { play in
                        // DER SICHTBARE WEG (B1), neben Zeile und Geste.
                        //
                        // Bis zum 02.09.2026 gab es Löschen, Umbenennen
                        // und Einordnen nur per Wisch und langem
                        // Drücken -- also nur unsichtbar. Sadana 2018:
                        // 1 von 16 findet das, 14 von 16 finden ein
                        // sichtbares Menü.
                        HStack(spacing: 0) {
                            NavigationLink(value: play) {
                                zeile(play)
                            }
                            if darfAendern {
                                Zeilenmenue {
                                    handgriffe(play)
                                }
                            }
                        }
                        .listRowBackground(Farben.flaechePanel)
                        .swipeActions(edge: .trailing) {
                            if darfAendern {
                                wischhandgriffe(play)
                            }
                        }
                        // DASSELBE AUF LANGES DRUECKEN (R51).
                        //
                        // Cyell am 01.09.2026: „zu dem seh ich in der app
                        // nicht mal eine funktion ein play zu loeschen."
                        // Es gab sie -- auf der Wischgeste darueber. Eine
                        // Geste hat aber keine Beschriftung: Wer sie nicht
                        // kennt, haelt die Funktion fuer nicht vorhanden.
                        //
                        // Niklas dazu: „loeschen als swipen aber auch
                        // drin lassen oder vielleicht noch lange auf das
                        // play gedrueckt halten." Genau so -- die
                        // Wischgeste bleibt fuer die, die sie kennen, und
                        // ist der schnellste Weg.
                        //
                        // DIESELBEN DREI HANDGRIFFE, aus demselben
                        // Zustand gebaut. Zwei Listen mit denselben
                        // Namen liefen irgendwann auseinander, und dann
                        // koennte man ueber die eine loeschen und ueber
                        // die andere nicht.
                        .contextMenu {
                            if darfAendern {
                                handgriffe(play)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .searchable(text: $suche, prompt: "Play suchen")
    }

    private func zeile(_ play: Modell.PlayKurz) -> some View {
        HStack(spacing: 10) {
            // Der Punkt in der Farbe der Kategorie, wie im Browser. Ohne
            // Kategorie kein Punkt: Ein grauer Punkt sähe aus wie eine
            // Kategorie namens Grau.
            if let farbe = play.kategorieFarbe {
                Circle()
                    .fill(Farbvorschlaege.farbe(farbe))
                    .frame(width: 9, height: 9)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(play.titel)
                    .font(.headline)
                    .foregroundStyle(Farben.ink)
                // Was aufgegeben ist, ist markiert -- wie im Browser
                // (A7). Sortiert wird deshalb NICHT: Ein Coach zieht die
                // Kacheln in dieser Liste selbst, und eine Ansicht, die
                // dieselbe Liste stillschweigend anders ordnet, macht
                // aus dem Ziehen eine Behauptung.
                if play.aufgabe {
                    Marke(text: String(localized: "Deine Aufgabe"))
                }
                if !play.situationen.isEmpty {
                    Text(play.situationen.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Farben.inkStill)
                }
            }
        }
        .padding(.vertical, 3)
    }

    /// Nach Kategorie gruppiert -- so, wie der Trainer sie ruft.
    ///
    /// **In der Reihenfolge der Kategorien, nicht alphabetisch.** Das ist
    /// dieselbe Ordnung, in der die Wristcoach-Einlage druckt: Was der
    /// Coach nach oben gezogen hat, steht auch hier oben. Alphabetisch
    /// sortiert stünde „Red Zone" zwischen „Pass" und „Trick", und die
    /// Liste in der Hand sähe anders aus als die auf dem Bildschirm.
    ///
    /// Gerechnet wird das in `Abschnitte` und nicht hier: Was in einer
    /// SwiftUI-Ansicht steht, lässt sich ohne Mac nicht messen, sondern
    /// nur behaupten. Diese Stelle filtert nur noch nach dem Suchfeld.
    private var gruppen: [Abschnitte.Abschnitt] {
        let gefiltert = suche.isEmpty ? plays : plays.filter {
            $0.name.localizedCaseInsensitiveContains(suche)
                || ($0.kategorie ?? "").localizedCaseInsensitiveContains(suche)
        }
        // Aufgegebene Plays nach oben -- aber nur für den, der die
        // Reihenfolge nicht selbst gelegt hat. Dieselbe Bedingung wie im
        // Browser (`playbook_detail`).
        return Abschnitte.gruppieren(gefiltert, kategorien: kategorien,
                                     aufgabeZuerst: !darfAendern)
    }

    /// Dieselben Plays, aber flach: die Reihenfolge zum Durchblättern.
    ///
    /// Aus `gruppen` gelesen und nicht neu gefiltert. Zwei Stellen, die
    /// dieselbe Frage beantworten, geben irgendwann verschiedene
    /// Antworten -- und dann blättert die Ansicht durch eine andere Liste
    /// als die, aus der sie aufgemacht wurde.
    private var geblaettert: [Modell.PlayKurz] {
        gruppen.flatMap(\.plays)
    }

    // --- Der Ordnen-Modus -------------------------------------------------

    /// Die Liste zum Ziehen: flach, in Serverreihenfolge, mit Vorschau.
    @ViewBuilder
    private var ordnenliste: some View {
        if let stand = ordnung {
            let vorschau = stand.vorschauNummern(
                nummernMitziehen: nummernMitziehen)
            List {
                ForEach(stand.inReihenfolge(plays)) { play in
                    HStack(spacing: 10) {
                        // Nach Kennung nachgeschlagen und nicht nach
                        // Stelle: Sonst zeigte jede Zeile die Nummer
                        // ihres Nachbarn, sobald sich die Listen um
                        // einen Eintrag unterscheiden.
                        nummernkachel(alt: play.nummer,
                                      neu: vorschau[play.id] ?? play.nummer)
                        Text(play.name)
                            .font(.headline)
                            .foregroundStyle(Farben.ink)
                        Spacer()
                    }
                    .padding(.vertical, 3)
                    .listRowBackground(Farben.flaechePanel)
                }
                .onMove { von, nach in
                    ordnung?.verschieben(von: von, nach: nach)
                }
            }
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
        }
    }

    /// Was hier steht und was daraus wird. Zwei Zahlen nur dann, wenn sie
    /// verschieden sind -- „4 → 4" ist Lärm.
    private func nummernkachel(alt: Int?, neu: Int?) -> some View {
        HStack(spacing: 3) {
            Text(alt.map { String($0) } ?? "–")
                .foregroundStyle(Farben.inkStill)
                .strikethrough(alt != neu, color: Farben.inkStill)
            if alt != neu {
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(Farben.inkStill)
                Text(neu.map { String($0) } ?? "–")
                    .foregroundStyle(Farben.gold)
            }
        }
        .font(.callout.monospacedDigit())
        .frame(minWidth: 52, alignment: .leading)
    }

    /// Die Leiste unter der Liste -- dieselbe Frage wie im Browser.
    ///
    /// **`nummern_mitziehen` muss ausdrücklich beantwortet werden.** Das
    /// ist die Stelle, an der Playmaker X seine Nutzer verliert: Dort
    /// wandern die Nummern beim Umsortieren nicht mit, und das gedruckte
    /// Armband zeigt danach auf den falschen Play, ohne dass es jemand
    /// merkt.
    ///
    /// Anders als im Browser steht hier ein Schalter statt zweier
    /// Knöpfe, und die Liste darüber zeigt live, was er anrichtet. Auf
    /// einem Telefon ist das der Unterschied zwischen einer Frage und
    /// einer beantwortbaren Frage.
    @ViewBuilder
    private var ordnungsleiste: some View {
        if let stand = ordnung, stand.geaendert {
            VStack(alignment: .leading, spacing: 10) {
                Text("""
                    Reihenfolge geändert. Sollen die Nummern mitwandern? Die \
                    Nummer ist das, was auf dem Armband steht.
                    """)
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
                Toggle("Nummern mitziehen", isOn: $nummernMitziehen)
                    .font(.subheadline)
                    .foregroundStyle(Farben.ink)
                    .tint(Farben.akzent)
                HStack {
                    Button("Zurücknehmen") { ordnung?.zuruecknehmen() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Sichern") { Task { await ordnungSichern() } }
                        .buttonStyle(.borderedProminent)
                        .tint(Farben.akzent)
                }
                .disabled(sichertOrdnung)
            }
            .padding(14)
            .background(Farben.flaechePanel)
            .overlay(alignment: .top) {
                Rectangle().fill(Farben.linie).frame(height: 1)
            }
        }
    }

    // --- Netz -------------------------------------------------------------

    private func laden() async {
        spur("playliste", "offen")
        let laden = Laden(anmeldung: anmeldung)
        do {
            let ausgabe = try await laden.playlisteMitVorrat(
                playbook: playbook.id)
            let liste = ausgabe.wert
            vorratsstand = ausgabe.stand
            kopf = liste.playbook
            let neu = liste.plays
            plays = neu
            zustand = neu.isEmpty ? .leer : .da
            // Ein offener Ordnen-Modus wird beim Neuladen geschlossen.
            // Eine halb gezogene Reihenfolge auf einer Liste, die sich
            // unter der Hand geändert hat, schickte falsche Kennungen.
            if ordnung != nil { ordnung = Ordnungsstand(neu.map(\.alsPlatz)) }
            // WAS NOCH FEHLT, UND ZWAR JEDES MAL (R69). Auch beim Laden
            // AUS dem Vorrat: Gerade dann ist die Frage „habe ich das
            // Heft dabei" die interessante, und `vorratFuellen` läuft in
            // diesem Fall gar nicht.
            fehlend = Laden.fehlend(neu).count
            await kategorienLaden(laden)
            // DAS HEFT AUF DAS GERÄT HOLEN, solange noch Netz da ist
            // (R14). Im Hintergrund: Der Trainer liest schon seine
            // Liste, während die Zeichnungen nachkommen. Nur nach einem
            // FRISCHEN Laden -- wer ohnehin gerade kein Netz hat,
            // braucht keine vierzig Anfragen, die in die Wartezeit
            // laufen.
            if !ausgabe.ausDemVorrat {
                Task { await vorratFuellen(neu) }
            }
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            zustand = .fehler(Fehlertext.von(error))
        }
    }

    /// Die Kategorien dazu -- in einer EIGENEN Fehlerbehandlung.
    ///
    /// **Ein Fehler hier legt die Liste nicht lahm.** Die Plays sind der
    /// Zweck dieser Seite; die Kategorien ordnen die Abschnitte und
    /// erlauben einen Handgriff mehr. Wer beides in dasselbe `catch`
    /// legte, zeigte einem Trainer „Das hat nicht geklappt" statt seiner
    /// vierzig Plays, weil eine zweite Anfrage in der Umkleide nicht
    /// durchkam. Ohne Kategorien stehen die Abschnitte alphabetisch, und
    /// der Knopf zum Einordnen fehlt -- beides sichtbar, beides
    /// harmlos. Was schiefging, sagt die Kategorienseite selbst.
    /// **Auch sie kommen notfalls vom Gerät (R14)**, und ihr `stand`
    /// wird bewusst weggeworfen: Die Leiste oben sagt schon, dass diese
    /// Seite ohne Netz entstanden ist. Zwei Leisten übereinander mit
    /// zwei Uhrzeiten wären eine Genauigkeit, nach der niemand gefragt
    /// hat.
    private func kategorienLaden(_ laden: Laden) async {
        do {
            kategorien = try await laden
                .kategorienMitVorrat(playbook: playbook.id).wert
        } catch {
            kategorien = []
        }
    }

    /// Die Zeichnungen dieses Hefts auf das Gerät holen (R14).
    ///
    /// Im Hintergrund und ohne Fehlerbild: Wenn es nicht klappt, hat
    /// der Trainer trotzdem seine Liste -- und am Platz merkt er es an
    /// der Leiste, die dann fehlt.
    private func vorratFuellen(_ neu: [Modell.PlayKurz]) async {
        await Laden(anmeldung: anmeldung).vorratFuellen(neu)
        fehlend = Laden.fehlend(neu).count
    }

    /// Das Heft ausdrücklich mitnehmen (R69) -- mit Anzeige.
    ///
    /// **Derselbe Weg wie das stille Füllen**, nur sichtbar. Ein
    /// zweiter Weg, der dieselben Dateien anders ablegte, ergäbe zwei
    /// Vorräte, von denen einer beim Nachsehen nicht gefunden wird.
    private func mitnehmen() async {
        guard !mitnahmeLaeuft else { return }
        mitnahmeLaeuft = true
        mitnahmeFehler = false
        geholt = 0
        let liste = plays
        zuHolen = Laden.fehlend(liste).count
        let geschafft = await Laden(anmeldung: anmeldung)
            .vorratFuellen(liste) { fertig, _ in
                Task { @MainActor in geholt = fertig }
            }
        fehlend = Laden.fehlend(liste).count
        mitnahmeFehler = !geschafft
        mitnahmeLaeuft = false
    }

    /// Was während und nach dem Mitnehmen dasteht.
    ///
    /// **Nur wenn es etwas zu sagen gibt.** Eine Zeile „alles da", die
    /// dauerhaft über der Liste klebt, ist nach dem dritten Öffnen
    /// keine Auskunft mehr, sondern Rand.
    @ViewBuilder
    private var mitnahmeleiste: some View {
        if mitnahmeLaeuft {
            HStack(spacing: 8) {
                ProgressView().tint(Farben.akzent)
                Text("Wird mitgenommen: \(geholt) von \(zuHolen)")
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Farben.flaechePanel)
        } else if mitnahmeFehler {
            // KEIN ALARM UND KEIN ROT: Es ist nichts kaputt, es fehlt
            // nur Netz. Was schon geholt ist, bleibt liegen und zählt.
            HStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark")
                Text("Nicht alles kam durch, \(fehlend) noch offen.")
                    .font(.footnote)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Farben.inkStill)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Farben.flaechePanel)
        }
    }

    /// Was der Coaching-Modus gerade tut (R143).
    ///
    /// **Drei Angaben und keine mehr:** wie viele Uhren mitlaufen, was
    /// zuletzt rausging, und was schiefging. Das ist, was ein Coach am
    /// Spielfeldrand in einer Sekunde ablesen kann.
    ///
    /// **„2 von 3 Uhren" und nicht „läuft".** Der Satz, auf den es
    /// ankommt, ist nicht „der Modus ist an" -- das weiss er, er hat
    /// ihn eingeschaltet. Es ist die Zahl der Handgelenke, die wirklich
    /// erreichbar sind. Eine Uhr in der Tasche sieht von vorne genauso
    /// aus wie eine am Arm.
    ///
    /// Die ganze Leiste ist antippbar und führt zur Uhrenliste: Wer
    /// liest, dass eine fehlt, will als Nächstes wissen, welche.
    private var coachingleiste: some View {
        Button {
            zeigtUhren = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .foregroundStyle(coaching.lebendig > 0
                                     ? Farben.gut : Farben.warnung)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(coaching.lebendig) von \(coaching.gewaehlt.count) Uhren")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Farben.ink)
                    if let hinweis = coaching.hinweis {
                        Text(hinweis)
                            .font(.caption2)
                            .foregroundStyle(Farben.warnung)
                            .lineLimit(2)
                    } else if let zuletzt = coaching.zuletzt {
                        Text("Gerufen: \(zuletzt)")
                            .font(.caption2)
                            .foregroundStyle(Farben.inkStill)
                            .lineLimit(1)
                    } else {
                        // SOLANGE NICHTS RAUSGING, STEHT HIER DER WEG.
                        // Das ist der Moment, in dem jemand sucht --
                        // und „Noch nichts gerufen" beantwortet genau
                        // die Frage nicht, die er dann hat.
                        Text("Drei Punkte an einem Play → Nächster Spielzug")
                            .font(.caption2)
                            .foregroundStyle(Farben.inkStill)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if coaching.arbeitet {
                    ProgressView().tint(Farben.akzent)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Farben.inkStill)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Farben.flaechePanel)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("coaching-leiste")
    }

    private func anlegen() async {
        let name = neuerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        legtAn = true
        defer { legtAn = false }
        do {
            switch try await Laden(anmeldung: anmeldung)
                .playAnlegen(playbook: playbook.id, name: name) {
            case .angelegt(let neu):
                // Neu laden statt anhängen: Nummer, Reihenfolge und
                // freier Platz kommen vom Server, und eine Liste, die
                // sich selbst fortschreibt, weicht irgendwann ab.
                await laden()
                // UND DANN HINEIN (R40). Cyell am 01.09.2026: „sowie
                // wenn man was ausgewählt hat das man wieder zurück
                // gebracht wird." Ein neuer Play entstand, die Liste lud
                // neu -- und der Trainer stand vor einer Liste und
                // musste seinen eigenen Play darin suchen.
                //
                // IN DEN EDITOR und nicht in die Ansicht: Wer einen Play
                // anlegt, will ihn zeichnen. Ein leeres Feld anzusehen
                // ist kein Ziel.
                gleichZeichnen = Zeichnen(play: neu.alsKurz)
            case .grenze(let text, let abo):
                grenze = Grenzmeldung(text: text, abo: abo)
            }
        } catch {
            zustand = .fehler(Fehlertext.von(error))
        }
    }

    private func umbenennen() async {
        guard let play = inArbeit else { return }
        let name = arbeitsname.trimmingCharacters(in: .whitespaces)
        inArbeit = nil
        guard !name.isEmpty, name != play.name else { return }
        do {
            switch try await Laden(anmeldung: anmeldung)
                .playUmbenennen(play.id, name: name, version: play.version) {
            case .gespeichert:
                await laden()
            case .konflikt(let fremd):
                // Ein 409 ist kein Fehler, sondern eine Nachricht: Jemand
                // anderes war schneller. Was dort jetzt steht, gehört in
                // die Meldung -- sonst weiß niemand, wogegen er verloren
                // hat.
                meldung = String(localized: """
                    Jemand anderes hat diesen Play inzwischen geändert. Er \
                    heißt jetzt „\(fremd.name)“. Die Liste ist neu geladen.
                    """)
                await laden()
            case .gesperrt(let wer):
                // DER FALL FEHLTE SEIT R6, und der Compiler hat es
                // gesagt: „switch must be exhaustive". Gehoert hat es
                // niemand, weil die App seither nicht gebaut wurde.
                //
                // Ein gesperrter Play laesst sich nicht umbenennen --
                // das ist der Sinn des Schlosses. Die Antwort darauf
                // ist nicht „nochmal versuchen", sondern „entsperren",
                // und dafuer muss dastehen, WER es zugemacht hat.
                // `vonWem` und nicht `$0`: `$0` steht in
                // `appsprache.GANZE_ZAHLEN` (anderswo ist es eine Zahl)
                // und haette hier `%lld` fuer einen TEXT ergeben. Das
                // sieht man nirgends -- ausser auf einem
                // fremdsprachigen Telefon.
                meldung = wer.map { vonWem in
                    String(localized: "„\(play.name)“ ist von \(vonWem) als fertig gesperrt. Zum Umbenennen erst entsperren.")
                } ?? String(localized: "Dieser Play ist als fertig gesperrt. Zum Umbenennen erst entsperren.")
            }
        } catch {
            // Der Satz des Servers: Er weiß, ob der Name schon vergeben
            // ist.
            meldung = Fehlertext.von(error)
        }
    }

    private func loeschen(_ play: Modell.PlayKurz) async {
        zumLoeschen = nil
        do {
            try await Laden(anmeldung: anmeldung).playLoeschen(play.id)
            await laden()
        } catch {
            meldung = Fehlertext.von(error)
        }
    }

    private func ordnungSichern() async {
        guard let stand = ordnung else { return }
        sichertOrdnung = true
        defer { sichertOrdnung = false }
        do {
            _ = try await Laden(anmeldung: anmeldung).reihenfolgeSichern(
                playbook: playbook.id, kennungen: stand.kennungen,
                nummernMitziehen: nummernMitziehen)
            // Neu laden und den Modus schließen. Die Vorschau war eine
            // Vorschau; was jetzt gilt, steht auf dem Server.
            ordnung = nil
            await laden()
            meldung = nummernMitziehen
                ? String(localized: """
                    Reihenfolge gesichert, die Nummern sind mitgewandert. \
                    Armband neu drucken.
                    """)
                : String(localized: """
                    Reihenfolge gesichert. Die Nummern sind geblieben, wo sie \
                    waren.
                    """)
        } catch {
            meldung = Fehlertext.von(error)
        }
    }
}

// MARK: - Einen Play einordnen (B7)

/// Das Blatt, mit dem ein Play seine Kategorie bekommt oder verliert.
///
/// **Warum das hier steht und nicht im Editor.** Im Browser sitzt die
/// Auswahl in der Seitenspalte des Editors, weil dort ohnehin Name,
/// Nummer und Seite stehen. Auf einem Telefon ist der Editor die
/// Zeichenfläche und sonst nichts -- eine Seitenspalte gibt es nicht,
/// und ein Play einzuordnen soll nicht heißen, ihn zu öffnen. Dieselbe
/// Fähigkeit, anderer Ort; wie bei den Nummern beim Umsortieren, wo im
/// Browser zwei Knöpfe stehen und hier ein Schalter.
struct KategorieWahl: View {
    let play: Modell.PlayKurz
    let kategorien: [Modell.Kategorie]
    /// Der Satz für die Liste dahinter, oder `nil` bei Abbruch.
    let fertig: (String?) -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var laeuft = false
    @State private var fehler: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    zeile(nil)
                    ForEach(kategorien) { kategorie in
                        zeile(kategorie)
                    }
                } header: {
                    Text("Kategorie")
                } footer: {
                    Text("""
                        Die Farbe färbt die Kachel dieses Plays. Die \
                        Kategorie ist ein Angebot, keine Pflicht.
                        """)
                }
                .listRowBackground(Farben.flaechePanel)

                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                    .listRowBackground(Farben.flaechePanel)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            .navigationTitle(play.titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        fertig(nil)
                    } label: {
                        // EIN X STATT „Ab…" (R57).
                        //
                        // Niklas am 02.09.2026 mit einem
                        // Bildschirmfoto: „Statt abbrechen
                        // vielleicht einfach ein X".
                        // „Abbrechen" passt in der
                        // Werkzeugleiste von iOS 26 nicht
                        // mehr und stand als „Ab…" da --
                        // und eine abgeschnittene
                        // Beschriftung sagt weniger als
                        // ein Zeichen, das jeder kennt.
                        Label("Abbrechen",
                              systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .disabled(laeuft)
        }
    }

    /// Eine Zeile. `nil` ist „Ohne Kategorie" -- der Weg zurück, den es
    /// im Browser als leeren Eintrag im Auswahlfeld gibt.
    private func zeile(_ kategorie: Modell.Kategorie?) -> some View {
        let gewaehlt = play.kategorieId == kategorie?.id
        return Button {
            // Ein Tipp auf die Kategorie, die schon dransteht, ist kein
            // Speichern. Sonst kostete ein versehentlicher Tipp eine
            // Fassungsnummer und einen Eintrag im Protokoll.
            if gewaehlt { fertig(nil); return }
            Task { await setzen(kategorie) }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(kategorie.map { Farbvorschlaege.farbe($0.farbe) }
                          ?? Color.clear)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Farben.linie, lineWidth: 1))
                    .accessibilityHidden(true)
                Text(kategorie?.name ?? Abschnitte.ohneKategorie)
                    .foregroundStyle(Farben.ink)
                Spacer()
                if gewaehlt {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Farben.akzent)
                }
            }
            // Trefferfläche: Die Mitte der Zeile ist sonst Luft.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(gewaehlt ? [.isSelected] : [])
    }

    private func setzen(_ kategorie: Modell.Kategorie?) async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            switch try await Laden(anmeldung: anmeldung).playKategorieSetzen(
                play.id, kategorie: kategorie?.id, version: play.version) {
            case .gespeichert:
                fertig(kategorie.map { String(localized:
                    "„\(play.name)“ steht jetzt unter „\($0.name)“.") }
                       ?? String(localized:
                           "„\(play.name)“ steht jetzt ohne Kategorie."))
            case .konflikt(let fremd):
                // Ein 409 ist kein Fehler, sondern eine Nachricht: Jemand
                // anderes war schneller, und dessen Arbeit gehört nicht
                // überschrieben.
                fertig(String(localized: """
                    Jemand anderes hat diesen Play inzwischen geändert. Er \
                    heißt jetzt „\(fremd.name)“. Die Liste ist neu geladen.
                    """))
            case .gesperrt(let wer):
                // Siehe oben: seit R6 offen, vom Compiler gefunden.
                fertig(wer.map { vonWem in
                    String(localized: "„\(play.name)“ ist von \(vonWem) als fertig gesperrt. Die Kategorie bleibt, wie sie war.")
                } ?? String(localized: "Dieser Play ist als fertig gesperrt. Die Kategorie bleibt, wie sie war."))
            }
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}
