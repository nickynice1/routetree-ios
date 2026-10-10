// Der Einstieg am Handgelenk: die Hefte (R140).
//
// Niklas am 25.09.2026: „Also nach playbook dann kann man nach
// kategorien sortieren und sich seine plays einzeln anschauen."
//
// Drei Ebenen, und keine mehr. Jede Ebene, die man auf einer Uhr
// hinzufügt, ist ein Dreh am Rädchen mehr, bevor ein Trainer den Play
// sieht -- und er sieht ihn zwischen zwei Spielzügen.

import SwiftUI

struct UhrHefte: View {

    @ObservedObject var empfang: Uhrempfang

    var body: some View {
        NavigationStack {
            Group {
                if empfang.istLeer {
                    UhrLeer(empfang: empfang)
                } else {
                    liste
                }
            }
            .navigationTitle("Routetree")
        }
    }

    private var liste: some View {
        List {
            if empfang.istVeraltet {
                UhrVeraltet(empfang: empfang)
            }
            ForEach(empfang.paket.hefte) { heft in
                // R140.3: Ein Heft fuehrt nicht mehr GERADE in die
                // Kategorien, sondern erst zur Wahl -- Spielmodus oder
                // nur ansehen.
                NavigationLink {
                    UhrHeftwahl(heft: heft, empfang: empfang)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(heft.name)
                            .font(.headline)
                            .lineLimit(2)
                        Text(Spielform.zu(heft.spielform).name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                }
            }
            UhrStandzeile(stand: empfang.paket.stand)
        }
    }
}

/// Was dasteht, solange nichts angekommen ist.
///
/// **Kein leerer Bildschirm und kein drehendes Rad.** Beides lässt
/// jemanden warten, der nicht weiß, worauf. Hier steht, was zu tun ist
/// -- und zwar das, was wirklich hilft: die App auf dem Telefon
/// aufmachen.
struct UhrLeer: View {

    @ObservedObject var empfang: Uhrempfang

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "figure.american.football")
                    .font(.largeTitle)
                    .foregroundStyle(Farben.petrol)
                Text("Noch keine Plays auf der Uhr.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Öffne Routetree auf dem iPhone. Die Uhr bekommt die Hefte dann von dort.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let hinweis = empfang.hinweis {
                    Text(hinweis)
                        .font(.caption2)
                        .foregroundStyle(Farben.warnung)
                        .multilineTextAlignment(.center)
                }
                Button {
                    empfang.neuHolen()
                } label: {
                    if empfang.holtGerade {
                        ProgressView()
                    } else {
                        Text("Jetzt holen")
                    }
                }
                .disabled(empfang.holtGerade)
            }
            .padding(.horizontal, 4)
        }
    }
}

/// Die Zeile, die sagt: Das Telefon ist weiter als du.
struct UhrVeraltet: View {

    @ObservedObject var empfang: Uhrempfang

    var body: some View {
        Button {
            empfang.neuHolen()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Neuer Stand auf dem iPhone")
                        .font(.caption)
                    Text("Tippen zum Holen")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(empfang.holtGerade)
    }
}

/// Wann die Uhr zuletzt etwas bekommen hat.
///
/// **Sie steht da, auch wenn alles stimmt.** Ein Trainer, der am Platz
/// nicht weiß, ob er den Stand von heute früh oder den von letzter
/// Woche in der Hand hat, traut dem Ding nicht -- und benutzt es dann
/// nicht.
struct UhrStandzeile: View {

    let stand: Date

    /// Der Zeitpunkt als fertiger Text.
    ///
    /// **Getrennt vom Satz, und das ist kein Schönheitsgriff.** Was in
    /// einem `String(localized:)` interpoliert wird, muss beim Bauen
    /// einem Platzhalter zugeordnet werden (`%@` oder `%lld`) --
    /// `appsprache.py` tut das und rät dabei nichts, weil ein falscher
    /// Platzhalter sich nirgends zeigt ausser auf einem
    /// fremdsprachigen Telefon. Ein ganzer Ausdruck mitten im Literal
    /// wäre dort nicht zuzuordnen; ein benannter Wert ist es.
    private var zeitpunkt: String {
        stand.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        Text(stand == .distantPast
             ? String(localized: #"Noch nichts übertragen"#)
             : String(localized: "Stand: \(zeitpunkt)"))
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}


/// Spielmodus oder nur ansehen (R140.3).
///
/// **Niklas, 25.09.2026:** „wenn man ein Playbook antippt, dass man
/// die Auswahl hat Playmodus oder ein X für einfach nur Anschauen."
///
/// **Der Spielmodus steht oben und ist trotzdem nicht die Vorgabe.**
/// Er kostet eine Health-Abfrage und legt ein Training an (siehe
/// `Spielsitzung`) -- das gehoert auf dem Feld hin und an der
/// Seitenlinie nicht. Deshalb wird gefragt, statt zu raten.
///
/// **Und deshalb steht neben „nur ansehen" KEIN Kreuz**, obwohl
/// Niklas eins genannt hat: Auf watchOS heisst ein X „schliessen".
/// Ein Kreuz neben dem Spielmodus sähe aus wie Abbrechen, und wer nur
/// nachsehen will, tippt dann gar nichts an. Das Auge sagt dasselbe
/// und heisst nichts anderes.
struct UhrHeftwahl: View {

    let heft: Uhrpaket.Heft

    /// **Nur für eins gebraucht:** ob der Coaching-Schlüssel da ist.
    ///
    /// Er könnte auch direkt aus `Coachinglager` gelesen werden -- dann
    /// aber einmal beim Zeichnen und nie wieder. Der Schlüssel kommt
    /// vom Telefon, wann er kommt; mit dem Empfang hier aktualisiert
    /// sich die Zeile in dem Moment, in dem er ankommt, und der Spieler
    /// muss nicht raten, ob er zu früh getippt hat.
    @ObservedObject var empfang: Uhrempfang

    var body: some View {
        List {
            NavigationLink {
                UhrSpielmodus(heft: heft)
            } label: {
                Wahlzeile(
                    zeichen: "figure.american.football",
                    titel: String(localized: "Spielmodus"),
                    satz: String(localized:
                        "Die Uhr bleibt auf dem Play. Crown oder wischen."))
            }
            .disabled(heft.plays.isEmpty)

            // R143: Der Coach wählt, die Uhr zeigt.
            //
            // **Niklas am 01.10.2026:** „auf der uhr gibt es denn auch
            // eine möglichkeit zu starten."
            //
            // Die Zeile steht AUCH OHNE Schlüssel da, führt dann aber
            // zur Erklärung statt ins Leere. Wäre sie dann weg, suchte
            // ein Spieler, dem der Coach gesagt hat „das geht auf der
            // Uhr", nach einem Knopf, den es scheinbar nicht gibt.
            NavigationLink {
                if empfang.coachingBereit,
                   let schluessel = Coachinglager.schluessel {
                    UhrCoaching(heft: heft, schluessel: schluessel)
                } else {
                    UhrCoachingFehlt()
                }
            } label: {
                Wahlzeile(
                    zeichen: "antenna.radiowaves.left.and.right",
                    titel: String(localized: "Coaching"),
                    satz: empfang.coachingBereit
                        ? String(localized: "Der Coach ruft, die Uhr zeigt.")
                        : String(localized: "Noch nicht eingerichtet."))
            }

            NavigationLink {
                UhrKategorien(heft: heft)
            } label: {
                Wahlzeile(
                    zeichen: "eye",
                    titel: String(localized: "Nur ansehen"),
                    satz: String(localized: "Nach Kategorien sortiert."))
            }
        }
        .navigationTitle(heft.name)
    }
}

/// Was dasteht, wenn jemand Coaching antippt, ohne Schlüssel.
///
/// **Der Weg steht hier vollständig drin**, auch wenn er umständlich
/// klingt. Er IST umständlich, und zwar aus einem technischen Grund:
/// Ein iPhone erreicht über WatchConnectivity nur seine eigene
/// gekoppelte Uhr. Der Schlüssel kann deshalb nicht vom Telefon des
/// Coaches auf dieses Handgelenk springen -- er muss über das Telefon
/// des Trägers.
///
/// Wer das nicht weiß, wartet am Spielfeldrand darauf, dass „es
/// gleich kommt".
struct UhrCoachingFehlt: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundStyle(Farben.petrol)
                Text("Diese Uhr ist noch nicht angemeldet.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("1. Dein Coach meldet sie an und gibt dir den Schlüssel. 2. Du trägst ihn auf DEINEM iPhone unter Coaching ein. 3. Von dort kommt er auf die Uhr.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(Text("Coaching"))
    }
}

private struct Wahlzeile: View {

    let zeichen: String
    let titel: String
    let satz: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: zeichen)
                .font(.title3)
                .frame(width: 24)
                .foregroundStyle(Uhrfarben.fuer(.gold))
            VStack(alignment: .leading, spacing: 1) {
                Text(titel).font(.headline).lineLimit(1)
                Text(satz)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 3)
    }
}
