import SwiftUI

/// Name und E-Mail-Adresse ändern (R100).
///
/// Niklas am 09.09.2026: „Kontodaten sollten änderbar sein."
///
/// **Zwei Knöpfe und nicht einer**, und das ist keine Umständlichkeit:
/// Der Name gilt sofort, die Adresse nimmt einen Umweg über einen Link.
/// Beides in einen Knopf zu legen hiesse, dass ein Namenswechsel eine
/// Bestätigungsmail auslöst -- oder dass die Adresse ohne eine gesetzt
/// wird. Das Zweite wäre die Lücke, durch die jemand mit einem
/// unbeaufsichtigten Telefon ein Konto übernimmt: neue Adresse
/// eintragen, „Passwort vergessen", fertig.
///
/// **Der Benutzername steht da und lässt sich nicht ändern.** Er hängt
/// an Einladungen, Protokolleinträgen und Kadernamen. Ihn wegzulassen
/// wäre auch falsch -- man braucht ihn zum Anmelden auf einem zweiten
/// Gerät.
struct KontodatenBlatt: View {
    @EnvironmentObject private var anmeldung: Anmeldung
    @Environment(\.dismiss) private var schliessen

    @State private var stand: Kontodaten.Stand?
    @State private var vorname = ""
    @State private var nachname = ""
    @State private var email = ""
    @State private var unterwegs = ""
    @State private var laeuft = false
    @State private var fehler: String?
    @State private var gesagt: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                Form {
                    if let fehler {
                        Text(fehler)
                            .font(.footnote)
                            .foregroundStyle(Farben.fehler)
                            .listRowBackground(Farben.flaechePanel)
                    }
                    if let gesagt {
                        Text(gesagt)
                            .font(.footnote)
                            .foregroundStyle(Farben.gut)
                            .listRowBackground(Farben.flaechePanel)
                    }

                    Section("Anmeldename") {
                        Text(stand?.benutzername ?? "…")
                            .foregroundStyle(Farben.inkStill)
                            .listRowBackground(Farben.flaechePanel)
                        Text("Der Anmeldename lässt sich nicht ändern. Er steht an Einladungen und im Kader.")
                            .font(.footnote)
                            .foregroundStyle(Farben.inkStill)
                            .listRowBackground(Farben.flaechePanel)
                    }

                    Section("Dein Name") {
                        TextField("Vorname", text: $vorname)
                            .textContentType(.givenName)
                            .listRowBackground(Farben.flaechePanel)
                        TextField("Nachname", text: $nachname)
                            .textContentType(.familyName)
                            .listRowBackground(Farben.flaechePanel)
                        Button("Namen speichern") {
                            Task { await namenSpeichern() }
                        }
                        .disabled(laeuft)
                        .listRowBackground(Farben.flaechePanel)
                    }

                    Section("E-Mail-Adresse") {
                        if let jetzt = stand?.email, !jetzt.isEmpty {
                            Text(jetzt)
                                .foregroundStyle(Farben.inkStill)
                                .listRowBackground(Farben.flaechePanel)
                        }
                        TextField("Neue E-Mail-Adresse", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .listRowBackground(Farben.flaechePanel)
                        Button("Adresse ändern") {
                            Task { await adresseAendern() }
                        }
                        .disabled(laeuft || email.isEmpty)
                        .listRowBackground(Farben.flaechePanel)
                        if unterwegs.isEmpty {
                            Text("Wir schicken einen Link an die neue Adresse. Erst er schaltet sie frei; deine bisherige bekommt einen Hinweis darüber.")
                                .font(.footnote)
                                .foregroundStyle(Farben.inkStill)
                                .listRowBackground(Farben.flaechePanel)
                        } else {
                            // OHNE DIESEN SATZ SÄHE ES AUS WIE NICHTS.
                            // Die alte Adresse steht noch oben, die neue
                            // nirgends -- und niemand wüsste, dass etwas
                            // unterwegs ist.
                            Text("An \(unterwegs) ist ein Link unterwegs. Öffne ihn, dann gilt die neue Adresse.")
                                .font(.footnote)
                                .foregroundStyle(Farben.warnung)
                                .listRowBackground(Farben.flaechePanel)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                if laeuft { ProgressView().tint(Farben.akzent) }
            }
            .navigationTitle("Kontodaten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Fertigknopf { schliessen() }
                }
            }
            .task { await laden() }
        }
    }

    private func laden() async {
        do {
            let token = try await anmeldung.gueltigesToken()
            // OHNE ÄNDERUNG FRAGEN: Ein leeres PATCH ändert nichts und
            // gibt zurück, was gilt. Eine eigene Leseadresse dafür wäre
            // eine zweite Stelle, an der dieselbe Antwort entsteht.
            let jetzt = try await Kontodaten.setzen(token: token)
            stand = jetzt
            vorname = jetzt.vorname
            nachname = jetzt.nachname
            unterwegs = jetzt.bestaetigungUnterwegs
        } catch {
            fehler = Fehlertext.von(error)
        }
    }

    private func namenSpeichern() async {
        laeuft = true
        defer { laeuft = false }
        fehler = nil
        gesagt = nil
        do {
            let token = try await anmeldung.gueltigesToken()
            stand = try await Kontodaten.setzen(
                vorname: vorname, nachname: nachname, token: token)
            gesagt = String(localized: "Gespeichert.")
        } catch {
            fehler = Fehlertext.von(error)
        }
    }

    private func adresseAendern() async {
        laeuft = true
        defer { laeuft = false }
        fehler = nil
        gesagt = nil
        do {
            let token = try await anmeldung.gueltigesToken()
            let jetzt = try await Kontodaten.setzen(email: email, token: token)
            stand = jetzt
            unterwegs = jetzt.bestaetigungUnterwegs
            email = ""
        } catch {
            fehler = Fehlertext.von(error)
        }
    }
}
