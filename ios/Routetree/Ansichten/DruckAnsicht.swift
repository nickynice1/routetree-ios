import StoreKit
import SwiftUI
import UIKit

/// Die Druckseite der App (B10).
///
/// Sie zeigt dieselben Ausgaben wie die Druckseite im Browser, mit
/// denselben Einstellungen: Playcards, Call Sheet, Wristcoach-Einlagen
/// und die Bilder. An einem einzelnen Play sind es das Blatt und das
/// Bild.
///
/// **Der Unterschied zum Browser ist der letzte Schritt, und nur der.**
/// Dort öffnet sich ein PDF in einem neuen Tab, und der Trainer druckt
/// es aus dem Browser heraus. Hier entsteht eine Datei auf dem Telefon,
/// und von dort geht sie ins Teilen-Blatt oder direkt zum Drucker. Alles
/// davor, bis auf das letzte Zeichen der Adresse, ist dasselbe.
struct DruckAnsicht: View {

    /// Woran gedruckt wird.
    let titel: String
    /// Die Kennung, die in die Adresse geht: das Heft oder der Play.
    let kennung: Int
    /// Welche Ausgaben zur Wahl stehen.
    let ausgaben: [Ausgabe]
    /// Das Heft, zu dem die Auskunft gehört. Bei einem Play ist es
    /// SEIN Heft: Ob der Streifen der Demo mitdruckt und ob ein Logo
    /// hinterlegt ist, hängt am Verein und nicht am einzelnen Play.
    let heft: Int?

    /// Für ein ganzes Playbook.
    init(playbook: Modell.Playbook) {
        self.titel = playbook.name
        self.kennung = playbook.id
        self.ausgaben = Druckwahl.ausgaben
        self.heft = playbook.id
    }

    /// Für einen einzelnen Play.
    ///
    /// `heft` ist SEIN Playbook und darf fehlen: Ob der Streifen der
    /// Demo mitdruckt, hängt am Verein und nicht am Play, und ohne
    /// Playbook lässt sich das nicht erfragen. Dann bleibt der Hinweis
    /// aus, statt geraten zu werden.
    init(playTitel: String, play: Int, heft: Int?) {
        self.titel = playTitel
        self.kennung = play
        self.ausgaben = Druckwahl.playAusgaben
        self.heft = heft
    }

    /// Der Weg zurück in die Playliste -- für den Leerzustand (B14).
    @Environment(\.dismiss) private var zurueck

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var auskunft: Modell.Druckauskunft?
    @State private var fehler: String?
    @State private var gewaehlt: Ausgabe?

    var body: some View {
        ZStack {
            Farben.flaeche.ignoresSafeArea()
            inhalt
        }
        .navigationTitle("Drucken")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $gewaehlt) { ausgabe in
            DruckBlatt(ausgabe: ausgabe, kennung: kennung,
                       auskunft: auskunft, ersatzname: titel)
        }
        .task { await laden() }
    }

    @ViewBuilder
    private var inhalt: some View {
        if let fehler {
            Hinweis(zeichen: "exclamationmark.triangle",
                    titel: String(localized: "Das hat nicht geklappt"),
                    text: fehler) {
                Button("Nochmal versuchen") { Task { await laden() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
            }
        } else if let auskunft, auskunft.plays == 0 {
            // Dasselbe wie im Browser: Ein Playbook ohne Plays hat
            // nichts zu drucken, und ein leerer Bogen wäre die
            // Antwort, die niemand erwartet hat.
            // MIT EINEM AUSGANG (B14). Der Satz nannte den nächsten
            // Schritt und liess einen dabei stehen: Zeichnen geht hier
            // nicht, und der Weg zurück war der Knopf oben links, den
            // in diesem Zustand niemand sucht.
            Hinweis(zeichen: "printer.dotmatrix",
                    titel: String(localized: "Noch nichts zu drucken"),
                    text: String(localized: """
                        Dieses Playbook hat noch keine Plays. Zeichne erst \
                        einen, dann gibt es hier etwas zu drucken.
                        """)) {
                Button("Zurück zu den Plays") { zurueck() }
                    .buttonStyle(.borderedProminent)
                    .tint(Farben.akzent)
            }
        } else {
            liste
        }
    }

    private var liste: some View {
        List {
            if let auskunft, auskunft.demo {
                Section {
                    Text(auskunft.demoText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Farben.gold)
                    // „Jede Ausgabe trägt diesen Streifen" stimmte nicht
                    // ganz: SVG gibt der Server in der Demo GAR NICHT
                    // heraus (`grenzen.svg_pruefen`), weil sich ein
                    // Streifen darin in zehn Sekunden wegklicken liesse.
                    // Der Satz versprach also einen Streifen, wo in
                    // Wahrheit eine Fehlermeldung kommt -- und die
                    // beiden SVG-Einträge stehen in der Liste darunter.
                    Text("""
                        Dieser Verein ist in der Demo. Jedes Blatt trägt \
                        diesen Streifen, auf jeder Seite und in jeder Karte, \
                        damit nichts davon versehentlich am Spieltag landet. \
                        SVG-Dateien gibt die Demo nicht heraus, weil sich der \
                        Streifen darin zu leicht entfernen ließe. Mit Abo \
                        fällt beides weg.
                        """)
                        .font(.footnote)
                        .foregroundStyle(Farben.inkStill)
                }
                .listRowBackground(Farben.flaechePanel)
            }

            Section {
                ForEach(ausgaben) { ausgabe in
                    Button { gewaehlt = ausgabe } label: {
                        // DAS BILD ZUR AUSGABE (R99).
                        //
                        // Niklas am 09.09.2026, mit einem Bild der
                        // Druckauswahl von Playmaker X und fünf
                        // gezeichneten Symbolen dazu: „bgl unserer druck
                        // funktion ja hübsch sie einfach mit unseren svg
                        // auf bitte".
                        //
                        // Ein Papierstapel, ein Armband, ein Bogen: Man
                        // sieht vor dem Antippen, was herauskommt. Der
                        // Name allein sagt es nicht -- „Playcards" und
                        // „Play-Blatt" sind zwei Wörter, die sich um
                        // einen Buchstaben unterscheiden und um eine
                        // ganze Papiersorte.
                        //
                        // Die Zeichnung kommt aus derselben Quelle wie
                        // im Browser (`druck.AUSGABEN`, Feld `zeichen`);
                        // im Bildkatalog liegt sie als PDF und bleibt
                        // deshalb in jeder Grösse scharf.
                        HStack(alignment: .top, spacing: 12) {
                            Image(ausgabe.zeichen)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 60)
                                .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: ausgabe.druckbar
                                      ? "printer" : "square.and.arrow.up")
                                    .foregroundStyle(Farben.akzent)
                                Text(ausgabe.titel)
                                    .font(.headline)
                                    .foregroundStyle(Farben.ink)
                            }
                            Text(ausgabe.text)
                                .font(.footnote)
                                .foregroundStyle(Farben.inkStill)
                                .multilineTextAlignment(.leading)
                            // DIE ZAHL DER VARIANTEN (R56).
                            //
                            // Niklas am 02.09.2026 zum Druckbildschirm
                            // von Playmaker X: Dort steht an jeder
                            // Kachel „11 Styles". Das Gute daran ist
                            // nicht die Schrägstellung, sondern die
                            // Auskunft -- man sieht vor dem Antippen,
                            // ob es dort überhaupt etwas zu wählen
                            // gibt.
                            //
                            // Nur ab zwei: „1 Variante" sagt nichts,
                            // was der Titel nicht schon sagt, und
                            // stünde nur im Weg.
                            if ausgabe.varianten > 1 {
                                Text("\(ausgabe.varianten) Varianten")
                                    .font(.caption)
                                    .foregroundStyle(Farben.inkStill)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .overlay(Capsule()
                                        .strokeBorder(Farben.linie,
                                                      lineWidth: 1))
                            }
                        }
                        }
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(titel)
            } footer: {
                if let auskunft, !auskunft.hatLogo {
                    Text("""
                        Für dieses Team ist kein Logo hinterlegt. Gedruckt \
                        wird dann das Kürzel \(auskunft.kuerzel).
                        """)
                }
            }
            .listRowBackground(Farben.flaechePanel)
        }
        .scrollContentBackground(.hidden)
    }

    private func laden() async {
        spur("drucken", "offen")
        guard let heft else { return }
        fehler = nil
        do {
            auskunft = try await Laden(anmeldung: anmeldung).druckauskunft(
                playbook: heft)
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}

// MARK: - Ein Blatt mit den Einstellungen

/// Die Einstellungen einer Ausgabe, und darunter die beiden Knöpfe.
///
/// **Welche Felder hier stehen, entscheidet der Server.**
/// `ausgabe.felder` ist erzeugt (`Druckwahl.swift`); eine Einstellung,
/// die der Server kennt und die App nicht, fehlt damit nicht
/// stillschweigend, sondern gar nicht.
struct DruckBlatt: View {
    let ausgabe: Ausgabe
    let kennung: Int
    let auskunft: Modell.Druckauskunft?
    /// Der Name, unter dem die Datei abgelegt wird, falls der Server
    /// keinen mitschickt.
    let ersatzname: String

    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen
    /// Apples Bewertungsabfrage (R154).
    ///
    /// **Sie sagt nicht, ob sie etwas gezeigt hat.** Apple
    /// entscheidet das selbst und schweigt darueber -- deshalb
    /// wird der Zaehler danach so oder so zurueckgesetzt.
    @Environment(\.requestReview) private var bewertungAnfragen

    @State private var wunsch: Druckwunsch
    @State private var laeuft = false
    @State private var fehler: String?
    @State private var zumTeilen: Druckspeicher.Datei?
    /// Ein paar Plays für die Vorschau (R55).
    ///
    /// **Wenige und nicht alle.** Gezeigt werden höchstens so viele,
    /// wie auf ein Blatt passen; mehr zu holen kostete Zeit für ein
    /// Bild, das sie nicht zeigt. Sie kommen aus dem Vorrat, den die
    /// Playliste ohnehin füllt (B6).
    @State private var vorschauplays: [Modell.PlayVoll] = []

    init(ausgabe: Ausgabe, kennung: Int, auskunft: Modell.Druckauskunft?,
         ersatzname: String) {
        self.ausgabe = ausgabe
        self.kennung = kennung
        self.auskunft = auskunft
        self.ersatzname = ersatzname
        _wunsch = State(initialValue: Druckwunsch(art: ausgabe.art))
    }

    private var felder: Set<String> { Set(ausgabe.felder) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(ausgabe.text)
                        .font(.footnote)
                        .foregroundStyle(Farben.inkStill)
                }
                .listRowBackground(Farben.flaechePanel)

                // DIE VORSCHAU (R55). Sie steht GANZ OBEN und ändert
                // sich mit jeder Einstellung darunter -- wer von vier
                // Karten auf neun umstellt, sieht das Blatt anders
                // werden, bevor er es erzeugt.
                //
                // Vorher war dieses Blatt eine Liste aus Namen und
                // Erklärungen: Wer „Wristcoach-Einlage" noch nie
                // gesehen hat, wusste nach dem Lesen so viel wie
                // vorher.
                Section {
                    Druckvorschau(art: ausgabe.art, plays: vorschauplays,
                                  wahl: wunsch)
                        .frame(maxHeight: 200)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                } header: {
                    Text("Vorschau")
                }
                .listRowBackground(Farben.flaechePanel)

                if felder.contains("pro_seite") { kartenfeld }
                if felder.contains("spalten") { spaltenfeld }
                if felder.contains("groesse") { armbandfelder }
                if felder.contains("bildbreite") { bildfeld }
                // R74. Dieselbe Frage an JEDER Ausgabe: wie viel vom
                // Feld zu sehen ist und wie kräftig gezeichnet wird.
                // Vorher beantwortete jede Ausgabe ihre eigenen Fragen,
                // und drei davon beantworteten gar keine.
                if felder.contains("zoom") || felder.contains("zeichenstil") {
                    zeichenfelder
                }
                if felder.contains("logo") || felder.contains("sw") {
                    aussehen
                }
                if felder.contains("seite") { seitenfeld }

                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Farben.fehler)
                    }
                    .listRowBackground(Farben.flaechePanel)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Grundflaeche())
            .navigationTitle(ausgabe.titel)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { knopfleiste }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Fertigknopf { schliessen() }
                }
            }
            .sheet(item: $zumTeilen, onDismiss: vielleichtBewerten) { datei in
                Teilblatt(url: datei.url)
            }
            .task { await vorschauLaden() }
        }
    }

    /// Die Plays für die Vorschau (R55).
    ///
    /// **Aus dem Vorrat, sonst vom Netz**, und höchstens neun: Mehr
    /// passen auf kein Blatt, und mehr zu holen kostete Zeit für ein
    /// Bild, das sie nicht zeigt.
    ///
    /// Ohne Fehlerbild: Kommt nichts, bleibt das Blatt leer. Der
    /// Druckknopf darunter funktioniert weiter, und ein rotes Dreieck
    /// über einer Vorschau wäre eine Warnung vor nichts.
    private func vorschauLaden() async {
        guard vorschauplays.isEmpty else { return }
        let laden = Laden(anmeldung: anmeldung)
        // Bei einem EINZELNEN Play ist die Kennung der Play selbst.
        if Druckblock.istPlayAusgabe(ausgabe.art) {
            if let voll = try? await laden.play(kennung) {
                vorschauplays = [voll]
            }
            return
        }
        guard let liste = try? await laden.plays(playbook: kennung) else {
            return
        }
        var gesammelt: [Modell.PlayVoll] = []
        for kurz in liste.prefix(9) {
            if let ausgabe = try? await laden.playMitVorrat(
                kurz.id, version: kurz.version) {
                gesammelt.append(ausgabe.wert)
            }
        }
        vorschauplays = gesammelt
    }

    // --- Die Felder -------------------------------------------------------

    private var kartenfeld: some View {
        Section {
            Picker("Karten pro Seite", selection: $wunsch.proSeite) {
                ForEach(Druckwahl.kartenZahlen, id: \.self) { zahl in
                    Text(String(zahl)).tag(zahl)
                }
            }
            // R74. Niklas am 03.09.2026: „Playcards -- ohne Wahl, was
            // auf der Karte steht." Wer die Karten am Spieltag
            // benutzt, will die Situationen; wer sie im Training
            // verteilt, die Hinweise des Trainers.
            Picker("Unter dem Diagramm", selection: $wunsch.kartenfuss) {
                ForEach(Druckwahl.kartenfuesse) { wahl in
                    Text(wahl.label).tag(wahl.wert)
                }
            }
        } footer: {
            Text("""
                Steht dort nichts, bleibt die Zeile weg, und alle Karten \
                sind gleich hoch.
                """)
        }
        .listRowBackground(Farben.flaechePanel)
    }

    private var spaltenfeld: some View {
        Section {
            Picker("Spalten", selection: $wunsch.spalten) {
                ForEach(Druckwahl.spaltenZahlen, id: \.self) { zahl in
                    Text(String(zahl)).tag(zahl)
                }
            }
            // R74. Ein Block „Red Zone" mit dreiundzwanzig Einträgen ist
            // am Spielfeldrand keine Hilfe: Gerufen werden die ersten
            // fünf. Die Wahl fehlte, und damit stand das ganze Heft
            // dreimal auf dem Blatt.
            Picker("Plays je Block", selection: $wunsch.jeBlock) {
                ForEach(Druckwahl.jeBlockZahlen, id: \.self) { zahl in
                    if zahl == 0 {
                        Text("Alle").tag(zahl)
                    } else {
                        Text("Die ersten \(zahl)").tag(zahl)
                    }
                }
            }
            Toggle("Mit kleinem Diagramm", isOn: $wunsch.diagramme)
                .tint(Farben.akzent)
                .foregroundStyle(Farben.ink)
        } footer: {
            Text("""
                Im Kopf jedes Blocks steht weiter, wie viele es insgesamt \
                sind. „5 von 23" ist eine Auskunft, „5" wäre eine falsche.
                """)
        }
        .listRowBackground(Farben.flaechePanel)
    }

    /// Zoom und Zeichenstil -- die zwei Fragen, die jede Ausgabe hat.
    @ViewBuilder
    private var zeichenfelder: some View {
        Section {
            if felder.contains("zoom") {
                Picker("Ausschnitt", selection: $wunsch.zoom) {
                    ForEach(Druckwahl.zooms) { stufe in
                        Text(stufe.label).tag(stufe.wert)
                    }
                }
            }
            if felder.contains("zeichenstil") {
                Picker("Strich", selection: $wunsch.zeichenstil) {
                    ForEach(Druckwahl.zeichenstile) { stufe in
                        Text(stufe.label).tag(stufe.wert)
                    }
                }
            }
        } footer: {
            // WARUM EINE EINSTELLUNG UND NICHT DREI: Playmaker X hat
            // Symbolgröße, Linienstärke und Beschriftungsstil getrennt.
            // Auf einer Einlage von 125 Millimetern sind das keine
            // unabhängigen Größen -- eine dickere Route unter gleicher
            // Schrift ergibt Matsch.
            Text("""
                Der Ausschnitt sagt, wie viel vom Feld im Bild steht. Der \
                Strich ändert Linien, Symbole und Schrift zusammen.
                """)
        }
        .listRowBackground(Farben.flaechePanel)
    }

    /// Das Einlagemaß in Zoll, fertig geschrieben (R74).
    ///
    /// **Als eigene Eigenschaft und nicht im Satz gerechnet.** In einem
    /// mehrzeiligen Swift-Literal ist der Backslash am Zeilenende die
    /// Fortsetzung -- INNERHALB einer Interpolation aber gewöhnlicher
    /// Code, und dort ist er ein Syntaxfehler. Eine lange Rechnung im
    /// Satz zwingt also entweder zu einer sehr langen Zeile oder zu
    /// einem Bau, der nicht übersetzt. Ausserdem trägt `appsprache.py`
    /// jeden interpolierten Ausdruck in seiner Tafel; ein kurzer Name
    /// steht dort lesbar, ein verschachtelter Aufruf nicht.
    private var zollbreite: String {
        Druckblock.mass(Druckblock.zoll(wunsch.einlage.breite))
    }
    private var zollhoehe: String {
        Druckblock.mass(Druckblock.zoll(wunsch.einlage.hoehe))
    }

    /// Wie viele verschiedene Einlagen aus dem Heft werden (R74).
    private var einlagenzahl: Int {
        Druckblock.einlagenZahl(plays: auskunft?.plays ?? 0,
                                jeEinlage: wunsch.jeEinlage)
    }

    /// Was aus dem Heft wird -- als GANZER SATZ je Fall (R126).
    ///
    /// **Ein Satz je Fall und kein Satzstück**, dieselbe Entscheidung
    /// wie in `PlaybookListe.loeschfrage`: Wer eine Zahl mitten in
    /// einen Satz setzt, bekommt „1 Einlagen", und in anderen Sprachen
    /// richtet sich noch mehr als die Endung danach.
    ///
    /// Gefunden am 11.09.2026 auf einem Bildschirmfoto von Niklas:
    /// „Aus 8 Plays werden 1 Einlagen, jede 4 mal auf dem Bogen."
    ///
    /// **Der Satz steht über dem Knopf, der Papier verbraucht.** Er ist
    /// die einzige Stelle, an der vorher jemand sieht, wie viele
    /// verschiedene Zuschnitte herauskommen -- und einen Satz, der
    /// falsch klingt, überliest man samt seiner Zahl.
    private var einlagensatz: String {
        let plays = auskunft?.plays ?? 0
        let einlagen = einlagenzahl
        let kopien = wunsch.kopien
        if plays == 1 {
            return kopien == 1
                ? String(localized: "Aus einem Play wird eine Einlage, einmal auf dem Bogen.")
                : String(localized: "Aus einem Play wird eine Einlage, \(kopien)-mal auf dem Bogen.")
        }
        if einlagen == 1 {
            return kopien == 1
                ? String(localized: "Aus \(plays) Plays wird eine Einlage, einmal auf dem Bogen.")
                : String(localized: "Aus \(plays) Plays wird eine Einlage, \(kopien)-mal auf dem Bogen.")
        }
        return kopien == 1
            ? String(localized: "Aus \(plays) Plays werden \(einlagen) verschiedene Einlagen, jede einmal auf dem Bogen.")
            : String(localized: "Aus \(plays) Plays werden \(einlagen) verschiedene Einlagen, jede \(kopien)-mal auf dem Bogen.")
    }

    @ViewBuilder
    private var armbandfelder: some View {
        Section {
            Picker("Größe", selection: $wunsch.groesse) {
                ForEach(Druckwahl.groessen) { groesse in
                    Text(groesse.label).tag(groesse.wert)
                }
                Text(Druckwahl.freiLabel).tag(Druckwahl.groesseFrei)
            }
            if wunsch.groesse == Druckwahl.groesseFrei {
                Schrittfeld(titel: String(localized: "Breite in mm"),
                            wert: $wunsch.breite,
                            von: Druckwahl.breiteMin, bis: Druckwahl.breiteMax)
                Schrittfeld(titel: String(localized: "Höhe in mm"),
                            wert: $wunsch.hoehe,
                            von: Druckwahl.hoeheMin, bis: Druckwahl.hoeheMax)
            }
            // R74. Niklas am 03.09.2026 mit den Bildern von Playmaker X:
            // „Guck und denn sind es so 8 plays Einlagen die man
            // ausschneidet." Vorher kamen ALLE Plays auf JEDE Einlage,
            // und „Einlagen pro Bogen" war die einzige Zahl -- die
            // beantwortet aber die Frage danach, nicht diese.
            //
            // ÜBER DEM KOPIENFELD, weil es die frühere Frage ist: Erst
            // was auf eine Einlage kommt, dann wie oft sie gedruckt wird.
            Picker("Plays je Einlage", selection: $wunsch.jeEinlage) {
                ForEach(Druckwahl.jeEinlageZahlen, id: \.self) { zahl in
                    // Die Null ist keine Zahl, sondern eine Ansage --
                    // „alle auf eine". Sie als „0" anzuschreiben wäre
                    // die eine Lesart, die niemand meint.
                    if zahl == 0 {
                        Text("Alle auf eine Einlage").tag(zahl)
                    } else {
                        Text("\(zahl) je Einlage").tag(zahl)
                    }
                }
            }
            Picker("Anordnung", selection: $wunsch.anordnung) {
                ForEach(Druckwahl.anordnungen) { art in
                    Text(art.label).tag(art.wert)
                }
            }
            Stepper("Einlagen pro Bogen: \(wunsch.kopien)",
                    value: $wunsch.kopien,
                    in: Druckwahl.kopienMin...Druckwahl.kopienMax)
                .foregroundStyle(Farben.ink)
            Picker("Bauart", selection: $wunsch.stil) {
                ForEach(Druckwahl.stile) { stil in
                    Text(stil.label).tag(stil.wert)
                }
            }
        } footer: {
            // Was WIRKLICH gedruckt wird, und zwar gerechnet. Ein frei
            // getipptes Maß, das zufällig der Jugendgröße entspricht,
            // heißt hier „Jugend" und nicht „Eigenes Maß" -- genau wie
            // auf dem Bogen, der dabei herauskommt.
            VStack(alignment: .leading, spacing: 6) {
                Text("""
                    Gedruckt wird \(wunsch.einlage.label), \
                    \(Druckblock.mass(wunsch.einlage.breite)) × \
                    \(Druckblock.mass(wunsch.einlage.hoehe)) mm \
                    (\(zollbreite) × \(zollhoehe) Zoll), mit \
                    \(Druckblock.mass(Druckwahl.schnittZugabeMm)) mm \
                    Schnittzone. Gedruckt wird etwas höher als das Fenster: \
                    Die Einlage rutscht hinter den Rand, sonst verschwindet \
                    die unterste Zeile.
                    """)
                // WIE VIELE ZUSCHNITTE DABEI HERAUSKOMMEN (R74). Das ist
                // die Zahl, die zählt: Wer acht Plays je Einlage wählt
                // und dreißig Plays hat, schneidet vier verschiedene
                // Einlagen aus -- jede so oft, wie oben steht.
                Text(einlagensatz)
            }
        }
        .listRowBackground(Farben.flaechePanel)
    }

    private var bildfeld: some View {
        Section {
            Picker("Breite", selection: $wunsch.bildbreite) {
                ForEach(Druckwahl.bildBreiten) { breite in
                    Text(breite.label).tag(breite.wert)
                }
            }
        } footer: {
            Text("""
                SVG ist ein Vektorbild. Es bleibt scharf, egal wie groß du es \
                ziehst.
                """)
        }
        .listRowBackground(Farben.flaechePanel)
    }

    @ViewBuilder
    private var aussehen: some View {
        Section {
            if felder.contains("logo") {
                Toggle(auskunft?.hatLogo == false
                       ? String(localized: "Mit Kürzel des Vereins")
                       : String(localized: "Mit Vereinslogo"),
                       isOn: $wunsch.logo)
                    .tint(Farben.akzent)
                    .foregroundStyle(Farben.ink)
            }
            if felder.contains("sw") {
                Toggle("Schwarzweiß für den Kopierer", isOn: $wunsch.sw)
                    .tint(Farben.akzent)
                    .foregroundStyle(Farben.ink)
            }
        }
        .listRowBackground(Farben.flaechePanel)
    }

    @ViewBuilder
    private var seitenfeld: some View {
        // Nur wenn es überhaupt etwas zu wählen gibt. Bei einer
        // einzigen belegten Seite wäre die Auswahl „Alle" gegen
        // „Offense" mit denselben Plays auf beiden Seiten.
        if let seiten = auskunft?.seiten, seiten.count > 1 {
            Section {
                Picker("Welche Plays", selection: $wunsch.seite) {
                    Text("Alle (\(auskunft?.plays ?? 0))").tag("")
                    ForEach(seiten) { seite in
                        Text("\(seite.name) (\(seite.anzahl))").tag(seite.wert)
                    }
                }
            }
            .listRowBackground(Farben.flaechePanel)
        }
    }

    // --- Die beiden Knöpfe ------------------------------------------------

    private var knopfleiste: some View {
        HStack(spacing: 12) {
            Button {
                Task { await holen(dann: .teilen) }
            } label: {
                Label("Teilen", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            // Der Druckknopf steht nur da, wo etwas zu drucken ist. Ein
            // Archiv voller SVG lässt sich teilen, aber nicht an einen
            // Drucker schicken.
            if ausgabe.druckbar {
                Button {
                    Task { await holen(dann: .drucken) }
                } label: {
                    Label("Drucken", systemImage: "printer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Farben.akzent)
            }
        }
        .disabled(laeuft)
        .overlay {
            if laeuft { ProgressView().tint(Farben.akzent) }
        }
        .padding(14)
        .background(Farben.flaechePanel)
        .overlay(alignment: .top) {
            Rectangle().fill(Farben.linie).frame(height: 1)
        }
    }

    private enum Danach { case teilen, drucken }

    /// Nach einem gelungenen Ausdruck nach einer Bewertung fragen.
    ///
    /// **Nur nach einem Erfolg, und nur selten.** Die Regeln stehen in
    /// `Bewertungsfrage` und nicht hier: Diese Ansicht weiss, WANN
    /// etwas gelungen ist, aber nicht, ob es das dritte Mal war oder
    /// ob diese Fassung schon gefragt hat.
    private func vielleichtBewerten() {
        guard fehler == nil, Bewertungsfrage.soll() else { return }
        bewertungAnfragen()
        Bewertungsfrage.gefragt()
    }

    private func holen(dann: Danach) async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            let datei = try await Laden(anmeldung: anmeldung).druckdatei(
                wunsch, kennung: kennung, ersatzname: ersatzname)
            switch dann {
            case .teilen:
                zumTeilen = datei
                // GEFRAGT WIRD ERST, WENN DAS BLATT WIEDER ZU IST
                // (`onDismiss`). Eine Bewertungsabfrage ueber dem
                // Teilen-Blatt waere genau die Unterbrechung, die
                // einen Stern kostet.
                Bewertungsfrage.merken(.gedruckt)
            case .drucken:
                try Drucker.drucken(datei)
                Bewertungsfrage.merken(.gedruckt)
                vielleichtBewerten()
            }
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}

// MARK: - Ein Feld für halbe Millimeter

/// Ein Maß in Millimetern, in halben Schritten.
///
/// Halbe und nicht beliebige: Der Server rundet auf ein Zehntel, und ein
/// Feld, in das sich 110,237 tippen lässt, zeigte danach eine andere
/// Zahl als die, die gedruckt wird.
struct Schrittfeld: View {
    let titel: String
    @Binding var wert: Double
    let von: Double
    let bis: Double

    var body: some View {
        Stepper(value: $wert, in: von...bis, step: 0.5) {
            HStack {
                Text(titel).foregroundStyle(Farben.ink)
                Spacer()
                Text("\(Druckblock.mass(wert)) mm")
                    .foregroundStyle(Farben.inkStill)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Teilen und Drucken

/// Das Teilen-Blatt des Systems.
struct Teilblatt: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url],
                                 applicationActivities: nil)
    }

    func updateUIViewController(_ steuerung: UIActivityViewController,
                                context: Context) { }
}

/// Der Weg zum Drucker.
///
/// **Warum das UIKit ist und kein SwiftUI.** SwiftUI hat keinen
/// Druckdialog. `UIPrintInteractionController` ist der einzige Weg, und
/// er ist genau der, den auch jede andere App benutzt: dieselbe Auswahl
/// von AirPrint-Druckern, dieselbe Seitenvorschau.
@MainActor
enum Drucker {

    enum Fehler: LocalizedError {
        case kannNicht
        case keinFenster

        var errorDescription: String? {
            switch self {
            case .kannNicht:
                return String(localized: """
                    Dieses Gerät kann diese Datei nicht drucken. Über \
                    „Teilen“ geht sie trotzdem weiter.
                    """)
            case .keinFenster:
                return String(localized:
                    "Der Druckdialog ließ sich nicht öffnen.")
            }
        }
    }

    static func drucken(_ datei: Druckspeicher.Datei) throws {
        guard UIPrintInteractionController.isPrintingAvailable,
              UIPrintInteractionController.canPrint(datei.url) else {
            throw Fehler.kannNicht
        }
        let steuerung = UIPrintInteractionController.shared
        let angaben = UIPrintInfo.printInfo()
        angaben.outputType = .general
        // Der Name steht in der Warteschlange des Druckers. Ohne ihn
        // heißt jeder Auftrag „Routetree", und wer drei abgeschickt hat,
        // weiß nicht mehr, welcher davon das Armband ist.
        angaben.jobName = datei.url.lastPathComponent
        steuerung.printInfo = angaben
        steuerung.printingItem = datei.url

        // AUF DEM IPAD BRAUCHT DER DIALOG EINEN ORT. `present(animated:)`
        // ist der Weg fürs iPhone; auf dem iPad muss ein Rechteck dabei
        // sein, sonst erscheint gar nichts -- und zwar ohne Fehler.
        if UIDevice.current.userInterfaceIdiom == .pad {
            guard let sicht = fenster()?.rootViewController?.view else {
                throw Fehler.keinFenster
            }
            let mitte = CGRect(x: sicht.bounds.midX, y: sicht.bounds.midY,
                               width: 1, height: 1)
            steuerung.present(from: mitte, in: sicht, animated: true)
        } else {
            steuerung.present(animated: true, completionHandler: nil)
        }
    }

    private static func fenster() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
