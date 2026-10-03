import StoreKit
import SwiftUI

/// Die Stufen zum Durchwischen -- und der Kauf gleich dort (R117).
///
/// **Der Auftrag** (Niklas, 10.09.2026): „demo version darunter funktion
/// -> 8€ standard und darunter funktion -> 15€ premium darunter funktion
/// und denn gleich die variante die man will das man die gleicj dort
/// kaufen kann. weisst du? und denn soll immer bei dem was man jat auch
/// stejen ‚das jast du aktuell'"
///
/// Dieselbe Geste wie bei den Mannschaften (R13), und aus demselben
/// Grund: Der Daumen liegt in der Mitte des Bildschirms. Drei Stufen
/// nebeneinander wären auf einem Telefon drei Spalten, in denen die
/// längste Zeile umbricht -- und danach steht „unbegrenzt" unter der
/// falschen Überschrift.
///
/// **Was hier nicht entschieden wird.** Welche Seiten es gibt, was
/// darauf steht und welche man hat, rechnet `Stufenblock` -- ohne
/// Bildschirm und damit prüfbar. Was ein Kauf bewirkt, entscheidet der
/// Server (`kasse.apple_verarbeiten`). Diese Datei zeichnet.
struct StufenAnsicht: View {
    let abo: Modell.Abo
    /// Für welchen Verein gekauft wird. `nil` heisst: Der Server nimmt
    /// den Verein dieser Person -- er kennt ihn ohnehin und muss ihn
    /// prüfen.
    let verein: Int?
    var titel: String = String(localized: "Abo")
    /// Wird gerufen, wenn ein Kauf durch ist. Die aufrufende Seite lädt
    /// dann neu -- was gilt, sagt der Server.
    var gekauft: ((Modell.Abo) -> Void)?

    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                StufenStapel(abo: abo, verein: verein, gekauft: gekauft)
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Fertigknopf { schliessen() }
                }
            }
        }
    }
}

/// Derselbe Stapel OHNE eigenen Rahmen.
///
/// **Warum getrennt.** Der Stapel erscheint an zwei Stellen: als
/// eigenes Blatt (oben) und mitten in `AboAnsicht`, die ihren eigenen
/// Rahmen und ihren eigenen „Weiter"-Knopf mitbringt -- am Ende der
/// Registrierung hängt daran die Übernahme des Tokenpaars. Zwei
/// Navigationsrahmen ineinander ergeben zwei Titelzeilen übereinander.
struct StufenStapel: View {
    let abo: Modell.Abo
    let verein: Int?
    var gekauft: ((Modell.Abo) -> Void)?

    @EnvironmentObject private var anmeldung: Anmeldung
    @StateObject private var kasse = Kasse()
    @State private var seiteId: String?
    @State private var laufzeit = Stufenblock.monat

    private var seiten: [Stufenblock.Seite] {
        Stufenblock.seiten(abo, laufzeit: laufzeit)
    }

    var body: some View {
        VStack(spacing: 0) {
            laufzeitwahl
            TabView(selection: $seiteId) {
                ForEach(seiten) { seite in
                    blatt(seite)
                        .padding(.horizontal, 20)
                        .tag(Optional(seite.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // DER KAUFKNOPF LIEGT AUSSERHALB DES STAPELS. Die
            // Begründung steht bei `blatt(_:)`. Nebenbei steht er damit
            // immer da, ohne dass jemand erst scrollen muss -- die
            // wichtigste Schaltfläche des Blattes war bis heute die
            // einzige, die man suchen musste.
            if let seite = aktuelleSeite {
                kaufteil(seite)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
            }

            wiederherstellen
        }
        // DER FEHLER KOMMT ALS MELDUNG UND NICHT ALS FUSSNOTE
        // (18.09.2026).
        //
        // Er stand hier als kleine rote Zeile zwischen der Blätterleiste
        // und „Käufe wiederherstellen" -- also an der Stelle, an der auf
        // einem Telefon am wenigsten hinsieht, wer gerade auf einen
        // Knopf getippt hat. Beim Suchen nach dem toten Kaufknopf war
        // die erste Frage an Niklas, ob dort unten etwas Rotes steht.
        // Eine Meldung, nach der man fragen muss, ist keine.
        //
        // `fehler` wird beim Schliessen geleert, sonst käme dieselbe
        // Meldung beim nächsten Tippen sofort wieder.
        .alert(
            String(localized: "Kauf"),
            isPresented: Binding(get: { kasse.fehler != nil },
                                 set: { if !$0 { kasse.fehler = nil } })
        ) {
            Button(String(localized: "OK"), role: .cancel) {
                kasse.fehler = nil
            }
        } message: {
            Text(kasse.fehler ?? "")
        }
        .onChange(of: laufzeit) { _, _ in
            // Beim Wechsel auf die eigene Stufe springen -- sonst steht
            // man nach dem Umschalten auf einer anderen Karte als
            // vorher, ohne dass jemand gewischt hat.
            seiteId = Stufenblock.anfangsseite(seiten)
        }
        .task {
            seiteId = seiteId ?? Stufenblock.anfangsseite(seiten)
            // Erst verbinden, dann laden: Ohne die Anmeldung käme ein
            // Kauf durch und liesse sich nicht abliefern.
            kasse.verbinden(anmeldung: anmeldung, verein: verein)
            await kasse.laden(abo.kaufbareStufen)
        }
        .onChange(of: kasse.stand) { _, neu in
            guard let neu else { return }
            gekauft?(neu)
        }
        .onDisappear { kasse.loesen() }
    }

    // --- Eine Stufe -------------------------------------------------------

    /// Eine Stufe -- **ohne den Kaufknopf** (18.09.2026).
    ///
    /// Der Knopf stand hier, als letztes Glied im `VStack` einer
    /// `ScrollView`, die ihrerseits in `TabView(.page)` liegt. Niklas:
    /// „ich kann halt gar nicht auf jetzt buchen tippen da passiert gar
    /// nix!" -- sichtbar, blau, nicht ausgegraut, und auf den Finger
    /// passierte nichts.
    ///
    /// **Es ist derselbe Fehler wie am 11.09.2026 beim Zurück-Knopf**,
    /// eine Schaltfläche weiter. Die Begründung steht in
    /// `AboAnsicht` ausführlich: Über der Fläche des Stapels liegt die
    /// Wischgeste, je Stufe darin eine `ScrollView` -- wessen Finger
    /// dort landet, gehört im Zweifel der Geste. Und es fällt erst auf,
    /// wenn gescrollt wurde, weil der Knopf vorher gar nicht zu sehen
    /// ist. Dort half `safeAreaInset`; hier steht der Knopf jetzt
    /// ausserhalb des `TabView`.
    ///
    /// **Der Fehler ist teuer, weil er nach nichts aussieht.** Kein
    /// Fehlertext, kein ausgegrauter Knopf, kein Eintrag im Protokoll
    /// des Servers -- `kaufen()` wird nie aufgerufen. Wer das sucht,
    /// sucht bei StoreKit, bei Apples Produkten und beim Sandbox-Konto.
    /// Dort ist alles in Ordnung.
    @ViewBuilder
    private func blatt(_ seite: Stufenblock.Seite) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                kopf(seite)
                leistungen(seite)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
        }
    }

    /// Die Stufe, die gerade vorn liegt.
    ///
    /// Der Rückfall auf die erste Seite ist kein Schönheitsfehler:
    /// `seiteId` ist erst nach `.task` gesetzt, und in dem Augenblick
    /// stünde sonst kein Kaufknopf da, obwohl eine Karte zu sehen ist.
    private var aktuelleSeite: Stufenblock.Seite? {
        seiten.first { $0.id == seiteId } ?? seiten.first
    }

    private func kopf(_ seite: Stufenblock.Seite) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name(seite))
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Farben.ink)

            // DER PREIS KOMMT VON APPLE, wenn Apple geantwortet hat.
            // Nur dort steht, was in der Währung des Käufers wirklich
            // abgebucht wird -- und was über dem Kaufknopf steht, muss
            // stimmen. Der Text des Servers ist der Rückfall, nicht der
            // Regelfall.
            if let preis = preistext(seite) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(preis)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Farben.ink)
                    Text(laufzeit == Stufenblock.jahr
                         ? String(localized: "im Jahr")
                         : String(localized: "im Monat"))
                        .font(.subheadline)
                        .foregroundStyle(Farben.inkStill)
                }
            } else if seite.stufe == Stufenblock.demo {
                Text("Kostenlos, mit Grenzen")
                    .font(.subheadline)
                    .foregroundStyle(Farben.inkStill)
            }

            // DER UMSATZSTEUERHINWEIS STEHT AM PREIS (R110.2, § 6
            // Abs. 1 PAngV). Nicht im Kleingedruckten und nicht auf
            // einer anderen Seite: Er gehört dorthin, wo die Zahl
            // steht, sonst ist er keine Angabe zum Preis.
            if preistext(seite) != nil,
               Stufenblock.steuerhinweisZeigen(storefront: kasse.storefront),
               let hinweis = abo.steuerhinweis, !hinweis.isEmpty {
                Text(hinweis)
                    .font(.caption)
                    .foregroundStyle(Farben.inkStill)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if seite.aktuell {
                // DER SATZ, DEN NIKLAS WÖRTLICH VERLANGT HAT.
                Text("Das hast du aktuell")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .paarung(Paare.aufgabenmarke, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func leistungen(_ seite: Stufenblock.Seite) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(seite.leistungen) { zeile in
                VStack(alignment: .leading, spacing: 3) {
                    Text(zeile.was)
                        .font(.caption)
                        .foregroundStyle(Farben.inkStill)
                    Text(zeile.wert)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Farben.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Farben.flaechePanel,
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Farben.linie))
            }
        }
    }

    @ViewBuilder
    private func kaufteil(_ seite: Stufenblock.Seite) -> some View {
        let kennungen = kasse.produkte.map(\.id)
        if Stufenblock.kaufbar(seite, bekannteProdukte: kennungen),
           let produkt = kasse.produkte.first(where: { $0.id == seite.produkt }) {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Task { await kasse.kaufen(produkt) }
                } label: {
                    Text(kasse.laeuft ? String(localized: "Einen Moment …")
                                      : String(localized: "Jetzt buchen"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        // DIE GANZE FLÄCHE, nicht nur die Schrift.
                        // Begründung bei `Hauptknopfflaeche` in
                        // `Fertigknopf.swift`.
                        .contentShape(Rectangle())
                }
                .paarung(Paare.knopfHaupt)
                .disabled(kasse.laeuft)

                // WAS DER KAUF BEDEUTET, STEHT DARUNTER UND NICHT IM
                // KLEINGEDRUCKTEN. Ein Abo, das sich verlängert, ohne
                // dass es jemand gelesen hat, ist der häufigste Grund
                // für eine Rückbuchung -- und die kostet mehr als der
                // Monat einbringt.
                Text(laufzeit == Stufenblock.jahr
                     ? String(localized: """
                        Verlängert sich jährlich, bis du kündigst. \
                        Kündigen geht in den Einstellungen deines \
                        Apple-Kontos.
                        """)
                     : String(localized: """
                        Verlängert sich monatlich, bis du kündigst. \
                        Kündigen geht in den Einstellungen deines \
                        Apple-Kontos.
                        """))
                    .font(.caption)
                    .foregroundStyle(Farben.inkStill)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        } else if seite.aktuell {
            // NUR WER BEZAHLT, BEZAHLT (R131). Der Satz stand auch
            // unter der Demo-Karte -- „Du bezahlst diese Stufe
            // bereits." über „Kostenlos, mit Grenzen". Niklas hat es
            // am 11.09.2026 auf dem Bildschirmfoto angestrichen.
            //
            // Auf der Demo steht ohnehin oben schon „Das hast du
            // aktuell"; hier gehört der Weg dahin, nicht die
            // Wiederholung.
            Text(seite.stufe == Stufenblock.demo
                 ? String(localized: """
                    Das ist dein jetziger Stand. Eine Stufe weiter \
                    findest du mit einem Wisch.
                    """)
                 : String(localized: "Du bezahlst diese Stufe bereits."))
                // EINE ZWEITE MARKE FÜR DEN BILDERLAUF (30.09.2026).
                //
                // Er erkennt die Kaufseite bisher an einem Knopf und an
                // zwei Kennungen auf Behältern. Behälter sind in
                // SwiftUI die unzuverlässigste Art, eine Kennung zu
                // tragen; ein `staticText` ist die sicherste. Diese
                // Zeile stand auf dem Foto vom gescheiterten Durchgang
                // deutlich lesbar da -- sie war die ganze Zeit greifbar
                // und wurde nur nicht gesucht.
                .accessibilityIdentifier("stufenstand")
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)
        } else if seite.stufe != Stufenblock.demo {
            // KEIN KNOPF, DER INS LEERE GREIFT. Solange Apple die
            // Produkte nicht kennt -- weil sie noch nicht angelegt sind
            // oder gerade nicht laden --, steht hier ein Satz und keine
            // Schaltfläche.
            Text("Diese Stufe lässt sich hier gerade nicht buchen.")
                .font(.footnote)
                .foregroundStyle(Farben.inkStill)
        }
    }

    /// Monat oder Jahr (R118).
    ///
    /// **Nur wenn es beides gibt.** Solange bei Apple kein
    /// Jahresprodukt angelegt ist, nennt der Server nur den Monat --
    /// dann steht hier nichts statt eines Umschalters, der auf eine
    /// leere Seite führt.
    @ViewBuilder
    private var laufzeitwahl: some View {
        let moeglich = Stufenblock.laufzeiten(abo)
        if moeglich.count > 1 {
            Picker("Wie oft du zahlst", selection: $laufzeit) {
                ForEach(moeglich, id: \.self) { wert in
                    Text(laufzeitname(wert)).tag(wert)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // WAS DIE JAHRESZAHLUNG SCHENKT, steht als Zahl da und
            // nicht als Prozentsatz. „Zwei Monate geschenkt" versteht
            // ein Vorstand ohne zu rechnen.
            if let geschenkt = seiten.compactMap(\.geschenkt).first,
               geschenkt > 0 {
                Text(String(localized: "\(geschenkt) Monate geschenkt"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Farben.akzent)
                    .padding(.top, 6)
            }
        }
    }

    private func laufzeitname(_ wert: String) -> String {
        wert == Stufenblock.jahr ? String(localized: "Jährlich")
                                 : String(localized: "Monatlich")
    }

    /// Apples Richtlinie 3.1.1 verlangt einen Weg zurück zu einem schon
    /// gekauften Abo -- wer das Telefon wechselt, hat es nicht verloren.
    private var wiederherstellen: some View {
        Button {
            Task { await kasse.wiederherstellen() }
        } label: {
            Text("Käufe wiederherstellen")
                .font(.footnote)
                .foregroundStyle(Farben.akzent)
        }
        .disabled(kasse.laeuft)
        // DIE KENNUNG GEHÖRT AN DEN KNOPF, NICHT AN SEINE AUFSCHRIFT.
        //
        // Sie stand bis zum 30.09.2026 an dem `Text` da oben. Der
        // Bilderlauf sucht `app.buttons["kaeufe-wiederherstellen"]` --
        // und fand nichts, weil die Kennung am Text hing und der Knopf
        // darum keine trug. Zehn Durchgänge in fünf Sprachen sind
        // daran gescheitert, jeder erst nach seinem letzten Schritt,
        // also nach sieben Minuten.
        //
        // Für den Menschen änderte das nichts: VoiceOver liest die
        // Aufschrift, und die Kaufseite ging die ganze Zeit auf.
        // Kaputt war nur der Weg, auf dem eine Maschine sie findet.
        .accessibilityIdentifier("kaeufe-wiederherstellen")
        .padding(.bottom, 12)
    }

    // --- Was dasteht ------------------------------------------------------

    /// Der Name einer Stufe -- **vom Server, wenn er ihn schickt**.
    ///
    /// Hier stand die Zuordnung von Schlüssel zu Überschrift, mit der
    /// Begründung, der Server kenne nur Schlüssel. Das stimmte, und
    /// genau deshalb ging es schief: Der BROWSER kannte auch nur
    /// Schlüssel und hat sich seine eigenen Überschriften dazu
    /// ausgedacht -- „Basis" und „Unbegrenzt". Dieselben zwei Stufen
    /// hiessen also an drei Stellen verschieden, denn auf Apples
    /// Abrechnung stehen „Standard" und „Premium".
    ///
    /// Seit dem 10.09.2026 schickt der Server den Namen mit
    /// (`abo.stufenname`). Die Zuordnung hier bleibt als Rückfall für
    /// einen älteren Server stehen: besser ein veralteter Name als eine
    /// Karte ohne Überschrift.
    private func name(_ seite: Stufenblock.Seite) -> String {
        if let vomServer = seite.name, !vomServer.isEmpty { return vomServer }
        switch seite.stufe {
        case Stufenblock.demo: return String(localized: "Demo")
        case "basis": return String(localized: "Standard")
        case "unbegrenzt": return String(localized: "Premium")
        default: return seite.stufe
        }
    }

    /// Der Preis auf der Karte -- die Regel steht in `Stufenblock`.
    ///
    /// Hier wird nur nachgeschlagen, was StoreKit zu diesem Produkt
    /// sagt. Ob daraus ein Preis wird, entscheidet
    /// `Stufenblock.preistext` -- und das lässt sich ohne Mac messen.
    private func preistext(_ seite: Stufenblock.Seite) -> String? {
        Stufenblock.preistext(
            seite,
            ausStoreKit: kasse.produkte
                .first { $0.id == seite.produkt }?.displayPrice)
    }
}
