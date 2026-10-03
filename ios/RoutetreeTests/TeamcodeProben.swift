// ERZEUGT VON scripts/teamcode_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/teamcode.py. Was hier steht, hat der
// SERVER gerechnet: Aus dieser Eingabe wird genau dieser Code.
//
// Der wunde Punkt sind die drei Fälle am Ende: ein O statt der Null,
// eine Stelle zu wenig, ein Zeichen zu viel. Alle drei ergeben einen
// LEEREN Code -- und nicht etwa einen um eine Stelle verschobenen. Eine
// App, die hier still kürzt, schickt eine Anfrage, die der Server nie
// finden kann, und sagt dem Spieler „gibt es nicht".
//
// Neu erzeugen:  ./scripts/teamcode_swift.py
// Geprüft von:   backend/designer/test_teamcode_swift.py (Gleichstand)
//                RoutetreeTests/TeamcodeTests.swift (Swift rechnet gleich)

import Foundation

enum TeamcodeProben {

    /// Eine Eingabe und das, was der Server daraus macht.
    /// `ergibt` leer heißt „so sieht kein Code aus".
    struct Fall {
        let eingabe: String
        let ergibt: String
        /// Der Code in Vierergruppen. Leer, wenn `ergibt` leer ist.
        let lesbar: String
    }

    static let faelle: [Fall] = [
        Fall(eingabe: "P7QK3MRW9XTB", ergibt: "P7QK3MRW9XTB", lesbar: "P7QK-3MRW-9XTB"),
        Fall(eingabe: "p7qk3mrw9xtb", ergibt: "P7QK3MRW9XTB", lesbar: "P7QK-3MRW-9XTB"),
        Fall(eingabe: "P7QK-3MRW-9XTB", ergibt: "P7QK3MRW9XTB", lesbar: "P7QK-3MRW-9XTB"),
        Fall(eingabe: "p7qk 3mrw 9xtb", ergibt: "P7QK3MRW9XTB", lesbar: "P7QK-3MRW-9XTB"),
        Fall(eingabe: "  P7QK-3MRW-9XTB  ", ergibt: "P7QK3MRW9XTB", lesbar: "P7QK-3MRW-9XTB"),
        Fall(eingabe: "P7QK·3MRW·9XTB", ergibt: "P7QK3MRW9XTB", lesbar: "P7QK-3MRW-9XTB"),
        Fall(eingabe: "P7QK_3MRW_9XTB", ergibt: "P7QK3MRW9XTB", lesbar: "P7QK-3MRW-9XTB"),
        Fall(eingabe: "P7QK.3MRW.9XTB", ergibt: "P7QK3MRW9XTB", lesbar: "P7QK-3MRW-9XTB"),
        Fall(eingabe: "O7QK3MRW9XTB", ergibt: "", lesbar: ""),
        Fall(eingabe: "P7QK3MRW9XT", ergibt: "", lesbar: ""),
        Fall(eingabe: "P7QK3MRW9XTBB", ergibt: "", lesbar: ""),
        Fall(eingabe: "P7QK3MRW9XT!", ergibt: "", lesbar: ""),
        Fall(eingabe: "", ergibt: "", lesbar: ""),
        Fall(eingabe: "----", ergibt: "", lesbar: ""),
    ]

    /// Haltbarkeit und die Minuten dahinter. `nil` heißt unbegrenzt.
    /// Die letzten beiden Zeilen sind Unsinn und Leere -- sie fallen auf
    /// die Voreinstellung zurück.
    static let spannen: [(wert: String, minuten: Int?)] = [
        ("10min", 10),
        ("1h", 60),
        ("12h", 720),
        ("24h", 1440),
        ("48h", 2880),
        ("7t", 10080),
        ("1monat", 43200),
        ("1jahr", 525600),
        ("unbegrenzt", nil),
        ("hundert-jahre", 1440),
        ("", 1440),
    ]

    static let alphabet = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
    static let laenge = 12
    static let vorgabe = "24h"
}
