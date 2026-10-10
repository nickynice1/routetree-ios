import SwiftUI

/// Was ein Abo kostet und was es aufhebt (A3, in der App seit B12).
///
/// **SEIT DEM 10.09.2026 LÄSST SICH HIER KAUFEN** (R117). Niklas:
/// „Ind warum kann ich aus der App heraus nicht gleich kaufen?" Sind
/// beim Server Produkte hinterlegt, zeigt dieses Blatt den Stapel der
/// Stufen zum Durchwischen (`StufenStapel`), und dort steht der
/// Kaufknopf. Gekauft wird über den In-App-Kauf -- den einzigen Weg,
/// den Apples Richtlinie 3.1.1 auf dem iPhone zulässt.
///
/// **Ein Weg AUS der App HERAUS gibt es weiterhin nicht.** Der Server
/// schickt `kaufweg: null`, und das Modell liest das Feld nicht einmal.
/// Ein Knopf „Jetzt buchen", der in Wahrheit eine Mail auslöst, wäre
/// die eine Sorte Unwahrheit, die ein Verein sofort bemerkt -- und
/// zugleich der Ablehnungsgrund beim nächsten Review.
///
/// **Ohne hinterlegte Produkte bleibt alles beim Alten:** Preis,
/// Gegenüberstellung und der Satz „Wir schalten frei und rechnen mit
/// dem Verein ab." Kein Kaufknopf ist besser als einer, der ins Leere
/// greift.
///
/// **DIESE SEITE HÄLT NIEMANDEN AUF.** Der auffälligste Knopf führt
/// zurück in die Arbeit, nicht in den Kauf. Ein Vorschlag, an dem man
/// vorbei muss, ist eine Bezahlschranke, und genau die soll die Demo
/// nicht sein.
///
/// **Gerechnet wird nichts.** Preise, Plätze und die Gegenüberstellung
/// kommen fertig vom Server (`abo.py`) -- als Zahl und als Text. Die App
/// setzt keinen Preis zusammen: „5,00 €" auf dem Rechner und „€5.00" auf
/// dem Telefon sind zwei Angebote für denselben Verein.
struct AboAnsicht: View {
    let abo: Modell.Abo
    /// **Um welchen Verein es geht -- und warum das hier stehen muss.**
    ///
    /// Niklas am 18.09.2026: Er hatte die Kaufseite von „Strelitz
    /// Dukes" offen, tippte auf Premium, und das Abo landete bei „MV
    /// Rangers". Hier stand `verein: nil`, und der Server nimmt dann
    /// den alphabetisch ersten.
    ///
    /// Denselben Fehler gab es am 10.09.2026 schon im Browser; er steht
    /// im Docstring von `abo.verein_fuer` beschrieben. Die App hat ihn
    /// geerbt, weil sie den Namen zwar in die Titelzeile schrieb, aber
    /// nicht mitschickte.
    ///
    /// `nil` heisst weiterhin „nicht bekannt" -- etwa an einer Grenze
    /// der Demo, die aus einer Playliste kommt. Der Server weist einen
    /// Kauf ohne Verein ab, sobald mehr als einer in Frage kommt.
    var verein: Int?
    /// Was oben steht. Nach der Registrierung „Willkommen", an einer
    /// Grenze „Die Demo ist hier zu Ende" -- dasselbe Blatt, zwei
    /// Richtungen, und das falsche Wort verwirrt genau in dem Moment, in
    /// dem jemand entscheidet.
    ///
    /// **Der Vorgabewert geht durch die Übersetzung**, obwohl ihn heute
    /// keine der fünf Aufrufstellen braucht: `titel` landet in
    /// `.navigationTitle(titel)` und `weiterText` in `Text(weiterText)`,
    /// und beides sind `String`. Ein Rückfall, der eintritt, zeigt sonst
    /// Deutsch, und zwar genau dann, wenn eine sechste Aufrufstelle die
    /// zwei Felder weglässt, also in dem Moment, in dem niemand hier
    /// nachsieht.
    var titel: String = String(localized: "Abo")
    var weiterText: String = String(localized: "Weiter")
    /// Der Satz, der über dem Vorschlag steht -- etwa „Willkommen. „X"
    /// ist angelegt". Vom Server, nicht hier formuliert.
    var meldung: String?
    /// Was „Weiter" tut. Ohne Angabe: das Blatt schließen.
    ///
    /// Am Ende der Registrierung ist es etwas anderes: Dort wird mit
    /// diesem Knopf das Tokenpaar übernommen, und erst danach ist
    /// jemand angemeldet. Der Vorschlag steht damit wirklich am Ende
    /// der Registrierung und nicht auf einer Seite, die man erst
    /// suchen muss.
    var weiter: (() -> Void)?

    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()

                if abo.kaufbareStufen.isEmpty {
                    // DER WEG OHNE KAUF -- und der bleibt. Ohne
                    // hinterlegte Produkte (oder gegen einen älteren
                    // Server) gibt es nichts zu buchen; dann steht hier
                    // dasselbe wie bisher.
                    ScrollView {
                        VStack(alignment: .leading, spacing: 26) {
                            meldungsteil
                            preis
                            gegenueberstellung
                            freischalten
                            weiterKnopf
                        }
                        .padding(22)
                    }
                } else {
                    // DER STAPEL ZUM DURCHWISCHEN (R117). Er ersetzt
                    // Preis und Gegenüberstellung: Beides steht dort
                    // Stufe für Stufe, und zweimal dieselbe Tabelle auf
                    // einem Blatt ist einmal zu viel.
                    VStack(spacing: 0) {
                        if meldung != nil {
                            meldungsteil.padding(.horizontal, 22)
                                .padding(.top, 16)
                        }
                        StufenStapel(abo: abo, verein: verein)
                    }
                    // HIER STEHT KEIN ZWEITER KNOPF MEHR (18.09.2026).
                    //
                    // Niklas: „ganzen unten der zurück button kann
                    // komplett weg weil oben rechts kann man ja auch
                    // fertig tippen".
                    //
                    // Er hat recht, und zwar buchstäblich: `weiterKnopf`
                    // und das Häkchen oben rechts riefen dieselbe
                    // Funktion `fertig` auf. Zwei Schaltflächen für eine
                    // Handlung sind keine Bequemlichkeit, sondern eine
                    // Frage -- welche ist die richtige?
                    //
                    // Er stand hier in einem `safeAreaInset`, weil er am
                    // 11.09.2026 schon einmal in der Wischgeste des
                    // Stapels gelandet war („Wenn man hier nach unten
                    // scrollt geht der Zurück Button nicht mehr"). Die
                    // Anordnung war die Antwort auf ein Problem, das
                    // ohne den Knopf gar nicht erst besteht.
                    //
                    // Auf dem Weg OHNE Kauf (oben) bleibt er: Dort ist
                    // er der Abschluss eines langen Textes und nicht das
                    // Doppel einer Werkzeugleiste.
                }
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            // DIE KENNUNG IST FÜR DEN BILDERLAUF (R120.2).
            //
            // Apple verlangt je Abonnement ein Foto DIESER Seite, und
            // sie hat zwei Gestalten: mit hinterlegten Produkten den
            // Stufenstapel, ohne sie den Weg über eine Anfrage. Eine
            // Marke, die in beiden gilt, gibt es sonst nicht -- und
            // „Fertig" gilt auch für das Kontoblatt darunter.
            .accessibilityIdentifier("aboseite")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Fertigknopf(tun: fertig)
                }
            }
        }
    }

    /// Der Satz über dem Vorschlag -- etwa „Willkommen. „X" ist
    /// angelegt". Vom Server, nicht hier formuliert.
    @ViewBuilder
    private var meldungsteil: some View {
        if let meldung {
            Text(meldung)
                .font(.callout)
                .foregroundStyle(Farben.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // --- Was es kostet ---------------------------------------------------

    private var preis: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let monatlich = abo.monatlichText {
                Text(monatlich)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Farben.ink)
                Text("im Monat für euren Verein")
                    .font(.subheadline)
                    .foregroundStyle(Farben.inkStill)
                // § 6 Abs. 1 PAngV, am Preis und nicht anderswo (R110.2).
                if let hinweis = abo.steuerhinweis, !hinweis.isEmpty {
                    Text(hinweis)
                        .font(.caption)
                        .foregroundStyle(Farben.inkStill)
                        .fixedSize(horizontal: false, vertical: true)
                }
                rechnung
            } else {
                // OHNE HINTERLEGTEN PREIS WIRD KEINER ERFUNDEN. Eine
                // erfundene Zahl steht zwei Wochen später in der Mail
                // des Vereins und wird eingefordert.
                Text("Wir machen euch ein Angebot")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Farben.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("""
                    Für euren Verein steht noch kein Preis fest. Schreib uns, \
                    dann rechnen wir es aus.
                    """)
                    .font(.subheadline)
                    .foregroundStyle(Farben.inkStill)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Farben.flaechePanel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Farben.linie))
    }

    /// Die Zwischenschritte, nicht nur die Summe.
    ///
    /// Ein Vorstand, der eine einzelne Zahl bekommt, fragt zurück, und
    /// dann dauert der Abschluss zwei Wochen länger.
    private var rechnung: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().overlay(Farben.linie).padding(.vertical, 8)
            if abo.nachStufen {
                stufenrechnung
            } else {
                platzrechnung
            }
            // Der Satz, mit dem die Startseite wirbt, muss auch der Satz
            // sein, nach dem gerechnet wird (ADR-0008).
            Text("""
                Ein Platz ist ein Mensch, der zeichnen darf. Wer nur \
                zuschaut, kostet nichts.
                """)
                .font(.caption)
                .foregroundStyle(Farben.inkStill)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
    }

    /// Zwei Stufen (R17): acht Euro mit fünf Zugängen, fünfzehn ohne
    /// Grenze.
    ///
    /// **Kein Platzpreis.** Im Stufenmodell gibt es keinen, und die
    /// Zeile „je weiterem Platz 0,00 €" stünde unter einem Preis, der
    /// beim sechsten Zugang um sieben Euro springt.
    @ViewBuilder
    private var stufenrechnung: some View {
        zeile(String(localized: "Zugänge belegt"), "\(abo.plaetze)")
        if let basis = abo.basisText, let wieviele = abo.basisPlaetze {
            zeile(String(localized: "Basis (bis \(wieviele))"), basis)
        }
        if let voll = abo.unbegrenztText {
            zeile(String(localized: "Unbegrenzt"), voll)
        }
        if abo.stufe == "unbegrenzt" {
            Text("""
                Ihr seid in der unbegrenzten Stufe: beliebig viele \
                Mannschaften und Zugänge.
                """)
                .font(.caption)
                .foregroundStyle(Farben.inkStill)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    /// Das alte Platzmodell, nur noch für Anlagen, auf denen keine
    /// Stufe hinterlegt ist.
    @ViewBuilder
    private var platzrechnung: some View {
        if let grund = abo.grundgebuehrText {
            zeile(String(localized: "Grundgebühr"), grund)
        }
        zeile(String(localized: "Plätze belegt"), "\(abo.plaetze)")
        if abo.plaetzeInklusive > 0 {
            zeile(String(localized: "davon inklusive"),
              "\(abo.plaetzeInklusive)")
        }
        if let jePlatz = abo.preisJePlatzText {
            zeile(String(localized: "je weiterem Platz"), jePlatz)
        }
    }

    private func zeile(_ was: String, _ wert: String) -> some View {
        HStack {
            Text(was)
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)
            Spacer()
            Text(wert)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Farben.ink)
        }
    }

    // --- Was ein Abo aufhebt ----------------------------------------------

    /// Die Gegenüberstellung, als Karten statt als Tabelle.
    ///
    /// Drei Spalten sind auf einem Telefon zwei zu viel: Die längste
    /// Zeile bricht um, und danach steht „unbegrenzt" unter der falschen
    /// Überschrift.
    private var gegenueberstellung: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Demo und Abo")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Farben.ink)

            // JE STUFE EIN WERT, wenn sie sich unterscheiden (R119).
            // Eine gemeinsame Spalte „Mit Abo" gibt es nur da, wo beide
            // bezahlten Stufen wirklich dasselbe sagen -- sonst stand
            // unter „Standard" das Versprechen von „Premium".
            // Gerechnet wird das in `Stufenblock.vergleich`, nicht hier.
            ForEach(Stufenblock.vergleich(abo)) { zeile in
                VStack(alignment: .leading, spacing: 6) {
                    Text(zeile.was)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Farben.ink)
                    HStack(alignment: .top, spacing: 12) {
                        // Durch die Übersetzung wie die Spalte daneben:
                        // `spalte(_ kopf: String, …)` zeigt den Kopf als
                        // `Text(kopf)`, und das schlägt nichts nach.
                        // Auf Französisch heisst die Stufe „Démo".
                        spalte(String(localized: "Demo"), zeile.demo,
                               betont: false)
                        if let gemeinsam = zeile.abo {
                            spalte(String(localized: "Mit Abo"), gemeinsam,
                                   betont: true)
                        } else {
                            ForEach(zeile.jeStufe) { wert in
                                spalte(wert.name, wert.wert, betont: true)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Farben.flaechePanel,
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Farben.linie))
            }
        }
    }

    private func spalte(_ kopf: String, _ wert: String,
                        betont: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kopf)
                .font(.caption2)
                .foregroundStyle(Farben.inkStill)
            Text(wert)
                .font(.caption)
                .foregroundStyle(betont ? Farben.akzent : Farben.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // --- Wie es weitergeht ------------------------------------------------

    private var freischalten: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(abo.hinweis)
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)
                .fixedSize(horizontal: false, vertical: true)

            if !abo.kontakt.isEmpty, let ziel = mailweg {
                Link(destination: ziel) {
                    Text(abo.kontakt)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Farben.akzent)
                }
            }
        }
    }

    /// Die Mailadresse mit vorbereitetem Betreff.
    ///
    /// Der Betreff kommt vom SERVER und trägt den Vereinsnamen. Eine
    /// leere Mail an eine unbekannte Adresse ist die Stelle, an der die
    /// Hälfte aufgibt, und eine ohne Vereinsnamen kostet eine Rückfrage.
    private var mailweg: URL? {
        var teile = URLComponents()
        teile.scheme = "mailto"
        teile.path = abo.kontakt
        if !abo.betreff.isEmpty {
            teile.queryItems = [URLQueryItem(name: "subject",
                                             value: abo.betreff)]
        }
        return teile.url
    }

    /// Ein Weg heraus, und zwar genau einer.
    ///
    /// Sonst schließt „Fertig" das Blatt, ohne das Tokenpaar zu
    /// übernehmen -- und der frisch registrierte Verein steht wieder
    /// vor der Anmeldemaske.
    private func fertig() {
        if let weiter { weiter() } else { schliessen() }
    }

    private var weiterKnopf: some View {
        Button(action: fertig) {
            Text(weiterText)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .contentShape(Rectangle())
        }
        .paarung(Paare.knopfHaupt)
    }
}

/// Ein Abo-Vorschlag, den ein Blatt zeigen kann.
///
/// `Modell.Abo` ist nicht `Identifiable`, und das soll es auch nicht
/// werden: Es gibt keine Kennung, unter der ein Vorschlag steht. Diese
/// Hülle gibt ihm eine, damit `sheet(item:)` damit arbeiten kann.
struct Abovorschlag: Identifiable {
    let id = UUID()
    let abo: Modell.Abo
    /// Der Verein, um den es geht. Siehe `AboAnsicht.verein`.
    var verein: Int?
    /// Durch die Übersetzung, aus demselben Grund wie in
    /// `AboAnsicht`: Die Hülle gibt die zwei Werte unverändert dorthin
    /// weiter, und dort sind sie `String`.
    var titel: String = String(localized: "Abo")
    var weiterText: String = String(localized: "Weiter")
}

/// Was der Server sagt, wenn die Demo am Ende ist -- samt Weg weiter.
///
/// **Der Weg gehört dazu.** Bis B12 zeigte die App an einer Grenze einen
/// Satz und einen Knopf „Verstanden". Das ist eine Sackgasse, und der
/// Coach hält sie für einen Fehler der App: Er hat gerade etwas
/// Alltägliches versucht und bekommt eine Absage ohne Alternative.
struct Grenzmeldung: Identifiable {
    let id = UUID()
    let text: String
    /// `nil` heißt „der Server hat keinen mitgeschickt". Dann steht der
    /// Satz allein, und das ist immer noch besser als ein Knopf, hinter
    /// dem nichts ist.
    let abo: Modell.Abo?

    var vorschlag: Abovorschlag? {
        abo.map {
            Abovorschlag(
                abo: $0,
                titel: String(localized: "Grenze der Demo"),
                weiterText: String(localized: "Zurück zur Arbeit"))
        }
    }
}
