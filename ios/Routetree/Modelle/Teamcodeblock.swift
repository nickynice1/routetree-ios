import Foundation

/// Was ein Teamcode ist -- dieselbe Regel wie auf dem Server.
///
/// **Warum die App das überhaupt rechnet.** Sie könnte jede Eingabe
/// hinschicken und den Server antworten lassen. Aber ein Feld, das erst
/// nach einer Anfrage sagt „so sieht kein Code aus", macht aus einem
/// Tippfehler eine Wartezeit -- und in der Umkleide gibt es kein WLAN.
/// Also prüft die App die FORM, bevor sie fragt, und der Server bleibt
/// der einzige, der über die GÜLTIGKEIT entscheidet.
///
/// **Warum das gemessen wird und nicht behauptet.** Die Regel steht
/// damit zweimal im Projekt, und die Hälfte, die still umfällt, ist
/// diese: Wer „O" heimlich zu „0" macht oder ein unbekanntes Zeichen
/// einfach weglässt, sucht danach einen Code, den es nicht gibt. Der
/// Server sieht diese Anfrage nie, der Spieler tippt dreimal ab und
/// gibt auf. `TeamcodeProben.swift` hält deshalb fest, was der SERVER
/// aus jeder Eingabe macht, und `TeamcodeTests` vergleicht Zeichen für
/// Zeichen.
enum Teamcodeblock {

    /// Ohne 0/O und 1/I/L: Der Code wird abgetippt, und die
    /// Verwechslung wäre kein Tippfehler, sondern einer, den niemand
    /// findet.
    static let alphabet = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
    static let laenge = 12
    static let gruppe = 4

    /// Zeichen, die beim Abtippen dazwischen landen und nichts
    /// bedeuten. Sie fliegen raus -- alles andere nicht.
    static let trenner: Set<Character> = [" ", "-", "_", ".", "·", "\t", "\n"]

    /// Macht aus einer Eingabe den gespeicherten Code, oder `""`.
    ///
    /// Leer heißt „so sieht kein Code aus". Ausdrücklich NICHT
    /// gekürzt: Ein O statt der Null ergibt hier nichts und nicht einen
    /// um eine Stelle verschobenen Code.
    static func normalisieren(_ roh: String) -> String {
        let erlaubt = Set(alphabet)
        let gestrafft = String(roh.uppercased().filter { !trenner.contains($0) })
        guard gestrafft.count == laenge else { return "" }
        guard gestrafft.allSatisfy({ erlaubt.contains($0) }) else { return "" }
        return gestrafft
    }

    /// Der Code in Vierergruppen, zum Vorlesen und Abtippen.
    static func lesbar(_ code: String) -> String {
        var gruppen: [String] = []
        var rest = Substring(code)
        while !rest.isEmpty {
            gruppen.append(String(rest.prefix(gruppe)))
            rest = rest.dropFirst(gruppe)
        }
        return gruppen.joined(separator: "-")
    }

    /// Sieht das nach einem Code aus? Mehr sagt die App nicht -- ob es
    /// ihn gibt, weiß nur der Server.
    static func siehtAusWieCode(_ roh: String) -> Bool {
        !normalisieren(roh).isEmpty
    }
}
