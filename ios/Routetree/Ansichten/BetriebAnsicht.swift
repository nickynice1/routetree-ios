import SwiftUI

/// Die abgespeckte Verwaltung in der App.
///
/// **Der Auftrag, wörtlich.** Niklas am 09.09.2026: „und am
/// allercoolsten wäre es wenn ich sie sogar über die app in die
/// verwaltung komme also dort eine abgespeckte verwaltung nur unter
/// meinem username habe weißt du? [...] und ich möchte bei mir denn
/// auch ne push benachrichtung sowohl per email als auch per app
/// bekommen wenn so eine anfrage reinkommt."
///
/// **Abgespeckt heisst nicht „dasselbe in klein".** Ein Datenbankeditor
/// auf einem Telefon ist ein Weg, sich zu vertippen. Hier steht der
/// Teil, der EILIG ist und unterwegs passiert: Ein Schulantrag liegt an,
/// eine Kündigung ist eingegangen, eine Zahlung ist schiefgegangen.
/// Preise, Rechtstexte und Funktionsschalter bleiben im Browser -- die
/// ändert niemand an der Ampel, und ein falsch getippter Preis steht
/// danach auf einem Blatt, das an ein Amt geht.
///
/// **Was WARTET, nicht was da ist.** „412 Schulanträge" sagt nichts;
/// „2 offen" sagt alles. Genau daran ist die Anfrageliste schon einmal
/// gescheitert: Bis zum 20.08.2026 war eine Anfrage nach dem Absenden
/// für niemanden sichtbar.
struct BetriebAnsicht: View {
    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen

    @State private var ueberblick: Betrieb.Ueberblick?
    @State private var antraege: [Betrieb.Schulantrag] = []
    @State private var erklaerungen: [Betrieb.Erklaerung] = []
    @State private var laeuft = true
    @State private var fehler: String?
    /// Welcher Antrag gerade bestätigt wird -- und mit welchem Grund.
    @State private var amBestaetigen: Betrieb.Schulantrag?
    @State private var grund = ""

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

                        if let ueberblick {
                            zustandsblock(ueberblick)
                        }
                        schulblock()
                        erklaerungsblock()
                    }
                    .padding(22)
                }
                if laeuft { ProgressView().tint(Farben.akzent) }
            }
            .navigationTitle("Betrieb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Fertigknopf { schliessen() }
                }
            }
            .refreshable { await laden() }
            .task { await laden() }
            .alert("Echtheit bestätigen", isPresented: .init(
                get: { amBestaetigen != nil },
                set: { if !$0 { amBestaetigen = nil } })) {
                TextField("Wie geprüft?", text: $grund)
                Button("Abbrechen", role: .cancel) { amBestaetigen = nil }
                Button("Bestätigen") {
                    if let antrag = amBestaetigen {
                        Task { await bestaetigen(antrag) }
                    }
                }
            } message: {
                // DER GRUND IST PFLICHT, und der Satz sagt warum. Der
                // Server weist einen Antrag ohne Begründung mit 400 ab;
                // ein Formular, das das erst hinterher verrät, ist eine
                // Sackgasse mit Ansage.
                Text("""
                    Schreib auf, wie du die Schule geprüft hast. Das steht \
                    später nur hier – „auf der Schulseite angerufen" ist \
                    eine Auskunft, ein leeres Feld ist keine.
                    """)
            }
        }
    }

    // --- Die Blöcke -------------------------------------------------

    @ViewBuilder
    private func zustandsblock(_ stand: Betrieb.Ueberblick) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // ZUERST DAS, WAS NICHT STIMMT. Ein Testbetrieb, in dem ein
            // Kauf wie ein Kauf aussieht und keiner ist, kostet
            // Vertrauen (ADR-0007) -- und ein abgeschalteter Kaufknopf
            // ist die Antwort auf „warum kauft niemand".
            if stand.testbetrieb {
                hinweis(String(localized: "Testbetrieb: Es wird kein Geld abgebucht."),
                        zeichen: "flask", farbe: Farben.warnung)
            }
            if !stand.zahlungBereit {
                hinweis(String(localized: "Bezahlen ist nicht eingerichtet. Es kann niemand kaufen."),
                        zeichen: "creditcard.trianglebadge.exclamationmark",
                        farbe: Farben.fehler)
            }
            if stand.wartet.zahlungsfehler > 0 {
                hinweis(String(localized: "\(stand.wartet.zahlungsfehler) Zahlungsmeldungen sind fehlgeschlagen."),
                        zeichen: "exclamationmark.triangle",
                        farbe: Farben.fehler)
            }
            if stand.wartet.anfragen > 0 {
                hinweis(String(localized: "\(stand.wartet.anfragen) Anfragen von Vereinen warten."),
                        zeichen: "envelope", farbe: Farben.warnung)
            }
            if stand.wartet.summe == 0 {
                hinweis(String(localized: "Nichts liegt an."),
                        zeichen: "checkmark.circle", farbe: Farben.gut)
            }
            if !stand.darfAendern {
                Text("Dieser Zugang darf sehen, nicht ändern.")
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)
            }
        }
    }

    @ViewBuilder
    private func schulblock() -> some View {
        let offene = antraege.filter { !$0.bestaetigt && !$0.eingeloest }
        gruppe(String(localized: "Schulanträge"), zahl: offene.count) {
            if antraege.isEmpty {
                leerzeile(String(localized: "Kein Antrag."))
            } else {
                ForEach(antraege) { antrag in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(antrag.schule)
                                .foregroundStyle(Farben.ink)
                            Spacer()
                            Text(antrag.zustand)
                                .font(.caption)
                                .foregroundStyle(marke(antrag.zustand))
                        }
                        Text(antrag.adresse)
                            .font(.footnote)
                            .foregroundStyle(Farben.inkStill)
                        if !antrag.bestaetigt && !antrag.eingeloest {
                            Button {
                                grund = ""
                                amBestaetigen = antrag
                            } label: {
                                Text("Echtheit bestätigen")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Farben.akzent)
                            }
                            .padding(.top, 4)
                            .disabled(ueberblick?.darfAendern != true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func erklaerungsblock() -> some View {
        let offene = erklaerungen.filter { !$0.erledigt }
        gruppe(String(localized: "Kündigungen und Widerrufe"),
               zahl: offene.count) {
            if erklaerungen.isEmpty {
                leerzeile(String(localized: "Nichts erklärt."))
            } else {
                ForEach(erklaerungen) { erklaerung in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(erklaerung.bezeichnung)
                                .foregroundStyle(Farben.ink)
                            Spacer()
                            if erklaerung.erledigt {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundStyle(Farben.gut)
                            }
                        }
                        Text("\(erklaerung.name) · \(erklaerung.mail)")
                            .font(.footnote)
                            .foregroundStyle(Farben.inkStill)
                        // OHNE BESTÄTIGUNG IST ES EINE OFFENE FLANKE.
                        // § 312k Abs. 4 verlangt die Bestätigung des
                        // Zugangs in Textform. Ist sie nicht rausgegangen,
                        // muss jemand von Hand nachfassen -- und das
                        // sieht man nur, wenn es dasteht.
                        if !erklaerung.bestaetigt {
                            Text("Eingangsbestätigung ging NICHT raus.")
                                .font(.caption)
                                .foregroundStyle(Farben.fehler)
                        }
                        if !erklaerung.erledigt {
                            Button {
                                Task { await erledigen(erklaerung) }
                            } label: {
                                Text("Abhaken")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Farben.akzent)
                            }
                            .padding(.top, 4)
                            .disabled(ueberblick?.darfAendern != true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // --- Kleinteile ---------------------------------------------------

    private func marke(_ zustand: String) -> Color {
        switch zustand {
        case "offen": return Farben.warnung
        case "eingelöst": return Farben.gut
        case "abgelaufen": return Farben.inkStill
        default: return Farben.akzent
        }
    }

    private func hinweis(_ text: String, zeichen: String,
                         farbe: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: zeichen).foregroundStyle(farbe)
            Text(text).foregroundStyle(Farben.ink)
            Spacer()
        }
        .font(.callout)
        .padding(14)
        .background(farbe.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 12))
    }

    private func leerzeile(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(Farben.inkStill)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Wie in `KontoAnsicht`, plus ein Abzeichen mit der Zahl.
    ///
    /// `titel` muss ÜBERSETZT hereinkommen -- ein `String` direkt in
    /// `Text(...)` geht an der Übersetzung vorbei, und der
    /// Sprachenprüfer sieht einen Satz nur hinter `Text(` oder
    /// `String(localized:`.
    private func gruppe<Inhalt: View>(
        _ titel: String, zahl: Int,
        @ViewBuilder inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(titel.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Farben.inkStill)
                if zahl > 0 {
                    Text(zahl.formatted())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Farben.aufPetrol)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Farben.warnung, in: Capsule())
                }
            }
            .padding(.bottom, 8)
            VStack(spacing: 0) { inhalt() }
                .background(Farben.flaechePanel,
                            in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Farben.linie))
        }
    }

    // --- Arbeiten -----------------------------------------------------

    private func laden() async {
        laeuft = true
        defer { laeuft = false }
        do {
            let token = try await anmeldung.gueltigesToken()
            ueberblick = try await Betrieb.ueberblick(token: token)
            antraege = try await Betrieb.schulantraege(token: token).antraege
            erklaerungen = try await Betrieb.erklaerungen(token: token)
                .erklaerungen
            fehler = nil
        } catch {
            fehler = Fehlertext.von(error)
        }
    }

    private func bestaetigen(_ antrag: Betrieb.Schulantrag) async {
        amBestaetigen = nil
        do {
            let token = try await anmeldung.gueltigesToken()
            _ = try await Betrieb.schulantragBestaetigen(
                antrag.id, grund: grund, token: token)
            await laden()
        } catch {
            fehler = Fehlertext.von(error)
        }
    }

    private func erledigen(_ erklaerung: Betrieb.Erklaerung) async {
        do {
            let token = try await anmeldung.gueltigesToken()
            _ = try await Betrieb.erklaerungErledigen(
                erklaerung.id,
                grund: String(localized: "Vertrag zugeordnet und beendet"),
                token: token)
            await laden()
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}
