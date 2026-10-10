// Den Coaching-Schlüssel von Telefon zu Telefon übergeben (R143).
//
// **Niklas am 01.10.2026**, auf die Frage, wie der Schlüssel zum
// Spieler kommt: Multipeer, Telefon zu Telefon. „denn kommt man vorm
// training zusammen."
//
// ## Warum es diesen Weg überhaupt braucht
//
// Ein iPhone erreicht über WatchConnectivity ausschliesslich SEINE
// eigene gekoppelte Uhr. Der Schlüssel entsteht beim Coach -- nur wer
// die Mannschaft führt, darf eine Uhr anmelden -- und muss auf das
// Handgelenk eines anderen Menschen. Dazwischen liegt zwangsläufig
// dessen Telefon.
//
// Von Hand eintippen geht (und bleibt, siehe `CoachingBlatt`). Für
// zwölf Spieler vor dem Training ist es zwölfmal Vorlesen und
// Vertippen.
//
// ## Wer ruft und wer sucht, und warum so
//
// **Der Spieler zeigt sich an, der Coach sucht.** Umgekehrt wäre
// naheliegender -- der Coach hat ja etwas zu verteilen --, aber dann
// sähe jeder Spieler jeden Coach in Funkreichweite, auch den der
// anderen Mannschaft auf dem Nebenplatz, und müsste den richtigen
// auswählen. So trifft die Wahl der, der weiß, wer wer ist.
//
// ## Was hier NICHT passiert
//
// Der Schlüssel geht nicht an alle, die sich zeigen. Der Coach tippt
// einen Namen an, und nur dieses Gerät bekommt ihn. Eine Rundsendung
// wäre bequemer und gäbe jedem Fremden in Funkreichweite denselben
// Lesezugang.
//
// ## Was er wert ist, wenn er abgefangen wird
//
// Die Verbindung ist verschlüsselt (`.required`). Selbst ohne das wäre
// der Schaden begrenzt: Der Schlüssel darf EINE Adresse lesen (welcher
// Play gerade gerufen ist) und eine Reihe um eins vorrücken. Er kann
// nichts ändern, nichts löschen und nichts anderes ansehen -- und der
// Coach meldet die Uhr jederzeit vom Telefon aus ab.

import Foundation
import MultipeerConnectivity

/// Der Dienstname auf dem Funk.
///
/// **Höchstens fünfzehn Zeichen, nur Kleinbuchstaben, Ziffern und
/// Bindestrich** -- das ist keine Empfehlung, sondern Bonjour: Ein
/// längerer Name lässt `MCNearbyServiceAdvertiser` beim Anlegen
/// abstürzen, nicht fehlschlagen.
///
/// Er steht an zwei weiteren Stellen: in `NSBonjourServices` in
/// `project.yml`, einmal als `_tcp` und einmal als `_udp`. Ohne diese
/// Einträge findet unter iOS 14 und neuer niemand jemanden -- und zwar
/// ohne Fehlermeldung.
private let dienst = "rt-coaching"

/// Ein Telefon in Funkreichweite, das auf einen Schlüssel wartet.
struct Funkgeraet: Identifiable, Equatable {
    let peer: MCPeerID
    var id: String { peer.displayName }
    var name: String { peer.displayName }
}

/// Wie ein Gerät sich auf dem Funk nennt.
///
/// **NICHT `UIDevice.current.name`**, und das ist der Fehler, den man
/// hier einmal macht: Seit iOS 16 gibt das für eine App ohne
/// Sonderberechtigung nicht mehr „iPhone von Jule" zurück, sondern
/// das MODELL -- „iPhone". Zwölf Spieler am Platz hätten damit zwölf
/// Einträge namens „iPhone", und der Coach rät, welcher welcher ist.
///
/// Genommen wird der Name aus dem Konto. Wer angemeldet ist, hat
/// einen; wer nicht, kommt an diesen Bildschirm nicht.
///
/// **Höchstens 40 Zeichen.** `MCPeerID` nimmt 63 Byte und wirft
/// sonst, und ein deutscher Name kostet schnell zwei Byte je
/// Buchstabe.
func funkname(_ roh: String) -> String {
    let sauber = roh.trimmingCharacters(in: .whitespacesAndNewlines)
    return sauber.isEmpty
        ? String(localized: "Unbenannt")
        : String(sauber.prefix(40))
}

/// Die Seite des COACHES: sucht Spieler und schickt den Schlüssel.
@MainActor
final class Schluesselsender: NSObject, ObservableObject {

    @Published private(set) var gefunden: [Funkgeraet] = []
    @Published private(set) var sucht = false

    /// An wen der Schlüssel schon ging -- damit der Coach bei zwölf
    /// Spielern nicht mitzählen muss.
    @Published private(set) var versorgt: Set<String> = []

    @Published var hinweis: String?

    private var sitzung: MCSession?
    private var sucher: MCNearbyServiceBrowser?

    /// Was der Schlüssel ist, der gerade verteilt wird.
    private var schluessel: String?

    deinit {
        sucher?.stopBrowsingForPeers()
        sitzung?.disconnect()
    }

    /// Fängt an zu suchen. `schluessel` ist der, der verteilt wird.
    func anfangen(schluessel: String, name: String) {
        guard !sucht else { return }
        self.schluessel = schluessel
        let ich = MCPeerID(displayName: funkname(name))
        let neu = MCSession(peer: ich, securityIdentity: nil,
                            encryptionPreference: .required)
        neu.delegate = self
        sitzung = neu
        let browser = MCNearbyServiceBrowser(peer: ich, serviceType: dienst)
        browser.delegate = self
        browser.startBrowsingForPeers()
        sucher = browser
        sucht = true
    }

    func aufhoeren() {
        sucher?.stopBrowsingForPeers()
        sucher = nil
        sitzung?.disconnect()
        sitzung = nil
        gefunden = []
        sucht = false
    }

    /// Diesem Gerät den Schlüssel geben.
    ///
    /// Die Einladung geht zuerst; geschickt wird erst, wenn die andere
    /// Seite angenommen hat (`didChange state: .connected`).
    func schicken(an geraet: Funkgeraet) {
        guard let sitzung, let sucher else { return }
        // 20 SEKUNDEN UND NICHT 10. Die andere Seite muss nicht tippen
        // -- sie nimmt automatisch an --, aber der erste Aufbau über
        // Bluetooth braucht auf älteren Geräten länger als man glaubt.
        sucher.invitePeer(geraet.peer, to: sitzung,
                          withContext: nil, timeout: 20)
    }
}

extension Schluesselsender: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             foundPeer peer: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard !self.gefunden.contains(where: { $0.peer == peer }) else {
                return
            }
            self.gefunden.append(Funkgeraet(peer: peer))
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             lostPeer peer: MCPeerID) {
        Task { @MainActor in
            self.gefunden.removeAll { $0.peer == peer }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            // **DER EINE FALL, DER WIRKLICH VORKOMMT:** Das lokale Netz
            // ist nicht erlaubt. iOS fragt genau einmal, und wer dann
            // „Nicht erlauben" tippt, bekommt hier einen Fehler und
            // sonst nirgends einen Hinweis.
            self.hinweis = String(localized: "Die Suche ging nicht los. Erlaube Routetree in den iPhone-Einstellungen das lokale Netzwerk.")
            self.sucht = false
        }
    }
}

extension Schluesselsender: MCSessionDelegate {

    nonisolated func session(_ session: MCSession, peer: MCPeerID,
                             didChange state: MCSessionState) {
        let name = peer.displayName
        Task { @MainActor in
            switch state {
            case .connected:
                guard let schluessel = self.schluessel,
                      let daten = schluessel.data(using: .utf8) else { return }
                do {
                    try session.send(daten, toPeers: [peer],
                                     with: .reliable)
                    self.versorgt.insert(name)
                    self.hinweis = nil
                } catch {
                    self.hinweis = String(localized: "Der Schlüssel ging nicht durch. Versuch es noch einmal.")
                }
            case .notConnected:
                // KEINE MELDUNG. Eine Verbindung, die nach dem Senden
                // zugeht, ist der Normalfall -- die andere Seite legt
                // auf, sobald sie den Schlüssel hat.
                break
            default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data,
                             fromPeer peer: MCPeerID) {}
    nonisolated func session(_ session: MCSession,
                             didReceive stream: InputStream,
                             withName name: String,
                             fromPeer peer: MCPeerID) {}
    nonisolated func session(_ session: MCSession,
                             didStartReceivingResourceWithName name: String,
                             fromPeer peer: MCPeerID,
                             with progress: Progress) {}
    nonisolated func session(_ session: MCSession,
                             didFinishReceivingResourceWithName name: String,
                             fromPeer peer: MCPeerID, at localURL: URL?,
                             withError error: Error?) {}
}

/// Die Seite des SPIELERS: zeigt sich an und nimmt den Schlüssel.
@MainActor
final class Schluesselempfang: NSObject, ObservableObject {

    /// Der Schlüssel, sobald einer angekommen ist.
    @Published private(set) var schluessel: String?

    /// Von welchem Gerät er kam -- damit der Spieler sieht, dass es
    /// wirklich das Telefon seines Coaches war und nicht irgendeins.
    @Published private(set) var von: String?

    @Published private(set) var zeigtSich = false
    @Published var hinweis: String?

    private var sitzung: MCSession?
    private var anzeige: MCNearbyServiceAdvertiser?

    deinit {
        anzeige?.stopAdvertisingPeer()
        sitzung?.disconnect()
    }

    /// `name` ist, was der Coach in seiner Liste liest.
    func anfangen(name: String) {
        guard !zeigtSich else { return }
        schluessel = nil
        von = nil
        let ich = MCPeerID(displayName: funkname(name))
        let neu = MCSession(peer: ich, securityIdentity: nil,
                            encryptionPreference: .required)
        neu.delegate = self
        sitzung = neu
        let werber = MCNearbyServiceAdvertiser(
            peer: ich, discoveryInfo: nil, serviceType: dienst)
        werber.delegate = self
        werber.startAdvertisingPeer()
        anzeige = werber
        zeigtSich = true
    }

    func aufhoeren() {
        anzeige?.stopAdvertisingPeer()
        anzeige = nil
        sitzung?.disconnect()
        sitzung = nil
        zeigtSich = false
    }
}

extension Schluesselempfang: MCNearbyServiceAdvertiserDelegate {

    /// Eine Einladung kommt -- und wird ANGENOMMEN, ohne zu fragen.
    ///
    /// **Weil der Spieler schon gefragt wurde.** Er hat „Vom Coach
    /// empfangen" getippt; das IST die Zustimmung. Eine zweite Frage
    /// („XY möchte sich verbinden -- erlauben?") käme eine Sekunde
    /// später, auf einem Bildschirm, den er gerade weglegt, und
    /// scheiterte in der Hälfte der Fälle an der Zeitgrenze.
    ///
    /// Angenommen wird nur, solange diese Seite sich anzeigt, und sie
    /// hört auf, sobald ein Schlüssel da ist.
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                               didReceiveInvitationFromPeer peer: MCPeerID,
                               withContext context: Data?,
                               invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            guard let sitzung = self.sitzung, self.schluessel == nil else {
                invitationHandler(false, nil)
                return
            }
            invitationHandler(true, sitzung)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                               didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            self.hinweis = String(localized: "Dein iPhone zeigt sich nicht. Erlaube Routetree in den iPhone-Einstellungen das lokale Netzwerk.")
            self.zeigtSich = false
        }
    }
}

extension Schluesselempfang: MCSessionDelegate {

    nonisolated func session(_ session: MCSession, peer: MCPeerID,
                             didChange state: MCSessionState) {}

    nonisolated func session(_ session: MCSession, didReceive data: Data,
                             fromPeer peer: MCPeerID) {
        // **GRENZE AM EMPFANG, nicht am Versand.** Was hier ankommt,
        // hat ein Gerät geschickt, über das dieses hier nichts weiss.
        // Ein Schlüssel ist eine kurze Zeichenkette; alles, was länger
        // ist, ist keiner -- und soll nicht in ein Textfeld wandern.
        guard data.count <= 512,
              let wert = String(data: data, encoding: .utf8) else { return }
        let sauber = wert.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty else { return }
        let name = peer.displayName
        Task { @MainActor in
            self.schluessel = sauber
            self.von = name
            // SOFORT AUFHOEREN. Wer einen Schlüssel hat, braucht
            // keinen zweiten -- und ein Telefon, das sich weiter
            // anzeigt, nimmt den nächsten Fremden auch noch an.
            self.aufhoeren()
        }
    }

    nonisolated func session(_ session: MCSession,
                             didReceive stream: InputStream,
                             withName name: String,
                             fromPeer peer: MCPeerID) {}
    nonisolated func session(_ session: MCSession,
                             didStartReceivingResourceWithName name: String,
                             fromPeer peer: MCPeerID,
                             with progress: Progress) {}
    nonisolated func session(_ session: MCSession,
                             didFinishReceivingResourceWithName name: String,
                             fromPeer peer: MCPeerID, at localURL: URL?,
                             withError error: Error?) {}
}
