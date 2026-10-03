// Das eigene Passwort ändern (R50).
//
// Niklas am 01.09.2026: „mach auf die roadmap ob man sein passwort
// zurücksetzen kann. davon hab ich noch gar nix gesehen glaub ich." Er
// hatte recht: Im Browser gibt es beides seit langem, in der App gab es
// keines.
//
// WARUM DAS EIN NATIVES BLATT IST UND KEIN LINK IN DEN BROWSER. Die App
// hält ein Token, keine Sitzung. Wer im Browser auf `/konto/passwort/`
// landet, ist dort nicht angemeldet und müsste sich ein zweites Mal
// anmelden -- mit genau dem Passwort, das er gerade ändern will, weil
// er es nicht mehr mag.
//
// WARUM „VERGESSEN" TROTZDEM IN DEN BROWSER GEHT. Wer sein Passwort
// vergessen hat, ist nicht angemeldet. Der Weg ist eine Mail mit einem
// Link, und der führt zwangsläufig in den Browser. Das steht auf der
// Anmeldemaske, nicht hier.
//
// WAS HIER NICHT GEPRÜFT WIRD: ob das Passwort taugt. Die Regeln stehen
// in `AUTH_PASSWORD_VALIDATORS` und nirgends sonst. Eine zweite Prüfung
// in Swift liesse irgendwann eines durch, das der Server ablehnt -- und
// der Trainer bekäme eine Absage, die er sich nicht erklären kann.
// Geprüft wird hier nur, was ohne den Server feststeht: dass die beiden
// neuen Felder gleich sind.
//
// GESAGT WIRD DIE REGEL TROTZDEM (R71). Niklas am 03.09.2026, mit einem
// Kringel um „Was ein Passwort können muss, sagt der Server beim
// Speichern": Das ist eine Auskunft darüber, dass es eine Auskunft
// gibt. Der Satz selbst steht längst auf dem Server
// (`RegistrierungForm.passworthinweis()`, gelesen aus denselben
// Validatoren) und kommt mit `/api/v1/registrieren/` heraus -- ohne
// Token, denn dieselbe Auskunft braucht auch, wer noch keines hat. Er
// wird also GEHOLT und nicht abgeschrieben; eine Zahl in Swift wäre die
// zweite Wahrheit, die R71 gerade verhindern soll.

import SwiftUI

struct PasswortBlatt: View {
    let schliessen: () -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var altes = ""
    @State private var neues = ""
    @State private var wiederholung = ""
    @State private var laeuft = false
    @State private var fehler: String?
    @State private var fertig = false
    /// Der Satz des Servers (R71). `nil`, solange er nicht da ist --
    /// dann steht der Rückfall da und nicht eine leere Zeile.
    @State private var hinweis: String?
    /// Wie lang ein Passwort mindestens sein muss -- **vom Server**
    /// (R110.10). `nil`, solange die Auskunft nicht durch ist; dann
    /// steht kein Balken da statt eines, der mit einer geratenen Zahl
    /// rechnet.
    @State private var mindestlaenge: Int?

    /// Beide neuen Felder gleich und nichts leer.
    ///
    /// Die LÄNGE steht hier bewusst nicht: Sie ist eine Regel des
    /// Servers, und eine zweite Zahl in Swift wäre die zweite Wahrheit.
    private var bereit: Bool {
        !altes.isEmpty && !neues.isEmpty && neues == wiederholung && !laeuft
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                Form {
                    Section {
                        SecureField("Bisheriges Passwort", text: $altes)
                            .textContentType(.password)
                    } header: {
                        Text("Bisher")
                    }

                    Section {
                        // `.newPassword` und nicht `.password`: Erst
                        // damit bietet der Schlüsselbund ein neues an
                        // und merkt sich hinterher das richtige
                        // (WCAG 3.3.8).
                        SecureField("Neues Passwort", text: $neues)
                            .textContentType(.newPassword)
                        SecureField("Neues Passwort wiederholen",
                                    text: $wiederholung)
                            .textContentType(.newPassword)
                        // DER STAERKEBALKEN (R110.10). Kein `umfeld`:
                        // Auf diesem Blatt gibt es weder Benutzername
                        // noch Namen, und die Prüfung darauf entfällt
                        // still -- genau wie im Browser auf derselben
                        // Seite.
                        if let mindestlaenge {
                            Staerkebalken(passwort: neues,
                                          mindestlaenge: mindestlaenge)
                        }
                        if !wiederholung.isEmpty, neues != wiederholung {
                            Text("Die beiden neuen Passwörter sind nicht gleich.")
                                .font(.footnote)
                                .foregroundStyle(Farben.fehler)
                        }
                    } header: {
                        Text("Neu")
                    } footer: {
                        // ZWEI TEXTE UND KEIN ZUSAMMENGESETZTER: Der
                        // erste kommt vom Server, der zweite steht in
                        // der App. Aneinandergehängt wäre der ganze
                        // Absatz für `appsprache.py` kein Satz mehr.
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hinweis ?? String(localized:
                                "Was ein Passwort können muss, sagt der Server beim Speichern."))
                            Text("Deine Anmeldung auf diesem Gerät bleibt bestehen.")
                        }
                    }

                    if let fehler {
                        Section {
                            Text(fehler)
                                .font(.footnote)
                                .foregroundStyle(Farben.fehler)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Passwort ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        schliessen()
                    } label: {
                        // Ein X statt „Ab…" (R57).
                        Label("Abbrechen", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Fertigknopf(name: String(localized: "Ändern")) {
                        Task { await aendern() }
                    }
                        .disabled(!bereit)
                }
            }
            // EIN TEXTKNOPF UND NICHT `Fertigknopf`: In einem Alert
            // zeichnet iOS die Knöpfe selbst und nimmt vom Inhalt nur
            // den Text an. Ein Häkchen als Bild käme dort als leere
            // Zeile heraus -- R65 gilt für Werkzeugleisten, in denen
            // der Platz knapp ist, nicht für einen Alert, der die ganze
            // Breite hat.
            .alert("Passwort geändert", isPresented: $fertig) {
                Fertigknopf { schliessen() }
            } message: {
                Text("Beim nächsten Anmelden gilt das neue.")
            }
            // OHNE `try`-Behandlung mit Fehlermeldung: Wer sein Passwort
            // ändern will, soll das tun können, auch wenn diese eine
            // Auskunft nicht durchkommt. Dann steht der Rückfallsatz da,
            // und der ist wahr.
            .task {
                // EIN AUFRUF UND NICHT ZWEI. Zweimal dieselbe Auskunft
                // zu holen wäre eine Anfrage zu viel an einer Stelle,
                // an der jemand wartet.
                let auskunft = try? await Konten.auskunft()
                hinweis = auskunft?.passwortHinweis
                mindestlaenge = auskunft?.passwortMindestlaenge
            }
        }
    }

    private func aendern() async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            try await Laden(anmeldung: anmeldung)
                .passwortAendern(altes: altes, neues: neues)
            fertig = true
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            // ÜBER `Fehlertext`: Der Satz des SERVERS sagt, was nicht
            // stimmt -- zu kurz, zu häufig, dem Namen zu ähnlich, altes
            // Passwort falsch. Ein eigenes „Das hat nicht geklappt"
            // liesse jemanden dreimal dasselbe versuchen.
            fehler = Fehlertext.von(error)
        }
    }
}
