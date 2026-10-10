// Der laufende Coaching-Modus auf dem Telefon des Coaches (R143).
//
// **Niklas am 01.10.2026:** „denn kann der coach einfach ins playbook
// gehen, hat dort oben rechts beim dropdown menü die möglichkeit den
// coaching modus zu starten. und denn kann zwischen playbooks switchen
// und wenn er ein play auswählt [...] denn landet der auf der uhr."
//
// ## Warum der Zustand ÜBER dem Playbook liegt
//
// „Und dann kann er zwischen Playbooks switchen" -- der Modus gehört
// also nicht zu einem Heft, sondern zur Mannschaft. Läge er in der
// Playliste, wäre er beim Wechsel weg, und der Coach müsste ihn
// mitten im Training neu starten.
//
// Deshalb eine eigene Stelle, die lange genug lebt: Sie hält, welche
// Uhren mitlaufen, wer zuletzt gerufen hat und wie viele warten.
//
// ## Was er NICHT tut: pollen
//
// Die Uhr fragt den Server; das Telefon nicht. Ein Coach, der ruft,
// weiss, was er gerufen hat -- dafür braucht es keine Abfrage. Die
// Liste der Uhren wird geholt, wenn er sie ansieht, und wenn er
// gerufen hat. Ein Dauerlauf im Hintergrund kostete Akku an einem
// Gerät, das am Spieltag vier Stunden durchhalten muss.

import Foundation

@MainActor
final class Coachingmodus: ObservableObject {

    /// Läuft gerade eine Sitzung?
    @Published private(set) var laeuft = false

    /// Für welche Mannschaft. `nil`, solange nichts läuft.
    @Published private(set) var team: Int?

    /// Alle Uhren dieser Mannschaft.
    @Published private(set) var uhren: [Coachinguhr] = []

    /// Welche davon mitlaufen.
    ///
    /// **Einzeln wählbar, so entschieden von Niklas am 01.10.2026.**
    /// Offense und Defense tragen verschiedene Uhren, und nicht jeder
    /// Ruf gilt allen.
    @Published var gewaehlt: Set<Int> = []

    /// Was zuletzt gerufen wurde -- für die Zeile unter der Liste.
    @Published private(set) var zuletzt: String?
    @Published private(set) var zuletztAm: Date?

    /// Was schiefging, als ganzer Satz.
    @Published var hinweis: String?

    /// Ob gerade eine Anfrage läuft. Hält den Knopf ruhig.
    @Published private(set) var arbeitet = false

    /// Ob die kurze Anleitung gerade offen ist.
    ///
    /// **Niklas am 07.10.2026:** „beim coaching modus starten auch
    /// kurze anleitung wie man denn ein play ansagt."
    @Published var zeigtAnleitung = false

    //: Dass dieser Mensch schon einmal einen Play gerufen hat.
    //:
    //: **Die Anleitung geht von selbst auf, solange er es nicht hat,
    //: und danach nie wieder.** Beide einfachen Loesungen sind
    //: schlechter: Jedes Mal zu zeigen nervt ab dem dritten Training,
    //: und nur beim allerersten Mal trifft genau den Fall, in dem
    //: jemand zwischen Anmelden und erstem Spieltag drei Wochen
    //: Pause hat.
    //:
    //: Der Schalter steht in `UserDefaults` und nicht auf dem Server:
    //: Er gehoert zu diesem Geraet und zu dieser Person, nicht zur
    //: Mannschaft, und er ist nichts wert, wenn er verlorengeht.
    private static let schonGerufenName = "de.routetree.coaching.gerufen"

    static var schonGerufen: Bool {
        get { UserDefaults.standard.bool(forKey: schonGerufenName) }
        set { UserDefaults.standard.set(newValue, forKey: schonGerufenName) }
    }

    /// Wie viele Uhren gerade erreichbar sind.
    var lebendig: Int { uhren.filter(\.lebt).count }

    /// Ob überhaupt gerufen werden kann.
    var bereit: Bool { laeuft && !gewaehlt.isEmpty }

    // MARK: - An und aus

    func starten(team: Int, token: String) async {
        self.team = team
        laeuft = true
        await uhrenHolen(token: token)
        // ALLE LEBENDEN SIND VORGEWAEHLT. Wer den Modus startet, will
        // rufen -- und zwar an die, die da sind. Eine leere Auswahl
        // hiesse, dass der erste Ruf ins Leere geht und der Coach
        // nicht weiss, warum.
        gewaehlt = Set(uhren.filter(\.lebt).map(\.id))
        // DIE ANLEITUNG, SOLANGE SIE GEBRAUCHT WIRD. Wer schon
        // einmal gerufen hat, weiss, wo der Knopf sitzt; ihm sie
        // trotzdem hinzulegen waere eine Tuer, die man jedes Mal
        // zumachen muss.
        zeigtAnleitung = !Coachingmodus.schonGerufen
    }

    func beenden() {
        laeuft = false
        team = nil
        uhren = []
        gewaehlt = []
        zuletzt = nil
        zuletztAm = nil
        hinweis = nil
    }

    // MARK: - Uhren

    func uhrenHolen(token: String) async {
        guard let team else { return }
        do {
            uhren = try await Coaching.uhren(team: team, token: token)
            // WEGGEFALLENE AUS DER AUSWAHL NEHMEN. Eine Uhr, die
            // abgemeldet wurde, bliebe sonst gewaehlt -- und jeder Ruf
            // an sie liefe in einen 404, den niemand sieht.
            let vorhanden = Set(uhren.map(\.id))
            gewaehlt = gewaehlt.intersection(vorhanden)
        } catch {
            hinweis = String(localized: "Die Uhren liessen sich nicht laden.")
        }
    }

    // MARK: - Rufen

    /// Jetzt sofort auf die gewählten Handgelenke.
    func rufen(play: Int, name: String, token: String) async {
        await schicken(play: play, name: name, token: token, reihen: false)
    }

    /// Hinten anstellen.
    func einreihen(play: Int, name: String, token: String) async {
        await schicken(play: play, name: name, token: token, reihen: true)
    }

    private func schicken(play: Int, name: String, token: String,
                          reihen: Bool) async {
        guard !gewaehlt.isEmpty else {
            hinweis = String(localized: "Keine Uhr ausgewählt.")
            return
        }
        arbeitet = true
        defer { arbeitet = false }

        let gescheitert = await Coaching.anAlle(
            Array(gewaehlt), play: play, token: token, einreihen: reihen)

        if gescheitert.isEmpty {
            zuletzt = name
            zuletztAm = Date()
            hinweis = nil
            // AB JETZT KANN ER ES. Der Schalter faellt erst, wenn ein
            // Ruf WIRKLICH angekommen ist -- nicht schon beim
            // Antippen. Wer dreimal auf eine tote Uhr tippt, hat es
            // nicht verstanden, und dem soll die Anleitung beim
            // naechsten Start wieder aufgehen.
            Coachingmodus.schonGerufen = true
        } else {
            // **WELCHE es nicht bekommen hat, nicht „etwas ging
            // schief".** Am Spielfeldrand ist der Unterschied
            // zwischen „eine Uhr im Funkloch" und „alle weg" die
            // ganze Auskunft.
            let namen = uhren
                .filter { gescheitert.contains($0.id) }
                .map(\.name)
                .joined(separator: ", ")
            hinweis = gescheitert.count == gewaehlt.count
                ? String(localized: "Keine Uhr hat es bekommen.")
                : String(localized: "Nicht angekommen bei: \(namen)")
            if gescheitert.count < gewaehlt.count {
                zuletzt = name
                zuletztAm = Date()
            }
        }
        await uhrenHolen(token: token)
    }
}
