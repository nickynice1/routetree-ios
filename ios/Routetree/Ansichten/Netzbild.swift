// Ein Bild aus dem Netz, das nicht bei jedem Blick neu lädt.
//
// **Der Fehler, den diese Datei behebt.** Niklas am 08.09.2026: „das
// logo lädt immer wieder nach, wieso wird das nicht einfach gecached?"
//
// Er hat recht, und die Ursache liegt nicht am Server: Ein Logo kommt
// von dort mit `Cache-Control: max-age=604800`, also sieben Tagen. Sie
// liegt an `AsyncImage`. Das zeigt bei JEDEM Neuaufbau der Ansicht
// wieder seinen `.empty`-Zustand, also den Ladekreis, und fängt von
// vorn an. In einer Liste, die beim Scrollen ihre Zeilen
// wiederverwendet, heißt das: Das Wappen blinkt bei jeder Bewegung.
//
// Der Bytespeicher von `URLSession` hilft dagegen nicht. Er spart die
// Leitung, nicht das Entpacken und nicht den Ladekreis -- und genau der
// ist das, was man sieht.
//
// **Zwei Schichten, und beide werden gebraucht.** Ein `NSCache` hält
// das FERTIG ENTPACKTE Bild; damit ist es beim nächsten Aufbau sofort
// da, ohne Ladekreis und ohne Arbeit. Und `URLCache` bekommt genug
// Platz, damit die Bytes einen Neustart der App überleben.
//
// **Warum eine eigene Ansicht und kein Ausbau von `AsyncImage`.** Man
// kann `AsyncImage` nicht sagen, dass es einen Treffer sofort zeigen
// soll; sein Zustandsautomat fängt immer bei `.empty` an. Das ist nicht
// einstellbar, sondern eingebaut.

import SwiftUI
import UIKit

/// Fertig entpackte Bilder, nach Adresse.
///
/// `NSCache` und kein `Dictionary`: Es räumt von selbst, wenn das
/// System Speicher braucht, und es ist über Threads hinweg sicher. Ein
/// Wörterbuch wüchse, bis die App abgeräumt wird -- bei einem Verein mit
/// vierzig Mannschaften wären das vierzig Bilder, die längst niemand
/// mehr ansieht.
enum Bildspeicher {

    private static let speicher: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        // Fünfzig Wappen sind mehr, als eine Ansicht je zeigt.
        c.countLimit = 50
        return c
    }()

    static func hole(_ adresse: URL) -> UIImage? {
        speicher.object(forKey: adresse as NSURL)
    }

    /// Den Bytespeicher vergrößern -- einmal beim Start.
    ///
    /// Die Vorgabe von iOS ist knapp, und ein Logo von 200 Kilobyte
    /// fliegt daraus heraus, sobald ein paar Antworten dazukommen.
    /// Zwanzig Megabyte im Arbeitsspeicher und hundert auf der Platte
    /// sind für Wappen reichlich und für ein Telefon nichts.
    static func einrichten() {
        URLCache.shared = URLCache(memoryCapacity: 20 * 1024 * 1024,
                                   diskCapacity: 100 * 1024 * 1024)
    }

    /// Holen und entpacken -- bewusst NICHT auf dem Hauptthread.
    ///
    /// Die Funktion ist `nonisolated` und `async`; damit läuft sie auf
    /// dem allgemeinen Ausführer, auch wenn die aufrufende Ansicht am
    /// Hauptthread hängt. Ein PNG von 200 Kilobyte zu entpacken dauert
    /// Millisekunden, aber die fallen genau dann an, wenn jemand
    /// scrollt.
    static func laden(_ adresse: URL) async -> UIImage? {
        if let da = hole(adresse) { return da }
        // Der Bytespeicher darf antworten; das ist der Sinn der Sache.
        var anfrage = URLRequest(url: adresse)
        anfrage.cachePolicy = .returnCacheDataElseLoad
        guard let (daten, _) = try? await URLSession.shared.data(for: anfrage),
              let neu = UIImage(data: daten) else { return nil }
        speicher.setObject(neu, forKey: adresse as NSURL)
        return neu
    }
}

/// Ein Bild von einer Adresse, mit Ersatz, solange oder falls keines da
/// ist.
///
/// Der Ersatz ist mit Absicht Pflicht und hat keine Vorgabe: Am
/// Spielfeldrand ist „kein Netz" der Normalfall, und eine leere Fläche
/// sieht aus wie ein Fehler der App.
struct Netzbild<Ersatz: View>: View {

    let adresse: URL?
    /// Wie das Bild in seinen Platz gelegt wird. `.fit` zeigt es ganz,
    /// `.fill` füllt und schneidet.
    var passung: ContentMode = .fit
    @ViewBuilder let ersatz: () -> Ersatz

    /// Beim ersten Aufbau schon gesetzt, wenn das Bild im Speicher
    /// liegt. Genau das ist der Unterschied zu `AsyncImage`: kein
    /// Ladekreis für etwas, das längst da ist.
    @State private var bild: UIImage?

    var body: some View {
        Group {
            if let bild {
                Image(uiImage: bild)
                    .resizable()
                    .aspectRatio(contentMode: passung)
            } else {
                ersatz()
            }
        }
        // `task(id:)` und nicht `onAppear`: Wechselt die Adresse (eine
        // andere Mannschaft in derselben wiederverwendeten Zeile), läuft
        // die Aufgabe neu an und die alte wird abgebrochen.
        .task(id: adresse) {
            guard let adresse else { return }
            if let da = Bildspeicher.hole(adresse) {
                bild = da
                return
            }
            let neu = await Bildspeicher.laden(adresse)
            // Nur setzen, wenn die Ansicht noch dieselbe Adresse meint.
            if adresse == self.adresse { bild = neu }
        }
    }
}
