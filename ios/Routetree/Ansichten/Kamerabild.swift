// Das Sucherbild für den Scanner (R142).
//
// **Nur die Kamera, sonst nichts.** Alles, was der Trainer sieht --
// Rahmen, Leiste, Ergebnis -- liegt als SwiftUI darüber. Diese Datei
// kennt weder Playbooks noch Yards; sie liefert ein Bild und ein Foto.
//
// Die Trennung hat einen praktischen Grund: Eine `UIViewRepresentable`
// lässt sich in der Vorschau nicht darstellen und in keinem Test
// ausführen. Was hier drinsteht, ist damit unprüfbar -- also steht
// hier so wenig wie möglich.

import AVFoundation
import SwiftUI
import UIKit

/// Der laufende Sucher, als SwiftUI-Ansicht.
struct Kamerabild: UIViewRepresentable {

    let sitzung: AVCaptureSession

    func makeUIView(context: Context) -> Sucherfeld {
        let feld = Sucherfeld()
        feld.schicht.session = sitzung
        // `resizeAspectFill` und nicht `resizeAspect`: Ein Sucher mit
        // schwarzen Balken sieht aus wie ein Fehler. Dass dabei etwas
        // vom Bildrand wegfällt, ist verkraftbar -- der Rahmen liegt
        // ohnehin weit innerhalb.
        feld.schicht.videoGravity = .resizeAspectFill
        return feld
    }

    func updateUIView(_ feld: Sucherfeld, context: Context) { }

    /// Eine Ansicht, die NUR aus der Vorschauschicht besteht.
    ///
    /// **Über `layerClass` und nicht über eine hinzugefügte Schicht.**
    /// Eine nachträglich eingehängte Schicht muss bei jeder
    /// Größenänderung von Hand nachgezogen werden, und genau das
    /// vergisst man beim Drehen des Geräts.
    final class Sucherfeld: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        var schicht: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

/// Führt die Kamera. Kennt keine Ansicht.
@MainActor
final class Kamerafuehrung: NSObject, ObservableObject {

    enum Lage: Equatable {
        case aus
        case laeuft
        case verweigert
        case geht_nicht(String)
    }

    @Published private(set) var lage: Lage = .aus

    let sitzung = AVCaptureSession()
    private let ausgabe = AVCapturePhotoOutput()
    private var fertig: ((Data?) -> Void)?

    /// Fragt nach Erlaubnis und startet.
    ///
    /// **Der Start läuft NICHT auf dem Hauptfaden.**
    /// `startRunning` blockiert, bis die Kamera bereit ist -- das sind
    /// auf einem älteren Gerät mehrere hundert Millisekunden, und auf
    /// dem Hauptfaden sind das mehrere hundert Millisekunden, in denen
    /// die App steht.
    func starten() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                lage = .verweigert
                return
            }
        default:
            lage = .verweigert
            return
        }

        if sitzung.inputs.isEmpty {
            do {
                try einrichten()
            } catch {
                lage = .geht_nicht(error.localizedDescription)
                return
            }
        }
        let sitzung = self.sitzung
        await Task.detached { sitzung.startRunning() }.value
        lage = .laeuft
    }

    func anhalten() {
        let sitzung = self.sitzung
        Task.detached { sitzung.stopRunning() }
    }

    private func einrichten() throws {
        sitzung.beginConfiguration()
        defer { sitzung.commitConfiguration() }
        sitzung.sessionPreset = .photo

        guard let geraet = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back)
        else {
            throw Kamerafehler.keineKamera
        }
        let eingang = try AVCaptureDeviceInput(device: geraet)
        guard sitzung.canAddInput(eingang), sitzung.canAddOutput(ausgabe)
        else {
            throw Kamerafehler.keineKamera
        }
        sitzung.addInput(eingang)
        sitzung.addOutput(ausgabe)
    }

    /// Löst aus. Gibt die Bilddaten als JPEG.
    func aufnehmen() async -> Data? {
        await withCheckedContinuation { weiter in
            fertig = { daten in weiter.resume(returning: daten) }
            let angaben = AVCapturePhotoSettings()
            ausgabe.capturePhoto(with: angaben, delegate: self)
        }
    }

    enum Kamerafehler: LocalizedError {
        case keineKamera
        var errorDescription: String? {
            String(localized: "Auf diesem Gerät ist keine Kamera zu finden.")
        }
    }
}

extension Kamerafuehrung: AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(_ ausgabe: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto foto: AVCapturePhoto,
                                 error: Error?) {
        let daten = foto.fileDataRepresentation()
        Task { @MainActor in
            let rueckruf = self.fertig
            self.fertig = nil
            rueckruf?(error == nil ? daten : nil)
        }
    }
}
