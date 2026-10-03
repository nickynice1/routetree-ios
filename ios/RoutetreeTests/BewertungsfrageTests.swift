import Testing
import Foundation
@testable import Routetree

/// Wann Routetree nach einer Bewertung fragt -- und vor allem: wann nicht.
///
/// **Warum das geprüft gehört.** Eine Abfrage zur falschen Zeit ist
/// schlimmer als keine: Sie unterbricht, und die Antwort darauf ist ein
/// Stern. Die Regeln sind deshalb Zahlen in `Bewertungsfrage`, und hier
/// stehen sie noch einmal als Fälle -- wer eine Schwelle ändert, sieht
/// hier, was er damit ändert.
///
/// Jeder Fall bekommt einen EIGENEN `UserDefaults`-Bereich. Ein
/// gemeinsamer wäre ein Zähler, den der vorige Fall schon hochgesetzt
/// hat, und dann misst der Test die Reihenfolge statt der Regel.
@Suite("Bewertungsfrage")
struct BewertungsfrageTests {

    private func frischerSpeicher(_ name: String) -> UserDefaults {
        let s = UserDefaults(suiteName: "probe.bewertung.\(name)")!
        s.removePersistentDomain(forName: "probe.bewertung.\(name)")
        return s
    }

    private let tag = 86_400.0

    @Test("Ohne Erfolge wird nie gefragt")
    func ohneErfolge() {
        let s = frischerSpeicher(#function)
        #expect(Bewertungsfrage.soll(speicher: s) == false)
    }

    @Test("Zwei Erfolge reichen nicht, drei schon")
    func abDemDrittenErfolg() {
        let s = frischerSpeicher(#function)
        let start = Date()
        // Weit genug in der Vergangenheit, damit nur die Zahl zählt.
        Bewertungsfrage.merken(.gedruckt, speicher: s, jetzt: start)
        Bewertungsfrage.merken(.geuebt, speicher: s, jetzt: start)
        let spaeter = start.addingTimeInterval(5 * tag)
        #expect(Bewertungsfrage.soll(speicher: s, jetzt: spaeter) == false)

        Bewertungsfrage.merken(.eingelesen, speicher: s, jetzt: spaeter)
        #expect(Bewertungsfrage.soll(speicher: s, jetzt: spaeter) == true)
    }

    @Test("In den ersten zwei Tagen wird nicht gefragt")
    func nichtSofort() {
        let s = frischerSpeicher(#function)
        let start = Date()
        for _ in 0..<5 {
            Bewertungsfrage.merken(.gedruckt, speicher: s, jetzt: start)
        }
        // Genug Erfolge, aber zu frisch.
        #expect(Bewertungsfrage.soll(
            speicher: s, jetzt: start.addingTimeInterval(tag)) == false)
        #expect(Bewertungsfrage.soll(
            speicher: s,
            jetzt: start.addingTimeInterval(2 * tag + 60)) == true)
    }

    @Test("Der erste Erfolg setzt den Anfangszeitpunkt, nicht der Start")
    func anfangIstDerersteErfolg() {
        let s = frischerSpeicher(#function)
        // Wer die App laedt und drei Wochen liegen laesst, hat sie
        // nicht benutzt. Gezaehlt wird ab dem ersten Erfolg.
        let spaet = Date().addingTimeInterval(21 * tag)
        for _ in 0..<3 {
            Bewertungsfrage.merken(.gedruckt, speicher: s, jetzt: spaet)
        }
        #expect(Bewertungsfrage.soll(
            speicher: s, jetzt: spaet.addingTimeInterval(60)) == false)
        #expect(Bewertungsfrage.soll(
            speicher: s,
            jetzt: spaet.addingTimeInterval(3 * tag)) == true)
    }

    @Test("Nach dem Fragen ist erst einmal Ruhe")
    func nurEinmalJeFassung() {
        let s = frischerSpeicher(#function)
        let start = Date()
        for _ in 0..<3 {
            Bewertungsfrage.merken(.gedruckt, speicher: s, jetzt: start)
        }
        let reif = start.addingTimeInterval(3 * tag)
        #expect(Bewertungsfrage.soll(speicher: s, jetzt: reif) == true)

        Bewertungsfrage.gefragt(speicher: s, jetzt: reif)
        #expect(Bewertungsfrage.soll(speicher: s, jetzt: reif) == false)

        // Auch mit neuen Erfolgen nicht -- dieselbe Fassung hat schon
        // gefragt. Apple deckelt ohnehin und verschluckt den Rest STILL.
        for _ in 0..<5 {
            Bewertungsfrage.merken(.geuebt, speicher: s, jetzt: reif)
        }
        #expect(Bewertungsfrage.soll(
            speicher: s,
            jetzt: reif.addingTimeInterval(200 * tag)) == false)
    }

    @Test("Das Fragen setzt den Zähler zurück")
    func zaehlerGehtAufNull() {
        let s = frischerSpeicher(#function)
        let start = Date()
        for _ in 0..<4 {
            Bewertungsfrage.merken(.gedruckt, speicher: s, jetzt: start)
        }
        Bewertungsfrage.gefragt(speicher: s, jetzt: start)
        #expect(Bewertungsfrage.erfolge(speicher: s) == 0)
    }

    @Test("Die Schwellen sind die, die im Kopf der Datei stehen")
    func schwellenStimmen() {
        // DIE GEGENPROBE. Ohne sie bestuenden die Faelle oben auch
        // dann, wenn jemand `abErfolgen` auf 1 setzt -- sie messen
        // Verhalten, nicht Absicht.
        #expect(Bewertungsfrage.abErfolgen == 3)
        #expect(Bewertungsfrage.nachTagen == 2.0)
        #expect(Bewertungsfrage.abstandTage == 120.0)
    }
}
