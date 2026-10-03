// Drucken: die Regeln, die aus einer Wahl eine Anfrage machen (B10).
//
// WARUM DAS EINE EIGENE DATEI IST -- und zwar aus demselben Grund wie
// `Zeichenblock` in B4 und `Ordnen` in B6: Es gibt keinen Mac, und eine
// Rückmeldung vom Läufer dauert eine halbe Stunde. Was in einer
// SwiftUI-Ansicht steht, lässt sich in dieser Zeit nicht messen, sondern
// nur behaupten.
//
// DIE ENTSCHEIDUNG, AN DER ALLES HÄNGT: DIE APP RECHNET DIE ADRESSE, UND
// DIE ZAHLEN KOMMEN VOM SERVER.
//
// Anders als beim Üben (B8), wo der Server gefragt wird, muss die App
// hier selbst rechnen: Sie zeigt die Auswahl, bevor irgendetwas
// gedruckt ist. „Standard, 125 × 75 mm" steht auf dem Bildschirm, und
// erst danach entsteht die Anfrage. Eine Vorschau kann keine Antwort
// liefern, weil es die Anfrage noch nicht gibt.
//
// Damit steht dieselbe Rechnung zweimal im Projekt: hier und in
// `designer/druck.py`. Der Unterschied sähe nicht falsch aus. Ein
// Armband, das 127 statt 125 Millimeter breit gedruckt wird, sieht aus
// wie ein schlecht sitzendes Armband. Zwölf Einlagen, von denen der
// Server nur acht setzt, sehen aus wie ein Bogen, der halt so voll ist.
//
// Deshalb rechnet der SERVER die Fälle, `scripts/druck_swift.py` legt
// sie als `DruckProben.swift` ab, und `DruckTests` vergleicht Zeichen
// für Zeichen. Die Zahlen selbst stehen in `Druckwahl.swift` und sind
// ebenfalls erzeugt.

import Foundation

/// Was gewählt ist, bevor gedruckt wird.
///
/// **Ein Wunsch trägt ALLE Felder, auch die, die zu seiner Art nicht
/// gehören.** Das ist Absicht: Wer zwischen Playcards und Armband hin
/// und her wechselt, soll seine Einstellungen wiederfinden. Welche davon
/// in der Anfrage landen, entscheidet `Druckwahl.ausgabe(art).felder` --
/// und die Liste ist erzeugt, kann hier also nicht abweichen.
struct Druckwunsch: Equatable {
    var art: String

    /// Playcards: Karten pro Seite.
    var proSeite: Int = Druckwahl.kartenStandard
    /// Call Sheet: Spalten.
    var spalten: Int = Druckwahl.spaltenStandard

    /// Wristcoach: die gewählte Größe, oder `Druckwahl.groesseFrei`.
    var groesse: String = Druckwahl.groesseStandard
    /// Das frei gemessene Maß. Es gilt nur, wenn `groesse` auf „frei"
    /// steht: Beides gleichzeitig zu schicken hieße, dem Server dieselbe
    /// Frage zweimal zu stellen.
    var breite: Double = Druckwahl.groessen
        .first { $0.wert == Druckwahl.groesseStandard }?.breite ?? 125
    var hoehe: Double = Druckwahl.groessen
        .first { $0.wert == Druckwahl.groesseStandard }?.hoehe ?? 75
    var kopien: Int = Druckwahl.kopienStandard
    var stil: String = Druckwahl.stilStandard
    /// Wie viele Plays auf EINE Einlage kommen (R74). `0` heißt „alle
    /// auf eine" und ist der Stand, den die App bis zum 03.09.2026 als
    /// einzigen kannte -- damals kamen bei dreißig Plays alle dreißig
    /// auf jede einzelne Einlage.
    var jeEinlage: Int = Druckwahl.jeEinlageStandard
    /// Wie sie darin stehen: im Raster oder untereinander.
    var anordnung: String = Druckwahl.anordnungStandard

    /// Playcards: was unter dem Diagramm steht (R74). Wer die Karten am
    /// Spieltag benutzt, will die Situationen; wer sie im Training
    /// verteilt, die Hinweise; wer sie an die Wand hängt, nichts davon.
    var kartenfuss: String = Druckwahl.kartenfussStandard

    /// Call Sheet: wie viele Plays je Situationsblock (R74). `0` heißt
    /// „alle" -- ein Block „Red Zone" mit dreiundzwanzig Einträgen ist
    /// am Spielfeldrand aber keine Hilfe.
    var jeBlock: Int = Druckwahl.jeBlockStandard
    /// Ob unter jedem Play ein kleines Diagramm steht.
    var diagramme: Bool = false

    /// Wie viel vom Feld im Bild steht -- an JEDER Ausgabe (R74).
    var zoom: String = Druckwahl.zoomStandard
    /// Wie kräftig gezeichnet wird -- ebenfalls an jeder Ausgabe.
    var zeichenstil: String = Druckwahl.zeichenstilStandard

    /// Bilder: die Ausgabebreite in Millimetern.
    var bildbreite: Double = Druckwahl.bildBreiteStandard

    var logo: Bool = true
    var sw: Bool = false
    /// Welche Plays. Leer heißt alle, und dann fehlt der Wert in der
    /// Adresse ganz: Für „alle" gibt es keinen.
    var seite: String = ""

    /// Die Einstellungen dieser Ausgabe, in der Reihenfolge des Servers.
    var paare: [(String, String)] {
        guard let eintrag = Druckwahl.ausgabe(art) else { return [] }
        var heraus: [(String, String)] = []
        for feld in eintrag.felder {
            switch feld {
            case "pro_seite":
                heraus.append(("pro_seite",
                               String(Druckblock.kartenZahl(proSeite))))
            case "spalten":
                heraus.append(("spalten",
                               String(Druckblock.spaltenZahl(spalten))))
            case "groesse":
                if groesse == Druckwahl.groesseFrei {
                    let gemessen = Druckblock.einlagemass(breite: breite,
                                                          hoehe: hoehe)
                    heraus.append(("breite", Druckblock.mass(gemessen.breite)))
                    heraus.append(("hoehe", Druckblock.mass(gemessen.hoehe)))
                } else {
                    heraus.append(("groesse",
                                   Druckblock.einlagemass(groesse: groesse).groesse))
                }
            case "je_einlage":
                heraus.append(("je_einlage",
                               String(Druckblock.jeEinlage(jeEinlage))))
            case "anordnung":
                heraus.append(("anordnung",
                               Druckblock.anordnung(anordnung)))
            case "kartenfuss":
                heraus.append(("kartenfuss",
                               Druckblock.kartenfuss(kartenfuss)))
            case "je_block":
                heraus.append(("je_block",
                               String(Druckblock.jeBlock(jeBlock))))
            case "diagramme":
                heraus.append(("diagramme", diagramme ? "1" : "0"))
            case "zoom":
                heraus.append(("zoom", Druckblock.zoom(zoom)))
            case "zeichenstil":
                heraus.append(("zeichenstil",
                               Druckblock.zeichenstil(zeichenstil)))
            case "kopien":
                heraus.append(("kopien", String(Druckblock.kopien(kopien))))
            case "stil":
                heraus.append(("stil", Druckblock.stil(stil)))
            case "bildbreite":
                heraus.append(("breite",
                               Druckblock.mass(Druckblock.bildbreite(bildbreite))))
            case "logo":
                heraus.append(("logo", logo ? "1" : "0"))
            case "sw":
                heraus.append(("sw", sw ? "1" : "0"))
            case "seite":
                if !seite.isEmpty { heraus.append(("seite", seite)) }
            default:
                break
            }
        }
        return heraus
    }

    /// Die Adresse, die diese Wahl beim Server anfragt.
    ///
    /// `kennung` ist das Playbook oder der Play, je nach Art. Welcher
    /// von beiden, sagt `Druckwahl.playAusgaben` und nicht der Aufrufer:
    /// Ein Playbook unter `/plays/` gibt es nicht, und der Server
    /// antwortete darauf mit „gibt es nicht" statt mit „falsche Adresse".
    func weg(kennung: Int) -> String {
        let stamm = Druckblock.istPlayAusgabe(art) ? "plays" : "playbooks"
        let basis = "/api/v1/\(stamm)/\(kennung)/druck/\(art)/"
        let teile = paare
        if teile.isEmpty { return basis }
        return basis + "?" + teile.map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")
    }

    /// Das aufgelöste Einlagemaß, für die Anzeige.
    var einlage: Druckblock.Einlagemass {
        groesse == Druckwahl.groesseFrei
            ? Druckblock.einlagemass(breite: breite, hoehe: hoehe)
            : Druckblock.einlagemass(groesse: groesse)
    }
}

/// Die Rechnungen dahinter. Ohne Ansicht, ohne Netz.
enum Druckblock {

    /// Ein aufgelöstes Einlagemaß in Millimetern.
    struct Einlagemass: Equatable {
        let breite: Double
        let hoehe: Double
        /// Wie das Maß heißt: eine Größe, oder `Druckwahl.groesseFrei`.
        let groesse: String
        let label: String
    }

    static func istPlayAusgabe(_ art: String) -> Bool {
        Druckwahl.playAusgaben.contains { $0.art == art }
    }

    /// Ob sich diese Ausgabe an einen Drucker schicken lässt.
    ///
    /// Ein Archiv voller SVG lässt sich teilen, aber nicht drucken. Ein
    /// Druckknopf daneben wäre ein toter Knopf (ADR-0007).
    static func druckbar(_ art: String) -> Bool {
        Druckwahl.ausgabe(art)?.druckbar ?? false
    }

    // --- Was der Server aus einer Zahl macht ------------------------------

    static func kartenZahl(_ zahl: Int) -> Int {
        Druckwahl.kartenZahlen.contains(zahl) ? zahl : Druckwahl.kartenStandard
    }

    /// Wie viele Karten nebeneinander stehen, bei so vielen je Seite.
    ///
    /// Aus derselben Tafel wie der Server (`druck.SPALTEN`). Gebraucht
    /// von der Druckvorschau (R55): Ohne sie müsste sie die Anordnung
    /// raten, und dann zeigte sie ein Blatt, das der Ausdruck nicht
    /// ergibt.
    static func kartenSpalten(_ proSeite: Int) -> Int {
        Druckwahl.kartenSpalten[kartenZahl(proSeite)] ?? 2
    }

    static func spaltenZahl(_ zahl: Int) -> Int {
        Druckwahl.spaltenZahlen.contains(zahl) ? zahl
            : Druckwahl.spaltenStandard
    }

    static func kopien(_ zahl: Int) -> Int {
        max(Druckwahl.kopienMin, min(Druckwahl.kopienMax, zahl))
    }

    /// Wie viele Plays wirklich auf eine Einlage kommen.
    ///
    /// AUSDRÜCKLICH EINE LISTE UND KEIN BEREICH: Zwischen 8 und 15 liegt
    /// nichts, was auf ein Armband passt, und ein Regler, der jede Zahl
    /// hergibt, verspräche eine Wahl, die der Server nicht hat -- er
    /// fällt auf die Voreinstellung zurück, ohne ein Wort dazu.
    static func jeEinlage(_ zahl: Int) -> Int {
        Druckwahl.jeEinlageZahlen.contains(zahl) ? zahl
            : Druckwahl.jeEinlageStandard
    }

    static func kartenfuss(_ wert: String) -> String {
        Druckwahl.kartenfuesse.contains { $0.wert == wert } ? wert
            : Druckwahl.kartenfussStandard
    }

    static func jeBlock(_ zahl: Int) -> Int {
        Druckwahl.jeBlockZahlen.contains(zahl) ? zahl
            : Druckwahl.jeBlockStandard
    }

    static func zoom(_ wert: String) -> String {
        Druckwahl.zooms.contains { $0.wert == wert } ? wert
            : Druckwahl.zoomStandard
    }

    static func zeichenstil(_ wert: String) -> String {
        Druckwahl.zeichenstile.contains { $0.wert == wert } ? wert
            : Druckwahl.zeichenstilStandard
    }

    static func anordnung(_ wert: String) -> String {
        Druckwahl.anordnungen.contains { $0.wert == wert } ? wert
            : Druckwahl.anordnungStandard
    }

    /// Wie viele Einlagen aus einem Heft werden.
    ///
    /// Dieselbe Rechnung wie `druck.einlagen_teilen`, nur zählt die App
    /// das Ergebnis statt es zu bauen: Die Vorschau (R55) zeigt damit,
    /// wie viele Zuschnitte auf dem Bogen stehen werden. IMMER
    /// mindestens einer, auch bei einem leeren Heft -- ein Bogen ohne
    /// jeden Zuschnitt sähe aus wie ein Fehler.
    static func einlagenZahl(plays: Int, jeEinlage zahl: Int) -> Int {
        let je = self.jeEinlage(zahl)
        if je <= 0 || plays <= 0 { return 1 }
        return Int((Double(plays) / Double(je)).rounded(.up))
    }

    /// Teilt ein Heft auf die Einlagen auf -- wie `druck.einlagen_teilen`.
    ///
    /// **Dieselbe Rechnung wie auf dem Server**, nicht eine zweite:
    /// `einlagenZahl` zählt nur, hier wird geteilt, und die Vorschau
    /// (R55) braucht die Teile selbst, um zu zeigen, WAS auf einer
    /// Einlage steht.
    ///
    /// IMMER mindestens eine Liste, auch bei einem leeren Heft -- ein
    /// Bogen ohne einen einzigen Zuschnitt sähe aus wie ein Fehler des
    /// Druckers.
    static func einlagenTeilen<T>(_ plays: [T], jeEinlage zahl: Int) -> [[T]] {
        let je = self.jeEinlage(zahl)
        if je <= 0 || plays.isEmpty { return [plays] }
        return stride(from: 0, to: plays.count, by: je).map { anfang in
            Array(plays[anfang..<min(anfang + je, plays.count)])
        }
    }

    /// Wie viele Spalten in EINER Einlage stehen.
    ///
    /// Dieselbe Regel wie `printing._wristband_liste`:
    /// „Untereinander" ist immer eine Spalte, und bis neun Posten
    /// bleibt es auch im Raster bei einer -- zwei Spalten mit je vier
    /// Zeilen sind am Handgelenk schlechter zu lesen als acht
    /// untereinander.
    ///
    /// ``posten`` sind Zeilen PLUS Gruppenköpfe. Die Vorschau kennt
    /// die Gruppen nicht und zählt die Zeilen; das verschiebt die
    /// Schwelle um die Zahl der Kategorien und ändert an der Aussage
    /// nichts -- gezeigt wird, ob eine oder zwei Spalten dastehen.
    static func einlagenSpalten(posten: Int, anordnung wert: String) -> Int {
        (self.anordnung(wert) == "spalte" || posten <= 9) ? 1 : 2
    }

    /// Millimeter in Zoll, auf ein Zwanzigstel -- wie `druck.zoll`.
    static func zoll(_ mm: Double) -> Double {
        (mm / Druckwahl.zollMm * 20).rounded() / 20
    }

    static func stil(_ wert: String) -> String {
        Druckwahl.stile.contains { $0.wert == wert } ? wert
            : Druckwahl.stilStandard
    }

    static func bildbreite(_ wert: Double) -> Double {
        zehntel(max(Druckwahl.bildBreiteMin,
                    min(Druckwahl.bildBreiteMax, wert)))
    }

    /// Auf ein Zehntel, wie der Server.
    static func zehntel(_ wert: Double) -> Double {
        (wert * 10).rounded() / 10
    }

    /// Ein Millimetermaß, wie es in der Adresszeile steht.
    ///
    /// **Ohne nachlaufende Null.** 125,0 wird `125`, 95,5 bleibt `95.5`.
    /// Für den Server sind beide Schreibweisen dasselbe Maß, für einen
    /// Vergleich zwischen App und Server nicht: `breite=125.0` gegen
    /// `breite=125` meldete einen Unterschied, den es nicht gibt, und
    /// nach dem zweiten Mal sieht niemand mehr hin.
    static func mass(_ wert: Double) -> String {
        let gerundet = zehntel(wert)
        if gerundet == gerundet.rounded() {
            return String(Int(gerundet.rounded()))
        }
        return String(format: "%.1f", gerundet)
    }

    /// Löst Größenwahl und freies Maß zu einem Maß auf.
    ///
    /// **Ein freies Maß schlägt die Größe.** Wer misst, hat recht. Und
    /// die Benennung hängt am Maß und nicht am mitgeschickten Namen: Wer
    /// die Jugendmaße von Hand eintippt, liest auf dem Bogen „Jugend"
    /// und nicht „Eigenes Maß".
    static func einlagemass(groesse: String? = nil, breite: Double? = nil,
                            hoehe: Double? = nil) -> Einlagemass {
        let vorlage = Druckwahl.groessen.first { $0.wert == (groesse ?? "") }
            ?? Druckwahl.groessen.first { $0.wert == Druckwahl.groesseStandard }
        // Ohne Vorlage gäbe es hier nichts zu rechnen. Das kann nur
        // passieren, wenn die erzeugte Liste leer ist -- dann ist die
        // Erzeugung kaputt und nicht diese Stelle.
        guard let vorlage else {
            return Einlagemass(breite: Druckwahl.breiteMin,
                               hoehe: Druckwahl.hoeheMin,
                               groesse: Druckwahl.groesseFrei,
                               label: Druckwahl.freiLabel)
        }
        let b = zehntel(max(Druckwahl.breiteMin,
                            min(Druckwahl.breiteMax, breite ?? vorlage.breite)))
        let h = zehntel(max(Druckwahl.hoeheMin,
                            min(Druckwahl.hoeheMax, hoehe ?? vorlage.hoehe)))
        for kandidat in Druckwahl.groessen
        where b == kandidat.breite && h == kandidat.hoehe {
            return Einlagemass(breite: b, hoehe: h, groesse: kandidat.wert,
                               label: kandidat.label)
        }
        return Einlagemass(breite: b, hoehe: h, groesse: Druckwahl.groesseFrei,
                           label: Druckwahl.freiLabel)
    }

    // --- Dateinamen -------------------------------------------------------

    /// Wie die Datei heißt, die dabei herauskommt.
    ///
    /// `stamm` ist der schon bereinigte Name des Hefts oder des Plays.
    static func dateiname(art: String, stamm: String) -> String {
        guard let eintrag = Druckwahl.ausgabe(art) else { return stamm }
        let teil = stamm.isEmpty ? "routetree" : stamm
        if istPlayAusgabe(art) { return "\(teil).\(eintrag.endung)" }
        return "\(teil)-\(art).\(eintrag.endung)"
    }

    /// Der Dateiname aus dem Kopf `Content-Disposition`.
    ///
    /// **Warum überhaupt der des Servers.** Er kennt den Namen des
    /// Hefts; die App kennt ihn auch, aber nur so, wie sie ihn zuletzt
    /// geladen hat. Wer ein Heft umbenennt und sofort druckt, teilt
    /// sonst eine Datei unter dem alten Namen.
    ///
    /// **Und warum er trotzdem nicht geglaubt wird.** Dieser Name wird
    /// gleich zu einem Dateipfad. Ein `filename="../geheim.pdf"` schriebe
    /// dann neben das Verzeichnis, in das er gehört. Der Server schickt
    /// so etwas nicht, aber diese Stelle ist die einzige, an der es
    /// auffiele -- und sie kostet drei Zeilen.
    static func dateinameAusKopf(_ kopf: String?) -> String? {
        guard let kopf else { return nil }
        for teil in kopf.split(separator: ";") {
            let sauber = teil.trimmingCharacters(in: .whitespaces)
            guard sauber.lowercased().hasPrefix("filename=") else { continue }
            var wert = String(sauber.dropFirst("filename=".count))
                .trimmingCharacters(in: .whitespaces)
            if wert.count >= 2, wert.hasPrefix("\""), wert.hasSuffix("\"") {
                wert = String(wert.dropFirst().dropLast())
            }
            return unbedenklich(wert)
        }
        return nil
    }

    /// Macht aus einem Namen einen, der nur eine Datei sein kann.
    ///
    /// Gibt `nil` zurück, statt still zu kürzen: Ein Name, von dem etwas
    /// weggeschnitten wurde, sieht danach richtig aus.
    static func unbedenklich(_ name: String) -> String? {
        let roh = name.trimmingCharacters(in: .whitespaces)
        guard !roh.isEmpty, roh.count <= 120 else { return nil }
        guard !roh.contains("/"), !roh.contains("\\"), !roh.contains("\0") else {
            return nil
        }
        guard roh != ".", roh != ".." else { return nil }
        return roh
    }
}
