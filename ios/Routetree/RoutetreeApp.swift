import SwiftUI

@main
struct RoutetreeApp: App {
    @StateObject private var anmeldung = Anmeldung()
    /// Ob die App gerade sichtbar ist -- gebraucht für die Bedienspur
    /// (R86): Beim Weglegen wird abgeliefert, sonst fehlte genau der
    /// letzte Handgriff, und der ist oft der aufschlussreichste.
    @Environment(\.scenePhase) private var lage
    /// Beim ALLERERSTEN Start einmal nach der Sprache fragen (R31).
    ///
    /// Der Zustand kommt aus `Sprachwahl.schonGefragt` und nicht aus
    /// „ist eine Sprache gesetzt": Wer „die meines Telefons" wählt, hat
    /// GEWÄHLT und darf nicht bei jedem Start wieder gefragt werden.
    @State private var fragtNachSprache = !Sprachwahl.schonGefragt

    /// Den Bildspeicher einrichten, bevor die erste Ansicht steht.
    ///
    /// Hier und nicht in `onAppear`: `URLCache.shared` muss gesetzt
    /// sein, BEVOR die erste Anfrage läuft. Danach gesetzt, hätte die
    /// erste Ladung schon den kleinen Vorgabespeicher benutzt.
    init() {
        Bildspeicher.einrichten()
    }

    var body: some Scene {
        WindowGroup {
            Wurzel()
                .environmentObject(anmeldung)
                // DIE BEDIENSPUR (R86). Sie bleibt aus, bis jemand sie
                // im Konto einschaltet -- hier wird nur gefragt, ob
                // eingewilligt wurde, und wohin die Schritte gehören.
                .task(id: anmeldung.angemeldet) {
                    Bedienspur.anmeldung = anmeldung
                    await Bedienspur.nachfragen()
                }
                .onChange(of: lage) { _, neueLage in
                    if neueLage != .active {
                        Bedienspur.gemeinsam.abliefern()
                    }
                }
                // Als Blatt und nicht als eigener Bildschirm: Es ist
                // eine Frage, keine Station. Wer sie beantwortet hat,
                // ist da, wo er ohnehin hinwollte.
                .sheet(isPresented: $fragtNachSprache) {
                    SprachAnsicht(erstesMal: true)
                }
                // Dunkel bleibt dunkel -- dieselbe Dauerregel wie im Web,
                // und aus demselben Grund: Ein Playbook wird am
                // Spielfeldrand gelesen, nicht am Schreibtisch.
                .preferredColorScheme(.dark)
                .tint(Farben.akzent)
                // EIN STIL FÜR ALLE KNÖPFE IN WERKZEUGLEISTEN (R38).
                //
                // Niklas am 01.09.2026, über Leos Telefon: „warum sieht
                // die app bei ihm so hässlich aus also die buttons".
                // Gezählt: 51 Knöpfe in 17 Dateien stehen in einer
                // `.toolbar` und geben KEINEN Stil vor. Wo das Programm
                // nichts sagt, entscheidet das Betriebssystem -- und
                // iOS 26 legt seine gerahmten Kapseln darum, iOS 18
                // nicht. Dieselbe App sieht auf zwei Telefonen
                // verschieden aus.
                //
                // HIER UND NICHT AN 51 STELLEN. SwiftUI reicht den
                // Knopfstil durch die Umgebung weiter, und die 39
                // Stellen, die selbst einen setzen, überschreiben ihn --
                // die nächstliegende Angabe gewinnt. Der teure Weg wäre
                // gewesen, 51 Zeilen anzufassen und dabei die 52. zu
                // vergessen.
                //
                // `.plain` und nicht `.bordered`: Der Rest der App ist
                // flach, und ein Rahmen um „Fertig" ist eine Aussage
                // über Wichtigkeit, die nicht stimmt. Die Farbe kommt
                // vom `.tint` darüber.
                //
                // NACHZUSEHEN AM GERÄT. Ob die Umgebung wirklich bis in
                // die Werkzeugleiste reicht, lässt sich ohne Mac nicht
                // messen -- das ist die eine Stelle in dieser Runde, die
                // ein Mensch bestätigen muss.
                .buttonStyle(.plain)
        }
    }
}

/// Angemeldet oder nicht -- mehr entscheidet diese Ebene nicht.
struct Wurzel: View {
    @EnvironmentObject private var anmeldung: Anmeldung

    var body: some View {
        if anmeldung.angemeldet {
            // ZWEI REITER SEIT B9, und das ist kein Schmuck.
            //
            // Ein Playbook öffnet man am Spielfeldrand, eine Mannschaft
            // verwaltet man am Küchentisch. Hinge der Kader als Zweig an
            // der Playbook-Liste, führte der Weg zum nächsten Play über
            // einen Bildschirm, auf dem Zugänge widerrufen werden -- und
            // die Playbook-Liste wäre nicht mehr das erste, was die App
            // zeigt.
            //
            // Playbooks stehen deshalb links und sind der erste Reiter.
            TabView {
                PlaybookListe()
                    .tabItem { Label("Playbooks", systemImage: "book.closed") }
                MannschaftsListe()
                    .tabItem { Label("Mannschaften", systemImage: "person.3") }
            }
        } else {
            // Nicht sofort die Anmeldemaske: Wer die App aus dem Store
            // laedt, hat keinen Zugang und saehe ein Formular, das er
            // nicht ausfuellen kann. Erst sagen, was das Ding tut.
            WillkommenAnsicht()
        }
    }
}

// DIE PALETTE STAND BIS B13 HIER, als getippte Zahlen.
//
// Sie steht jetzt in `Modelle/Gestaltung.swift` und wird ERZEUGT -- aus
// `backend/static/designer/app.css` fuer die Oberflaeche und aus
// `scripts/marke.mjs` fuer das Zeichen. Getippt war sie eine Mischung
// aus beidem, und deshalb sah die App anders aus als die Website:
// Akzent #3E9DB8 statt #75BCD2, Gold #C8871F statt #E0B26A, Fehler
// #DB5C4D statt #EF7F74. Jede fuer sich stimmig, keine dieselbe.
//
// Neu erzeugen:  ./scripts/gestaltung_swift.py
