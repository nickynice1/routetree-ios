// Eine Zeichnung zum Server bringen -- und wissen, wenn jemand
// schneller war.
//
// Der Server schützt einen Play mit einem Zähler: Ein `PUT` schickt die
// Fassung mit, die es gelesen hat. Stimmt sie nicht mehr, antwortet er
// mit **409** und überschreibt NICHT. Genau denselben Schutz hat der
// Editor im Browser.
//
// WARUM DAS HIER EIN EIGENES STÜCK IST. Ein 409 ist kein Fehler, sondern
// eine Nachricht: „Jemand anderes hat inzwischen gespeichert." Wer ihn
// wie einen Netzfehler behandelt, zeigt „Speichern fehlgeschlagen" und
// lässt einen Trainer dieselbe Änderung noch dreimal versuchen. Wer ihn
// wegdrückt, überschreibt die Arbeit des Kollegen.

import Foundation

/// Speichert Zeichnungen und trennt den Konflikt vom Fehler.
enum Playspeicher {

    /// Was beim Speichern herauskommt.
    enum Ergebnis {
        /// Gespeichert. Die neue Fassungsnummer kommt mit -- ohne sie
        /// wäre der nächste Speicherversuch sofort wieder ein Konflikt.
        ///
        /// **Und die Regelanmerkungen** (08.09.2026): Der Server
        /// antwortet mit dem vollständigen Play, also auch mit dem,
        /// was an der gerade gesicherten Aufstellung dem Regelwerk
        /// widerspricht. Ohne sie stünde die Regelleiste im Editor auf
        /// dem Stand des LADENS -- wer einen Spieler ins Backfield
        /// zieht und sichert, bekäme die alte Auskunft.
        case gespeichert(version: Int, anmerkungen: [Modell.Anmerkung])
        /// Jemand anderes hat inzwischen gespeichert. Die fremde Fassung
        /// kommt mit, damit die App zeigen kann, was dort steht, statt
        /// nur zu melden, dass etwas ist.
        case konflikt(fremd: Modell.PlayVoll)
        /// Der Play ist als fertig gesperrt (R6, **423**). Ein eigener
        /// Fall und kein Fehler, aus demselben Grund wie beim Konflikt:
        /// Die Antwort darauf ist nicht „nochmal versuchen", sondern
        /// „entsperren" -- und die Zeichnung bleibt dabei, wo sie ist.
        case gesperrt(von: String?)
    }

    /// Die Felder eines Plays, die nicht die Zeichnung sind (B7).
    ///
    /// **Der Server nimmt sie seit jeher entgegen** (`_play_felder`),
    /// die App schickte bis zum 02.09.2026 nur die Zeichnung. Cyell hat
    /// es am 01.09. gemeldet: „Mann will ein Play erstellen und kann die
    /// Formation, Katalogisieren auswählen, allgemeine Play Notiz
    /// erstellen."
    ///
    /// **Jedes Feld ist ein `Optional`, und das ist die ganze Logik.**
    /// Ein weggelassener Schlüssel heißt beim Server „keine Meinung" und
    /// lässt den Wert stehen; ein mitgeschickter heißt „genau das".
    /// Deshalb schickt der Editor nur, was er wirklich anzeigt, und das
    /// Umbenennen aus der Liste bleibt, wie es war.
    ///
    /// `kategorie` trägt die KENNUNG, nicht den Namen: Zwei gleichnamige
    /// Kategorien in zwei Heften ließen sich über den Namen nicht
    /// auseinanderhalten. `NSNull` löscht sie.
    struct Eigenschaften {
        var name: String?
        var nummer: Int??
        var seite: String?
        var kategorie: Int??
        var situationen: [String]?
        var hinweise: String?
        /// Wo der Ball liegt, in Yards vom linken Feldrand (R110.3).
        ///
        /// **Musste dazu**, sonst waere der Regler in der App ein
        /// Bedienelement ohne Wirkung: Der Server nimmt `los` seit
        /// jeher entgegen (`_play_felder`), die App hat es nie
        /// geschickt. Ein Play, der nicht an der Mittellinie beginnt,
        /// liess sich am Telefon nicht anlegen.
        var los: Double?
        /// Die Angriffsrichtung: 1 nach rechts, -1 nach links.
        var richtung: Int?

        /// Was davon in den Rumpf gehört. Leeres Ergebnis heißt: nichts
        /// zu ändern, und dann sieht die Anfrage aus wie vorher.
        var rumpf: [String: Any] {
            var heraus: [String: Any] = [:]
            if let name { heraus["name"] = name }
            if let seite { heraus["seite"] = seite }
            if let situationen { heraus["situationen"] = situationen }
            if let hinweise { heraus["hinweise"] = hinweise }
            if let los { heraus["los"] = los }
            if let richtung { heraus["richtung"] = richtung }
            // AUSGESCHRIEBEN UND NICHT `nummer ?? NSNull()`: Das eine
            // ist `Int?`, das andere `NSNull`, und was Swift daraus
            // macht, hängt am Zusammenhang. Auf einem Server ohne
            // Compiler ist das keine Frage, die man offen lässt --
            // zumal `SWIFT_TREAT_WARNINGS_AS_ERRORS` steht.
            if let nummer {
                if let zahl = nummer {
                    heraus["nummer"] = zahl
                } else {
                    heraus["nummer"] = NSNull()
                }
            }
            if let kategorie {
                if let kennung = kategorie {
                    heraus["kategorie"] = kennung
                } else {
                    heraus["kategorie"] = NSNull()
                }
            }
            return heraus
        }
    }

    /// Schickt eine Zeichnung zum Server.
    ///
    /// - Parameter version: Die Fassung, die geladen wurde. NICHT die
    ///   zuletzt gesehene aus einer Liste: Diese Zahl ist die Zusicherung
    ///   „ich habe genau das bearbeitet, was ich gelesen habe".
    /// - Parameter eigenschaften: Was neben der Zeichnung mitgeht.
    ///   Standardmäßig nichts, und dann ist die Anfrage Zeichen für
    ///   Zeichen dieselbe wie vor B7.
    static func sichern(play: Int, zeichnung: Zeichnung, version: Int,
                        eigenschaften: Eigenschaften = Eigenschaften(),
                        token: String) async throws -> Ergebnis {
        let daten = try JSONEncoder().encode(zeichnung)
        guard let objekt = try JSONSerialization.jsonObject(with: daten)
                as? [String: Any] else {
            throw Server.Fehler.server(
                text: String(localized:
                    "Die Zeichnung ließ sich nicht verpacken."),
                lage: 0, rumpf: nil)
        }

        var rumpf: [String: Any] = ["zeichnung": objekt, "version": version]
        rumpf.merge(eigenschaften.rumpf) { _, neu in neu }

        let anfrage = try Server.anfrage(
            "/api/v1/plays/\(play)/", methode: "PUT",
            rumpf: rumpf, token: token)

        do {
            let antwort = try await Server.hole(anfrage,
                                                als: Modell.PlayVoll.self)
            return .gespeichert(version: antwort.version,
                                anmerkungen: antwort.anmerkungen)
        } catch Server.Fehler.server(_, let lage, _) where lage == 409 {
            // Der Server hat abgelehnt, weil er die neuere Fassung hat.
            // Sie wird geholt, damit die App zeigen kann, was dort steht.
            // Schlägt auch das fehl, ist es ein echter Fehler.
            let fremd = try await Server.hole(
                Server.anfrage("/api/v1/plays/\(play)/", token: token),
                als: Modell.PlayVoll.self)
            return .konflikt(fremd: fremd)
        } catch Server.Fehler.server(_, let lage, let rumpf) where lage == 423 {
            return .gesperrt(von: Self.wer(rumpf))
        }
    }

    /// Wer den Play gesperrt hat, aus der Absage des Servers.
    ///
    /// `nil`, wenn nichts dasteht -- und dann steht in der App auch
    /// nichts. Ein erfundener Name ist schlimmer als kein Name.
    private static func wer(_ rumpf: Data?) -> String? {
        guard let rumpf,
              let objekt = try? JSONSerialization.jsonObject(with: rumpf)
                as? [String: Any] else { return nil }
        return objekt["gesperrt_von"] as? String
    }

    /// Den Play fertig melden oder wieder aufmachen (R6).
    ///
    /// EIGENE ADRESSE, nicht ein Feld im Sichern: Könnte dieselbe
    /// Anfrage schreiben UND aufschließen, hütete das Schloss nichts.
    /// Dieselbe Begründung steht auf der Serverseite bei
    /// ``_sperre_setzen``.
    static func sperre(play: Int, gesperrt: Bool,
                       token: String) async throws -> Modell.Sperrstand {
        let anfrage = try Server.anfrage(
            "/api/v1/plays/\(play)/sperre/", methode: "POST",
            rumpf: ["gesperrt": gesperrt], token: token)
        return try await Server.hole(anfrage, als: Modell.Sperrstand.self)
    }
}

/// Einen neuen Play anlegen (B3).
///
/// Getrennt vom Sichern, weil der interessante Fall ein anderer ist: Beim
/// Sichern ist es der Konflikt, beim Anlegen die **Grenze der Demo**. Ein
/// Verein in der Demo darf acht Plays je Playbook; der neunte wird mit
/// 403 abgelehnt, und in der Absage steckt der Abo-Vorschlag.
///
/// WARUM DER VORSCHLAG AN DER ABSAGE HAENGT und nicht an einer zweiten
/// Adresse: Sonst zeigte die App eine Sackgasse, und der Coach hielte die
/// Grenze fuer einen Fehler der App.
extension Playspeicher {

    enum Anlegen {
        case angelegt(Modell.PlayVoll)
        /// Die Demo ist am Ende. `text` ist der Satz des SERVERS und
        /// wird nicht in der App formuliert: Was die Demo hergibt und was
        /// ein Abo kostet, weiss der Server (A2, A3).
        ///
        /// SEIT B12 IST DER ABO-VORSCHLAG DABEI. Bis dahin trug
        /// `Server.Fehler` nur den Text, also blieb von der 403-Antwort
        /// die Haelfte liegen -- und die App zeigte eine Grenze ohne
        /// jeden Weg daran vorbei. Genau das ist eine Sackgasse, und der
        /// Coach haelt sie fuer einen Fehler der App.
        ///
        /// `nil` heisst „der Server hat keinen mitgeschickt", nicht „es
        /// gibt keinen": Dann steht der Satz allein, und das ist immer
        /// noch besser als ein Knopf, hinter dem nichts ist.
        case grenze(text: String, abo: Modell.Abo?)
    }

    /// Dasselbe MIT einer fertigen Zeichnung -- fuer den Scanner (R142).
    ///
    /// **Ein eigener Weg und kein Zusatzfeld am bestehenden.** Der
    /// Unterschied ist nicht technisch, sondern inhaltlich: `anlegen`
    /// schickt ABSICHTLICH keine Zeichnung mit, damit der Server seine
    /// Startaufstellung setzt (siehe unten). Wer dort einen optionalen
    /// Parameter anhaengte, haette eine Funktion, die je nach Aufruf
    /// das Gegenteil bedeutet -- und der naechste Leser muesste beide
    /// Faelle im Kopf behalten.
    static func anlegen(playbook: Int, name: String, zeichnung: Zeichnung,
                        token: String) async throws -> Anlegen {
        let daten = try JSONEncoder().encode(zeichnung)
        let alsObjekt = try JSONSerialization.jsonObject(with: daten)
        let anfrage = try Server.anfrage(
            "/api/v1/playbooks/\(playbook)/plays/", methode: "POST",
            rumpf: ["name": name, "data": alsObjekt], token: token)
        do {
            let (antwort, _) = try await Server.ausfuehren(anfrage)
            return .angelegt(try Server.entschluessler.decode(
                Modell.PlayVoll.self, from: antwort))
        } catch Server.Fehler.server(let text, let lage, let rumpf)
            where lage == 403 {
            return .grenze(text: text, abo: Modell.Abo.ausAbsage(rumpf))
        }
    }

    static func anlegen(playbook: Int, name: String, token: String)
        async throws -> Anlegen {
        // KEINE ZEICHNUNG MITSCHICKEN. Ein weggelassener Schluessel heisst
        // „keine Meinung", und dann setzt der Server dieselbe
        // Startaufstellung, mit der auch „Play zeichnen" im Browser
        // beginnt. Ein mitgeschicktes leeres Objekt hiesse „ausdruecklich
        // leer" und ergaebe ein Feld ohne Spieler.
        let anfrage = try Server.anfrage(
            "/api/v1/playbooks/\(playbook)/plays/", methode: "POST",
            rumpf: ["name": name], token: token)
        do {
            let (daten, _) = try await Server.ausfuehren(anfrage)
            return .angelegt(try Server.entschluessler.decode(
                Modell.PlayVoll.self, from: daten))
        } catch Server.Fehler.server(let text, let lage, let rumpf)
            where lage == 403 {
            return .grenze(text: text, abo: Modell.Abo.ausAbsage(rumpf))
        }
    }
}
