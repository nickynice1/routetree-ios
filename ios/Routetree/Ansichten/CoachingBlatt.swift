// Coach zu Spieler -- die Seite des TRÄGERS (R143).
//
// **Niklas am 01.10.2026:** „wollen wir in den einstellungen einfach
// ein Coach zu Spieler verbindung anbieten? denn kommt man vorm
// training zusammen der coach startet das in der app."
//
// ## Warum dieser Bildschirm existieren MUSS
//
// Ein iPhone erreicht über WatchConnectivity ausschliesslich SEINE
// eigene gekoppelte Uhr. Es gibt keinen Weg, mit dem Handgelenk eines
// anderen Menschen zu sprechen -- kein Bluetooth, kein Trick.
//
// Der Schlüssel entsteht deshalb beim Coach (nur wer die Mannschaft
// führt, darf eine Uhr anmelden) und muss über das Telefon des
// Spielers auf dessen Uhr. Dieses Telefon, diese Seite.
//
// ## Warum von Hand eingetippt
//
// Weil es die einzige Übergabe ist, die ohne weitere Technik
// funktioniert -- und weil sie genau einmal passiert: „denn kommt man
// vorm training zusammen." Zwei Leute, ein Schlüssel, fertig.
//
// Der bequemere Weg (Telefon zu Telefon über Multipeer, von Niklas am
// 01.10.2026 so gewählt) kommt obendrauf und ersetzt diesen hier
// nicht: Er braucht beide Geräte gleichzeitig im selben Raum und
// dieselbe App-Fassung. Wer das nicht hat, tippt.

import SwiftUI

struct CoachingBlatt: View {

    @ObservedObject var bruecke: Uhrbruecke
    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen

    @StateObject private var funk = Schluesselempfang()

    @State private var eingabe = ""
    @State private var gesendet: Date?
    @State private var fragtAbmelden = false

    /// Wie dieses Telefon beim Coach in der Liste steht.
    @State private var meinName = ""

    /// Was eingetippt wurde, ohne Leerzeichen und Zeilenumbrüche.
    ///
    /// **Beides fällt wirklich an.** Ein Schlüssel kommt per Nachricht
    /// oder Zettel; wer ihn in iOS kopiert, nimmt das Leerzeichen
    /// dahinter mit. Mit ihm bekäme der Server einen Schlüssel, den er
    /// nicht kennt, und auf der Uhr stünde „nicht mehr angemeldet".
    private var sauber: String {
        eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    kopf
                    if bruecke.uhrVorhanden {
                        funkteil
                        Divider()
                        eingabefeld
                        knopf
                        if let gesendet { bestaetigung(gesendet) }
                        abmelden
                    } else {
                        keineUhr
                    }
                    erklaerung
                }
                .padding(16)
            }
            .background(Farben.flaeche.ignoresSafeArea())
            .task { await namenHolen() }
            .onDisappear { funk.aufhoeren() }
            // EIN ANGEKOMMENER SCHLÜSSEL GEHT GLEICH WEITER.
            //
            // **Und nicht erst nach einem zweiten Knopfdruck.** Wer
            // „Vom Coach empfangen" getippt hat, hat damit gesagt, was
            // er will; ihm danach den Schlüssel zum Bestätigen
            // hinzulegen wäre eine Frage, die er schon beantwortet hat
            // -- vor dem Training, mit zwanzig Leuten um ihn herum.
            //
            // Er steht trotzdem im Feld: Geht etwas schief, hat der
            // Spieler ihn noch und muss den Coach nicht neu suchen.
            .onChange(of: funk.schluessel) { _, neu in
                guard let neu else { return }
                eingabe = neu
                if bruecke.coachingschluessel(neu) {
                    gesendet = Date()
                    eingabe = ""
                }
            }
            .navigationTitle(String(localized: "Coaching"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Fertigknopf { schliessen() }
                }
            }
            .alert("Uhr abmelden", isPresented: $fragtAbmelden) {
                Button("Abbrechen", role: .cancel) {}
                // **„Uhr abmelden" und nicht „Abmelden".**
                //
                // „Abmelden" gibt es in dieser App schon, und zwar
                // für etwas anderes: den eigenen Zugang verlassen
                // („Sign out"). Zwei deutsche Sätze mit demselben
                // Wortlaut und verschiedener Bedeutung bekommen EINE
                // Übersetzung -- `uebersetzen.py` nimmt lautlos eine
                // davon. Auf einem englischen Telefon stünde in
                // diesem Dialog „Sign out", und ein Spieler, der nur
                // seine Uhr abmelden will, lässt es lieber.
                Button("Uhr abmelden", role: .destructive) {
                    bruecke.coachingAus()
                    gesendet = nil
                    eingabe = ""
                }
            } message: {
                Text("Die Uhr vergisst den Schlüssel und zeigt keine gerufenen Spielzüge mehr. Zum Wiederanmelden brauchst du einen neuen Schlüssel von deinem Coach.")
            }
        }
    }

    // MARK: - Teile

    private var kopf: some View {
        HStack(spacing: 12) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.largeTitle)
                .foregroundStyle(Farben.akzent)
            Text("Dein Coach wählt am Spielfeldrand den Spielzug, und er erscheint auf deiner Uhr.")
                .font(.subheadline)
                .foregroundStyle(Farben.inkLeise)
        }
    }

    /// Den Schlüssel per Funk vom Coach holen (R143, Multipeer).
    ///
    /// **Niklas am 01.10.2026**, auf die Frage nach dem Weg: Telefon
    /// zu Telefon. Dieses Gerät zeigt sich an, der Coach sucht und
    /// tippt den Namen an -- die Begründung dieser Richtung steht in
    /// `Schluesselfunk.swift`.
    ///
    /// **Der bequeme Weg steht OBEN, der getippte darunter.** Vor dem
    /// Training stehen beide zusammen; dann ist Funk der kürzere Weg.
    /// Wer später dazukommt oder dessen Funk nicht will, tippt.
    @ViewBuilder
    private var funkteil: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vom Coach empfangen")
                .font(.headline)
            if funk.zeigtSich {
                HStack(spacing: 8) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dein iPhone zeigt sich dem Coach.")
                            .font(.footnote)
                            .foregroundStyle(Farben.inkLeise)
                        // **DER NAME, UNTER DEM ER DASTEHT.** Ohne ihn
                        // sagt der Spieler „ich bin da" und der Coach
                        // sieht drei Namen und weiss nicht, welcher
                        // er ist.
                        Text("Du stehst bei ihm als „\(meinName)“.")
                            .font(.caption2)
                            .foregroundStyle(Farben.inkStill)
                    }
                    Spacer(minLength: 0)
                }
                Button {
                    funk.aufhoeren()
                } label: {
                    Text("Abbrechen").font(.footnote)
                }
            } else {
                Button {
                    funk.anfangen(name: meinName)
                } label: {
                    Label("Vom Coach empfangen",
                          systemImage: "dot.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .background(Farben.flaechePanel)
                .foregroundStyle(Farben.ink)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("coaching-funk-empfangen")
            }
            if let von = funk.von {
                Text("Angekommen von „\(von)“.")
                    .font(.footnote)
                    .foregroundStyle(Farben.gut)
            }
            if let hinweis = funk.hinweis {
                Text(hinweis)
                    .font(.footnote)
                    .foregroundStyle(Farben.warnung)
            }
        }
    }

    private var eingabefeld: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Schlüssel vom Coach")
                .font(.headline)
            TextField("Schlüssel", text: $eingabe)
                // KEINE AUTOKORREKTUR UND KEINE GROSSSCHREIBUNG.
                //
                // Ein Schlüssel ist eine Zeichenfolge ohne Sinn. iOS
                // macht aus dem ersten Buchstaben sonst einen grossen
                // und schlägt Wörter vor -- und der Schlüssel, der
                // ankommt, ist dann ein anderer als der, der
                // abgeschickt wurde. Gesucht würde danach im Netz.
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .background(Farben.flaechePanel)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("coaching-schluessel")
            if let meldung = bruecke.meldung {
                Text(meldung)
                    .font(.footnote)
                    .foregroundStyle(Farben.fehler)
            }
        }
    }

    private var knopf: some View {
        Button {
            if bruecke.coachingschluessel(sauber) {
                gesendet = Date()
                // DER SCHLÜSSEL BLEIBT IM FELD NICHT STEHEN. Er ist
                // jetzt auf der Uhr; hier liegt er nur noch herum --
                // auf einem Bildschirm, den jemand über die Schulter
                // mitliest.
                eingabe = ""
            }
        } label: {
            Text("Auf meine Uhr schicken")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                // AM LABEL UND NICHT AM KNOPF: Die Trefferfläche
                // entscheidet die Beschriftung. Gemeldet von Niklas am
                // 28.09.2026 am Übertragen-Knopf daneben -- derselbe
                // Fehler, deshalb hier von Anfang an richtig.
                .contentShape(Rectangle())
        }
        .background(Farben.petrol)
        .foregroundStyle(Farben.aufPetrol)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(sauber.isEmpty || !bruecke.appInstalliert)
        .accessibilityIdentifier("coaching-schluessel-schicken")
    }

    private func bestaetigung(_ wann: Date) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Farben.gut)
            // **„Bei der nächsten Verbindung" und nicht „angekommen".**
            // Der Anwendungszusammenhang wird zugestellt, wenn die Uhr
            // erreichbar ist -- das kann sofort sein oder in einer
            // Minute. Wer hier „ist drauf" liest und auf der Uhr noch
            // nichts sieht, hält es für kaputt und tippt neu.
            Text("Der Schlüssel ist unterwegs. Er kommt an, sobald die Uhr das nächste Mal Verbindung hat. Öffne dort Routetree, tippe dein Playbook an und dann „Coaching“.")
                .font(.footnote)
                .foregroundStyle(Farben.inkLeise)
        }
        .padding(10)
        .background(Farben.flaechePanel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var abmelden: some View {
        Button {
            fragtAbmelden = true
        } label: {
            Text("Uhr abmelden")
                .font(.footnote)
                .foregroundStyle(Farben.fehler)
        }
        .accessibilityIdentifier("coaching-abmelden")
    }

    /// Den eigenen Namen für den Funk holen.
    ///
    /// Er kommt vom Server und nicht vom Gerät: Seit iOS 16 heissen
    /// für eine App alle iPhones „iPhone" (siehe `funkname`).
    private func namenHolen() async {
        guard meinName.isEmpty,
              let marke = try? await anmeldung.gueltigesToken(),
              let stand = try? await Kontodaten.setzen(token: marke)
        else { return }
        meinName = stand.anzeigename
    }

    private var keineUhr: some View {
        Text("An diesem iPhone ist keine Apple Watch gekoppelt. Der Coaching-Modus braucht eine.")
            .font(.footnote)
            .foregroundStyle(Farben.inkLeise)
    }

    /// Was zu tun ist, als Schritte statt als Absatz.
    ///
    /// **Niklas am 07.10.2026**, mit einem Bildschirmfoto genau dieses
    /// Abschnitts: „Kannst du diese KI Texte in einfach steps machen?
    /// Also 1. das das 2. das und das."
    ///
    /// Er hat recht, und der Grund liegt an der Stelle: Hier steht
    /// jemand VOR dem Training und will wissen, was er tun muss. Ein
    /// Absatz erklärt, wie es funktioniert; eine Liste sagt, was zu
    /// tun ist. Die Erklärung kommt danach und kürzer.
    private var erklaerung: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("So geht es")
                .font(.headline)

            schritt(1, Text("Dein Coach meldet deine Uhr in der App an und gibt dir den Schlüssel."))
            schritt(2, Text("Trag ihn oben ein und tippe auf „Auf meine Uhr schicken“."))
            schritt(3, Text("Öffne Routetree auf der Uhr, tippe dein Playbook an und dann „Coaching“."))
            schritt(4, Text("Fertig. Ab jetzt erscheint der Spielzug, den dein Coach wählt, von selbst auf der Uhr."))

            // DER WICHTIGSTE SATZ STEHT ALLEIN, nicht in der Liste.
            //
            // Eine Uhr ohne Mobilfunk bekommt die gerufenen Spielzüge
            // NUR über ihr iPhone. Wer sein Telefon beim Coach an der
            // Bank lässt, steht auf dem Feld mit einer Uhr, die nichts
            // mehr bekommt, und hält sie für kaputt. Als Punkt 5 in
            // einer Liste würde er überlesen.
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Farben.warnung)
                Text("Hat deine Uhr keinen Mobilfunk, muss dein iPhone bei dir bleiben. Es darf nicht an der Bank liegen, sonst bekommt die Uhr nichts mehr.")
                    .font(.footnote)
                    .foregroundStyle(Farben.ink)
            }
            .padding(10)
            .background(Farben.flaechePanel)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("Der Schlüssel gilt nur zum Lesen des gerufenen Spielzugs. Ändern oder anderes ansehen kann man damit nicht.")
                .font(.footnote)
                .foregroundStyle(Farben.inkLeise)
        }
    }

    /// Eine nummerierte Zeile.
    ///
    /// **Die Zahl steht in einer festen Breite.** Ohne sie rutscht der
    /// Text je nach Ziffer um ein paar Punkte, und eine Liste, deren
    /// Zeilen nicht untereinander anfangen, liest sich wie ein Fehler.
    /// **`Text` und nicht `String`:** Ein `String` in `Text(…)` wird
    /// nicht uebersetzt, und `appsprache.py` sammelt ein Literal nur
    /// ein, wenn es direkt in `Text(` steht. Siehe `Coachinganleitung`.
    private func schritt(_ nummer: Int, _ text: Text) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // VERBATIM, weil eine blanke Ziffer kein Satz ist.
            // Ohne das sammelt `appsprache.py` sie als zu
            // uebersetzenden Text ein und verlangt fuer „1"
            // vier Fassungen.
            Text(verbatim: "\(nummer)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Farben.aufPetrol)
                .frame(width: 22, height: 22)
                .background(Farben.petrol, in: Circle())
            text
                .font(.subheadline)
                .foregroundStyle(Farben.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
