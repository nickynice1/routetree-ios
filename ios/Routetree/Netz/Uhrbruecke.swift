// Das Telefon schickt der Uhr, was sie zeigen soll (R140).
//
// Niklas am 25.09.2026: „quasi wie ein digitaler wristcoach."
//
// WARUM DIE UHR NICHT SELBST BEIM SERVER FRAGT. Sie könnte es -- eine
// Apple Watch hat WLAN und in der Mobilfunk-Fassung ein eigenes Netz.
// Am Spielfeldrand hat sie beides nicht: Das WLAN des Vereinsheims
// reicht nicht bis aufs Feld, und wer eine Uhr ohne Mobilfunk trägt
// (die Mehrheit), steht mit einer leeren Liste da.
//
// Dazu käme ein zweiter Anmeldeweg auf einem Bildschirm von vier
// Zentimetern -- mit Passwort, Zweitfaktor und der Frage, was mit dem
// Zugang passiert, wenn die Uhr weitergegeben wird.
//
// Deshalb: Das Telefon packt, die Uhr hält. Was auf dem Telefon offline
// verfügbar ist, ist es auf der Uhr auch -- und mehr verspricht diese
// Brücke nicht.
//
// GEPACKT WIRD AUS DEM VORRAT, nicht aus einem eigenen Weg zum Server.
// `Laden.…MitVorrat` ist die Stelle, an der die App schon heute
// entscheidet, ob sie vom Gerät oder aus dem Netz liest. Ein zweiter
// Weg daneben wäre eine zweite Antwort auf dieselbe Frage -- und die
// beiden liefen auseinander, sobald jemand einen von ihnen anfasst.

import Foundation
import WatchConnectivity

/// Packt Hefte für die Uhr und schickt sie hinüber.
@MainActor
final class Uhrbruecke: NSObject, ObservableObject {

    /// Gibt es überhaupt eine Uhr? `false` auf dem iPad und auf jedem
    /// iPhone ohne gekoppelte Uhr -- dann bleibt der Bereich im Konto
    /// weg, statt einen Knopf zu zeigen, der nichts tut.
    @Published private(set) var uhrVorhanden = false

    /// Ist die Uhr-App installiert? Ohne sie ist Übertragen sinnlos.
    @Published private(set) var appInstalliert = false

    @Published private(set) var laeuft = false

    /// Wann zuletzt erfolgreich gepackt und abgeschickt wurde.
    @Published private(set) var letzterStand: Date?

    /// Was zuletzt passiert ist, als Satz für Menschen.
    @Published private(set) var meldung: String?

    private var sitzung: WCSession?

    /// Woher die Hefte kommen. Wird von der Ansicht gesetzt, die die
    /// Brücke besitzt.
    ///
    /// **Stark und nicht `weak`**, und das ist kein Versehen: Eine
    /// Bitte von der Uhr kommt, wann sie kommt -- auch wenn gerade
    /// keine Ansicht offen ist, die ein `Laden` hielte. Mit einem
    /// schwachen Verweis wäre es dann weg, und die Uhr bekäme auf ihr
    /// „Jetzt holen" nichts, ohne dass jemand erführe, warum.
    var laden: Laden?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        sitzung = .default
        sitzung?.delegate = self
        sitzung?.activate()
    }

    // MARK: - Packen

    /// Baut das Paket aus den Heften, die dieser Mensch sehen darf.
    ///
    /// **Jedes Heft einzeln und in Ruhe.** Dieselbe Überlegung wie in
    /// `Laden.vorratFuellen`: Vierzig gleichzeitige Anfragen aus einem
    /// Hotspot sind der Weg in die Bremse des Servers.
    ///
    /// **Ein Play ohne Zeichnung wird übersprungen, nicht erfunden.**
    /// Wer ihn am Handgelenk sucht und nicht findet, sieht, dass etwas
    /// fehlt. Ein leeres Feld an seiner Stelle sähe aus wie ein Play
    /// ohne Routen -- und genau danach würde am Platz jemand handeln.
    func packen() async -> Uhrpaket? {
        guard let laden else { return nil }
        laeuft = true
        meldung = nil
        defer { laeuft = false }

        do {
            let hefte = try await laden.heftlisteMitVorrat().wert
            var gepackt: [Uhrpaket.Heft] = []

            for heft in hefte {
                let kategorien = (try? await laden
                    .kategorienMitVorrat(playbook: heft.id).wert) ?? []
                let liste = try? await laden
                    .playlisteMitVorrat(playbook: heft.id).wert
                let kurz = liste?.plays ?? []

                // Kennung der Kategorie -> ihre Plays. Plays ohne
                // Kategorie kommen unter `nil` und bekommen unten ein
                // eigenes Fach.
                var faecher: [Int?: [Uhrpaket.Play]] = [:]
                // Die Maße kommen aus dem ersten Play, der ankommt: Der
                // Server legt sie dort ab (`PlayVoll.feld`), und im Heft
                // sind sie für alle gleich. Das Heft selbst nennt nur
                // die KENNUNG des Formats, und die reicht nicht -- siehe
                // `Feld` in `Feld.swift`.
                var masse: Feld?
                for k in kurz {
                    guard let voll = try? await laden
                        .playMitVorrat(k.id, version: k.version).wert
                    else { continue }
                    masse = masse ?? voll.feld
                    faecher[k.kategorieId, default: []].append(
                        Uhrpaket.Play(id: String(voll.id),
                                      name: voll.name,
                                      los: voll.los,
                                      richtung: voll.richtung,
                                      zeichnung: voll.zeichnung))
                }

                var fertig: [Uhrpaket.Kategorie] = kategorien
                    .sorted { $0.position < $1.position }
                    .compactMap { k in
                        let plays = faecher[k.id] ?? []
                        guard !plays.isEmpty else { return nil }
                        return Uhrpaket.Kategorie(id: String(k.id),
                                                  name: k.name,
                                                  farbe: k.farbe,
                                                  plays: plays)
                    }
                if let ohne = faecher[nil], !ohne.isEmpty {
                    fertig.append(Uhrpaket.Kategorie(
                        id: "ohne",
                        name: String(localized: #"Ohne Kategorie"#),
                        farbe: nil,
                        plays: ohne))
                }
                // OHNE MASSE KEIN HEFT. Sie fehlen genau dann, wenn kein
                // einziger Play ankam -- dann gibt es auch nichts zu
                // zeigen. Ein Rückfall auf die Normmaße wäre die
                // schlechtere Antwort: Die Uhr zeichnete ein Feld, das
                // es in diesem Verein nicht gibt.
                guard !fertig.isEmpty, let masse else { continue }
                gepackt.append(Uhrpaket.Heft(id: String(heft.id),
                                             name: heft.name,
                                             spielform: heft.spielform,
                                             feld: masse,
                                             kategorien: fertig))
            }

            return Uhrpaket(stand: Date(), hefte: gepackt)
        } catch {
            meldung = Fehlertext.von(error)
            return nil
        }
    }

    /// Packt und schickt. Der Knopf im Konto hängt hier dran.
    func uebertragen() async {
        guard let paket = await packen() else { return }
        schicken(paket)
    }

    // MARK: - Schicken

    private func schicken(_ paket: Uhrpaket) {
        guard let sitzung, let daten = try? paket.schreiben() else {
            meldung = String(localized: #"Der Stand ließ sich nicht packen."#)
            return
        }

        // DER STAND GEHT IMMER MIT, auch wenn der Inhalt in der
        // Warteschlange hängt. Der Anwendungszusammenhang überschreibt
        // sich selbst und kommt beim nächsten Kontakt an -- damit weiß
        // die Uhr, dass sie alt ist, noch bevor ein Byte Inhalt da ist.
        try? sitzung.updateApplicationContext(
            [Uhrfunk.stand: paket.stand.timeIntervalSince1970])

        if daten.count < Uhrfunk.grenzeFuerDatei {
            sitzung.transferUserInfo([Uhrfunk.paket: daten])
        } else {
            // ÜBER EINE DATEI IM EIGENEN ORDNER. Das System kopiert sie
            // sich; wir dürfen sie danach wegräumen, müssen aber bis
            // dahin warten.
            let weg = FileManager.default.temporaryDirectory
                .appendingPathComponent(Uhrfunk.dateiname)
            guard (try? daten.write(to: weg, options: .atomic)) != nil else {
                meldung = String(localized: #"Der Stand ließ sich nicht ablegen."#)
                return
            }
            sitzung.transferFile(weg, metadata: nil)
        }

        letzterStand = paket.stand
        meldung = nil
    }
}

// MARK: - WCSessionDelegate

extension Uhrbruecke: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        let gekoppelt = session.isPaired
        let installiert = session.isWatchAppInstalled
        Task { @MainActor in
            self.uhrVorhanden = gekoppelt
            self.appInstalliert = installiert
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Nach einem Wechsel der Uhr muss die Sitzung neu aktiviert werden.
    /// Ohne diese Zeile schweigt die Brücke ab da, und zwar dauerhaft.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let gekoppelt = session.isPaired
        let installiert = session.isWatchAppInstalled
        Task { @MainActor in
            self.uhrVorhanden = gekoppelt
            self.appInstalliert = installiert
        }
    }

    /// Die Uhr bittet um einen frischen Stand.
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        guard message[Uhrfunk.bitteSchicken] != nil else {
            replyHandler([:])
            return
        }
        // SOFORT ANTWORTEN, dann arbeiten. Der Antwortgriff hat eine
        // kurze Frist; wer ihn erst nach dem Packen bedient, bekommt
        // auf der Uhr einen Zeitfehler statt eines Pakets.
        replyHandler([:])
        Task { @MainActor in await self.uebertragen() }
    }
}
