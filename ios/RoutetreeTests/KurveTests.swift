import SwiftUI
import XCTest
@testable import Routetree

/// Biegt die App eine Route so wie der Ausdruck?
///
/// `Kurve.stuetzen` ist die dritte Fassung derselben Rechnung: Die erste
/// steht in `backend/designer/render.py` (`_catmull_rom_to_bezier`), die
/// zweite in `backend/static/designer/editor.js` (`bezierStuetzen`). Die
/// erwarteten Werte in `KurveProben` hat Python ausgerechnet; hier
/// werden dieselben Fälle in Swift nachgerechnet.
///
/// **Der Fall, für den es gebaut wurde** (R7/R12, 25.08.2026). Bis dahin
/// hatte die App eine EIGENE, einfachere Rechnung: eine Kette
/// quadratischer Bögen durch die Mittelpunkte. Sie ging durch dieselben
/// Stützpunkte und sah auf den ersten Blick richtig aus -- dazwischen
/// lief sie anders. Bei einer Wheel Route ist genau das Dazwischen die
/// Route.
final class KurveTests: XCTestCase {

    /// Die Rechnung läuft in Bildeinheiten, in denen ein Yard etliche
    /// Punkte groß ist. Was hier verglichen wird, sind aber die rohen
    /// Zahlen aus Python, und die sollen bis auf Rundung stimmen.
    ///
    /// **Warum nicht 1e-9, wie es hier bis zum 28.08.2026 stand.**
    /// Die Punkte kommen aus einem SwiftUI-`Path` zurück, und der hält
    /// sie intern in EINFACHER Genauigkeit. Python rechnet in
    /// doppelter. Der Unterschied liegt bei etwa 2e-8 -- und wo Python
    /// `0.8333333333333333` sagt, kommt `0.8333333134651184` zurück.
    /// Das ist keine falsche Rechnung, sondern eine Zahl mit weniger
    /// Stellen.
    ///
    /// 1e-5 Bildeinheiten sind bei rund 20 Punkten je Yard ein
    /// Zweimillionstel Yard. Ein Fehler, der DAS überschreitet, ist
    /// keine Rundung mehr, sondern eine andere Formel -- und genau die
    /// soll diese Prüfung finden.
    private let genauigkeit = 1e-5

    func test_alpha_ist_die_zahl_aus_python() {
        XCTAssertEqual(Kurve.alpha, KurveProben.alpha,
                       "Die zentripetale Parametrisierung ist weggelaufen")
    }

    func test_stuetzpunkte_wie_python() {
        for (i, probe) in KurveProben.stuetzen.enumerated() {
            let (p0, p1, p2, p3, b1Soll, b2Soll) = probe
            let (b1, b2) = Kurve.stuetzen(p0, p1, p2, p3)
            XCTAssertEqual(Double(b1.x), Double(b1Soll.x), accuracy: genauigkeit,
                           "Probe \(i): b1.x weicht von Python ab")
            XCTAssertEqual(Double(b1.y), Double(b1Soll.y), accuracy: genauigkeit,
                           "Probe \(i): b1.y weicht von Python ab")
            XCTAssertEqual(Double(b2.x), Double(b2Soll.x), accuracy: genauigkeit,
                           "Probe \(i): b2.x weicht von Python ab")
            XCTAssertEqual(Double(b2.y), Double(b2Soll.y), accuracy: genauigkeit,
                           "Probe \(i): b2.y weicht von Python ab")
        }
    }

    /// Ohne diese Probe wäre der Test oben zufrieden, wenn `KurveProben`
    /// leer wäre -- eine Schleife über nichts läuft grün durch.
    func test_es_gibt_ueberhaupt_proben() {
        XCTAssertGreaterThan(KurveProben.stuetzen.count, 10,
                             "Die Proben sind weg oder wurden nicht erzeugt")
    }

    // MARK: - Der Pfad

    func test_zwei_punkte_bleiben_eine_gerade() {
        // Durch zwei Punkte geht genau eine Gerade. `render.py` und
        // `editor.js` entscheiden an derselben Stelle genauso -- ein
        // Bogen wäre hier eine Erfindung.
        let punkte = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)]
        XCTAssertEqual(Kurve.pfad(punkte, weich: true),
                       Kurve.pfad(punkte, weich: false),
                       "Bei zwei Punkten darf sich nichts unterscheiden")
    }

    func test_eckig_und_weich_sind_nicht_dasselbe() {
        // Die Sabotageprobe zur vorigen: Ab drei Punkten MUSS sich etwas
        // unterscheiden, sonst rundet der Schalter nichts.
        let punkte = [CGPoint(x: 0, y: 0), CGPoint(x: 6, y: 0),
                      CGPoint(x: 10, y: 4)]
        XCTAssertNotEqual(Kurve.pfad(punkte, weich: true),
                          Kurve.pfad(punkte, weich: false),
                          "Der Kurvenschalter ändert nichts am Pfad")
    }

    func test_der_pfad_geht_durch_die_stuetzpunkte() {
        // Catmull-Rom interpoliert: Die Kurve LIEGT auf den Punkten, sie
        // nähert sie nicht an. Das war der Unterschied zur alten
        // Mittelpunkt-Rechnung, und daran hängt, dass eine Route dort
        // ankommt, wo der Trainer sie hingezogen hat.
        let punkte = [CGPoint(x: 0, y: 0), CGPoint(x: 6, y: 0),
                      CGPoint(x: 10, y: 4), CGPoint(x: 11, y: 14)]
        let kasten = Kurve.pfad(punkte, weich: true).boundingRect
        for punkt in punkte {
            XCTAssertTrue(kasten.insetBy(dx: -0.001, dy: -0.001).contains(punkt),
                          "\(punkt) liegt nicht auf dem Pfad")
        }
    }

    func test_leere_punkte_geben_einen_leeren_pfad() {
        XCTAssertTrue(Kurve.pfad([], weich: true).isEmpty)
    }

    func test_eine_zone_ist_geschlossen() {
        let punkte = [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 0),
                      CGPoint(x: 5, y: 5)]
        XCTAssertNotEqual(Kurve.pfad(punkte, weich: false, geschlossen: false),
                          Kurve.pfad(punkte, weich: false, geschlossen: true),
                          "Eine Zone muss sich schließen")
    }

    // MARK: - Der Ring (R8)

    /// Zerlegt einen Pfad in seine Segmente.
    ///
    /// `Path.forEach` ist die einzige ehrliche Art, das zu messen: Ein
    /// Vergleich zweier `Path`-Werte sagt nur „gleich oder nicht", und
    /// genau daran ist bei R8 nichts abzulesen -- die Frage ist, WELCHE
    /// Stützpunkte am ersten und am letzten Segment stehen.
    private func segmente(_ pfad: Path)
    -> (kurven: [(CGPoint, CGPoint, CGPoint)],
        geraden: Int, geschlossen: Bool) {
        var kurven: [(CGPoint, CGPoint, CGPoint)] = []
        var geraden = 0
        var geschlossen = false
        pfad.forEach { element in
            switch element {
            case let .curve(to, control1, control2):
                kurven.append((control1, control2, to))
            case .line:
                geraden += 1
            case .closeSubpath:
                geschlossen = true
            default:
                break
            }
        }
        return (kurven, geraden, geschlossen)
    }

    func test_ein_runder_ring_rechnet_ringsum_wie_python() {
        for probe in KurveProben.ringe {
            let teile = segmente(Kurve.pfad(probe.ecken, weich: true,
                                            geschlossen: true))
            XCTAssertTrue(teile.geschlossen,
                          "\(probe.name): der Ring schließt sich nicht")
            XCTAssertEqual(
                teile.kurven.count, probe.segmente.count,
                "\(probe.name): ein Ring hat so viele Segmente wie Ecken")
            for (i, soll) in probe.segmente.enumerated() where i < teile.kurven.count {
                let ist = teile.kurven[i]
                XCTAssertEqual(Double(ist.0.x), Double(soll.0.x),
                               accuracy: genauigkeit,
                               "\(probe.name), Segment \(i): b1.x")
                XCTAssertEqual(Double(ist.0.y), Double(soll.0.y),
                               accuracy: genauigkeit,
                               "\(probe.name), Segment \(i): b1.y")
                XCTAssertEqual(Double(ist.1.x), Double(soll.1.x),
                               accuracy: genauigkeit,
                               "\(probe.name), Segment \(i): b2.x")
                XCTAssertEqual(Double(ist.1.y), Double(soll.1.y),
                               accuracy: genauigkeit,
                               "\(probe.name), Segment \(i): b2.y")
                XCTAssertEqual(Double(ist.2.x), Double(soll.2.x),
                               accuracy: genauigkeit,
                               "\(probe.name), Segment \(i): Ziel x")
                XCTAssertEqual(Double(ist.2.y), Double(soll.2.y),
                               accuracy: genauigkeit,
                               "\(probe.name), Segment \(i): Ziel y")
            }
        }
    }

    func test_es_gibt_ueberhaupt_ringproben() {
        XCTAssertGreaterThanOrEqual(KurveProben.ringe.count, 3,
                                    "Die Ringproben sind weg oder wurden "
                                    + "nicht erzeugt")
    }

    /// DER FALL, UM DEN ES BEI R8 GEHT.
    ///
    /// Ein Ring hat ein Segment MEHR als ein Weg durch dieselben Punkte:
    /// die Rückkehr zur ersten Ecke. Wer sie als Gerade schließt, hat
    /// eine Zone mit einer platten Seite.
    func test_der_ring_hat_ein_segment_mehr_als_der_weg() {
        let ecken = [CGPoint(x: -5, y: 0), CGPoint(x: 0, y: -5),
                     CGPoint(x: 5, y: 0), CGPoint(x: 0, y: 5)]
        let ring = segmente(Kurve.pfad(ecken, weich: true, geschlossen: true))
        let weg = segmente(Kurve.pfad(ecken, weich: true, geschlossen: false))
        XCTAssertEqual(ring.kurven.count, weg.kurven.count + 1,
                       "Die Rückkehr zur ersten Ecke fehlt")
        XCTAssertEqual(ring.geraden, 0,
                       "Ein runder Ring darf keine gerade Kante haben")
    }

    /// Und die zweite Hälfte: Auch das ERSTE Segment muss anders
    /// aussehen. Bis R8 wurde am Rand gespiegelt -- damit war die erste
    /// Ecke ein Knick, während die dazwischen rund waren.
    func test_der_ring_spiegelt_die_erste_ecke_nicht() {
        let ecken = [CGPoint(x: -5, y: 0), CGPoint(x: 0, y: -5),
                     CGPoint(x: 5, y: 0), CGPoint(x: 0, y: 5)]
        let ring = segmente(Kurve.pfad(ecken, weich: true, geschlossen: true))
        let weg = segmente(Kurve.pfad(ecken, weich: true, geschlossen: false))
        XCTAssertNotEqual(ring.kurven[0].0, weg.kurven[0].0,
                          "Der Ring nimmt am ersten Segment dieselben "
                          + "Stützpunkte wie ein Weg -- er spiegelt also "
                          + "noch immer den Rand")
    }

    func test_eine_eckige_zone_bleibt_eckig() {
        let ecken = [CGPoint(x: 0, y: 0), CGPoint(x: 6, y: 0),
                     CGPoint(x: 3, y: 5)]
        let teile = segmente(Kurve.pfad(ecken, weich: false, geschlossen: true))
        XCTAssertEqual(teile.kurven.count, 0, "Ohne Rundung keine Bögen")
        XCTAssertTrue(teile.geschlossen)
    }

    func test_ein_ring_aus_zwei_punkten_ist_nichts() {
        // `render.path_from_points` gibt für einen geschlossenen Weg mit
        // weniger als drei Punkten nichts aus. Eine Strecke hin und
        // zurück ist keine Zone.
        let punkte = [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 0)]
        XCTAssertTrue(Kurve.pfad(punkte, weich: true, geschlossen: true).isEmpty)
    }
}

// MARK: - Die Beschriftung (R25)

/// Steht „Go" auf dem Gerät da, wo es auf dem Papier steht?
///
/// **Der Fund** (26.08.2026, beim Messen von R8): `Feldansicht` zeichnete
/// Spieler, Linien, Pfeile und Zonen -- und keinen einzigen Text an einer
/// Linie. Verloren hat die App die Beschriftung nie, sie hat sie nur nie
/// gezeigt.
///
/// **Warum es dafür einen SWIFT-Test braucht und die Prüfungen in
/// `test_beschriftung_swift.py` nicht reichen.** Die messen den Quelltext:
/// dass die Zahl dieselbe ist, dass der Faktor durchgereicht wird. Ob mit
/// beidem dasselbe herauskommt, rechnet nur ein Rechner. Genau daran ist
/// die erste Fassung gescheitert -- sie hatte dieselbe Zahl und rechnete
/// sie in der falschen EINHEIT.
final class BeschriftungsstelleTests: XCTestCase {

    private let genauigkeit = 1e-9

    func test_die_zahlen_sind_die_aus_python() {
        XCTAssertEqual(Beschriftungsstelle.abstand,
                       KurveProben.labelAbstand, accuracy: genauigkeit,
                       "Anderer Abstand als render.LABEL_OFFSET")
        XCTAssertEqual(Beschriftungsstelle.grundlinie,
                       KurveProben.labelGrundlinie, accuracy: genauigkeit,
                       "Andere halbe Zeilenhöhe als render.LABEL_MITTE")
    }

    func test_die_stelle_ist_die_aus_python() {
        for probe in KurveProben.beschriftungen {
            guard let wo = Beschriftungsstelle.fuer(probe.punkte,
                                                    faktor: 1) else {
                XCTFail("\(probe.name): keine Stelle")
                continue
            }
            XCTAssertEqual(Double(wo.x), Double(probe.mitte.x),
                           accuracy: 1e-6, "\(probe.name): x")
            XCTAssertEqual(Double(wo.y), Double(probe.mitte.y),
                           accuracy: 1e-6, "\(probe.name): y")
        }
    }

    /// Ohne diese Probe wäre der Test darüber zufrieden, wenn
    /// `KurveProben.beschriftungen` leer wäre -- dieselbe Vorsicht wie
    /// bei `test_es_gibt_ueberhaupt_proben`.
    func test_es_gibt_ueberhaupt_beschriftungsproben() {
        XCTAssertGreaterThanOrEqual(KurveProben.beschriftungen.count, 5)
    }

    /// DIE PRÜFUNG AUF DEN FEHLER, MIT DEM DIESE DATEI ANGEFANGEN HAT.
    ///
    /// Die Punkte kommen als BILDSCHIRMPUNKTE herein, `abstand` steht in
    /// BILDEINHEITEN. Wer ihn ungestreckt draufrechnet, bekommt auf dem
    /// iPhone knapp daneben und auf dem iPad die Beschriftung mitten in
    /// der Pfeilspitze. Gemessen wird das so: Streckt man Punkte UND
    /// Faktor um denselben Wert, muss die Stelle sich ebenso strecken.
    func test_der_massstab_geht_in_die_stelle_ein() {
        let einfach = [CGPoint(x: 30, y: -40), CGPoint(x: 80, y: -40)]
        let doppelt = einfach.map { CGPoint(x: $0.x * 2, y: $0.y * 2) }
        guard let klein = Beschriftungsstelle.fuer(einfach, faktor: 1),
              let gross = Beschriftungsstelle.fuer(doppelt, faktor: 2) else {
            return XCTFail("keine Stelle")
        }
        XCTAssertEqual(Double(gross.x), Double(klein.x) * 2,
                       accuracy: 1e-6,
                       "Der Abstand wächst nicht mit dem Maßstab -- die "
                       + "Beschriftung rutscht auf großen Geräten in die "
                       + "Pfeilspitze")
        XCTAssertEqual(Double(gross.y), Double(klein.y) * 2,
                       accuracy: 1e-6)
    }

    /// Und die Gegenrichtung: Bei GLEICHEN Punkten und größerem Faktor
    /// muss die Stelle weiter weg liegen. Ohne diese Hälfte wäre der
    /// Test oben auch grün, wenn der Faktor gar nicht einginge -- dann
    /// skalierte allein die Eingabe.
    func test_ein_groesserer_faktor_schiebt_weiter_hinaus() {
        let punkte = [CGPoint(x: 30, y: -40), CGPoint(x: 80, y: -40)]
        guard let eins = Beschriftungsstelle.fuer(punkte, faktor: 1),
              let zwei = Beschriftungsstelle.fuer(punkte, faktor: 2) else {
            return XCTFail("keine Stelle")
        }
        XCTAssertEqual(Double(zwei.x) - Double(eins.x),
                       Beschriftungsstelle.abstand, accuracy: 1e-6,
                       "Der Faktor geht gar nicht in den Abstand ein")
    }

    /// Auf der Spitze läge sie über dem Pfeil. `render.py` verlängert
    /// deshalb die letzte Teilstrecke.
    func test_sie_sitzt_hinter_der_spitze_und_nicht_darauf() {
        let punkte = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: -50)]
        guard let wo = Beschriftungsstelle.fuer(punkte, faktor: 1) else {
            return XCTFail("keine Stelle")
        }
        XCTAssertLessThan(Double(wo.y), -50,
                          "Die Beschriftung sitzt auf der Spitze oder "
                          + "davor statt dahinter")
    }

    func test_ohne_punkte_gibt_es_keine_stelle() {
        XCTAssertNil(Beschriftungsstelle.fuer([], faktor: 1))
        XCTAssertNil(Beschriftungsstelle.mitte([]))
    }

    /// Bei zwei gleichen Punkten gäbe die Formel eine Division durch
    /// null. Sie fällt auf den Punkt selbst zurück -- wie im Browser.
    func test_eine_linie_ohne_laenge_faellt_auf_den_punkt_zurueck() {
        let punkte = [CGPoint(x: 12, y: -7), CGPoint(x: 12, y: -7)]
        guard let wo = Beschriftungsstelle.fuer(punkte, faktor: 1) else {
            return XCTFail("keine Stelle")
        }
        XCTAssertEqual(Double(wo.x), 12, accuracy: 1e-9)
        XCTAssertTrue(Double(wo.y).isFinite, "Division durch null")
    }

    func test_die_zonenmitte_ist_die_aus_python() {
        for probe in KurveProben.zonenmitten {
            guard let wo = Beschriftungsstelle.mitte(probe.ecken) else {
                XCTFail("\(probe.name): keine Mitte")
                continue
            }
            XCTAssertEqual(Double(wo.x), Double(probe.mitte.x),
                           accuracy: 1e-6, "\(probe.name): x")
            XCTAssertEqual(Double(wo.y), Double(probe.mitte.y),
                           accuracy: 1e-6, "\(probe.name): y")
        }
    }

    /// Der Schwerpunkt der ECKEN, nicht die Mitte des umschließenden
    /// Rechtecks. Bei einer ungleichmäßigen Zone liegt beides
    /// auseinander, und `render.py` nimmt den Schwerpunkt.
    func test_die_zonenmitte_ist_nicht_die_mitte_des_rechtecks() {
        // Drei Ecken links, eine rechts: Der Schwerpunkt liegt links,
        // die Rechteckmitte in der Mitte.
        let ecken = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 10),
                     CGPoint(x: 1, y: 5), CGPoint(x: 20, y: 5)]
        guard let wo = Beschriftungsstelle.mitte(ecken) else {
            return XCTFail("keine Mitte")
        }
        XCTAssertEqual(Double(wo.x), 5.25, accuracy: 1e-9)
        XCTAssertNotEqual(Double(wo.x), 10, accuracy: 1e-6)
    }
}
