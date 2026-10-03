// Das Feldformat, wie es vom Server kommt.
//
// `Feld.swift` ist erzeugt und darf deshalb nichts über JSON wissen --
// wer dort etwas hinzufügt, verliert es beim nächsten Erzeugen. Also
// steht das Lesen hier.
//
// WARUM ES ÜBERHAUPT MITKOMMT. Der Editor zeichnet selbst (B3). Ohne
// diese Angabe müsste er die Normmaße annehmen, und bei einem Playbook
// auf kleinem Feld stünde die Aufstellung fünf Yards neben der
// Seitenlinie -- ohne Fehlermeldung, weil der Server sie beim Speichern
// stillschweigend ins Feld schiebt.

import Foundation

extension Feld {

    /// Die fünf Grundmaße, so wie `_play_voll` sie schickt.
    ///
    /// Nur die fünf: Torlinien, Mitte und Gesamtlänge rechnet `Feld`
    /// daraus aus. Zwei Stellen, die dasselbe ableiten, laufen
    /// auseinander -- und dann zeigt die App eine andere Line to Gain
    /// als der Ausdruck.
    struct VomServer: Decodable {
        // DOUBLE UND NICHT INT (T8). Jedes Flagfeld ist ganze Yards
        // breit, deshalb ging `Int` jahrelang. Das Tackle-Feld ist es
        // nicht: 53⅓ Yards, im Programm 53,33 -- und `Int` daraus macht
        // 53. Ein Drittel Yard klingt nach nichts; auf dem Ausdruck
        // steht der Empfänger dann einen Drittel Yard neben der
        // Seitenlinie und auf dem Handy einen Drittel davor.
        //
        // Schlimmer noch: Ein `Int`-Decoder WIRFT bei 53.33. Ein
        // Tackle-Playbook hätte sich in der App gar nicht geöffnet, mit
        // einer Meldung über einen Typfehler.
        let spielLaenge: Double
        let endzone: Double
        let breite: Double
        let keinLauf: Double
        let rush: Double
        /// Fehlt bei jedem Flagfeld und bei zwei Tackle-Formen.
        let hashAbstand: Double?

        /// Die Namen auf der Leitung, ausgeschrieben. Nicht über eine
        /// automatische Umbenennung: `keinLauf` würde daraus
        /// `kein_lauf`, `spielLaenge` aber `spiel_laenge` -- und der
        /// Server schreibt `spiellaenge`. Solche Regeln stimmen bis auf
        /// einen Fall, und der fällt erst auf dem Gerät auf.
        enum CodingKeys: String, CodingKey {
            case spielLaenge = "spiellaenge"
            case endzone
            case breite
            case keinLauf = "kein_lauf"
            case rush
            case hashAbstand = "hash_abstand"
        }

        var alsFeld: Feld {
            Feld(spielLaenge: spielLaenge, endzone: endzone, breite: breite,
                 keinLauf: keinLauf, rush: rush, hashAbstand: hashAbstand)
        }
    }
}
