import PhotosUI
import SwiftUI
import UIKit

// Die Blätter der Mannschaftsseite (B9): ein Kadermitglied, die
// Mannschaft selbst, Teamcode, Einladung, Schlüssel.
//
// WARUM SIE IN EINER DATEI STEHEN. Es sind fünf kurze Formulare zu
// EINEM Bildschirm. Fünf Dateien mit je vierzig Zeilen wären fünf
// Stellen, an denen dieselbe Fehlerbehandlung steht -- und beim nächsten
// Mal hätte eine davon sie nicht.
//
// WAS HIER NIRGENDS PASSIERT: Es wird nie entschieden, ob jemand etwas
// darf. Das steht als `darfFuehren`, `darfAendern` und `darfName` in der
// Antwort des Servers; welche Knöpfe daraus folgen, rechnet
// `Kaderblock` -- geprüft, ohne dass ein Gerät dafür laufen muss.

// MARK: - Ein Kadermitglied

/// Rolle, Name, Aufgabe, Zugang eines Menschen im Kader.
///
/// **Eine Seite und kein Menü in der Zeile.** Vier Handlungen an einer
/// Listenzeile sind vier Wischgesten, die man im Vorbeigehen auslöst --
/// und eine davon entfernt jemanden aus der Mannschaft.
struct KaderAnsicht: View {
    let team: Modell.Mannschaft
    let zeile: Modell.Kadermitglied
    /// Wird gerufen, wenn sich etwas geändert hat. Die Mannschaftsseite
    /// lädt dann neu -- was gilt, steht auf dem Server.
    let geaendert: () -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen
    @State private var name: String
    @State private var rolle: String
    @State private var zumEntfernen = false
    /// Ob die Rueckfrage zum eigenen Austritt offen ist (R110.11).
    @State private var zumAustritt = false
    @State private var laeuft = false
    @State private var meldung: String?
    @State private var fehler: String?

    init(team: Modell.Mannschaft, zeile: Modell.Kadermitglied,
         geaendert: @escaping () -> Void) {
        self.team = team
        self.zeile = zeile
        self.geaendert = geaendert
        _name = State(initialValue: zeile.name)
        _rolle = State(initialValue: zeile.rolle)
    }

    private var kann: Kaderblock.Moeglichkeiten {
        Kaderblock.moeglichkeiten(fuer: zeile, in: team)
    }

    var body: some View {
        ZStack {
            Farben.flaeche.ignoresSafeArea()
            Form {
                kopfteil
                if kann.umbenennen { nameteil }
                if kann.rolleAendern { rolleteil }
                if kann.aufgeben { aufgabenteil }
                if kann.entfernen { entfernteil }
                if kann.austreten { austrittsteil }
                if let grund = kann.grund {
                    Section {
                        Text(grund).foregroundStyle(Farben.inkStill)
                    }
                }
                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(zeile.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Modell.Aufgabenziel.self) { ziel in
            AufgabeAnsicht(team: ziel.team, mitglied: ziel.mitglied,
                           name: ziel.name) {
                geaendert()
            }
            .environmentObject(anmeldung)
        }
        .alert("Aus dem Kader nehmen?", isPresented: $zumEntfernen) {
            Button("Entfernen", role: .destructive) {
                Task { await entfernen() }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("""
                \(zeile.name) sieht die Playbooks danach nicht mehr. Die \
                Lernstände bleiben erhalten, falls jemand wieder dazukommt.
                """)
        }
        .alert("Mannschaft wirklich verlassen?", isPresented: $zumAustritt) {
            Button("Verlassen", role: .destructive) {
                Task { await entfernen() }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            // WAS DANACH IST, STEHT VOR DEM KNOPF und nicht erst
            // hinterher: Die Playbooks sind weg, der Lernstand bleibt.
            // Beides will man wissen, BEVOR man tippt.
            Text("""
                Du siehst die Playbooks von \(team.name) danach nicht mehr. \
                Dein Lernstand bleibt erhalten, falls du wieder dazukommst. \
                Zurück geht es nur über eine neue Einladung oder den \
                Teamcode.
                """)
        }
        .alert("Hinweis",
               isPresented: Binding(get: { meldung != nil },
                                    set: { if !$0 { meldung = nil } })) {
            Button("Verstanden", role: .cancel) { meldung = nil }
        } message: {
            Text(meldung ?? "")
        }
    }

    private var kopfteil: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(Kaderblock.unterzeile(zeile))
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
                if let fortschritt = zeile.fortschritt, fortschritt.gesamt > 0 {
                    Balken(anteil: fortschritt.anteil)
                    Text(standsatz(fortschritt))
                        .font(.caption)
                        .foregroundStyle(Farben.inkStill)
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Farben.flaechePanel)
        }
    }

    /// „3 von 6 aufgegebenen Plays sitzen."
    ///
    /// Der Zusatz gehört dazu: „3 von 6" und „3 von 40" sehen sonst nach
    /// einem Fehler aus, obwohl beides stimmt (A7).
    private func standsatz(_ fortschritt: Modell.Fortschritt) -> String {
        // Zwei ganze Sätze statt eines eingesetzten Wortes (R22):
        // „aufgegebenen" ist ein Adjektiv, und Adjektive stehen
        // nicht in jeder Sprache vor dem Substantiv.
        return fortschritt.ausAuftrag
            ? String(localized: """
                \(fortschritt.sitzen) von \(fortschritt.gesamt) aufgegebenen \
                Plays sitzen.
                """)
            : String(localized: """
                \(fortschritt.sitzen) von \(fortschritt.gesamt) Plays sitzen.
                """)
    }

    private var nameteil: some View {
        Section {
            TextField("Name im Kader", text: $name)
                .listRowBackground(Farben.flaechePanel)
            Button("Namen speichern") { Task { await nameSichern() } }
                .disabled(!nameBereit)
                .listRowBackground(Farben.flaechePanel)
        } header: {
            Text("Name")
        } footer: {
            // Leeren geht nicht, und das ist keine Bequemlichkeit: Leer
            // heißt in der Datenbank „nie gefragt worden" (A5).
            Text("""
                Der Name gilt in dieser Mannschaft. Wer bei zwei Vereinen \
                mitmacht, heißt dort vielleicht anders. Leer lassen geht \
                nicht.
                """)
        }
    }

    private var nameBereit: Bool {
        let sauber = name.trimmingCharacters(in: .whitespaces)
        return !sauber.isEmpty && sauber != zeile.name && !laeuft
    }

    private var rolleteil: some View {
        Section {
            Picker("Rolle", selection: $rolle) {
                ForEach(team.rollen) { auswahl in
                    Text(auswahl.text).tag(auswahl.wert)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .listRowBackground(Farben.flaechePanel)
            Button("Rolle speichern") { Task { await rolleSichern() } }
                .disabled(rolle == zeile.rolle || laeuft)
                .listRowBackground(Farben.flaechePanel)
        } header: {
            Text("Rolle")
        } footer: {
            Text("""
                Head Coach verwaltet Zugänge. Assistenz darf zeichnen und \
                Aufgaben verteilen. Nur Ansicht sieht und übt.
                """)
        }
    }

    private var aufgabenteil: some View {
        Section {
            NavigationLink(value: Modell.Aufgabenziel(team: team.id,
                                                      mitglied: zeile.id,
                                                      name: zeile.name)) {
                Label(Kaderblock.aufgabenknopf(fuer: zeile),
                      systemImage: "checklist")
            }
            .listRowBackground(Farben.flaechePanel)
        } header: {
            Text("Lernauftrag")
        } footer: {
            Text("""
                Angehakte Plays stehen im Playbook oben und kommen im \
                Übungsmodus zuerst dran. Sitzen sie alle, öffnet sich wieder \
                das ganze Playbook.
                """)
        }
    }

    /// Selbst gehen (R110.11).
    ///
    /// Ein eigener Abschnitt und nicht derselbe Knopf mit anderem Wort:
    /// „Aus dem Kader nehmen" steht in der Verwaltung, „Mannschaft
    /// verlassen" ist eine Entscheidung über sich selbst. Sie stehen
    /// deshalb nie zusammen da -- `Kaderblock.moeglichkeiten` nimmt
    /// `entfernen` an der eigenen Zeile heraus.
    private var austrittsteil: some View {
        Section {
            Button(role: .destructive) {
                zumAustritt = true
            } label: {
                Label("Mannschaft verlassen",
                      systemImage: "rectangle.portrait.and.arrow.right")
            }
            .disabled(laeuft)
            .listRowBackground(Farben.flaechePanel)
        } footer: {
            Text("""
                Danach siehst du die Playbooks dieser Mannschaft nicht \
                mehr. Dein Lernstand bleibt.
                """)
        }
    }

    private var entfernteil: some View {
        Section {
            Button(role: .destructive) {
                zumEntfernen = true
            } label: {
                Label("Aus dem Kader nehmen", systemImage: "person.badge.minus")
            }
            .disabled(laeuft)
            .listRowBackground(Farben.flaechePanel)
        }
    }

    // MARK: Arbeit

    private func nameSichern() async {
        await tun {
            try await Laden(anmeldung: anmeldung).nameImKaderSetzen(
                mitglied: zeile.id,
                name: name.trimmingCharacters(in: .whitespaces))
        }
    }

    private func rolleSichern() async {
        await tun {
            try await Laden(anmeldung: anmeldung)
                .rolleSetzen(mitglied: zeile.id, rolle: rolle)
        }
    }

    private func entfernen() async {
        laeuft = true
        defer { laeuft = false }
        do {
            _ = try await Laden(anmeldung: anmeldung)
                .mitgliedEntfernen(zeile.id)
            geaendert()
            // Zurück, und zwar sofort: Diesen Menschen gibt es im Kader
            // nicht mehr, und die Seite hier beantwortete die nächste
            // Anfrage mit 404. Eine Meldung auf einer Seite, die gleich
            // verschwindet, liest ohnehin niemand -- dass es geklappt
            // hat, sieht man am Kader dahinter, aus dem die Zeile weg
            // ist.
            schliessen()
        } catch {
            fehler = Fehlertext.von(error)
        }
    }

    /// Eine Änderung ausführen und melden, was der Server dazu sagt.
    ///
    /// **Der Satz kommt vom Server**, auch der bei „war schon so". In
    /// Swift nachgebaut wäre er beim nächsten Wort ein anderer als im
    /// Browser, und `test_ton.py` käme gar nicht an ihn heran.
    private func tun(
        _ arbeit: () async throws -> Modell.Kaderergebnis) async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            let ergebnis = try await arbeit()
            meldung = ergebnis.meldung
            if ergebnis.geaendert { geaendert() }
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}

// MARK: - Die Mannschaft bearbeiten

/// Name, Farbe und **das Logo** (R33). Kein Feldformat.
///
/// **Das Logo stand bis zum 28.08.2026 nicht hier**, und an seiner
/// Stelle der Satz „Ein Bild lädt die App nicht hoch. Das geht auf der
/// Website." Niklas per Telegram, mit einem Kringel darum: „Auch in der
/// App vochladbar soll es sein."
///
/// Die Begründung von damals -- ein Bild geht nicht durch ein JSON-Feld
/// -- stimmte und taugte nur nie als Begründung dafür, es ganz zu
/// lassen. Jetzt geht es über eine eigene Adresse als Multipart,
/// dieselbe Art, in der auch der Browser Dateien schickt.
///
/// **Warum das Logo trotzdem am „Speichern" hängt und nicht sofort
/// hochgeht.** Ein Blatt mit „Abbrechen" verspricht, dass Abbrechen
/// etwas bedeutet. Ein Bild, das beim Auswählen schon oben ist, bricht
/// dieses Versprechen -- und zwar an der Stelle, wo es am meisten weh
/// tut, denn das alte ist dann weg.
struct MannschaftBearbeiten: View {
    let team: Modell.Mannschaft
    let fertig: (Bool) -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var name: String
    @State private var farbe: String
    @State private var spielform: String
    @State private var laeuft = false
    @State private var fehler: String?

    /// Was mit dem Logo geschehen soll, wenn gespeichert wird.
    ///
    /// Drei Zustände und nicht ein `Data?`: „unverändert" und
    /// „entfernen" sind verschiedene Absichten, und mit `nil` für beides
    /// löschte ein Blatt, auf dem niemand das Logo angefasst hat, beim
    /// Speichern des NAMENS das Bild mit.
    private enum Logowunsch {
        case unveraendert
        case neu(Data)
        case weg
    }

    @State private var logowunsch: Logowunsch = .unveraendert
    @State private var auswahl: PhotosPickerItem?

    init(team: Modell.Mannschaft, fertig: @escaping (Bool) -> Void) {
        self.team = team
        self.fertig = fertig
        _name = State(initialValue: team.name)
        _farbe = State(initialValue: team.farbe)
        // LEER HEISST FLAG, wie auf dem Server. Eine Mannschaft aus der
        // Zeit vor T4 hat gar keine Spielform gespeichert; stünde hier
        // dann nichts angehakt, sähe es aus, als hätte sie keine.
        _spielform = State(initialValue: team.spielform.isEmpty
                           ? Spielform.standard : team.spielform)
    }

    private var geprueft: Farbwert.Ergebnis { Farbwert.pruefen(farbe) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name der Mannschaft", text: $name)
                }
                // ZU BERICHTIGEN, NICHT NUR ZU SETZEN (Audit 07.09.2026).
                //
                // Der Anlass steht in der Datenbank: Am 07.09. um 05:16
                // wurde „TackleStrelitz" in der App angelegt -- mit einem
                // Bau, der noch nicht nach der Spielform fragte. Sie stand
                // danach auf Flag, und es gab in der App keinen Weg
                // zurück. Wer eine Mannschaft in der App anlegt, muss sie
                // auch dort berichtigen können; sonst ist der Browser die
                // Bedingung dafür, einen Fehler der App zu beheben.
                Section {
                    ForEach(Spielform.alle) { form in
                        Button {
                            spielform = form.schluessel
                        } label: {
                            Formkachel(form: form,
                                       gewaehlt: spielform == form.schluessel)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Was spielt diese Mannschaft?")
                } footer: {
                    // DIE WARNUNG GEHÖRT HIERHIN UND NICHT ZUM ANLEGEN.
                    // Beim Anlegen gibt es nichts, was verrutschen könnte.
                    Text("""
                        Bestimmt Feldmaße, Aufstellung und Regelhinweise. \
                        Playbooks, die es schon gibt, behalten ihr Feld. \
                        Nur neue folgen der neuen Form.
                        """)
                }
                Section {
                    Farbwahl(farbe: $farbe)
                } header: {
                    Text("Vereinsfarbe")
                } footer: {
                    Text(geprueft.fehler
                         ?? String(localized:
                             "Wird für Kacheln und Akzente benutzt."))
                        .foregroundStyle(geprueft.taugt ? Farben.inkStill
                                                        : Farben.fehler)
                }
                Section {
                    logozeile
                    PhotosPicker(selection: $auswahl, matching: .images) {
                        // ZWEI GANZE `Text`, kein Fragezeichen dazwischen.
                        // Der Sprachenprüfer sieht einen Satz nur, wenn
                        // er DIREKT hinter `Text(` steht; in einem
                        // ternären Ausdruck findet er ihn nicht -- die
                        // Übersetzung wäre da und käme nie an.
                        if zeigtEinBild {
                            Text("Anderes Bild wählen")
                        } else {
                            Text("Bild wählen")
                        }
                    }
                    if zeigtEinBild {
                        Button("Logo entfernen", role: .destructive) {
                            logowunsch = .weg
                            auswahl = nil
                        }
                    }
                } header: {
                    Text("Logo")
                } footer: {
                    // KEINE ZAHL HIER. Wie groß ein Logo sein darf, sagt
                    // der Server; eine Zahl in der App wäre eine zweite
                    // Wahrheit und beim nächsten Verschieben die falsche.
                    // Die App verkleinert ohnehin vorher (`Bildpaket`),
                    // damit die Frage praktisch nie gestellt wird.
                    Text("""
                        Am besten quadratisch. Das Bild steht auf den \
                        Kacheln der Mannschaft und auf den Playcards.
                        """)
                }
                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            // `task(id:)` und nicht `onChange`: Das Einlesen ist
            // asynchron, und `onChange` hätte dafür einen eigenen
            // `Task` aufmachen müssen -- einen, den niemand abbricht,
            // wenn das Blatt zugeht oder schnell ein zweites Bild
            // gewählt wird.
            .task(id: auswahl) { await aufnehmen(auswahl) }
            .navigationTitle("Mannschaft bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        fertig(false)
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
                    Fertigknopf(name: String(localized: "Sichern")) {
                        Task { await sichern() }
                    }
                        .disabled(!bereit)
                }
            }
        }
    }

    private var bereit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && geprueft.taugt && !laeuft
    }

    /// Ist nach dem Speichern ein Bild da?
    ///
    /// Der WUNSCH zählt, nicht der Bestand: Wer gerade „entfernen"
    /// gedrückt hat, soll den Knopf nicht mehr sehen, auch wenn auf dem
    /// Server noch eins liegt.
    private var zeigtEinBild: Bool {
        switch logowunsch {
        case .neu: return true
        case .weg: return false
        case .unveraendert: return team.logo != nil
        }
    }

    /// Was gerade gilt -- als Bild, nicht als Satz.
    @ViewBuilder
    private var logozeile: some View {
        switch logowunsch {
        case .neu(let daten):
            HStack {
                if let bild = UIImage(data: daten) {
                    Image(uiImage: bild)
                        .resizable().scaledToFit()
                        .frame(width: 44, height: 44)
                }
                Text("Neu gewählt. Wird beim Speichern hochgeladen.")
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
            }
        case .weg:
            Text("Wird beim Speichern entfernt.")
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)
        case .unveraendert:
            if let ziel = team.logo {
                Netzbild(adresse: ziel) { ProgressView() }
                    .frame(width: 44, height: 44)
            } else {
                Text("Noch kein Logo.")
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
            }
        }
    }

    /// Ein ausgewähltes Foto einlesen und verkleinern.
    ///
    /// **Hier, nicht beim Speichern.** Aus einem Foto von 4000 Pixeln
    /// ein 512er PNG zu machen dauert einen Moment; passiert das erst
    /// beim Druck auf „Speichern", steht der Knopf so lange still und
    /// sieht kaputt aus. Beim Auswählen wartet ohnehin gerade jemand.
    private func aufnehmen(_ was: PhotosPickerItem?) async {
        guard let was else { return }
        fehler = nil
        guard let roh = try? await was.loadTransferable(type: Data.self),
              let klein = Bildpaket.alsLogo(roh) else {
            fehler = String(localized:
                "Dieses Bild ließ sich nicht lesen. Nimm ein anderes.")
            return
        }
        logowunsch = .neu(klein)
    }

    private func sichern() async {
        guard let wert = geprueft.wert else { return }
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        let laden = Laden(anmeldung: anmeldung)
        do {
            // ERST NAME UND FARBE, DANN DAS BILD. Andersherum stünde
            // nach einem abgelehnten Namen ein neues Logo auf dem
            // Server, während das Blatt eine Fehlermeldung zeigt -- die
            // Hälfte einer Änderung, die niemand angefordert hat.
            _ = try await laden.teamAendern(
                team.id, name: name.trimmingCharacters(in: .whitespaces),
                farbe: wert, spielform: spielform)
            switch logowunsch {
            case .neu(let daten):
                _ = try await laden.teamLogoSetzen(team.id, bild: daten)
            case .weg:
                _ = try await laden.teamLogoEntfernen(team.id)
            case .unveraendert:
                break
            }
            fertig(true)
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}

// MARK: - Teamcode erzeugen

/// Einen Teamcode erzeugen, mit wählbarer Haltbarkeit.
///
/// **Vorausgewählt sind 24 Stunden und nicht „unbegrenzt".** Die Wahl,
/// die man trifft, ohne hinzusehen, muss die harmlose sein. Die Liste
/// selbst ist erzeugt (`Haltbarkeit.swift`, aus `teamcode.py`) und nicht
/// abgeschrieben: Eine Reihenfolge, in der „unbegrenzt" oben steht,
/// sähe aus wie eine Entscheidung.
struct TeamcodeBlatt: View {
    let team: Modell.Mannschaft
    /// Der Satz für die Seite dahinter, oder `nil` bei Abbruch.
    let fertig: (String?) -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var haltbarkeit = Haltbarkeiten.vorgabe
    @State private var laeuft = false
    @State private var fehler: String?

    private var ersetzt: Bool { team.teamcode != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Gültig", selection: $haltbarkeit) {
                        ForEach(Haltbarkeiten.alle) { spanne in
                            Text(spanne.text).tag(spanne.wert)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Wie lange soll der Code gelten?")
                } footer: {
                    Text(warnung)
                }
                if ersetzt {
                    Section {
                        Text("Der bisherige Code gilt danach nicht mehr.")
                            .foregroundStyle(Farben.inkStill)
                    } footer: {
                        Text("""
                            Wer ihn im Training vorgelesen bekommen hat, \
                            kommt damit nicht mehr herein. Wer schon \
                            beigetreten ist, bleibt im Kader.
                            """)
                    }
                }
                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            .navigationTitle(ersetzt
                             ? String(localized: "Neuen Code erzeugen")
                             : String(localized: "Teamcode erzeugen"))
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
                    Fertigknopf(name: String(localized: "Erzeugen")) {
                        Task { await erzeugen() }
                    }
                        .disabled(laeuft)
                }
            }
        }
    }

    /// Die Warnung beim Knopf. Sie nennt beides: dass ein Code
    /// weitergeschickt werden kann, und dass „unbegrenzt" für immer heißt.
    ///
    /// Als eigene Eigenschaft und nicht als Ausdruck in der Ansicht --
    /// dieselbe Lehre wie aus `PlaybookListe.loeschfrage` (B6).
    private var warnung: String {
        if Haltbarkeiten.mit(wert: haltbarkeit).unbegrenzt {
            return String(localized: """
                Unbegrenzt heißt für immer. Wer den Code weiterschickt, lässt \
                Fremde in eure Plays, und du merkst es nur an der Zahl der \
                Beitritte.
                """)
        }
        return String(localized: """
            Ein Code kann weitergeschickt werden. Danach sind eure Plays in \
            fremden Händen, bis du einen neuen erzeugst.
            """)
    }

    private func erzeugen() async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            let neu = try await Laden(anmeldung: anmeldung).teamcodeAnlegen(
                team: team.id, haltbarkeit: haltbarkeit)
            fertig(neu.ersetzt
                   ? String(localized: """
                       Neuer Teamcode: \(neu.teamcode.lesbar). Der alte gilt \
                       nicht mehr.
                       """)
                   : String(localized:
                        "Teamcode: \(neu.teamcode.lesbar)"))
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}

// MARK: - Einladung

/// Ein Link für EINE Person, EINMAL gültig, mit Rolle.
struct EinladungBlatt: View {
    let team: Modell.Mannschaft
    let fertig: (Bool) -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var rolle = ""
    @State private var tage = 0
    @State private var laeuft = false
    @State private var fehler: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Rolle") {
                    Picker("Rolle", selection: $rolle) {
                        ForEach(team.rollen) { auswahl in
                            Text(auswahl.text).tag(auswahl.wert)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Picker("Gültig", selection: $tage) {
                        ForEach(team.einladungTage ?? [7, 14, 30], id: \.self) {
                            Text("\($0) Tage").tag($0)
                        }
                    }
                } footer: {
                    Text("""
                        Der Link gilt einmal. Wer ihn einlöst, bekommt genau \
                        diese Rolle.
                        """)
                }
                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            .navigationTitle("Einladung anlegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        fertig(false)
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
                    Fertigknopf(name: String(localized: "Anlegen")) {
                        Task { await anlegen() }
                    }
                        .disabled(rolle.isEmpty || laeuft)
                }
            }
            .onAppear {
                // Die Vorbelegung kommt vom Server. Sie in Swift zu
                // setzen hieße, sie bei der nächsten Änderung an zwei
                // Stellen nachzuziehen.
                if rolle.isEmpty {
                    rolle = team.standardRolle ?? team.rollen.last?.wert ?? ""
                }
                if tage == 0 { tage = team.standardTage ?? 14 }
            }
        }
    }

    private func anlegen() async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            _ = try await Laden(anmeldung: anmeldung).einladungAnlegen(
                team: team.id, rolle: rolle, tage: tage)
            fertig(true)
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}

// MARK: - Maschinenschlüssel

struct SchluesselBlatt: View {
    let team: Modell.Mannschaft
    /// Der frisch angelegte Schlüssel, oder `nil` bei Abbruch.
    let fertig: (Modell.Schluessel?) -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var name = ""
    @State private var bereich = ""
    @State private var tage = 0
    @State private var laeuft = false
    @State private var fehler: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Wofür ist er? z. B. Liveticker", text: $name)
                } header: {
                    Text("Name")
                } footer: {
                    Text("""
                        Damit du in einem Jahr noch weißt, welches Programm \
                        daran hängt.
                        """)
                }
                Section("Was er darf") {
                    Picker("Bereich", selection: $bereich) {
                        ForEach(team.schluesselBereiche ?? []) { auswahl in
                            Text(auswahl.text).tag(auswahl.wert)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Picker("Gültig", selection: $tage) {
                        ForEach(team.schluesselTage ?? [30, 180, 365, 730],
                                id: \.self) {
                            Text("\($0) Tage").tag($0)
                        }
                    }
                } footer: {
                    Text("""
                        Ein Schlüssel gehört der Mannschaft und keinem \
                        Menschen. Er kann jederzeit widerrufen werden.
                        """)
                }
                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            .navigationTitle("Schlüssel anlegen")
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
                    Fertigknopf(name: String(localized: "Anlegen")) {
                        Task { await anlegen() }
                    }
                        .disabled(name.trimmingCharacters(in: .whitespaces)
                                    .isEmpty || laeuft)
                }
            }
            .onAppear {
                if bereich.isEmpty {
                    bereich = team.schluesselBereiche?.first?.wert ?? ""
                }
                if tage == 0 { tage = team.standardSchluesselTage ?? 365 }
            }
        }
    }

    private func anlegen() async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            fertig(try await Laden(anmeldung: anmeldung).schluesselAnlegen(
                team: team.id,
                name: name.trimmingCharacters(in: .whitespaces),
                bereich: bereich, tage: tage))
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}

/// Der Klartext eines frisch angelegten Schlüssels.
///
/// **Er steht genau hier und danach nirgends mehr**, auch nicht auf dem
/// Server: Dort liegt nur ein Hash. Im Browser geht er durch die Sitzung
/// an die nächste Seite; die App hat keine Sitzung, also gibt es ihn in
/// der Antwort auf das Anlegen. Wer ihn wegklickt, legt einen neuen an.
struct SchluesselZeigen: View {
    let schluessel: Modell.Schluessel
    let fertig: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(schluessel.wert ?? "")
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(Farben.ink)
                } header: {
                    Text(schluessel.name)
                } footer: {
                    Text("""
                        Schreib ihn jetzt weg. Danach zeigt ihn niemand mehr, \
                        auch der Server nicht. Wer ihn verliert, legt einen \
                        neuen an und widerruft diesen.
                        """)
                }
                if let wert = schluessel.wert {
                    Section {
                        ShareLink(item: wert) {
                            Label("Schlüssel teilen",
                                  systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            .navigationTitle("Neuer Schlüssel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Fertigknopf { fertig() }
                }
            }
        }
    }
}

// MARK: - Mannschaft löschen

/// Eine Mannschaft löschen -- mit allem, was daran hängt.
///
/// **Der Auftrag.** Niklas am 08.09.2026: „man sollte übrigens wenn man
/// auf mannschaft geht auch die möglichkeit haben eine mannschaft zu
/// löschen sowohl in app als auch im web."
///
/// **Dieselbe Leiter wie im Browser**, und zwar Stufe für Stufe, weil
/// zwei verschiedene Rückfragen für dieselbe Handlung bedeuten, dass
/// eine von beiden zu lasch ist:
///
/// * **Erst zeigen, was verloren geht, dann fragen.** Gezählt und nicht
///   geschätzt: Wer „einige Plays" liest, weiß nicht, ob er zwei oder
///   achtzig wegwirft.
/// * **Bestätigt wird durch ABTIPPEN DES NAMENS.** Ein „Wirklich
///   löschen?" tippt man weg, ohne es gelesen zu haben. Einen Namen
///   tippt niemand versehentlich ab.
/// * **Nur wer die Mannschaft führt.** Diese Ansicht ist von der
///   Mannschaftsseite aus nur dann erreichbar, und der Server prüft es
///   ein zweites Mal -- eine Sicht ist keine Berechtigung.
struct MannschaftLoeschen: View {
    let team: Modell.Mannschaft
    /// `true`, wenn wirklich gelöscht wurde. Die Mannschaftsseite geht
    /// dann zurück in die Liste; stehen bleiben könnte sie nicht, sie
    /// zeigt etwas, das es nicht mehr gibt.
    let fertig: (Bool) -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var getippt = ""
    @State private var laeuft = false
    @State private var fehler: String?

    /// Offene Wege ins Team, in einer Zahl. Einladung, Schlüssel und
    /// Teamcode sind für den, der hier steht, dasselbe: Zugänge, die
    /// danach zu sind.
    private var zugaenge: Int {
        (team.einladungen?.count ?? 0)
            + (team.schluessel?.count ?? 0)
            + (team.teamcode != nil ? 1 : 0)
    }

    /// Der Name muss genau stimmen, bis auf Leerzeichen am Rand. Die
    /// Groß- und Kleinschreibung bleibt streng: Sie ist Teil des
    /// Namens, und wer abtippt, sieht ihn ja vor sich.
    private var stimmt: Bool {
        getippt.trimmingCharacters(in: .whitespaces) == team.name
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                Form {
                    bilanzteil
                    tippteil
                    if let fehler {
                        Section {
                            Text(fehler).foregroundStyle(Farben.fehler)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Mannschaft löschen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Abbruchknopf { fertig(false) }
                        .disabled(laeuft)
                }
            }
        }
    }

    private var bilanzteil: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(team.name) mit allem, was daran hängt. Das lässt sich nicht rückgängig machen.")
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
                Text(team.playbooks == 1
                     ? String(localized: "1 Playbook")
                     : String(localized: "\(team.playbooks) Playbooks"))
                Text(team.plays == 1
                     ? String(localized: "1 Play mit allen Zeichnungen")
                     : String(localized: "\(team.plays) Plays mit allen Zeichnungen"))
                Text(team.mitglieder == 1
                     ? String(localized: "1 Person im Kader")
                     : String(localized: "\(team.mitglieder) Personen im Kader"))
                if zugaenge > 0 {
                    Text(zugaenge == 1
                         ? String(localized: "1 offener Zugang, also Einladung, Schlüssel oder Teamcode")
                         : String(localized: "\(zugaenge) offene Zugänge, also Einladungen, Schlüssel und Teamcode"))
                }
                Text("""
                    Dazu jeder Lernstand und jeder Lernauftrag dieser \
                    Mannschaft, auch der von Spielern, die gerade nicht \
                    hier sind.
                    """)
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)
            }
            .padding(.vertical, 4)
            .listRowBackground(Farben.flaechePanel)
        } header: {
            Text("Was verloren geht")
        }
    }

    private var tippteil: some View {
        Section {
            TextField("Name der Mannschaft", text: $getippt)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .listRowBackground(Farben.flaechePanel)
            Button(role: .destructive) {
                Task { await loeschen() }
            } label: {
                HStack {
                    if laeuft { ProgressView().tint(Farben.fehler) }
                    Text("Mannschaft endgültig löschen")
                }
            }
            .disabled(!stimmt || laeuft)
            .listRowBackground(Farben.flaechePanel)
        } header: {
            Text("Zum Bestätigen den Namen abtippen")
        } footer: {
            // `verbatim`: Der Name ist ein Eigenname und kein Satz.
            // Als Schlüssel wäre er „%@" -- ein Katalogeintrag, der aus
            // nichts als einem Platzhalter besteht und in jeder Sprache
            // dasselbe heißt.
            Text(verbatim: team.name)
                .font(.footnote.monospaced())
                .foregroundStyle(Farben.inkStill)
        }
    }

    private func loeschen() async {
        // Zweite Prüfung, obwohl der Knopf gesperrt ist: Zwischen dem
        // Tippen und dem Druck kann das Feld wieder leer sein, und ein
        // gesperrter Knopf ist eine Anzeige, keine Bedingung.
        guard stimmt, !laeuft else { return }
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            try await Laden(anmeldung: anmeldung).teamLoeschen(team.id)
            fertig(true)
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}
