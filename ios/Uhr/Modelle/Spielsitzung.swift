// Der Spielmodus: die Uhr bleibt auf dem Play (R140.3).
//
// **Niklas, 25.09.2026:** „der Playmodus soll so sein, dass die App
// immer vorne bleibt: ich spiele jetzt Play 1, dann lass ich meine
// Arme so, dass meine Uhr automatisch wieder in Ruhemodus geht -- aber
// wenn ich das Play gespielt habe und wieder meinen Arm anwinkle und
// die Uhr angeht, soll gleich wieder derselbe Bildschirm da sein."
//
// **Das entscheidet nicht die App, sondern watchOS.** Eine gewöhnliche
// App fällt nach kurzer Zeit auf das Zifferblatt zurück; sie kann das
// nicht verbieten. Der einzige Weg, der es zuverlässig hält, ist eine
// Workout-Sitzung -- und zwar ohne Zeitlimit und ohne dass der Träger
// vorher eine Systemeinstellung umgestellt haben muss.
//
// **Entschieden am 25.09.2026 von Niklas**, aus drei vorgelegten
// Wegen. Der Preis ist eine Health-Abfrage und ein Trainingseintrag.
// Für einen Spieler ist das keine Ausrede, sondern die Wahrheit: Wer
// mit dem Wristcoach am Arm auf dem Feld steht, trainiert gerade --
// und bekommt Spielzeit und Puls dazu.
//
// Für einen Trainer an der Seitenlinie wäre es zu viel. Genau deshalb
// ist der Spielmodus eine WAHL beim Antippen des Hefts und nicht der
// Normalfall.

import Foundation
import HealthKit

@MainActor
final class Spielsitzung: NSObject, ObservableObject {

    enum Lage: Equatable {
        case aus
        case faengtAn
        case laeuft
        case verweigert
        case gehtNicht(String)
    }

    @Published private(set) var lage: Lage = .aus

    /// Wie lange das Spiel schon läuft. `nil`, solange nichts läuft.
    @Published private(set) var seit: Date?

    private let speicher = HKHealthStore()
    private var sitzung: HKWorkoutSession?
    private var schreiber: HKLiveWorkoutBuilder?

    /// Ob auf diesem Gerät überhaupt etwas zu holen ist.
    ///
    /// **Geprüft und nicht angenommen.** Im Simulator gibt es kein
    /// HealthKit; ohne diese Abfrage wirft der erste Zugriff, und der
    /// Spielmodus sähe aus, als wäre er kaputt.
    static var moeglich: Bool { HKHealthStore.isHealthDataAvailable() }

    func anfangen() async {
        guard Self.moeglich else {
            lage = .gehtNicht(String(localized:
                "Auf diesem Gerät gibt es keine Gesundheitsdaten."))
            return
        }
        lage = .faengtAn

        // **Nur SCHREIBEN anfragen, nicht lesen.** Ein Wristcoach
        // braucht keine fremden Gesundheitsdaten, und jede Berechtigung,
        // die man anfragt, muss man im Review begründen.
        // **`Set<HKSampleType>` ausgeschrieben, nicht `Set` geraten.**
        // `HKObjectType.workoutType()` liefert einen `HKWorkoutType`;
        // ohne die Angabe leitet Swift `Set<HKWorkoutType>` ab, und das
        // passt nicht auf `toShare:`.
        let schreiben: Set<HKSampleType> = [HKObjectType.workoutType()]
        do {
            try await speicher.requestAuthorization(toShare: schreiben,
                                                    read: [])
        } catch {
            lage = .verweigert
            return
        }

        let aufbau = HKWorkoutConfiguration()
        // AMERICAN FOOTBALL und nicht „other": Die Sportart steht
        // hinterher in der Health-App, und „Sonstiges" wäre eine
        // Auskunft, die niemandem hilft.
        aufbau.activityType = .americanFootball
        aufbau.locationType = .outdoor

        do {
            let neue = try HKWorkoutSession(healthStore: speicher,
                                            configuration: aufbau)
            let bauer = neue.associatedWorkoutBuilder()
            bauer.dataSource = HKLiveWorkoutDataSource(
                healthStore: speicher, workoutConfiguration: aufbau)
            neue.delegate = self

            let jetzt = Date()
            neue.startActivity(with: jetzt)
            try await bauer.beginCollection(at: jetzt)

            sitzung = neue
            schreiber = bauer
            seit = jetzt
            lage = .laeuft
        } catch {
            lage = .gehtNicht(error.localizedDescription)
        }
    }

    /// Beendet das Spiel und sichert den Eintrag.
    ///
    /// **Sichern und nicht verwerfen.** Wer die Health-Abfrage
    /// beantwortet hat, hat damit gerechnet, dass etwas ankommt. Eine
    /// Sitzung, die nur die App vorne hält und am Ende nichts
    /// hinterlässt, hätte die Erlaubnis unter falschem Vorwand geholt.
    func aufhoeren() async {
        guard let sitzung, let schreiber else {
            lage = .aus
            return
        }
        let jetzt = Date()
        sitzung.end()
        try? await schreiber.endCollection(at: jetzt)
        _ = try? await schreiber.finishWorkout()
        self.sitzung = nil
        self.schreiber = nil
        seit = nil
        lage = .aus
    }
}

extension Spielsitzung: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(_ sitzung: HKWorkoutSession,
                                    didChangeTo neu: HKWorkoutSessionState,
                                    from alt: HKWorkoutSessionState,
                                    date: Date) {
        // **Nur das Ende interessiert.** Wenn watchOS die Sitzung von
        // sich aus beendet -- etwa weil der Akku zur Neige geht --,
        // muss die Ansicht das erfahren. Sonst stünde dort „Spielmodus
        // läuft", während die Uhr längst wieder aufs Zifferblatt
        // zurückfällt.
        guard neu == .ended else { return }
        Task { @MainActor in
            if self.lage == .laeuft { self.lage = .aus }
            self.seit = nil
        }
    }

    nonisolated func workoutSession(_ sitzung: HKWorkoutSession,
                                    didFailWithError fehler: Error) {
        Task { @MainActor in
            self.lage = .gehtNicht(fehler.localizedDescription)
            self.seit = nil
        }
    }
}
