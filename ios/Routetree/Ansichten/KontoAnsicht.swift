import SwiftUI

/// Konto und Recht — was Apple verlangt und was sich gehört.
///
/// **Kontolöschung ist Pflicht, nicht Kür.** Apples Richtlinie 5.1.1(v)
/// verlangt bei jeder App mit Konto einen Weg, es wieder loszuwerden --
/// *in der App*, nicht per Mail und nicht auf einer Webseite. Eine App
/// ohne diesen Weg wird abgelehnt, und zwar zuverlässig.
///
/// Der Server kann es längst (`DELETE /api/v1/konto/`, seit Teil 8). Was
/// fehlte, war der Weg dorthin -- und ein Löschrecht, das man erst
/// anfordern muss, ist eins auf dem Papier.
///
/// **Der Datenschutz-Link gehört ebenfalls hierher.** Apple verlangt eine
/// Datenschutzerklärung, und wer sie nur im Store findet, findet sie
/// nicht.
struct KontoAnsicht: View {

    /// Die Bruecke zur Uhr (R140).
    ///
    /// Sie gehoert hierher und nicht in die App-Wurzel: Sie wird nur
    /// gebraucht, wo jemand sie bedient, und eine `WCSession`, die beim
    /// Start mit aufgeht, kostet jeden Kaltstart Zeit -- auch auf einem
    /// iPad, an dem nie eine Uhr haengt.
    @StateObject private var uhr = Uhrbruecke()
    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen

    @State private var zeigtLoeschfrage = false
    /// Ob die Bedienspur mitschreibt (R86). Der Stand kommt vom Server
    /// und nicht vom Gerät: Eine Einwilligung liegt am Konto, nicht am
    /// Telefon, mit dem sie gegeben wurde.
    @State private var spurAn = false
    /// Welches Blatt gerade offen ist. `nil` heisst: keins.
    ///
    /// **EIN Zustand und EIN `.sheet`.** Warum das so sein MUSS, steht
    /// unten am Modifizierer -- kurz: Sieben `.sheet` an derselben
    /// Ansicht ergaben aus diesem Blatt heraus null offene Blätter.
    @State private var blatt: Blatt?
    @State private var laeuft = false
    @State private var fehler: String?
    /// Die Vereine dieser Person, für den Abo-Vorschlag (B12).
    ///
    /// HIER UND NICHT AUF EINEM EIGENEN REITER. Ein Abo sieht man sich
    /// einmal an und dann nie wieder; ein Reiter dafür stünde neben
    /// „Playbooks" und „Mannschaften" und wäre der einzige, den niemand
    /// benutzt. Im Browser liegt `/abo/` aus demselben Grund nicht in der
    /// Hauptnavigation.
    @State private var vereine: [Modell.Verein] = []
    /// Was im Betrieb anliegt -- oder `nil`, wenn dieser Zugang kein
    /// Betreiber ist (R103).
    ///
    /// **Der Server entscheidet das, nicht die App.** Ein Menüpunkt, der
    /// bei jedem steht und bei allen ausser einem 403 liefert, verrät
    /// den Bereich ohne Grund -- und ein Menüpunkt, den die App aus dem
    /// Benutzernamen ableitet, ist eine zweite Rechteregel neben der
    /// echten.
    @State private var betrieb: Betrieb.Ueberblick?

    /// Die Datenschutzerklärung liegt beim Server -- dieselbe, die auch
    /// die Website zeigt. Zwei Fassungen wären zwei Wahrheiten.
    private var datenschutz: URL {
        URL(string: "/datenschutz/", relativeTo: Server.basis)!
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        if let fehler {
                            Text(fehler)
                                .font(.footnote)
                                .foregroundStyle(Farben.fehler)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Farben.fehler.opacity(0.10),
                                            in: RoundedRectangle(cornerRadius: 12))
                        }

                        // DIE HILFE (R28).
                        //
                        // Niklas am 01.09.2026: „also ich sehe nirgendwo
                        // hilfecenter. Bau das bitte vernünftig im
                        // browser ein und auch in der app. z.b. bei den
                        // einstelliungen".
                        //
                        // GANZ OBEN, noch vor der Sprache: Wer hier
                        // hereinkommt, weil er nicht weiterkommt, soll
                        // nicht erst an drei Verweisen und einem
                        // Löschknopf vorbei.
                        //
                        // **Ein Link in den Browser, keine zweite
                        // Hilfeseite in Swift.** Die Seite setzt sich
                        // auf dem Server aus dem zusammen, was dort
                        // ohnehin gepflegt wird (`hilfe.py`) -- sie
                        // nativ nachzubauen hiesse, dieselbe
                        // Zusammenstellung ein zweites Mal zu pflegen,
                        // und die zweite wäre die, die veraltet. Genau
                        // das sollte R28 verhindern.
                        //
                        // Der Preis dafür steht dabei: ohne Netz geht
                        // es nicht. Wer Hilfe braucht, hat meistens
                        // welches -- und was am Platz zählt, liegt seit
                        // R14 ohnehin auf dem Gerät.
                        // DIE HILFE IST HIER RAUS (B6, 02.09.2026).
                        //
                        // Sie stand in diesem Blatt, und das war nur
                        // über ein stummes Symbol auf EINEM von zwei
                        // Reitern erreichbar. Genau daher kam Niklas'
                        // Satz „also ich sehe nirgendwo hilfecenter" --
                        // und meine Antwort darauf war, sie in dieselbe
                        // Schublade zu legen, in der das Problem
                        // entstanden ist.
                        //
                        // Jetzt steht sie als eigener beschrifteter
                        // Knopf in der Leiste JEDES Reiters. WCAG 3.2.6
                        // „Consistent Help" ist Stufe A, und über
                        // WCAG2ICT gilt das auch für ein natives
                        // Programm.
                        //
                        // Man sucht die Hilfe nicht in den
                        // Einstellungen. Man sucht sie da, wo man nicht
                        // weiterkommt.

                        // DIE SPRACHE (R31). Vor „Rechtliches", weil
                        // sie das Einzige hier ist, das man wirklich
                        // einstellt -- alles andere sind Verweise und
                        // ein Löschknopf.
                        //
                        // Seit R28 steht die Hilfe darüber: Wer hier
                        // hereinkommt, weil er nicht weiterkommt, sucht
                        // sie und nicht die Spracheinstellung.
                        gruppe(String(localized: "Sprache")) {
                            Button {
                                blatt = .sprache
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "globe")
                                        .frame(width: 22)
                                        .foregroundStyle(Farben.akzent)
                                    Text("Sprache")
                                        .foregroundStyle(Farben.ink)
                                    Spacer()
                                    Text(Sprachwahl.gewaehlt
                                            .map(Sprachwahl.name)
                                         ?? String(localized: "Wie das Telefon"))
                                        .font(.callout)
                                        .foregroundStyle(Farben.inkStill)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Farben.inkStill)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                // OHNE TREFFERFLÄCHE IST DIE MITTE LUFT.
                                //
                                // Ein SwiftUI-Knopf ist nur dort tippbar,
                                // wo er auch zeichnet. Zwischen Text und
                                // Pfeil steht ein `Spacer()` -- und genau
                                // dorthin tippt, wer eine Zeile antippt.
                                .contentShape(Rectangle())
                            }
                        }

                        // DER VEREIN STEHT ÜBER DEM RECHTLICHEN.
                        //
                        // Niklas am 10.09.2026, mit einem Bild, auf
                        // dem beide Blöcke umkringelt sind: „Verein
                        // über rechtliches bitte.“
                        //
                        // Und das ist auch die richtige Reihenfolge:
                        // Wer die Kontoseite öffnet, sucht in aller
                        // Regel seinen Verein -- Impressum und
                        // Datenschutz sucht man einmal. Die beiden
                        // Pflichtschaltflächen bleiben davon
                        // unberührt: „ständig verfügbar sowie
                        // unmittelbar und leicht zugänglich“
                        // (§ 312k Abs. 2 Satz 3 BGB) heisst
                        // erreichbar ohne Umweg, nicht ganz oben.
                        if !vereine.isEmpty {
                            gruppe(String(localized: "Verein")) {
                                ForEach(vereine) { verein in
                                    // HIER WIRD NICHTS MEHR GEKAUFT
                                    // (R134, 23.09.2026).
                                    //
                                    // Niklas: „das abonnent verhalten
                                    // gilt ja eh auf den account nicht
                                    // auf das team."
                                    //
                                    // Hier stand je Verein eine
                                    // Abo-Zeile -- als koennte man je
                                    // Verein eines kaufen. Genau das
                                    // kann man nicht: Apples Abo-Gruppe
                                    // laesst eine Apple-ID genau ein Abo
                                    // halten, und `apple_verarbeiten`
                                    // bindet es dauerhaft an EINEN
                                    // Verein.
                                    //
                                    // Eine Liste, die etwas anderes
                                    // behauptet, ist der Naehrboden fuer
                                    // den Kauf beim falschen Verein --
                                    // und genau der ist am 18.09.2026
                                    // passiert. Der Zustand steht
                                    // weiterhin hier, der Weg zum Kauf
                                    // unter „Abonnement".
                                    vereinszeile(verein, tippbar: false)
                                    // DAS WAPPEN ÄNDERN (R30, Rest).
                                    //
                                    // Nur für Vereinsverwalter, und die
                                    // Frage danach beantwortet der
                                    // SERVER (`verein.rolle`). Ein Head
                                    // Coach führt seine Mannschaft --
                                    // der Verein gehört ihm deshalb
                                    // nicht, und ein Knopf, der in ein
                                    // 404 läuft, ist schlimmer als
                                    // keiner.
                                    if verein.istVereinsadmin {
                                        Button {
                                            blatt = .wappen(verein)
                                        } label: {
                                            zeile(String(localized:
                                                    "Vereinslogo"),
                                                  "photo")
                                        }
                                    }
                                }
                            }
                        }

                        // DAS ABONNEMENT GEHOERT ZUM KONTO (R134).
                        //
                        // Die Begruendung steht ausfuehrlich in
                        // `AbonnementAnsicht`: Eine Apple-ID traegt
                        // genau ein Abo, und es gehoert dauerhaft zu
                        // einem Verein. Unter „Verein" gehoert es
                        // deshalb nicht hin.
                        //
                        // VOR „Rechtliches": Wer hier hereinkommt und
                        // etwas mit Geld sucht, sucht es oben und nicht
                        // hinter dem Impressum.
                        gruppe(String(localized: "Abonnement")) {
                            Button {
                                blatt = .abonnement
                            } label: {
                                zeile(String(localized: "Abonnement verwalten"),
                                      "creditcard")
                            }
                            // DIE KENNUNG IST FÜR DEN BILDERLAUF
                            // (R120.2). Apple verlangt je Abonnement ein
                            // Foto der Kaufseite; der Weg dorthin fuehrt
                            // seit R134 ueber diese Zeile und nicht mehr
                            // ueber die Vereinszeile.
                            .accessibilityIdentifier("abozeile")
                        }

                        // DIE UHR (R140). Nur wo eine gekoppelt ist:
                        // Ein Eintrag, der auf jedem iPad steht und
                        // dort nichts tun kann, ist eine Einladung zu
                        // einer Enttaeuschung.
                        if uhr.uhrVorhanden {
                            gruppe(String(localized: "Apple Watch")) {
                                Button {
                                    blatt = .uhr
                                } label: {
                                    zeile(String(localized: "Plays auf die Uhr"),
                                          "applewatch")
                                }
                                .accessibilityIdentifier("uhrzeile")
                            }
                        }

                        gruppe(String(localized: "Rechtliches")) {
                            Link(destination: datenschutz) {
                                zeile(String(localized: "Datenschutzerklärung"),
                                      "hand.raised")
                            }
                            Link(destination: URL(string: "/impressum/",
                                                  relativeTo: Server.basis)!) {
                                zeile("Impressum", "info.circle")
                            }
                            // DIE HAUSORDNUNG (Apple 1.2, 16.09.2026).
                            //
                            // Sie sagt, was hier nicht hingehört, wie
                            // gemeldet wird und was auf eine Meldung
                            // hin passiert. Sie muss von der App aus
                            // erreichbar sein und nicht nur im
                            // Browser -- wer die App benutzt, öffnet
                            // routetree.de nie.
                            //
                            // `test_hausordnung.py` hält diesen Link
                            // fest; ohne ihn ist die Seite für App-
                            // Benutzer nicht vorhanden.
                            Link(destination: URL(string: "/hausordnung/",
                                                  relativeTo: Server.basis)!) {
                                zeile(String(localized: "Hausordnung"),
                                      "checklist")
                            }
                            // DIE BEIDEN PFLICHTSCHALTFLÄCHEN -- auch hier.
                            //
                            // Dass der KAUFknopf in der App fehlt, ist
                            // richtig: Apple 3.1.1 verbietet Wege zu
                            // einem anderen Kaufweg als dem In-App-Kauf.
                            // Die KÜNDIGUNG ist davon nicht berührt.
                            // § 312k Abs. 2 Satz 3 BGB verlangt sie
                            // „ständig verfügbar sowie unmittelbar und
                            // leicht zugänglich", und die Rechtsfolge
                            // einer fehlenden Schaltfläche ist, dass
                            // jederzeit fristlos gekündigt werden kann
                            // (Abs. 6). Dasselbe für den Widerruf seit
                            // dem 19.06.2026 (§ 356a).
                            //
                            // Die Beschriftungen sind WORTLAUT und
                            // stehen im Server in `kasse.py` fest; hier
                            // stehen sie ein zweites Mal, weil die App
                            // sie ohne Netz zeigen können muss. Ein
                            // Test (`test_app_rechtstexte.py`) hält
                            // beide Fassungen gleich.
                            Link(destination: URL(string: "/kuendigen/",
                                                  relativeTo: Server.basis)!) {
                                zeile(String(localized: "Verträge hier kündigen"),
                                      "xmark.circle")
                            }
                            Link(destination: URL(string: "/widerrufen/",
                                                  relativeTo: Server.basis)!) {
                                zeile(String(localized: "Vertrag widerrufen"),
                                      "arrow.uturn.backward")
                            }
                        }

                        // NUTZUNGSQUALITÄT VERBESSERN (R86, Text und
                        // Platz nach Niklas' Vorgabe vom 09.09.2026).
                        //
                        // „das kann man aber auch anders ausdrücken mit
                        // der bedienspur. nutzungsqualität verbessern,
                        // und darunter im text teile deine nutzungsdaten
                        // um die app stetig zu verbessern und ich will
                        // es weiter unten haben."
                        //
                        // „Bedienung mitschneiden" beschreibt die
                        // Technik, nicht den Zweck -- und wer nur die
                        // Technik liest, sagt nein, ohne zu wissen,
                        // wofür.
                        //
                        // WEITER UNTEN, aber VOR dem Konto: Die
                        // Kontolöschung bleibt der letzte Eintrag der
                        // Seite. Ein Schalter unter einem roten Knopf
                        // wäre der, den niemand mehr liest.
                        //
                        // ALS SCHALTER UND NICHT ALS VOREINSTELLUNG.
                        // Was jemand wann antippt, ist sein Verhalten;
                        // das nimmt man nicht nebenbei mit. Der Schalter
                        // wirkt in beide Richtungen -- Ausschalten
                        // löscht drüben, was schon liegt.
                        gruppe(String(localized: "Nutzungsqualität verbessern")) {
                            Toggle(isOn: $spurAn) {
                                HStack(spacing: 12) {
                                    Image(systemName: "hand.tap")
                                        .frame(width: 22)
                                        .foregroundStyle(Farben.akzent)
                                    Text("Nutzungsdaten teilen")
                                        .foregroundStyle(Farben.ink)
                                }
                            }
                            .tint(Farben.akzent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .onChange(of: spurAn) { _, neuerStand in
                                guard neuerStand != Bedienspur.gemeinsam.istAn
                                else { return }
                                Task {
                                    do {
                                        try await Bedienspur.schalten(neuerStand)
                                    } catch {
                                        // Zurückstellen, statt einen
                                        // Schalter stehen zu lassen, der
                                        // etwas behauptet, was drüben
                                        // nicht gilt.
                                        spurAn = Bedienspur.gemeinsam.istAn
                                    }
                                }
                            }
                            // ZWECK ZUERST, DANN DIE EINZELHEITEN. Eine
                            // Einwilligung muss informiert sein: Der
                            // zweite Satz sagt, was wirklich
                            // aufgezeichnet wird, sonst wäre der erste
                            // eine Zusage über etwas Unbekanntes.
                            Text("""
                                Teile deine Nutzungsdaten, um die App \
                                stetig zu verbessern. Aufgezeichnet wird \
                                nur, welche Schaltfläche wann getippt \
                                wird, keine Namen und keine Zeichnungen. \
                                Ausschalten löscht die bisherige \
                                Aufzeichnung.
                                """)
                                .font(.footnote)
                                .foregroundStyle(Farben.inkStill)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }

                        // DER BETRIEB (R103, 09.09.2026). Niklas: „am
                        // allercoolsten wäre es wenn ich sie sogar über
                        // die app in die verwaltung komme also dort eine
                        // abgespeckte verwaltung nur unter meinem
                        // username habe weißt du?"
                        //
                        // ER STEHT NUR DA, WENN ER DA STEHEN DARF. Die
                        // Antwort auf `/admin/uebersicht/` ist die
                        // Rechteprüfung; bleibt sie aus, bleibt der
                        // Abschnitt weg. Das ist auch der Grund, warum
                        // die Zahl gleich mitkommt: Wer den Punkt sieht,
                        // soll ohne Hineinsehen wissen, ob etwas
                        // anliegt.
                        if let betrieb {
                            gruppe(String(localized: "Betrieb")) {
                                Button {
                                    blatt = .betrieb
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "wrench.and.screwdriver")
                                            .frame(width: 22)
                                            .foregroundStyle(Farben.akzent)
                                        Text("Was anliegt")
                                            .foregroundStyle(Farben.ink)
                                        Spacer()
                                        if betrieb.wartet.summe > 0 {
                                            Text(betrieb.wartet.summe.formatted())
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(Farben.aufPetrol)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Farben.warnung,
                                                            in: Capsule())
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Farben.inkStill)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                            }
                        }

                        gruppe(String(localized: "Konto")) {
                            // DAS PASSWORT ÄNDERN (R50).
                            //
                            // Im Browser gibt es das seit langem
                            // (`/konto/passwort/`), in der App gab es
                            // keinen Weg dorthin. Und ihn dorthin zu
                            // verlinken wäre keiner: Die App hält ein
                            // Token, keine Sitzung -- im Browser müsste
                            // man sich ein zweites Mal anmelden.
                            //
                            // Vor „Abmelden": Wer sein Passwort ändern
                            // will, sucht es unter „Konto" und nicht
                            // hinter dem Ausgang.
                            // KONTODATEN (R100, 09.09.2026). Niklas:
                            // „Kontodaten sollten änderbar sein."
                            //
                            // VOR dem Passwort: Wer hier hereinkommt,
                            // will meistens seine Adresse nachtragen --
                            // ohne sie gibt es kein „Passwort
                            // vergessen", und das merkt man erst, wenn
                            // man es braucht.
                            Button {
                                blatt = .kontodaten
                            } label: {
                                zeile(String(localized: "Name und E-Mail"),
                                      "person.text.rectangle")
                            }
                            Button {
                                blatt = .passwort
                            } label: {
                                zeile(String(localized: "Passwort ändern"),
                                      "key")
                            }
                            Button {
                                Task { await anmeldung.abmelden() }
                            } label: {
                                zeile("Abmelden", "rectangle.portrait.and.arrow.right")
                            }
                            // MEINE DATEN MITNEHMEN (R110.9).
                            //
                            // VOR dem Löschen, und das ist der ganze
                            // Punkt: Bis zum 10.09.2026 stand in der
                            // App genau ein Weg zu den eigenen Daten,
                            // und nach dem sind sie weg. Art. 15 DSGVO
                            // gibt das Recht auf Auskunft, Art. 20 das
                            // auf ein Format, mit dem man woandershin
                            // kann -- beides also VOR der Tür und
                            // nicht dahinter.
                            Button {
                                Task { await auskunftHolen() }
                            } label: {
                                zeile(String(localized: "Meine Daten mitnehmen"),
                                      "square.and.arrow.up")
                            }
                            .disabled(laeuft)
                            Button(role: .destructive) {
                                zeigtLoeschfrage = true
                            } label: {
                                zeile(String(localized: "Konto löschen"), "trash",
                                      warnend: true)
                            }
                        }

                        // Was beim Löschen passiert, steht VOR dem Knopf --
                        // nicht erst in der Rückfrage. Wer es danach liest,
                        // hat sich schon entschieden.
                        // DER HINWEIS AUF DIE MITNAHME STEHT HIER
                        // (R110.9) und nicht in der Rückfrage: Wer die
                        // erst liest, hat sich schon entschieden -- und
                        // danach ist die Auskunft nicht mehr zu holen.
                        Text("""
                            Beim Löschen verschwindet dein Zugang samt \
                            Mitgliedschaften, Lernständen und angemeldeten \
                            Geräten. Hol dir vorher „Meine Daten mitnehmen", \
                            wenn du sie behalten willst. Danach geht es nicht \
                            mehr. Die Playbooks bleiben beim Verein, sie \
                            sind die Arbeit einer Saison und gehören nicht \
                            der Person, die zuletzt daran gezeichnet hat. Wo \
                            dein Name an einem Play stand, steht danach \
                            niemand mehr.
                            """)
                            .font(.footnote)
                            .foregroundStyle(Farben.inkStill)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Konto")
            .navigationBarTitleDisplayMode(.inline)
            // EINE KENNUNG, DIE DEN ZUSTAND VERRÄT (nur fürs Messen).
            //
            // Die Frage, an der vier Läufe hängen: Setzt der Knopf
            // `blatt`, und das Blatt geht nur nicht auf? Oder läuft die
            // Aktion des Knopfes gar nicht? Von aussen sieht beides
            // gleich aus -- es passiert nichts.
            //
            // Die Kennung ist keine Beschriftung: Sie steht in keiner
            // Sprache auf keinem Bildschirm, und VoiceOver liest sie
            // nicht vor. Sie beantwortet genau diese eine Frage.
            .accessibilityIdentifier(
                blatt == nil ? "konto-ohne-blatt" : "konto-mit-blatt")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Fertigknopf { schliessen() }
                }
            }
            .alert("Konto wirklich löschen?", isPresented: $zeigtLoeschfrage) {
                Button("Abbrechen", role: .cancel) { }
                Button("Endgültig löschen", role: .destructive) {
                    Task { await loeschen() }
                }
            } message: {
                Text("Das lässt sich nicht rückgängig machen.")
            }
            .overlay {
                if laeuft {
                    ProgressView().tint(Farben.akzent)
                }
            }
            .task {
                // Schlägt es fehl, bleibt der Abschnitt weg. Ein Konto
                // löschen zu können, darf nicht davon abhängen, ob die
                // Vereinsliste durchkommt.
                vereine = (try? await Laden(anmeldung: anmeldung).vereine())
                    ?? []
                await Bedienspur.nachfragen()
                spurAn = Bedienspur.gemeinsam.istAn
                // KEIN FEHLER, WENN ES 403 GIBT. Fast jeder Zugang ist
                // kein Betreiber; das ist der Normalfall und keine
                // Störung. `try?` und der Abschnitt bleibt weg.
                if let token = try? await anmeldung.gueltigesToken() {
                    betrieb = try? await Betrieb.ueberblick(token: token)
                }
            }
        }
        // EIN `.sheet`, UND ES HÄNGT AUSSEN (15.09.2026).
        //
        // **Der Befund, nicht die Vermutung.** Aus dem Kontoblatt
        // heraus ging KEIN Blatt auf. Gemessen auf dem Simulator, in
        // vier Läufen: Die Vereinszeile ist da und antippbar, sie wird
        // dreimal angetippt, die Sprachwahl aus demselben Blatt geht
        // ebenso wenig auf -- aber „Fertig" schliesst das Kontoblatt.
        // Tipps kommen also an.
        //
        // Sechs Wege waren damit tot, und zwar für jeden Benutzer:
        // Sprache, Betrieb, Name und E-Mail, Passwort, die Auskunft
        // und das Abo. Aufgefallen ist es erst, als der Bilderlauf
        // für den Store die Kaufseite fotografieren sollte.
        //
        // ZWEI DINGE GEÄNDERT, und beide sind für sich richtig:
        //
        // 1. **Ein Zustand statt sieben.** Sieben `.sheet` an derselben
        //    Ansicht sind sieben Präsentationen, von denen die Ansicht
        //    nur eine führen kann. Ein Aufzählungstyp kann nur einen
        //    Wert haben und bildet damit ab, was SwiftUI kann.
        // 2. **Aussen statt innen.** Der Modifizierer hing am INHALT
        //    des `NavigationStack`. Ein Blatt, das aus einem Blatt
        //    heraus aufgehen soll, gehört an dessen äusserste Ansicht
        //    -- innen liegt es unter einer Navigationsschicht, die
        //    selbst präsentiert.
        //
        // In der Playbook-Liste trägt das alte Muster (fünf Blätter an
        // einer Ansicht) klaglos. Die ist aber die WURZEL und liegt
        // unter keiner Präsentation.
        .sheet(item: $blatt) { welches in
            switch welches {
            case .sprache:
                SprachAnsicht(erstesMal: false)
            case .betrieb:
                BetriebAnsicht().environmentObject(anmeldung)
            case .kontodaten:
                KontodatenBlatt().environmentObject(anmeldung)
            case .passwort:
                PasswortBlatt { blatt = nil }
                    .environmentObject(anmeldung)
            case .auskunft(let datei):
                Teilblatt(url: datei.url)
            case .abo(let gezeigt):
                AboAnsicht(abo: gezeigt.abo, verein: gezeigt.verein,
                           titel: gezeigt.titel,
                           weiterText: gezeigt.weiterText)
                    .environmentObject(anmeldung)
            case .abonnement:
                AbonnementAnsicht(vereine: vereine) { _ in
                    // NACH EINEM KAUF NEU LADEN. Der Zustand steht in
                    // der Vereinsliste darunter, und eine Liste, die
                    // weiter „Demo" sagt, sieht aus wie ein
                    // fehlgeschlagener Kauf.
                    Task {
                        vereine = (try? await Laden(
                            anmeldung: anmeldung).vereine()) ?? vereine
                    }
                }
                .environmentObject(anmeldung)
            case .uhr:
                UhrBlatt(bruecke: uhr).environmentObject(anmeldung)
            case .wappen(let verein):
                VereinBlatt(verein: verein) { geaendert in
                    blatt = nil
                    // NEU LADEN, wenn sich etwas geändert hat: Das
                    // Wappen steht auch in der Zeile darüber, und
                    // eine Liste, die das alte Bild behält, sieht
                    // aus, als sei das Hochladen fehlgeschlagen.
                    if geaendert {
                        Task {
                            vereine = (try? await Laden(
                                anmeldung: anmeldung).vereine()) ?? vereine
                        }
                    }
                }
                .environmentObject(anmeldung)
            }
        }
    }

    /// Eine Gruppe mit Überschrift.
    ///
    /// **`titel` muss ÜBERSETZT hereinkommen.** Diese Funktion reicht
    /// ihn unverändert an `Text(...)` weiter, und ein `String` dort
    /// geht an der Übersetzung vorbei -- der Sprachenprüfer sieht einen
    /// Satz nur direkt hinter `Text(` oder `String(localized:`.
    ///
    /// **Bis zum 01.09.2026 standen deshalb ALLE fünf Überschriften
    /// dieser Seite auf Deutsch**, in jeder Sprache: „SPRACHE",
    /// „RECHTLICHES", „VEREIN", „KONTO". Aufgefallen ist es erst, als
    /// eine sechste dazukam („Hilfe") und der Prüfer sie im Katalog
    /// fand, aber nicht im Quelltext.
    ///
    /// Drei davon standen zufällig doch übersetzt da, weil dasselbe
    /// Wort woanders in einem `Text(...)` vorkommt. „Rechtliches" nicht
    /// -- das gab es in keinem Katalog.
    private func gruppe<Inhalt: View>(
        _ titel: String, @ViewBuilder inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titel.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Farben.inkStill)
                .padding(.bottom, 8)
            VStack(spacing: 0) { inhalt() }
                .background(Farben.flaechePanel, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Farben.linie))
        }
    }

    /// Ein Verein mit seinem Zustand.
    ///
    /// Der Zustand steht dran, weil er der Grund ist, aus dem jemand
    /// hier hinsieht. „Freigeschaltet" und nicht „Kunde": Das eine sagt,
    /// woran der Verein ist, das andere klingt nach Buchhaltung.
    private func vereinszeile(_ verein: Modell.Verein,
                              tippbar: Bool = true) -> some View {
        HStack(spacing: 12) {
            // DAS WAPPEN STATT DES HAUSSYMBOLS (R30).
            //
            // Gemeldet von Niklas am 25.08.2026 mit Bildschirmfoto:
            // „Hier auch Logo". Hier stand `Image(systemName:
            // "building.2")` -- und das war kein Versehen in der
            // Ansicht: Zu einem Verein lieferte der Server `name` und
            // `demo`, mehr nicht. Es gab nichts zu zeigen.
            //
            // Dieselbe Leiter wie in der Mannschaftskachel: Bild, sonst
            // Initialen vom Server, sonst ein Sinnbild. Ein leerer
            // Platz sähe aus wie ein Fehler der App -- und am
            // Spielfeldrand ohne Empfang ist genau das der Normalfall.
            vereinswappen(verein)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(verein.name)
                    .foregroundStyle(Farben.ink)
                Text(verein.demo ? String(localized: "Demo, Abo möglich")
                                 : String(localized: "Freigeschaltet"))
                    .font(.caption)
                    .foregroundStyle(Farben.inkStill)
            }
            Spacer()
            // EIN PFEIL VERSPRICHT EINEN WEG. Seit R134 fuehrt die
            // Vereinszeile nirgendwohin -- ein Pfeil daran waere die
            // naechste Schaltflaeche, die nichts tut.
            if tippbar {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Farben.inkStill)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // OHNE TREFFERFLÄCHE IST DIE MITTE LUFT.
        //
        // **Das war der Fehler, der vierzehn Läufe gekostet hat.** Ein
        // SwiftUI-Knopf ist nur dort tippbar, wo er auch zeichnet --
        // zwischen dem Namen links und dem Pfeil rechts steht ein
        // `Spacer()`, und der zeichnet nichts. Wer die Zeile in der
        // Mitte antippt, tippt ins Leere.
        //
        // Von aussen sieht das aus wie ein Knopf, der nichts tut, und
        // genau so sah es aus: Die Vereinszeile war da, sie war laut
        // Bedienungshilfen antippbar, und es passierte nichts. Dasselbe
        // galt für Sprache, Betrieb, Name und E-Mail, Passwort und die
        // Auskunft -- sechs Wege, die nur auf ihrer Schrift reagierten.
        .contentShape(Rectangle())
    }

    /// Bild, sonst Initialen, sonst ein Sinnbild (R30).
    ///
    /// **Die Reihenfolge ist die Aussage.** Ein Verein ohne Logo ist der
    /// Normalfall, kein Fehler -- und die Initialen kommen vom SERVER,
    /// aus derselben Regel wie auf jedem Ausdruck
    /// (`models.initialen_aus`). Würde die App sie selbst rechnen,
    /// hieße derselbe Verein auf dem Blatt „SD" und im Telefon „SU".
    ///
    /// Beim Laden und beim Fehlschlag steht dasselbe da wie ohne Bild.
    /// Am Spielfeldrand ohne Empfang ist der Fehlschlag der Normalfall,
    /// und ein leerer Platz sähe dort aus, als sei die App kaputt.
    @ViewBuilder
    private func vereinswappen(_ verein: Modell.Verein) -> some View {
        if let adresse = verein.logo.flatMap(URL.init(string:)) {
            Netzbild(adresse: adresse) { vereinszeichen(verein) }
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            vereinszeichen(verein)
        }
    }

    @ViewBuilder
    private func vereinszeichen(_ verein: Modell.Verein) -> some View {
        let kurz = verein.initialen.trimmingCharacters(in: .whitespaces)
        if kurz.isEmpty {
            Image(systemName: "building.2")
                .foregroundStyle(Farben.akzent)
        } else {
            Text(kurz)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Farben.akzent)
                .minimumScaleFactor(0.6)
        }
    }

    private func zeile(_ text: String, _ zeichen: String,
                       warnend: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: zeichen)
                .frame(width: 22)
                .foregroundStyle(warnend ? Farben.fehler : Farben.akzent)
            Text(text)
                .foregroundStyle(warnend ? Farben.fehler : Farben.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Farben.inkStill)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        // OHNE TREFFERFLÄCHE IST DIE MITTE LUFT (siehe `vereinszeile`).
        .contentShape(Rectangle())
    }

    /// Holt die Auskunft und öffnet das Teilen-Blatt (R110.9).
    ///
    /// **Kein eigener Bildschirm, der sie anzeigt.** Eine Auskunft ist
    /// eine Datei und keine Ansicht: Was darin steht, entscheidet der
    /// Server, und eine App, die es hübsch macht, entscheidet dabei
    /// mit, was man zu sehen bekommt. Über das Teilen-Blatt geht sie in
    /// „Dateien", in eine Mail oder in die Cloud -- also dorthin, wo
    /// Art. 20 sie haben will.
    private func auskunftHolen() async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            let token = try await anmeldung.gueltigesToken()
            blatt = .auskunft(Auskunftsdatei(
                url: try await Datenauskunft.holen(token: token)))
        } catch {
            // Der Satz des Servers hat Vorrang -- er weiss mehr.
            fehler = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Die Auskunft liess sich nicht holen.")
        }
    }

    private func loeschen() async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            let token = try await anmeldung.gueltigesToken()
            let anfrage = try Server.anfrage("/api/v1/konto/",
                                             methode: "DELETE", token: token)
            _ = try await Server.ausfuehren(anfrage)
            // Der Server hat das Konto samt Sitzungen entfernt. Örtlich
            // aufräumen, sonst zeigt die App eine Liste, die es nicht
            // mehr gibt.
            Schluesselbund.loeschen()
            await anmeldung.abmelden()
        } catch {
            // DIESE STELLE HAT LANGE DAS FALSCHE ERKLÄRT. Hier stand,
            // der häufigste Fall sei keine Störung, sondern eine
            // Auflage: Der letzte Vereinsadmin dürfe nicht gehen, ohne
            // die Rolle zu übergeben.
            //
            // Das war seit dem 27.08.2026 nicht mehr wahr und seit dem
            // 02.09.2026 auch nicht mehr gebaut. Es war ausserdem eine
            // Sackgasse: Wer sich über „Kostenlos ausprobieren"
            // anmeldet, legt dabei seinen eigenen Verein an und IST der
            // einzige Vereinsadmin. Er kam hier nie heraus. Apple 5.1.1
            // (v) verlangt das Gegenteil, und der Kopf dieser Datei
            // beruft sich selbst darauf.
            //
            // Was jetzt hier ankommt, ist eine echte Störung: kein Netz,
            // Server weg, Token abgelaufen. Der Satz des Servers hat
            // trotzdem Vorrang vor unserem eigenen -- er weiss mehr.
            fehler = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Das Löschen hat nicht geklappt.")
        }
    }
}

/// Eine abgelegte Datenauskunft, solange das Teilen-Blatt sie zeigt
/// (R110.9).
///
/// **Ein eigener Typ und nicht `URL?`.** `sheet(item:)` verlangt
/// `Identifiable`, und eine `URL` ist es nicht -- sie mit einer
/// Erweiterung dazu zu machen, hinge an der Adresse als Kennung. Holt
/// jemand die Auskunft zweimal am selben Tag, ist es dieselbe Adresse,
/// und das Blatt ginge beim zweiten Mal nicht auf.
struct Auskunftsdatei: Identifiable {
    let id = UUID()
    let url: URL
}

extension KontoAnsicht {
    /// Welches Blatt über dem Konto liegt.
    ///
    /// **Ein Aufzählungstyp und nicht sieben Schalter.** Die Begründung
    /// steht am `.sheet` in `body`: Sieben `.sheet`-Modifizierer an
    /// derselben Ansicht ergaben aus diesem Blatt heraus null offene
    /// Blätter. Ein Zustand kann nur einen Wert haben, und genau das
    /// bildet ab, was SwiftUI kann -- ein Blatt führt eine Präsentation.
    enum Blatt: Identifiable {
        case sprache
        case betrieb
        case kontodaten
        case passwort
        case auskunft(Auskunftsdatei)
        case abo(Abovorschlag)
        case abonnement
        case uhr
        case wappen(Modell.Verein)

        /// Die Kennung entscheidet, wann SwiftUI NEU aufbaut.
        ///
        /// Bei den vier festen Blättern reicht der Name. Bei den drei
        /// mit Inhalt muss er mit: Wer zweimal hintereinander ein
        /// anderes Wappen öffnet, soll das zweite sehen und nicht das
        /// erste noch einmal.
        var id: String {
            switch self {
            case .sprache: return "sprache"
            case .betrieb: return "betrieb"
            case .kontodaten: return "kontodaten"
            case .passwort: return "passwort"
            case .auskunft(let datei): return "auskunft-\(datei.id)"
            case .abo(let vorschlag): return "abo-\(vorschlag.id)"
            case .abonnement: return "abonnement"
            case .uhr: return "uhr"
            case .wappen(let verein): return "wappen-\(verein.id)"
            }
        }
    }
}
