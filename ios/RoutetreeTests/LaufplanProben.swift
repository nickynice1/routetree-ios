// ERZEUGT VON scripts/laufplan_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/static/designer/laufplan.js, ausgeführt unter
// Node -- also genau die Zahlen, mit denen der Browser abspielt.
//
// Neu erzeugen:  ./scripts/laufplan_swift.py
// Geprüft von:   backend/designer/test_laufplan_swift.py (Gleichstand)
//                RoutetreeTests/LaufplanTests.swift (Nachrechnen)

import Foundation

enum LaufplanProben {

    /// Ein Fall: die Linien als JSON und die Zeitachse, die der Browser
    /// dazu rechnet.
    struct Fall {
        let schluessel: String
        let linien: String
        let erwartet: String
    }

    /// Drei Routen ohne Motion: alle starten nach dem Snap.
    static let nurRouten = Fall(
        schluessel: "nurRouten",
        linien: #"[{"kind":"route","player":"o_x","points":[{"x":35,"y":5},{"x":45,"y":5}]},{"kind":"route","player":"o_y","points":[{"x":35,"y":20},{"x":40,"y":15},{"x":45,"y":15}]},{"kind":"route","player":"o_z","points":[{"x":35,"y":5},{"x":45,"y":5}]}]"#,
        erwartet: #"{"eintraege":[{"ende":2160,"kind":"route","start":260,"vorSnap":false},{"ende":2160,"kind":"route","start":260,"vorSnap":false},{"ende":2160,"kind":"route","start":260,"vorSnap":false}],"gesamt":2160,"hatMotion":false,"nachlauf":550,"routenStart":260,"snapZeit":0}"#)

    /// Eine Motion vor dem Snap schiebt alles andere nach hinten.
    static let mitMotion = Fall(
        schluessel: "mitMotion",
        linien: #"[{"kind":"motion","player":"o_z","points":[{"x":35,"y":5},{"x":45,"y":5}]},{"kind":"route","player":"o_x","points":[{"x":35,"y":20},{"x":40,"y":15},{"x":45,"y":15}]}]"#,
        erwartet: #"{"eintraege":[{"ende":900,"kind":"motion","start":0,"vorSnap":true},{"ende":3060,"kind":"route","start":1160,"vorSnap":false}],"gesamt":3060,"hatMotion":true,"nachlauf":550,"routenStart":1160,"snapZeit":900}"#)

    /// Die Motion-Phase dauert, bis der LETZTE Motion-Läufer durch ist.
    static let motionMitVerzug = Fall(
        schluessel: "motionMitVerzug",
        linien: #"[{"delay":0.4,"kind":"motion","player":"o_z","points":[{"x":35,"y":5},{"x":45,"y":5}]},{"kind":"motion","player":"o_y","points":[{"x":35,"y":20},{"x":40,"y":15},{"x":45,"y":15}]},{"kind":"route","player":"o_x","points":[{"x":35,"y":5},{"x":45,"y":5}]}]"#,
        erwartet: #"{"eintraege":[{"ende":1300,"kind":"motion","start":400,"vorSnap":true},{"ende":900,"kind":"motion","start":0,"vorSnap":true},{"ende":3460,"kind":"route","start":1560,"vorSnap":false}],"gesamt":3460,"hatMotion":true,"nachlauf":550,"routenStart":1560,"snapZeit":1300}"#)

    /// Halbes Tempo verdoppelt die Motion und damit den Snap.
    static let langsameMotion = Fall(
        schluessel: "langsameMotion",
        linien: #"[{"kind":"motion","player":"o_z","points":[{"x":35,"y":5},{"x":45,"y":5}],"speed":0.5},{"kind":"route","player":"o_x","points":[{"x":35,"y":5},{"x":45,"y":5}]}]"#,
        erwartet: #"{"eintraege":[{"ende":1800,"kind":"motion","start":0,"vorSnap":true},{"ende":3960,"kind":"route","start":2060,"vorSnap":false}],"gesamt":3960,"hatMotion":true,"nachlauf":550,"routenStart":2060,"snapZeit":1800}"#)

    /// Zwei Receiver kreuzen nacheinander, nicht gleichzeitig.
    static let verzugAufRouten = Fall(
        schluessel: "verzugAufRouten",
        linien: #"[{"delay":0.0,"kind":"route","player":"o_x","points":[{"x":35,"y":5},{"x":45,"y":5}]},{"delay":0.6,"kind":"route","player":"o_z","points":[{"x":35,"y":20},{"x":40,"y":15},{"x":45,"y":15}]}]"#,
        erwartet: #"{"eintraege":[{"ende":2160,"kind":"route","start":260,"vorSnap":false},{"ende":2760,"kind":"route","start":860,"vorSnap":false}],"gesamt":2760,"hatMotion":false,"nachlauf":550,"routenStart":260,"snapZeit":0}"#)

    /// Tempo streckt und staucht die Dauer, nicht den Start.
    static let tempoJeLinie = Fall(
        schluessel: "tempoJeLinie",
        linien: #"[{"kind":"route","player":"o_x","points":[{"x":35,"y":5},{"x":45,"y":5}],"speed":2.0},{"kind":"route","player":"o_y","points":[{"x":35,"y":20},{"x":40,"y":15},{"x":45,"y":15}],"speed":0.5},{"kind":"route","player":"o_z","points":[{"x":35,"y":5},{"x":45,"y":5}],"speed":1.0}]"#,
        erwartet: #"{"eintraege":[{"ende":1210,"kind":"route","start":260,"vorSnap":false},{"ende":4060,"kind":"route","start":260,"vorSnap":false},{"ende":2160,"kind":"route","start":260,"vorSnap":false}],"gesamt":4060,"hatMotion":false,"nachlauf":550,"routenStart":260,"snapZeit":0}"#)

    /// Eine Zone steht, sie läuft nicht -- sie kommt gar nicht vor.
    static let zoneLaeuftNicht = Fall(
        schluessel: "zoneLaeuftNicht",
        linien: #"[{"kind":"zone","player":null,"points":[{"x":35,"y":5},{"x":45,"y":5},{"x":45,"y":15}]},{"kind":"route","player":"o_x","points":[{"x":35,"y":5},{"x":45,"y":5}]}]"#,
        erwartet: #"{"eintraege":[{"ende":2160,"kind":"route","start":260,"vorSnap":false}],"gesamt":2160,"hatMotion":false,"nachlauf":550,"routenStart":260,"snapZeit":0}"#)

    /// Ein Play, in dem nichts läuft: keine Einträge, keine Dauer.
    static let nurEineZone = Fall(
        schluessel: "nurEineZone",
        linien: #"[{"kind":"zone","player":null,"points":[{"x":35,"y":5},{"x":45,"y":5},{"x":45,"y":15}]}]"#,
        erwartet: #"{"eintraege":[],"gesamt":0,"hatMotion":false,"nachlauf":550,"routenStart":260,"snapZeit":0}"#)

    /// Gar keine Linien. Der Ablauf ist null lang und stürzt nicht ab.
    static let leer = Fall(
        schluessel: "leer",
        linien: #"[]"#,
        erwartet: #"{"eintraege":[],"gesamt":0,"hatMotion":false,"nachlauf":550,"routenStart":260,"snapZeit":0}"#)

    /// Abgabe und Pass laufen wie Routen, nur trägt sie der Ball.
    static let ballwege = Fall(
        schluessel: "ballwege",
        linien: #"[{"kind":"handoff","player":"o_qb","points":[{"x":35,"y":5},{"x":45,"y":5}]},{"delay":1.2,"kind":"pass","player":"o_qb","points":[{"x":35,"y":20},{"x":40,"y":15},{"x":45,"y":15}]}]"#,
        erwartet: #"{"eintraege":[{"ende":2160,"kind":"handoff","start":260,"vorSnap":false},{"ende":3360,"kind":"pass","start":1460,"vorSnap":false}],"gesamt":3360,"hatMotion":false,"nachlauf":550,"routenStart":260,"snapZeit":0}"#)

    /// Verzug unter null und Tempo null fallen auf die Vorgaben zurück.
    static let unsinnigeAngaben = Fall(
        schluessel: "unsinnigeAngaben",
        linien: #"[{"delay":-1.0,"kind":"route","player":"o_x","points":[{"x":35,"y":5},{"x":45,"y":5}],"speed":0.0},{"delay":0.0,"kind":"motion","player":"o_z","points":[{"x":35,"y":20},{"x":40,"y":15},{"x":45,"y":15}],"speed":-2.0}]"#,
        erwartet: #"{"eintraege":[{"ende":3060,"kind":"route","start":1160,"vorSnap":false},{"ende":900,"kind":"motion","start":0,"vorSnap":true}],"gesamt":3060,"hatMotion":true,"nachlauf":550,"routenStart":1160,"snapZeit":900}"#)

    /// Motion mit Verzug, Block, Pass und drei Routen mit Tempo.
    static let allesZusammen = Fall(
        schluessel: "allesZusammen",
        linien: #"[{"delay":0.3,"kind":"motion","player":"o_z","points":[{"x":35,"y":5},{"x":45,"y":5}],"speed":1.5},{"kind":"block","player":"o_c","points":[{"x":35,"y":5},{"x":45,"y":5}]},{"delay":0.2,"kind":"route","player":"o_x","points":[{"x":35,"y":20},{"x":40,"y":15},{"x":45,"y":15}],"speed":0.75},{"kind":"route","player":"o_y","points":[{"x":35,"y":5},{"x":45,"y":5}],"speed":2.0},{"delay":0.9,"kind":"pass","player":"o_qb","points":[{"x":35,"y":20},{"x":40,"y":15},{"x":45,"y":15}]},{"kind":"zone","player":null,"points":[{"x":35,"y":5},{"x":45,"y":5},{"x":45,"y":15}]}]"#,
        erwartet: #"{"eintraege":[{"ende":900,"kind":"motion","start":300,"vorSnap":true},{"ende":3060,"kind":"block","start":1160,"vorSnap":false},{"ende":3893.3333333333335,"kind":"route","start":1360,"vorSnap":false},{"ende":2110,"kind":"route","start":1160,"vorSnap":false},{"ende":3960,"kind":"pass","start":2060,"vorSnap":false}],"gesamt":3960,"hatMotion":true,"nachlauf":550,"routenStart":1160,"snapZeit":900}"#)

    /// Alle Fälle, für den Durchlauf im Test.
    static let alle: [Fall] = [
        nurRouten,
        mitMotion,
        motionMitVerzug,
        langsameMotion,
        verzugAufRouten,
        tempoJeLinie,
        zoneLaeuftNicht,
        nurEineZone,
        leer,
        ballwege,
        unsinnigeAngaben,
        allesZusammen
    ]
}
