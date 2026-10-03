import Foundation

/// Der Zugang zum Server. Eine Stelle, nicht in jeder Ansicht eine eigene.
///
/// **Was hier NICHT passiert:** Es wird nie eine Quittung, ein Abo oder
/// ein Recht lokal ausgewertet. Was jemand darf, sagt der Server
/// (ADR-0006). Die App zeigt es nur an.
enum Server {

    /// Die Zieladresse. Aus dem Info.plist überschreibbar, damit sich ein
    /// Testserver ansprechen lässt, ohne den Code anzufassen.
    ///
    /// **Es muss die ENDGÜLTIGE Adresse sein, keine, die weiterleitet.**
    /// Hier stand bis zum 28.08.2026 `https://playbook.afcv-mv.de`. Diese
    /// Adresse gibt es noch, sie antwortet aber mit `301` auf
    /// `https://routetree.de`. Ein `URLSession` folgt einer 301 --  und
    /// macht dabei aus einem `POST` ein `GET` und wirft den Rumpf weg.
    /// Das ist kein Fehler der Bibliothek, sondern altes HTTP-Verhalten.
    ///
    /// Die Folge war unsichtbar und vollständig: **Jedes Schreiben aus
    /// der App kam als `GET` an** und bekam `405 Method Not Allowed`.
    /// Lesen ging weiter, weil ein `GET` ein `GET` bleibt -- deshalb sah
    /// die App gesund aus. Aufgefallen ist es an der Anmeldung mit
    /// Google: Fenster auf, Konto gewählt, Fenster zu, und dann nichts.
    /// Im Serverprotokoll stand `GET /api/v1/auth/fremd/ 405`, obwohl im
    /// Swift-Code `methode: "POST"` steht.
    ///
    /// `umgeleitet(_:nach:)` unten sorgt dafür, dass so etwas nie wieder
    /// still passiert.
    static var basis: URL {
        if let text = Bundle.main.object(forInfoDictionaryKey: "RoutetreeServer") as? String,
           let eigene = URL(string: text) {
            return eigene
        }
        return URL(string: "https://routetree.de")!
    }

    /// Fehler, die der Aufrufer unterscheiden muss.
    ///
    /// Bewusst wenige: Wer zwanzig Fälle hat, behandelt neunzehn davon
    /// gleich und den zwanzigsten falsch.
    enum Fehler: LocalizedError {
        /// Nicht angemeldet oder Token abgelaufen. Der einzige Fall, in
        /// dem die App selbst etwas tun kann: erneuern oder abmelden.
        case abgemeldet
        /// Gebremst, mit der Wartezeit in Sekunden, falls der Server sie nennt.
        case gebremst(sekunden: Int?)
        /// Alles andere, mit dem Text des Servers.
        ///
        /// **`rumpf` trägt die Antwort mit, und zwar seit B12.** Vorher
        /// blieb vom Rumpf nur der eine Satz unter `fehler` übrig, und
        /// alles Weitere fiel hier weg. Zwei Stellen haben darunter
        /// gelitten, beide unbemerkt: Die Absage an der Grenze der Demo
        /// enthält den Abo-Vorschlag (A3), und die Absage eines
        /// Formulars enthält, an WELCHEM Feld es hakte (B12). Ohne
        /// beides zeigt die App einen Satz und keinen Weg -- und der
        /// Satz steht dann über einem Feld, das in Ordnung ist.
        ///
        /// Roh und nicht entschlüsselt: Diese Schicht weiß nicht, was in
        /// einer Absage steht, und soll es nicht wissen.
        case server(text: String, lage: Int, rumpf: Data?)
        case netz(Error)

        var errorDescription: String? {
            switch self {
            case .abgemeldet:
                return String(localized: "Die Anmeldung gilt nicht mehr.")
            case .gebremst(let sekunden):
                if let s = sekunden {
                    return String(localized: """
                        Zu viele Versuche. Bitte \(max(1, s / 60)) Minuten \
                        warten.
                        """)
                }
                return String(localized:
                    "Zu viele Versuche. Bitte kurz warten.")
            case .server(let text, _, _):
                return text
            case .netz:
                // Absichtlich ohne technische Einzelheiten: „Der Server
                // ist nicht erreichbar" hilft; NSURLErrorDomain -1009 nicht.
                return String(localized: "Keine Verbindung zum Server.")
            }
        }
    }

    /// Eine Anfrage, fertig verpackt.
    ///
    /// `token` wird durchgereicht statt hier gelesen: Diese Schicht kennt
    /// keinen Zustand. Wer sich anmeldet, hat noch keins, und wer
    /// erneuert, braucht ein anderes als das laufende.
    static func anfrage(
        _ weg: String,
        methode: String = "GET",
        rumpf: [String: Any]? = nil,
        token: String? = nil,
        annehmen: String = "application/json",
        wartezeit: TimeInterval = 20
    ) throws -> URLRequest {
        guard let ziel = URL(string: weg, relativeTo: basis) else {
            throw Fehler.server(
                text: String(localized: "Ungültige Adresse: \(weg)"),
                lage: 0, rumpf: nil)
        }
        var anfrage = URLRequest(url: ziel)
        anfrage.httpMethod = methode
        // Die Wartezeit ist einstellbar, weil eine davon aus der Reihe
        // fällt: Ein Bogen mit vierzig Playcards entsteht auf dem Server
        // Diagramm für Diagramm und braucht länger als zwanzig Sekunden
        // (B10). Ein Abbruch dabei sieht aus wie „kein Netz", und der
        // Trainer versucht es in der Umkleide noch dreimal.
        anfrage.timeoutInterval = wartezeit
        anfrage.setValue(annehmen, forHTTPHeaderField: "Accept")
        if let token {
            anfrage.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let rumpf {
            anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
            anfrage.httpBody = try JSONSerialization.data(withJSONObject: rumpf)
        }
        return anfrage
    }

    /// Eine Anfrage mit einer DATEI darin (R33).
    ///
    /// **Warum das ein eigener Bauweg ist und kein Feld in `anfrage`.**
    /// Ein Bild geht nicht durch ein JSON-Feld. base64 wäre der
    /// naheliegende Ausweg und der falsche: Es bläht um ein Drittel
    /// auf, braucht eine eigene Größenrechnung, und der Rumpf landet
    /// als Textblock in jedem Protokoll. Multipart ist die Art, in der
    /// auch ein Browser Dateien schickt -- und damit kommt das Bild auf
    /// dem Server durch DASSELBE Formular wie dort.
    ///
    /// **Die Grenze steht nicht hier.** Was ein Logo sein darf, sagt
    /// der Server (`TeamForm`). Eine Zahl in Swift wäre eine zweite
    /// Wahrheit und beim nächsten Verschieben die falsche. Was die App
    /// tut, ist etwas anderes: Sie verkleinert vorher (siehe
    /// `Bildpaket`), damit ein Foto aus der Mediathek gar nicht erst in
    /// die Nähe der Grenze kommt.
    static func anfrageMitDatei(
        _ weg: String,
        feld: String,
        daten: Data,
        dateiname: String,
        typ: String,
        felder: [String: String] = [:],
        methode: String = "POST",
        token: String? = nil,
        wartezeit: TimeInterval = 60
    ) throws -> URLRequest {
        var anfrage = try Self.anfrage(weg, methode: methode, token: token,
                                       wartezeit: wartezeit)
        // Die Grenze muss in den Daten NICHT vorkommen. Eine UUID kommt
        // in einem Bild nicht vor; eine feste Zeichenkette könnte es,
        // und dann bricht der Rumpf mittendrin ab -- ein Fehler, der
        // nur bei einem von tausend Bildern auftritt und deshalb nie
        // reproduzierbar ist.
        let grenze = "----routetree-\(UUID().uuidString)"
        anfrage.setValue("multipart/form-data; boundary=\(grenze)",
                         forHTTPHeaderField: "Content-Type")

        var rumpf = Data()
        func schreibe(_ text: String) {
            rumpf.append(Data(text.utf8))
        }
        // ZUERST die Textfelder, dann die Datei. Dem Server ist die
        // Reihenfolge gleich -- aber sie sortiert zu halten macht einen
        // mitgeschnittenen Rumpf lesbar, und genau den schaut man an,
        // wenn ein Upload nicht ankommt.
        //
        // Nach Namen sortiert, damit zwei gleiche Anfragen denselben
        // Rumpf ergeben: Ein Woerterbuch hat keine Reihenfolge.
        for (name, wert) in felder.sorted(by: { $0.key < $1.key }) {
            schreibe("--\(grenze)\r\n")
            schreibe("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            schreibe("\(wert)\r\n")
        }
        schreibe("--\(grenze)\r\n")
        schreibe("Content-Disposition: form-data; name=\"\(feld)\";"
                 + " filename=\"\(dateiname)\"\r\n")
        schreibe("Content-Type: \(typ)\r\n\r\n")
        rumpf.append(daten)
        schreibe("\r\n--\(grenze)--\r\n")
        anfrage.httpBody = rumpf
        return anfrage
    }

    /// Führt aus und entschlüsselt -- oder wirft einen der Fälle oben.
    static func hole<T: Decodable>(_ anfrage: URLRequest, als: T.Type) async throws -> T {
        try await holeMitRumpf(anfrage, als: T.self).wert
    }

    /// Dasselbe, gibt aber die Antwort MIT heraus.
    ///
    /// **Gebraucht für den Vorrat (R14).** Auf dem Gerät liegt der
    /// Rumpf und nicht das Modell -- so geht die Kopie am Platz durch
    /// genau dieselbe Entschlüsselung wie eine frische Antwort, und ein
    /// Feld, das die App nicht schreiben kann, kann auch nicht falsch
    /// abgelegt werden.
    ///
    /// Es ist DIESELBE Funktion und keine zweite: `hole` ruft sie auf.
    /// Zwei Wege, eine Antwort zu lesen, wären zwei Gelegenheiten, sie
    /// verschieden zu lesen.
    static func holeMitRumpf<T: Decodable>(
        _ anfrage: URLRequest, als: T.Type
    ) async throws -> (wert: T, rumpf: Data) {
        let (daten, antwort) = try await ausfuehren(anfrage)
        do {
            return (try entschluessler.decode(T.self, from: daten), daten)
        } catch {
            throw Fehler.server(
                text: String(localized:
                    "Die Antwort des Servers war nicht lesbar."),
                lage: (antwort as? HTTPURLResponse)?.statusCode ?? 0,
                rumpf: daten)
        }
    }

    /// Führt aus, ohne eine Antwort zu erwarten (etwa beim Abmelden).
    @discardableResult
    static func ausfuehren(_ anfrage: URLRequest) async throws -> (Data, URLResponse) {
        let daten: Data
        let antwort: URLResponse
        do {
            (daten, antwort) = try await URLSession.shared.data(for: anfrage)
        } catch {
            throw Fehler.netz(error)
        }

        guard let http = antwort as? HTTPURLResponse else {
            throw Fehler.server(
                text: String(localized: "Unerwartete Antwort."),
                lage: 0, rumpf: daten)
        }

        // VOR der Prüfung der Lage, nicht danach: Eine verschluckte
        // Umleitung meldet sich als `405` oder `400`, und wer diesen
        // Text liest, sucht den Fehler in der Schnittstelle statt in
        // der Adresse. Genau das hat am 28.08.2026 einen halben Tag
        // gekostet.
        if Self.umgeleitet(anfrage, nach: http.url) {
            throw Fehler.server(
                text: String(localized:
                    "Die App spricht mit einer veralteten Serveradresse. Bitte aktualisiere sie im App Store."),
                lage: http.statusCode, rumpf: daten)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw fehlerAus(http: http, daten: daten)
        }
        return (daten, antwort)
    }

    /// Kam die Antwort von einer ANDEREN Adresse als der gefragten?
    ///
    /// Nur dann ist unterwegs eine Umleitung passiert, und nur bei einem
    /// `POST`, `PATCH` oder `DELETE` ist sie gefährlich: Dort wirft
    /// `URLSession` beim Folgen Methode und Rumpf weg. Ein `GET`
    /// überlebt jede Umleitung unbeschadet und darf sie behalten --
    /// sonst zerbräche jeder Bildabruf an einem Schrägstrich zu viel.
    ///
    /// Eigene Funktion und ohne Netz, damit ein Test sie messen kann.
    /// Der Fall selbst ist im Test nicht herstellbar; die Regel schon.
    static func umgeleitet(_ anfrage: URLRequest, nach ziel: URL?) -> Bool {
        guard (anfrage.httpMethod ?? "GET") != "GET",
              let ziel, let gefragt = anfrage.url
        else { return false }
        return ziel.absoluteString != gefragt.absoluteString
    }

    private static func fehlerAus(http: HTTPURLResponse, daten: Data) -> Fehler {
        switch http.statusCode {
        case 401:
            return .abgemeldet
        case 429:
            // `Retry-After` steht in Sekunden -- der Server schickt ihn,
            // also raten wir nicht.
            let kopf = http.value(forHTTPHeaderField: "Retry-After")
            return .gebremst(sekunden: kopf.flatMap { Int($0) })
        default:
            let text = (try? JSONSerialization.jsonObject(with: daten) as? [String: Any])?
                .flatMap { $0["fehler"] as? String }
                ?? String(localized:
                    "Der Server hat abgelehnt (\(http.statusCode)).")
            return .server(text: text, lage: http.statusCode, rumpf: daten)
        }
    }

    static let entschluessler: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { entschluessler in
            let text = try entschluessler.singleValueContainer()
                .decode(String.self)
            guard let zeit = Zeitstempel.lesen(text) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: entschluessler.codingPath,
                    debugDescription: "Kein Zeitstempel: \(text)"))
            }
            return zeit
        }
        return d
    }()
}

/// Zeitangaben des Servers lesen -- **mit Sekundenbruchteilen**.
///
/// **Warum das nicht `.iso8601` sein kann.** Djangos `isoformat()`
/// schreibt Mikrosekunden, sobald welche da sind, und bei `auto_now` sind
/// immer welche da: `2026-08-25T05:58:53.123456+00:00`. Foundations
/// `.iso8601` liest genau das NICHT -- es kennt nur ganze Sekunden und
/// wirft. Und weil die Entschlüsselung einer Antwort auf einmal
/// geschieht, fällt damit nicht ein Datum aus, sondern die ganze Liste:
/// Die App zeigt „Die Antwort des Servers war nicht lesbar", und zwar
/// erst auf dem Gerät.
///
/// Gefunden in B9 beim Kader, wo „dabei seit" das erste Datum ist, das
/// jemand liest. Die Playbook-Liste trägt seit B2 dasselbe Feld.
///
/// **Warum abgeschnitten und nicht mit `.withFractionalSeconds`.** Weil
/// dessen Verhalten bei sechs Nachkommastellen von der Fassung des
/// Betriebssystems abhängt -- drei Stellen liest es sicher, sechs je
/// nachdem. Ein Zeitstempel, den das eine Gerät liest und das andere
/// nicht, ist schlimmer als gar keine Bruchteile. Die Bruchteile werden
/// hier deshalb abgeschnitten: Angezeigt wird ohnehin ein Tag.
enum Zeitstempel {

    static let leser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func lesen(_ text: String) -> Date? {
        if let zeit = leser.date(from: text) { return zeit }
        return leser.date(from: ohneBruchteile(text))
    }

    /// Schneidet `.123456` heraus -- und nur das. Ein Punkt ohne Ziffern
    /// dahinter bleibt stehen, damit aus einem kaputten Text nicht durch
    /// Wegkürzen ein gültiger wird.
    static func ohneBruchteile(_ text: String) -> String {
        guard let punkt = text.firstIndex(of: ".") else { return text }
        var ende = text.index(after: punkt)
        while ende < text.endIndex, text[ende].isNumber {
            ende = text.index(after: ende)
        }
        guard ende > text.index(after: punkt) else { return text }
        return String(text[text.startIndex..<punkt]) + String(text[ende...])
    }
}
