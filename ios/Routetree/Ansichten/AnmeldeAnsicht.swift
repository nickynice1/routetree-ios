import SwiftUI

/// Anmelden, für die, die schon dabei sind.
///
/// Registriert wird woanders (`RegistrierAnsicht`), und beigetreten
/// auch (`BeitretenNeuAnsicht`) -- beides hängt an `WillkommenAnsicht`.
/// Hier steht nur der Weg dorthin: Wer ohne Konto auf einer
/// Anmeldemaske landet, soll nicht raten müssen.
struct AnmeldeAnsicht: View {
    @EnvironmentObject private var anmeldung: Anmeldung
    /// Der sichtbare Weg zurück (B2).
    ///
    /// Apple, HIG „Modality": **„Always give people an obvious way to
    /// dismiss a modal view."** Diese Maske war ein Blatt ohne
    /// Werkzeugleiste -- heraus kam man nur durch Herunterwischen, also
    /// über eine unbeschriftete Geste. Und ihr eigener Text verweist auf
    /// „den Bildschirm davor", den genau diese Geste erreicht.
    ///
    /// Es ist das ERSTE, was ein neuer Mensch von der App sieht.
    @Environment(\.dismiss) private var schliessen
    @State private var benutzername = ""
    @State private var passwort = ""
    @FocusState private var feld: Feld?

    private enum Feld { case name, passwort }

    var body: some View {
        NavigationStack {
        ZStack {
            Farben.flaeche.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Routetree")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Farben.ink)
                    Text("Playbooks für Flag und Tackle Football")
                        .font(.subheadline)
                        .foregroundStyle(Farben.inkStill)
                }

                if let fehler = anmeldung.fehler {
                    Text(fehler)
                        .font(.footnote)
                        .foregroundStyle(Farben.fehler)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Farben.fehler.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 10))
                }

                VStack(spacing: 12) {
                    TextField("Benutzername", text: $benutzername)
                        // EINE KENNUNG, DIE KEINE SPRACHE HAT (R120).
                        //
                        // Der Bilderlauf suchte das Feld bisher ueber
                        // seine BESCHRIFTUNG („Benutzername"). Das ging
                        // gut, solange die App deutsch lief -- und
                        // genau das war der Fehler: Der englische
                        // Durchgang lieferte deutsche Bilder. Seit er
                        // wirklich englisch laeuft (30.09.2026), heisst
                        // das Feld „Username" und war nicht mehr zu
                        // finden.
                        //
                        // Eine Kennung ist keine Beschriftung: Sie wird
                        // nicht uebersetzt und aendert sich nicht, wenn
                        // jemand den Text verbessert.
                        .accessibilityIdentifier("feld-benutzername")
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($feld, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { feld = .passwort }

                    SecureField("Passwort", text: $passwort)
                        .accessibilityIdentifier("feld-passwort")
                        .textContentType(.password)
                        .focused($feld, equals: .passwort)
                        .submitLabel(.go)
                        .onSubmit(anmelden)
                }
                .textFieldStyle(.plain)
                .padding(14)
                .background(Farben.flaechePanel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Farben.linie))
                .foregroundStyle(Farben.ink)

                Button(action: anmelden) {
                    HStack {
                        if anmeldung.laeuft {
                            ProgressView().tint(Paare.knopfHaupt.schrift.farbe)
                        }
                        Text(anmeldung.laeuft
                             ? String(localized: "Einen Moment")
                             : String(localized: "Anmelden"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("anmelden")
                .paarung(Paare.knopfHaupt)
                .disabled(anmeldung.laeuft || !vollstaendig)
                .opacity(vollstaendig ? 1 : 0.5)

                // SEIT B12 STIMMT DER ALTE SATZ NICHT MEHR. Hier stand
                // „Routetree ist nicht öffentlich. Zugänge vergibt dein
                // Verein." Seit A1 (21.08.) legt sich ein Verein selbst
                // an, und wer das hier las, ging von der Anmeldemaske
                // wieder weg -- mit der Auskunft, er müsse jemanden
                // fragen, den es für ihn gar nicht gibt.
                Text("""
                    Noch kein Konto? Auf dem Bildschirm davor kannst du \
                    Routetree kostenlos ausprobieren oder mit dem Teamcode \
                    deines Trainers beitreten.
                    """)
                    .font(.footnote)
                    .foregroundStyle(Farben.inkStill)

                // PASSWORT VERGESSEN (B4).
                //
                // Der Browser hat das seit jeher (`login.html`), die App
                // hatte es nicht -- und die Registrierung verspricht
                // sogar ausdrücklich „Die Adresse brauchen wir für das
                // Zurücksetzen des Passworts". Wer es auf dem Telefon
                // vergisst, kam aus der App nicht mehr heraus.
                //
                // ALS LINK IN DEN BROWSER, und das ist hier richtig: Das
                // Zurücksetzen läuft über eine Mail mit einem Link, und
                // der öffnet ohnehin den Browser. Eine eigene Maske in
                // der App führte an derselben Stelle wieder hinaus,
                // nur mit einem Schritt mehr.
                Link(destination: URL(string: "/passwort-vergessen/",
                                      relativeTo: Server.basis)!) {
                    Text("Passwort vergessen?")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Farben.akzent)
                }

                Spacer()
            }
            .padding(24)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    schliessen()
                } label: {
                    Label("Zurück", systemImage: "chevron.backward")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .toolbarBackground(Farben.flaeche, for: .navigationBar)
        }
        .onAppear { feld = .name }
    }

    private var vollstaendig: Bool {
        !benutzername.trimmingCharacters(in: .whitespaces).isEmpty
            && !passwort.isEmpty
    }

    private func anmelden() {
        guard vollstaendig else { return }
        feld = nil
        Task {
            await anmeldung.anmelden(
                benutzername: benutzername.trimmingCharacters(in: .whitespaces),
                passwort: passwort)
            if anmeldung.angemeldet { passwort = "" }
        }
    }
}
