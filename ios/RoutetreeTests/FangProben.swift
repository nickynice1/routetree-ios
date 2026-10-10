// ERZEUGT VON scripts/fang_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/fang.py -- dieselbe Regel, die
// `editor.js` im Browser anwendet. Die Zahlen unten hat der SERVER
// gerechnet, nicht ein Mensch abgeschrieben.
//
// Der Fang ist seit dem 27.08.2026 MAGNETISCH: Knapp an einer Marke
// rastet ein Punkt ein, weiter weg bleibt er, wo er gesetzt wurde.
// Niklas: „Punkte werden gesetzt, wo getippt wird, nicht im Raster."
//
// Neu erzeugen:  ./scripts/fang_swift.py
// Geprüft von:   backend/designer/test_fang_swift.py (Gleichstand)
//                RoutetreeTests/FangTests.swift (Swift rechnet gleich)

import Foundation

enum FangProben {

    struct Fall {
        let wert: Double
        let erwartet: Double
        let hinweis: String
    }

    struct Winkelfall {
        let nachX: Double
        let nachY: Double
        let erwartetX: Double
        let erwartetY: Double
        let hinweis: String
    }

    static let faelle: [Fall] = [
        Fall(wert: 3.0, erwartet: 3.0,
             hinweis: "Genau auf einer Marke. Muss liegen bleiben."),
        Fall(wert: 3.5, erwartet: 3.5,
             hinweis: "Auch die halben Marken sind Marken."),
        Fall(wert: 3.04, erwartet: 3.0,
             hinweis: "Knapp daneben: Der Magnet zieht."),
        Fall(wert: 2.96, erwartet: 3.0,
             hinweis: "Dasselbe von der anderen Seite."),
        Fall(wert: 3.11, erwartet: 3.0,
             hinweis: "Knapp INNERHALB der Magnetweite. Zieht noch."),
        Fall(wert: 3.14, erwartet: 3.14,
             hinweis: "Knapp AUSSERHALB. Bleibt liegen. Zusammen mit dem Fall darueber ist die Grenze damit eingekreist."),
        Fall(wert: 3.2, erwartet: 3.2,
             hinweis: "DER FALL AUS DEM AUFTRAG. Vorher wurde daraus 3,0."),
        Fall(wert: 3.25, erwartet: 3.25,
             hinweis: "Genau zwischen zwei Marken. Bleibt, wo es ist."),
        Fall(wert: 0.0, erwartet: 0.0,
             hinweis: "Der Nullpunkt darf nicht wegrutschen."),
        Fall(wert: -0.04, erwartet: 0.0,
             hinweis: "Knapp negativ: zieht auf null, nicht auf minus 0,5."),
        Fall(wert: 49.97, erwartet: 50.0,
             hinweis: "Am anderen Feldende rechnet es genauso."),
    ]

    static let winkelfaelle: [Winkelfall] = [
        Winkelfall(nachX: 5.0, nachY: 0.0,
                   erwartetX: 5.0, erwartetY: 0.0,
                   hinweis: "Ein Go laeuft gerade. Muss gerade bleiben."),
        Winkelfall(nachX: 5.0, nachY: 5.0,
                   erwartetX: 4.949747468305833, erwartetY: 4.949747468305832,
                   hinweis: "Genau 45 Grad, die Diagonale eines Slants."),
        Winkelfall(nachX: 5.0, nachY: 0.35,
                   erwartetX: 5.0, erwartetY: 0.0,
                   hinweis: "4 Grad daneben: Der Magnet zieht auf gerade."),
        Winkelfall(nachX: 5.0, nachY: 2.5,
                   erwartetX: 4.919349550499537, erwartetY: 2.4596747752497685,
                   hinweis: "27 Grad. Weit weg von jeder Marke, bleibt schraeg."),
        Winkelfall(nachX: 0.2, nachY: 0.0,
                   erwartetX: 0.0, erwartetY: 0.0,
                   hinweis: "Kuerzer als ein halber Rasterschritt: bleibt am Start."),
    ]
}
