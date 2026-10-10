// Kategorien verwalten (B7).
//
// Dieselben fünf Handgriffe wie auf der Kategorieseite im Browser:
// anlegen, umbenennen, färben, ordnen, entfernen. Und derselbe Satz
// darüber, warum die Reihenfolge zählt -- was oben steht, steht auch auf
// dem Armband oben.
//
// WAS ANDERS IST ALS IM BROWSER, und warum. Dort sichert ein Knopf am
// Fuß der Seite alle Zeilen auf einmal, und die Pfeile daneben wirken
// sofort. Auf einem Telefon gibt es keine Tabelle mit acht Zeilen und
// zwei Eingabefeldern je Zeile: Geändert wird eine Kategorie, in einem
// Blatt, mit allem, was zu ihr gehört. Gezogen statt gepfeilt.
//
// WAS NICHT ANDERS IST: was dabei herauskommt. Die Reihenfolge schreibt
// `Playbook.kategorien_ordnen`, dieselbe Stelle, die auch die Pfeile im
// Browser bedienen, und ob eine Farbe taugt, entscheidet `Farbwert` --
// gemessen gegen den Server.

import SwiftUI

struct KategorieListe: View {
    let playbook: Modell.Playbook

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var kategorien: [Modell.Kategorie] = []
    @State private var zustand: PlaybookListe.Zustand = .laedt
    @State private var legtAn = false
    @State private var inArbeit: Modell.Kategorie?
    @State private var zumLoeschen: Modell.Kategorie?
    @State private var meldung: String?
    /// Läuft gerade ein Umsortieren zum Server? Solange bleibt die Liste
    /// stehen: Ein zweiter Zug auf halbem Weg schickte eine Reihenfolge,
    /// die es nie gab.
    @State private var ordnetGerade = false
    /// Ob die Reihenfolge gerade geändert werden darf (B13).
    ///
    /// **Zu, bis jemand es sagt.** Playmaker X hat in seinen eigenen
    /// Release-Notes festgehalten, woran das lag: „it was too easy to
    /// accidentally reorder plays in the gallery ... when the app was
    /// out of order with player wristbands". Bei den Plays haben wir
    /// dafür längst einen eigenen Modus; bei den Kategorien hing das
    /// Ziehen an jeder Zeile.
    ///
    /// Und hier wiegt es schwerer als bei den Plays: Die Reihenfolge
    /// der Kategorien ist die Reihenfolge der Blöcke auf der
    /// Wristcoach-Einlage. Ein Daumen, der beim Scrollen hängenbleibt,
    /// druckt am Spieltag ein anderes Armband.
    @State private var ordnenErlaubt = false

    private var darfAendern: Bool { playbook.darfAendern }

    var body: some View {
        ZStack {
            Farben.flaeche.ignoresSafeArea()
            inhalt
        }
        .navigationTitle("Kategorien")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if darfAendern {
                // NUR AB ZWEI KATEGORIEN. Bei einer gibt es nichts zu
                // ordnen, und ein Knopf, der nichts tun kann, ist einer
                // zu viel (ADR-0007) -- dieselbe Regel wie bei den
                // Plays.
                if kategorien.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            ordnenErlaubt.toggle()
                        } label: {
                            Label(ordnenErlaubt
                                  ? String(localized: "Ordnen beenden")
                                  : String(localized: "Ordnen"),
                                  systemImage: "arrow.up.arrow.down")
                        }
                        .disabled(ordnetGerade)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        legtAn = true
                    } label: {
                        Label("Kategorie anlegen", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $legtAn) {
            KategorieBlatt(playbook: playbook, kategorie: nil) { satz in
                legtAn = false
                if let satz {
                    meldung = satz
                    Task { await laden() }
                }
            }
        }
        .sheet(item: $inArbeit) { kategorie in
            KategorieBlatt(playbook: playbook, kategorie: kategorie) { satz in
                inArbeit = nil
                if let satz {
                    meldung = satz
                    Task { await laden() }
                }
            }
        }
        .alert("Kategorie entfernen",
               isPresented: Binding(get: { zumLoeschen != nil },
                                    set: { if !$0 { zumLoeschen = nil } }),
               presenting: zumLoeschen) { kategorie in
            Button("Entfernen", role: .destructive) {
                Task { await loeschen(kategorie) }
            }
            Button("Abbrechen", role: .cancel) { zumLoeschen = nil }
        } message: { kategorie in
            // Der Satz nennt, was NICHT passiert. „Wirklich löschen?"
            // lässt offen, ob die Plays mitgehen, und genau das ist die
            // Frage, die jemand vor diesem Knopf hat.
            Text(loeschtext(kategorie))
        }
        .alert("Hinweis",
               isPresented: Binding(get: { meldung != nil },
                                    set: { if !$0 { meldung = nil } })) {
            Button("Verstanden", role: .cancel) { meldung = nil }
        } message: {
            Text(meldung ?? "")
        }
        .task { await laden() }
        .refreshable { await laden() }
    }

    private func loeschtext(_ kategorie: Modell.Kategorie) -> String {
        let anzahl = kategorie.plays ?? 0
        guard anzahl > 0 else {
            return String(localized: """
                „\(kategorie.name)“ ist danach weg. In dieser Kategorie steht \
                kein Play.
                """)
        }
        // Ganze Sätze und kein eingesetztes Satzstück (R22): „steht" und
        // „stehen" gehören zu ihrem Satz, und in einer anderen Sprache
        // steht das Verb woanders.
        let mitte = anzahl == 1
            ? String(localized: "1 Play steht danach ohne Kategorie.")
            : String(localized:
                "\(anzahl) Plays stehen danach ohne Kategorie.")
        return String(localized: "„\(kategorie.name)“ ist danach weg.")
            + " " + mitte + " "
            + String(localized:
                "Kein Play und keine Zeichnung geht dabei verloren.")
    }

    @ViewBuilder
    private var inhalt: some View {
        switch zustand {
        case .laedt:
            ProgressView().tint(Farben.akzent)

        case .leer:
            Hinweis(zeichen: "tag",
                    titel: String(localized: "Noch keine Kategorien"),
                    text: darfAendern
                        ? String(localized: """
                            Eine Kategorie färbt die Kachel des Plays und \
                            bildet einen Block auf dem Armband. Typisch sind \
                            Pass, Lauf, Red Zone und Trick.
                            """)
                        : String(localized:
                            "Dieses Playbook hat keine Kategorien.")) {
                // DER LEERZUSTAND IST DIE BEDIENUNGSANLEITUNG (B14).
                //
                // Drei andere Listen der App bieten hier einen Knopf an,
                // diese nicht -- man musste wissen, dass oben rechts
                // einer steht. Flag Forge macht es als einziges Werkzeug
                // im ganzen Feld richtig und sagt im Leerzustand
                // wörtlich, welche Handgriffe es kennt. Kostet nichts.
                if darfAendern {
                    Button("Erste Kategorie anlegen") { legtAn = true }
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
            liste
        }
    }

    private var liste: some View {
        List {
            Section {
                ForEach(kategorien) { kategorie in
                    // DER SICHTBARE WEG (B1), neben Zeile und Geste.
                    HStack(spacing: 0) {
                        zeile(kategorie)
                        if darfAendern {
                            Zeilenmenue {
                                Button {
                                    inArbeit = kategorie
                                } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    zumLoeschen = kategorie
                                } label: {
                                    Label("Entfernen", systemImage: "trash")
                                }
                            }
                        }
                    }
                        .listRowBackground(Farben.flaechePanel)
                        .swipeActions(edge: .trailing) {
                            if darfAendern {
                                Button(role: .destructive) {
                                    zumLoeschen = kategorie
                                } label: {
                                    Label("Entfernen", systemImage: "trash")
                                }
                                Button {
                                    inArbeit = kategorie
                                } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                .tint(Farben.akzent)
                            }
                        }
                        // Auch auf langes Drücken (R51), aus demselben
                        // Grund wie bei den Plays: Eine Geste hat keine
                        // Beschriftung.
                        .contextMenu {
                            if darfAendern {
                                Button {
                                    inArbeit = kategorie
                                } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    zumLoeschen = kategorie
                                } label: {
                                    Label("Entfernen", systemImage: "trash")
                                }
                            }
                        }
                }
                .onMove(perform: umsortieren)
            } footer: {
                Text("""
                    Die Farbe färbt die Kachel des Plays und den Punkt \
                    daneben. Die Reihenfolge bestimmt die Blöcke auf der \
                    Wristcoach-Einlage: Was hier oben steht, steht auch auf \
                    dem Armband oben.
                    """)
                // WO DIE REIHENFOLGE HERKOMMT (B13/B14). Der Satz
                // darüber sagt, dass sie zählt; ohne diesen sagt
                // niemand, wie man sie ändert -- seit das Ziehen hinter
                // einem Modus liegt.
                if darfAendern, kategorien.count > 1, !ordnenErlaubt {
                    Text("Zum Umsortieren oben auf „Ordnen“ tippen.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        // ZIEHBAR ERST NACH „ORDNEN" (B13).
        //
        // Hier stand: „Dauerhaft ziehbar und nicht erst nach
        // ‚Bearbeiten': Umsortieren ist hier folgenlos, es wandert
        // keine Nummer mit."
        //
        // **Es ist nicht folgenlos, und die Fußzeile drei Zeilen weiter
        // oben sagt es selbst:** „Die Reihenfolge bestimmt die Blöcke
        // auf der Wristcoach-Einlage: Was hier oben steht, steht auch
        // auf dem Armband oben." Es wandert keine Nummer -- es wandert
        // der Bogen, den die Mannschaft am Spieltag am Handgelenk
        // trägt.
        //
        // Playmaker X hat genau diesen Fehler in seinen Release-Notes
        // eingeräumt: „it was too easy to accidentally reorder plays in
        // the gallery ... when the app was out of order with player
        // wristbands."
        .environment(\.editMode,
                      .constant(darfAendern && ordnenErlaubt
                                ? .active : .inactive))
        .disabled(ordnetGerade)
    }

    private func zeile(_ kategorie: Modell.Kategorie) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Farbvorschlaege.farbe(kategorie.farbe))
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Farben.linie, lineWidth: 1))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(kategorie.name)
                    .font(.headline)
                    .foregroundStyle(Farben.ink)
                Text(playtext(kategorie))
                    .font(.caption)
                    .foregroundStyle(Farben.inkStill)
            }
            Spacer()
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { if darfAendern { inArbeit = kategorie } }
    }

    /// „4 Plays". `nil` heißt „nicht gezählt" und wird nicht zu einer
    /// Null erklärt: Nach dem Umsortieren schickt der Server die Zahl
    /// nicht mit, und „0 Plays" wäre dann schlicht falsch.
    private func playtext(_ kategorie: Modell.Kategorie) -> String {
        guard let anzahl = kategorie.plays else { return kategorie.farbe }
        let plays = anzahl == 1
            ? String(localized: "1 Play")
            : String(localized: "\(anzahl) Plays")
        return "\(plays) · \(kategorie.farbe)"
    }

    // --- Netz -------------------------------------------------------------

    private func laden() async {
        do {
            let neu = try await Laden(anmeldung: anmeldung)
                .kategorien(playbook: playbook.id)
            kategorien = neu
            zustand = neu.isEmpty ? .leer : .da
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            zustand = .fehler(Fehlertext.von(error))
        }
    }

    /// `nil`, wenn hier niemand ändern darf. Ein `onMove`, das immer
    /// dasteht, macht die Zeilen ziehbar -- auch für einen Zuschauer,
    /// der beim Loslassen ein 403 bekäme (ADR-0007: keine toten Knöpfe).
    private var umsortieren: ((IndexSet, Int) -> Void)? {
        // UND SEIT B13 AUCH NUR IM ORDNEN-MODUS. Ein `onMove`, das
        // immer dasteht, macht jede Zeile ziehbar -- und diese
        // Reihenfolge steht auf dem Armband.
        guard darfAendern, ordnenErlaubt else { return nil }
        return { von, nach in self.verschieben(von: von, nach: nach) }
    }

    /// Gezogen und losgelassen: sofort sichern.
    ///
    /// **Kein „Sichern"-Knopf, anders als bei den Plays.** Dort hängt an
    /// der Reihenfolge die Frage, ob die Nummern mitwandern, und die muss
    /// beantwortet werden, bevor etwas passiert. Hier wandert nichts mit:
    /// Eine Kategorie hat keine Nummer, und eine falsch gezogene Zeile
    /// zieht man zurück.
    private func verschieben(von: IndexSet, nach: Int) {
        var neu = kategorien
        neu.move(fromOffsets: von, toOffset: nach)
        kategorien = neu
        Task { await ordnungSichern(neu.map(\.id)) }
    }

    private func ordnungSichern(_ kennungen: [Int]) async {
        ordnetGerade = true
        defer { ordnetGerade = false }
        do {
            _ = try await Laden(anmeldung: anmeldung)
                .kategorienOrdnen(playbook: playbook.id, kennungen: kennungen)
            // Neu laden statt die eigene Liste stehen zu lassen: Die
            // Antwort trägt die Plätze, aber nicht die Zahl der Plays.
            // Was gilt, steht auf dem Server.
            await laden()
        } catch {
            meldung = Fehlertext.von(error) + " "
                + String(localized: "Die Reihenfolge ist nicht geändert.")
            await laden()
        }
    }

    private func loeschen(_ kategorie: Modell.Kategorie) async {
        zumLoeschen = nil
        do {
            let weg = try await Laden(anmeldung: anmeldung)
                .kategorieLoeschen(kategorie.id)
            // Die Zahl des Servers, nicht die aus der Liste: Zwischen
            // Laden und Drücken kann jemand anderes einen Play
            // eingeordnet haben.
            let entfernt = String(localized: "„\(weg.geloescht)“ entfernt.")
            meldung = weg.playsOhneKategorie > 0
                ? entfernt + " " + (weg.playsOhneKategorie == 1
                    ? String(localized:
                        "1 Play steht jetzt ohne Kategorie.")
                    : String(localized: """
                        \(weg.playsOhneKategorie) Plays stehen jetzt ohne \
                        Kategorie.
                        """))
                : entfernt
            await laden()
        } catch {
            meldung = Fehlertext.von(error)
        }
    }
}

// MARK: - Anlegen und Bearbeiten

/// Ein Blatt für beides: neue Kategorie und vorhandene ändern.
///
/// **Eins statt zwei.** Die Felder sind dieselben, die Prüfung ist
/// dieselbe, und zwei Blätter liefen beim nächsten Feld auseinander --
/// dann hätte die neue Kategorie eine Farbwahl und die alte nicht.
struct KategorieBlatt: View {
    let playbook: Modell.Playbook
    /// `nil` heißt: eine neue.
    let kategorie: Modell.Kategorie?
    /// Der Satz für die Liste dahinter, oder `nil` bei Abbruch.
    let fertig: (String?) -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var name: String
    @State private var farbe: String
    @State private var laeuft = false
    @State private var fehler: String?

    init(playbook: Modell.Playbook, kategorie: Modell.Kategorie?,
         fertig: @escaping (String?) -> Void) {
        self.playbook = playbook
        self.kategorie = kategorie
        self.fertig = fertig
        _name = State(initialValue: kategorie?.name ?? "")
        _farbe = State(initialValue: kategorie?.farbe
                       ?? Farbvorschlaege.standard)
    }

    /// Was `Farbwert` zu der Eingabe sagt. An EINER Stelle gefragt: Der
    /// Knopf und der Fehlersatz müssen sich einig sein.
    private var geprueft: Farbwert.Ergebnis { Farbwert.pruefen(farbe) }

    private var bereit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && geprueft.taugt && !laeuft
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z. B. Zwei-Minuten", text: $name)
                        .autocorrectionDisabled()
                }
                Section {
                    // Feld, Tupfer und Vorschau stehen seit B9 in
                    // `Farbwahl` -- dieselbe Palette wählt auch eine
                    // Mannschaft aus.
                    Farbwahl(farbe: $farbe)
                } header: {
                    Text("Farbe")
                } footer: {
                    // Der Satz des Servers, wörtlich. Wer am Telefon
                    // etwas anderes liest als am Schreibtisch, hält eins
                    // von beiden für kaputt.
                    Text(geprueft.fehler
                         ?? String(localized: """
                             Färbt die Kachel des Plays und den Punkt \
                             daneben.
                             """))
                        .foregroundStyle(geprueft.taugt ? Farben.inkStill
                                                        : Farben.fehler)
                }
                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            .navigationTitle(kategorie == nil
                             ? String(localized: "Kategorie anlegen")
                             : String(localized: "Kategorie bearbeiten"))
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
                ToolbarItem(placement: .confirmationAction) {
                    // Beide Wörter durch die Übersetzung. Ob Swift
                    // bei einem Fragezeichenausdruck die Überladung
                    // mit `LocalizedStringKey` wählt, lässt sich ohne
                    // Mac nicht entscheiden, und der Sammler zählt
                    // die Stelle ohnehin nicht: Die zwei Schlüssel
                    // lagen nur durch andere Stellen im Katalog. So
                    // ist beides entschieden.
                    Button(kategorie == nil ? String(localized: "Anlegen")
                                            : String(localized: "Sichern")) {
                        Task { await sichern() }
                    }
                    .disabled(!bereit)
                }
            }
        }
    }

    private func sichern() async {
        let sauber = name.trimmingCharacters(in: .whitespaces)
        guard let wert = geprueft.wert, !sauber.isEmpty else { return }
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            let laden = Laden(anmeldung: anmeldung)
            if let kategorie {
                let neu = try await laden.kategorieAendern(
                    kategorie.id, name: sauber, farbe: wert)
                fertig(String(localized: "„\(neu.name)“ gespeichert."))
            } else {
                switch try await laden.kategorieAnlegen(
                    playbook: playbook.id, name: sauber, farbe: wert) {
                case .angelegt(let neu):
                    fertig(String(localized: "Kategorie „\(neu.name)“ angelegt."))
                case .schonDa(let vorhanden):
                    // Kein roter Fehler: Der Server hat die vorhandene
                    // zurückgegeben, und die steht in der Liste. Gesagt
                    // werden muss es trotzdem, sonst sucht jemand seine
                    // neue Farbe.
                    fertig(String(localized: """
                        „\(vorhanden.name)“ gibt es in diesem Playbook schon. \
                        Die vorhandene ist unverändert geblieben.
                        """))
                }
            }
        } catch {
            // Der Satz des Servers: Er weiß, ob der Name schon vergeben
            // ist.
            fehler = Fehlertext.von(error)
        }
    }
}
