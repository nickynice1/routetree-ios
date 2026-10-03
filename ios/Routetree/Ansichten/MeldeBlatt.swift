// Einen Spielzug melden (Apple-Richtlinie 1.2).
//
// WARUM ES DAS ÜBERHAUPT GIBT. Routetree trägt Inhalte, die Nutzer
// erstellen: Spielzüge, Aufstellungen, Namen im Kader. Apple verlangt
// dafür vier Dinge -- eine Hausordnung, einen Meldeweg, die
// Möglichkeit, jemanden auszuschliessen, und eine veröffentlichte
// Kontaktadresse. Die Verwaltung einer Mannschaft kann längst Mitglieder
// entfernen, die Adresse steht im Impressum. Dies hier ist der Meldeweg.
//
// WARUM ES NATIV IST UND KEIN LINK IN DEN BROWSER. Die App hält ein
// Token, keine Sitzung. Wer im Browser auf `/play/<id>/melden/` landet,
// ist dort nicht angemeldet -- und müsste sich anmelden, um etwas zu
// melden, das er gerade sieht. Derselbe Grund wie beim Passwortblatt.
//
// WER MELDEN DARF: jeder, der den Spielzug SIEHT. Kein Schreibrecht,
// keine Rolle, keine Bedingung. Ein Zuschauer oder ein Spieler ist
// genau der, dem eine Beleidigung auffällt und der nichts dagegen tun
// kann -- ein Meldeknopf nur für den Coach wäre keiner.
//
// DER GRUND IST PFLICHT, DER TEXT NICHT. Wer meldet, hat meist schon
// gezögert, bevor er darauf getippt hat; ein Pflichtfeld für eine
// Begründung ist die Stelle, an der er wieder abbricht. Der Gegenstand
// steht ohnehin fest, wir sehen ihn uns selbst an.
//
// UND DIE ERKLÄRUNG IST PFLICHT -- die einzige Reibung, die bleibt.
// Artikel 16 Absatz 2 Buchstabe d DSA verlangt, dass der Melder
// erklärt, seine Angaben träfen nach bestem Wissen zu. Erst eine
// Meldung mit allen Angaben aus Absatz 2 begründet die „tatsächliche
// Kenntnis" nach Absatz 3, und an der hängt, ab wann wir für den
// Inhalt haften. Ein Blatt, das dem Melder diesen Satz erspart,
// erspart ihn nicht -- es verschiebt ihn auf uns.
//
// Der Server weist eine Meldung ohne die Erklärung mit 400 ab. Der
// Schalter hier ist die Bedienung dazu, nicht die Prüfung: Die steht
// an einer Stelle, und zwar dort.

import SwiftUI

struct MeldeBlatt: View {
    /// Der Spielzug, um den es geht.
    let play: Modell.PlayKurz
    let schliessen: () -> Void

    @EnvironmentObject private var anmeldung: Anmeldung
    @State private var grund: Meldestelle.Grund = .sonst
    @State private var text = ""
    @State private var inGutemGlauben = false
    @State private var laeuft = false
    @State private var fehler: String?
    @State private var fertig = false

    /// Die Hausordnung steht offen im Netz -- ohne Anmeldung, damit sie
    /// auch der findet, der nur nachlesen will, was hier gilt.
    private var hausordnung: URL {
        URL(string: "/hausordnung/", relativeTo: Server.basis)!
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                Form {
                    Section {
                        // EINE LISTE UND KEIN AUSKLAPPER. Wer meldet,
                        // soll sehen, was es gibt, ohne erst etwas
                        // aufzumachen -- die Auswahl ist kurz genug.
                        ForEach(Meldestelle.Grund.allCases) { fall in
                            Button {
                                grund = fall
                            } label: {
                                HStack {
                                    Text(fall.beschriftung)
                                        .foregroundStyle(Farben.ink)
                                    Spacer()
                                    if grund == fall {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Farben.petrol)
                                    }
                                }
                                // DIE GANZE ZEILE IST DER KNOPF. Ohne
                                // das reagiert sie nur dort, wo sie
                                // ZEICHNET, und die Mitte zwischen Text
                                // und Haken bliebe tot -- derselbe
                                // Fehler, der am 15.09.2026 elf
                                // Bedienstellen lahmgelegt hat.
                                .contentShape(Rectangle())
                            }
                            .accessibilityIdentifier("meldegrund-\(fall.rawValue)")
                        }
                    } header: {
                        Text("Was stimmt damit nicht?")
                    }

                    Section {
                        TextEditor(text: $text)
                            .frame(minHeight: 90)
                            .accessibilityIdentifier("meldetext")
                    } header: {
                        Text("Willst du etwas dazu sagen?")
                    } footer: {
                        Text("Freiwillig. Zwei Sätze reichen.")
                    }

                    Section {
                        Toggle(isOn: $inGutemGlauben) {
                            Text("Ich erkläre, dass meine Angaben nach bestem Wissen zutreffen.")
                                .font(.footnote)
                        }
                        .accessibilityIdentifier("meldeerklaerung")
                    }

                    Section {
                        Link(destination: hausordnung) {
                            Label("Hausordnung lesen", systemImage: "checklist")
                        }
                    } footer: {
                        // DER SCHNELLERE WEG GEHÖRT DAZU. Die Verwaltung
                        // der Mannschaft kennt die Leute und kann sofort
                        // handeln; das zu verschweigen, um Meldungen
                        // einzusammeln, wäre gegen das Interesse dessen,
                        // der hier steht.
                        Text("Geht es schnell? Die Verwaltung deiner Mannschaft kann Mitglieder entfernen, Inhalte löschen und den Teamcode wechseln, ohne auf uns zu warten.")
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
            .navigationTitle("Melden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        schliessen()
                    } label: {
                        Label("Abbrechen", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Fertigknopf(name: String(localized: "Melden")) {
                        Task { await melden() }
                    }
                        .disabled(laeuft || !inGutemGlauben)
                        .accessibilityIdentifier("meldenabsenden")
                }
            }
            .alert("Angekommen", isPresented: $fertig) {
                Fertigknopf { schliessen() }
            } message: {
                Text("Ein Mensch sieht sich das an, kein Automat. Wir melden uns innerhalb von 24 Stunden; die Bestätigung des Eingangs liegt in deinem Postfach.")
            }
        }
    }

    private func melden() async {
        laeuft = true
        fehler = nil
        defer { laeuft = false }
        do {
            try await Laden(anmeldung: anmeldung)
                .playMelden(play.id, grund: grund, text: text,
                            inGutemGlauben: inGutemGlauben)
            fertig = true
        } catch Server.Fehler.abgemeldet {
            await anmeldung.abmelden()
        } catch {
            // ÜBER `Fehlertext`: Der Satz des SERVERS sagt, was nicht
            // stimmt -- etwa, dass der Grund unbekannt ist oder von
            // hier gerade zu viele Meldungen kamen.
            fehler = Fehlertext.von(error)
        }
    }
}
