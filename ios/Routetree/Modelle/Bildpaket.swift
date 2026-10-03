import Foundation
import UIKit

/// Ein Bild aus der Mediathek in etwas verwandeln, das ein Logo sein kann (R33).
///
/// **Warum überhaupt verkleinert wird.** Ein Foto aus einem heutigen
/// Telefon ist 4000 Pixel breit und wiegt mehrere Megabyte. Als Logo
/// erscheint es auf einer Kachel, keine 200 Pixel groß. Das Original
/// hochzuladen hieße: minutenlang warten im Hotspot am Spielfeldrand,
/// Speicher auf dem Server, und am Ende eine Absage, weil der Server
/// bei drei Megabyte die Grenze zieht.
///
/// **Die Grenze selbst steht NICHT hier.** Was ein Logo sein darf, sagt
/// `TeamForm` auf dem Server -- eine Zahl in Swift wäre eine zweite
/// Wahrheit und beim nächsten Verschieben die falsche. Diese Datei
/// sorgt nur dafür, dass die Frage praktisch nie gestellt wird: Was
/// hier herauskommt, liegt weit unter jeder vernünftigen Grenze.
///
/// **Und warum PNG und nicht JPEG.** Vereinswappen haben Flächen und
/// harte Kanten, oft mit durchsichtigem Rand. JPEG macht daraus einen
/// grauen Schleier um jede Kante, und bei einem Wappen auf dunklem
/// Grund sieht man das sofort. PNG ist bei so einem Bild auch nicht
/// größer, weil es wenige Farben hat.
enum Bildpaket {

    /// Die längere Kante nach dem Verkleinern.
    ///
    /// 512 und nicht 1024: Angezeigt wird das Bild auf einer Kachel und
    /// im Kopf der Mannschaftsseite, beides deutlich kleiner. 512 ist
    /// auf einem Bildschirm mit dreifacher Auflösung immer noch mehr
    /// als nötig -- und der Puffer ist Absicht, denn dasselbe Bild
    /// steht auch auf einer gedruckten Playcard.
    static let kante: CGFloat = 512

    /// Verkleinert und macht ein PNG daraus. `nil`, wenn es kein Bild war.
    ///
    /// **Ein kleines Bild wird nicht vergrößert.** Ein Wappen, das als
    /// 128er PNG vorliegt, auf 512 aufzublasen macht es nicht schöner,
    /// nur größer und unscharf -- und der Server bekäme ein Bild, das
    /// schlechter ist als das, was jemand ausgesucht hat.
    static func alsLogo(_ daten: Data) -> Data? {
        guard let bild = UIImage(data: daten) else { return nil }

        let groesste = max(bild.size.width, bild.size.height)
        guard groesste > 0 else { return nil }
        let faktor = min(1, kante / groesste)
        if faktor >= 1 {
            // Schon klein genug. Trotzdem durch die PNG-Ausgabe, damit
            // ein HEIC aus der Mediathek nicht als HEIC hochgeht -- das
            // kann der Server nicht lesen, und die Absage käme erst
            // nach dem Hochladen.
            return bild.pngData()
        }

        let ziel = CGSize(width: (bild.size.width * faktor).rounded(),
                          height: (bild.size.height * faktor).rounded())
        // `opaque: false` und Maßstab 1: Die Durchsichtigkeit muss
        // bleiben (ein Wappen hat sie fast immer), und der Maßstab des
        // Geräts hat hier nichts zu suchen -- sonst käme auf einem
        // dreifach auflösenden Telefon ein dreimal so großes Bild
        // heraus als auf einem anderen, aus derselben Vorlage.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let zeichner = UIGraphicsImageRenderer(size: ziel, format: format)
        let klein = zeichner.image { _ in
            bild.draw(in: CGRect(origin: .zero, size: ziel))
        }
        return klein.pngData()
    }
}
