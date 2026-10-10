// ERZEUGT VON scripts/ordnen_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/ordnen.py -- dieselbe Rechnung, die
// `Playbook.reihenfolge_setzen` beim Sichern wirklich ausführt. Die
// Zahlen unten hat der SERVER gerechnet, nicht ein Mensch abgeschrieben.
//
// Neu erzeugen:  ./scripts/ordnen_swift.py
// Geprüft von:   backend/designer/test_ordnen_swift.py (Gleichstand)
//                RoutetreeTests/OrdnenTests.swift (Swift rechnet gleich)

import Foundation

enum OrdnenProben {

    /// Ein Fall: alte Plätze und Nummern in der NEUEN Reihenfolge, dazu
    /// das Ergebnis mit und ohne mitwandernde Nummern.
    struct Fall {
        let name: String
        let hinweis: String
        /// Die alten `position`-Werte, in der neuen Reihenfolge.
        let plaetze: [Int]
        /// Die alten `number`-Werte, in derselben Reihenfolge.
        /// `nil` heißt „hat keine Nummer".
        let nummern: [Int?]
        /// Erwartet ohne Mitziehen: (Platz, Nummer) je Play.
        let ohneMitziehen: [(platz: Int, nummer: Int?)]
        /// Erwartet mit Mitziehen.
        let mitMitziehen: [(platz: Int, nummer: Int?)]
    }

    static let faelle: [Fall] = [
        Fall(
            name: "umgedreht",
            hinweis: "Vier Plays, vollstaendig umgedreht. Der Normalfall.",
            plaetze: [4, 3, 2, 1],
            nummern: [4, 3, 2, 1],
            ohneMitziehen: [(platz: 1, nummer: 4), (platz: 2, nummer: 3), (platz: 3, nummer: 2), (platz: 4, nummer: 1)],
            mitMitziehen: [(platz: 1, nummer: 1), (platz: 2, nummer: 2), (platz: 3, nummer: 3), (platz: 4, nummer: 4)]),
        Fall(
            name: "einer_nach_vorn",
            hinweis: "Der letzte wandert an die Spitze, der Rest rutscht.",
            plaetze: [4, 1, 2, 3],
            nummern: [4, 1, 2, 3],
            ohneMitziehen: [(platz: 1, nummer: 4), (platz: 2, nummer: 1), (platz: 3, nummer: 2), (platz: 4, nummer: 3)],
            mitMitziehen: [(platz: 1, nummer: 1), (platz: 2, nummer: 2), (platz: 3, nummer: 3), (platz: 4, nummer: 4)]),
        Fall(
            name: "unveraendert",
            hinweis: "Nichts bewegt. Muss dieselben Zahlen zurueckgeben.",
            plaetze: [1, 2, 3],
            nummern: [1, 2, 3],
            ohneMitziehen: [(platz: 1, nummer: 1), (platz: 2, nummer: 2), (platz: 3, nummer: 3)],
            mitMitziehen: [(platz: 1, nummer: 1), (platz: 2, nummer: 2), (platz: 3, nummer: 3)]),
        Fall(
            name: "luecken_in_den_plaetzen",
            hinweis: "Plaetze 2, 5, 9 -- so sieht es nach einem gefilterten Umsortieren aus. Es entstehen NICHT 1, 2, 3.",
            plaetze: [9, 2, 5],
            nummern: [7, 3, 11],
            ohneMitziehen: [(platz: 2, nummer: 7), (platz: 5, nummer: 3), (platz: 9, nummer: 11)],
            mitMitziehen: [(platz: 2, nummer: 3), (platz: 5, nummer: 7), (platz: 9, nummer: 11)]),
        Fall(
            name: "luecken_in_den_nummern",
            hinweis: "Nummern 3, 12, 40 bleiben genau diese drei Nummern.",
            plaetze: [1, 2, 3],
            nummern: [40, 3, 12],
            ohneMitziehen: [(platz: 1, nummer: 40), (platz: 2, nummer: 3), (platz: 3, nummer: 12)],
            mitMitziehen: [(platz: 1, nummer: 3), (platz: 2, nummer: 12), (platz: 3, nummer: 40)]),
        Fall(
            name: "einer_ohne_nummer",
            hinweis: "Der mittlere hat keine. Er bekommt auch keine -- sonst entstuende eine Armbandzeile aus dem Nichts.",
            plaetze: [3, 1, 2],
            nummern: [5, nil, 2],
            ohneMitziehen: [(platz: 1, nummer: 5), (platz: 2, nummer: nil), (platz: 3, nummer: 2)],
            mitMitziehen: [(platz: 1, nummer: 2), (platz: 2, nummer: nil), (platz: 3, nummer: 5)]),
        Fall(
            name: "keiner_hat_eine_nummer",
            hinweis: "Nur Plaetze wandern. Nichts darf erfunden werden.",
            plaetze: [3, 1, 2],
            nummern: [nil, nil, nil],
            ohneMitziehen: [(platz: 1, nummer: nil), (platz: 2, nummer: nil), (platz: 3, nummer: nil)],
            mitMitziehen: [(platz: 1, nummer: nil), (platz: 2, nummer: nil), (platz: 3, nummer: nil)]),
        Fall(
            name: "nur_der_erste_hat_eine",
            hinweis: "Eine einzige Nummer im Spiel. Sie bleibt an dem Play, der sie hatte -- er ist der einzige Kandidat.",
            plaetze: [2, 1, 3],
            nummern: [nil, 8, nil],
            ohneMitziehen: [(platz: 1, nummer: nil), (platz: 2, nummer: 8), (platz: 3, nummer: nil)],
            mitMitziehen: [(platz: 1, nummer: nil), (platz: 2, nummer: 8), (platz: 3, nummer: nil)]),
        Fall(
            name: "ein_einziger_play",
            hinweis: "Der Grenzfall. Umsortieren einer Liste mit einem Element.",
            plaetze: [7],
            nummern: [7],
            ohneMitziehen: [(platz: 7, nummer: 7)],
            mitMitziehen: [(platz: 7, nummer: 7)]),
        Fall(
            name: "zwoelf_am_stueck",
            hinweis: "Ein volles Playbook, um eins nach hinten gedreht.",
            plaetze: [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
            nummern: [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
            ohneMitziehen: [(platz: 1, nummer: 12), (platz: 2, nummer: 1), (platz: 3, nummer: 2), (platz: 4, nummer: 3), (platz: 5, nummer: 4), (platz: 6, nummer: 5), (platz: 7, nummer: 6), (platz: 8, nummer: 7), (platz: 9, nummer: 8), (platz: 10, nummer: 9), (platz: 11, nummer: 10), (platz: 12, nummer: 11)],
            mitMitziehen: [(platz: 1, nummer: 1), (platz: 2, nummer: 2), (platz: 3, nummer: 3), (platz: 4, nummer: 4), (platz: 5, nummer: 5), (platz: 6, nummer: 6), (platz: 7, nummer: 7), (platz: 8, nummer: 8), (platz: 9, nummer: 9), (platz: 10, nummer: 10), (platz: 11, nummer: 11), (platz: 12, nummer: 12)]),
        Fall(
            name: "nummern_hoeher_als_plaetze",
            hinweis: "Platz und Nummer haben nichts miteinander zu tun. Wer sie verwechselt, faellt hier auf.",
            plaetze: [1, 2, 3],
            nummern: [30, 20, 10],
            ohneMitziehen: [(platz: 1, nummer: 30), (platz: 2, nummer: 20), (platz: 3, nummer: 10)],
            mitMitziehen: [(platz: 1, nummer: 10), (platz: 2, nummer: 20), (platz: 3, nummer: 30)]),
        Fall(
            name: "gemischt_mit_luecken",
            hinweis: "Der schwerste Fall: Luecken in beidem und zwei Plays ohne Nummer, verteilt.",
            plaetze: [8, 2, 5, 1, 9],
            nummern: [nil, 14, 2, nil, 9],
            ohneMitziehen: [(platz: 1, nummer: nil), (platz: 2, nummer: 14), (platz: 5, nummer: 2), (platz: 8, nummer: nil), (platz: 9, nummer: 9)],
            mitMitziehen: [(platz: 1, nummer: nil), (platz: 2, nummer: 2), (platz: 5, nummer: 9), (platz: 8, nummer: nil), (platz: 9, nummer: 14)]),
    ]
}
