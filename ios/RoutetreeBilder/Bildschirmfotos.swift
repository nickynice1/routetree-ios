// Bildschirmfotos für den App Store -- aufgenommen, nicht gemalt (R120).
//
// WARUM ES DAS GEBEN MUSS. Apple verlangt zweierlei: Bilder der App für
// die Produktseite und je Abonnement ein Prüfbild, das die Kaufseite IN
// der App zeigt. Beides gibt es nur aus einem laufenden Programm -- und
// das läuft nur auf einem Simulator, also nur auf dem Läufer.
//
// WARUM EIN EIGENES ZIEL UND EIN EIGENES SCHEMA. Oberflächenprüfungen
// sind langsam und zerbrechlich: Sie starten die App wirklich, tippen
// wirklich und warten auf Dinge, die noch nicht da sind. Liefen sie im
// Schema `Routetree` mit, zahlte jeder gewöhnliche Bau ihre Zeit und
// jede ihrer Launen -- und der Prüfstand, der heute in Sekunden
// antwortet, wäre der langsamste Teil des Tages. Das Schema `Bilder`
// wird deshalb NUR aufgerufen, wenn jemand Bilder will.
//
// DIE ANMELDUNG KOMMT AUS DER UMGEBUNG. Der Prüfzugang gehört nicht in
// den Quelltext -- er steht als Geheimnis am Lauf und kommt über
// `PRUEF_BENUTZER` und `PRUEF_PASSWORT` herein. Fehlt er, bricht der
// Lauf mit einem klaren Satz ab statt mit einem Bild vom Anmeldefenster.
//
// UND ER BRICHT AUCH AB, WENN DIE ANMELDUNG NICHT KLAPPT. Am 15.09.2026
// lieferte der dritte Anlauf einen grünen Lauf mit einem Foto der
// ANMELDEMASKE: Den Zugang gab es auf dem Server gar nicht, die App
// zeigte „Die Anmeldung gilt nicht mehr." -- und der Durchgang knipste
// munter weiter. Ein Bilderlauf, der die Anmeldemaske fotografiert, ist
// ein Fehlschlag und muss so aussehen.

import XCTest

final class Bildschirmfotos: XCTestCase {

    /// Wie lange auf einen Bildschirm gewartet wird.
    ///
    /// Zwanzig Sekunden, weil der erste Start eines frischen Simulators
    /// alles gleichzeitig tut: App laden, Schrift bauen, Netz fragen.
    /// Fünf wären am Schreibtisch genug und auf dem Läufer zu wenig --
    /// und ein zu knapper Wert sieht später aus wie ein Fehler in der
    /// App.
    private let wartezeit: TimeInterval = 20

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // DIE SPRACHE KOMMT AUS DER UMGEBUNG (30.09.2026).
        //
        // Hier stand fest `(de)`, mit der Begründung: „Ein Simulator
        // auf Englisch lieferte Bilder, die im deutschen Store falsch
        // beschriftet wären." Das stimmte -- und war trotzdem der
        // Grund für einen schlimmeren Fehler:
        //
        // Der US-Store zeigte DIESELBEN DREI DATEIEN wie der deutsche.
        // Ein amerikanischer Trainer sah „Demo-Playbook", „Vorschau /
        // Liste", „Playbooks / Mannschaften". Gemessen am 30.09.2026
        // stand die App dort bei der Suche nach ihrem eigenen Namen
        // auf Platz 14 von 45 -- bei null Bewertungen und einer
        // Produktseite in einer fremden Sprache.
        //
        // Jetzt läuft der Durchgang je Sprache einmal. Ohne Angabe
        // bleibt es bei Deutsch, damit ein Aufruf von Hand tut, was er
        // immer tat.
        //
        // `TEST_RUNNER_` DAVOR IST PFLICHT und wird von xcodebuild
        // abgestreift -- derselbe Weg wie beim Prüfzugang, siehe der
        // Kopf dieser Datei.
        let sprache = ProcessInfo.processInfo
            .environment["BILDER_SPRACHE"] ?? "de"
        app.launchArguments += ["-AppleLanguages", "(\(sprache))",
                                "-AppleLocale", Self.ort(zu: sprache)]
        app.launch()
    }

    /// Welcher Ort zu welcher Sprache gehört.
    ///
    /// **Apple will beides.** `-AppleLanguages` steuert die Texte,
    /// `-AppleLocale` die Zahlen, Daten und Trennzeichen. Wer nur das
    /// erste setzt, bekommt englische Sätze mit deutschen Kommazahlen
    /// -- und auf einer Produktseite fällt genau so etwas auf.
    ///
    /// Eine Tabelle und keine Ableitung: `en` heißt `en_US` und nicht
    /// `en_EN`, `it` heißt `it_IT`. Wer das rechnet, rechnet bei der
    /// ersten Sprache falsch, die nicht so heißt wie ihr Land.
    static func ort(zu sprache: String) -> String {
        [
            "de": "de_DE", "en": "en_US", "es": "es_ES",
            "fr": "fr_FR", "it": "it_IT",
        ][sprache] ?? "en_US"
    }

    /// Der ganze Durchgang: anmelden, durchklicken, unterwegs
    /// fotografieren.
    ///
    /// **Ein Test und nicht fünf.** Jeder Test startet die App neu und
    /// meldet sich neu an; fünf Tests wären fünfmal derselbe Weg und
    /// fünfmal dieselbe Gelegenheit, an der Anmeldung zu scheitern.
    func testBilderFuerDenStore() throws {
        // EIN BILD VOM ANFANG, IMMER. Wenn der Weg irgendwo abbricht,
        // zeigt es, WO -- und beim naechsten Lauf muss niemand raten.
        // Kostet ein PNG und spart eine halbe Stunde Laeuferzeit.
        knipsen("00-start")
        try anmelden()

        // 1. Das Heft -- der erste Eindruck und das, was ein Trainer
        //    täglich sieht.
        knipsen("01-playbooks")

        // 2. Die Playliste des ersten Hefts, als Raster gezeichneter
        //    Spielzüge. Das ist das Bild, das erklärt, wofür es die App
        //    gibt.
        let kachel = app.buttons["playkachel"].firstMatch
        guard schritt("heft-oeffnen", tippt: app.cells.firstMatch,
                      bis: kachel) else { return }
        // Ein Atemzug, damit auch die ÜBRIGEN Kacheln ihre Zeichnung
        // haben. Die erste ist da, die letzte lädt noch -- und ein
        // Raster mit drei fertigen und neun leeren Feldern ist ein
        // schlechteres Bild als eines, das eine Sekunde später entsteht.
        warten(2)
        knipsen("02-plays")

        // 3. EIN SPIELZUG -- und zwar der, den DIESES Konto sieht.
        //
        // Hier stand nur `app.buttons["Abspielen"]`, und „Abspielen"
        // gibt es ausschliesslich im Editor. Der Pruefzugang ist aber
        // ZUSCHAUER (`manage.py pruefzugang` setzt das mit Absicht: Der
        // letzte Vereinsadmin darf sich nicht loeschen, und der Pruefer
        // MUSS die Kontoloeschung testen koennen). Ein Zuschauer landet
        // beim Tippen auf eine Kachel in `PlayAnsicht`, nie im Editor --
        // der Durchgang wartete also auf etwas, das dieses Konto
        // niemals zu sehen bekommt, und brach jedes Mal hier ab.
        //
        // Aufgefallen am 18.09.2026, nachdem die Anmeldung endlich ging:
        // Das Bild zum Fehlschlag zeigte den Spielzug offen und schoen
        // gezeichnet -- die Ansicht stimmte, nur die Erwartung nicht.
        //
        // BEIDE MARKEN, nicht die eine ersetzt: Wer mit einem Konto mit
        // Schreibrecht laeuft, landet weiterhin im Editor, und dann ist
        // „Abspielen" die richtige Marke.
        //
        // UND WARUM `playmenue` ALLEIN NICHT REICHTE. Es sitzt an einem
        // SwiftUI-`Menu`, und das gibt XCUITest nicht als `button`
        // heraus -- `app.buttons["playmenue"]` traf nichts, obwohl das
        // Menue da war. Deshalb steht „Drucken" davor: ein
        // `NavigationLink` mit `Label`, und der IST ein Knopf. Er
        // erscheint ausserdem erst, wenn der Spielzug geladen ist --
        // also genau dann, wenn das Bild etwas taugt.
        guard schritt("play-oeffnen", tippt: kachel,
                      bis: app.buttons["drucken"],
                           app.buttons["abspielen"],
                           app.descendants(matching: .any)["playmenue"]
                               .firstMatch) else { return }
        warten(2)
        knipsen("03-spielzug")
        // ZURUECK UND NACHSEHEN. Ein blankes `zurueck()` stand hier und
        // hat am 30.09.2026 nicht gewirkt: Der Durchgang blieb im
        // Editor und lief dort in ein Menue mit einem einzigen Eintrag.
        guard zurueckBis(kachel, was: "spielzug-schliessen") else {
            return
        }

        // 4. Der Übungsmodus -- das, was die Mannschaft benutzt. Er
        //    hängt im Menü „Mehr" der Playliste, nicht offen in der
        //    Leiste.
        //
        //    NACH DER KENNUNG UND NICHT NACH DER BESCHRIFTUNG. „Mehr"
        //    steht elfmal auf diesem Bildschirm: einmal in der Leiste
        //    und einmal an jeder Kachel. Die Suche danach traf am
        //    15.09.2026 nichts statt elf Dinge, und der Durchgang
        //    endete an einem Menü, das er nie geöffnet hat.
        guard schritt("menue-oeffnen", tippt: app.buttons["mehrmenue"],
                      bis: app.buttons["ueben"]) else { return }
        guard schritt("ueben-oeffnen", tippt: app.buttons["ueben"],
                      bis: app.staticTexts["uebenfrage"])
        else { return }
        warten(2)
        knipsen("04-ueben")
        // Auch hier nachsehen -- derselbe Grund wie oben.
        guard zurueckBis(kachel, was: "ueben-schliessen") else { return }

        // 5. Die Kaufseite -- daraus wird auch das Prüfbild je
        //    Abonnement (R120.2). Der Weg: zurück in die Playbook-
        //    Liste, dort „Konto", und darin „Abonnement verwalten".
        //
        // **BIS R134 FÜHRTE DER WEG ÜBER DIE VEREINSZEILE.** Dort wird
        // seit dem 23.09.2026 nichts mehr gekauft: Eine Apple-ID trägt
        // genau ein Abo, und das gehört dauerhaft zu einem Verein --
        // eine Abo-Zeile je Verein behauptete das Gegenteil.
        //
        // Diese Kopplung ist die unsichtbare: Wer den Weg in der App
        // verlegt, merkt vom Bilderlauf nichts, und der Lauf wird GRÜN
        // mit einem Foto vom Kontoblatt. Genau das ist im September
        // mehrfach passiert. `test_bilderlauf_weg.py` hält beide Enden
        // zusammen.
        // Von der Playliste zurueck in die Playbookliste. Die Marke ist
        // `konto` selbst: Der Knopf steht nur dort, nicht in der
        // Playliste -- also ist er der Beweis, dass wir angekommen
        // sind, und `schritt` darunter faengt ihn dann auch wirklich.
        guard zurueckBis(app.buttons["konto"], was: "playliste-schliessen")
        else { return }
        guard schritt("konto-oeffnen", tippt: app.buttons["konto"],
                      bis: app.buttons["abozeile"].firstMatch)
        else { return }

        // AUF ETWAS WARTEN, DAS ES NUR HIER GIBT.
        //
        // Hier stand der Knopf „Fertig" -- und den trägt auch das
        // Kontoblatt darunter. Er war sofort da, das Foto entstand
        // sofort, und darauf war das Konto zu sehen statt der
        // Kaufseite. „Käufe wiederherstellen" verlangt Apple auf jeder
        // Kaufseite (Richtlinie 3.1.1); `aboseite` gilt auch für die
        // Gestalt ohne hinterlegte Produkte.
        let kaufseite = tippenUndWarten(
            app.buttons["abozeile"].firstMatch,
            bis: app.buttons["kaeufe-wiederherstellen"],
            app.staticTexts["stufenstand"],
            app.otherElements["abonnementseite"],
            app.otherElements["aboseite"],
            app.staticTexts["im Monat für euren Verein"])
        if kaufseite {
            // Der Preis kommt von StoreKit und nicht vom ersten Bildaufbau.
            warten(3)
            knipsen("05-abo")
            return
        }

        // KEINE PROBEN MEHR IN DIESEM BILDSCHIRM. NIE WIEDER.
        //
        // **Der Bilderlauf hat den Prüfzugang gelöscht.** Am 15.09.2026
        // um 21:51 steht im Protokoll des Servers `konto_geloescht`,
        // Grund „Selbstlöschung über die App", davor zweimal
        // `auskunft`. Das war dieser Durchgang.
        //
        // Hier standen vier Proben zur Fehlersuche, die blind in der
        // Kontoansicht getippt haben: die Sprachzeile, der erste
        // Schalter, der erste „Fertig"-Knopf, jeder davon bis zu
        // dreimal. Solange die Trefferflächen kaputt waren, tat das
        // nichts. Mit der Reparatur wurden dieselben Tipps scharf -- und
        // in genau diesem Bildschirm stehen „Meine Daten mitnehmen" und
        // „Konto löschen".
        //
        // Blind tippen ist auf einem Bildschirm mit einem Löschknopf
        // keine Fehlersuche, sondern ein Würfelwurf. Wer hier etwas
        // messen will, misst es an einem Konto, das niemand braucht.
        knipsen("99-kaufseite-oeffnen")
        XCTFail("Die Kaufseite geht nicht auf. Auf dem Schirm: "
                + sichtbares())
    }

    // MARK: - Handgriffe

    /// Der Zugang aus der Umgebung -- mit und ohne den Vorsatz, den
    /// xcodebuild abstreift.
    ///
    /// **`TEST_RUNNER_` ist der Weg hinein.** Der Durchgang läuft auf
    /// dem Simulator und erbt die Umgebung des Läufers nicht; nur
    /// Variablen mit diesem Vorsatz reicht xcodebuild weiter und
    /// entfernt ihn dabei. Gelesen werden beide Schreibweisen, damit
    /// derselbe Test auch am Schreibtisch läuft, wo man ihn von Hand
    /// setzt.
    private func ausDerUmgebung(_ name: String) -> String {
        let umgebung = ProcessInfo.processInfo.environment
        return umgebung[name] ?? umgebung["TEST_RUNNER_" + name] ?? ""
    }

    /// Durch den ersten Start hindurch bis zur Anmeldung.
    ///
    /// **Weil die App nicht bei der Anmeldung anfängt.** Beim ersten
    /// Start fragt sie erst nach der Sprache (als Blatt) und zeigt dann
    /// das Willkommensbild mit drei Wegen hinein. Der erste Versuch am
    /// 15.09.2026 suchte gleich das Feld „Benutzername", fand es nicht
    /// und fotografierte die Sprachwahl -- ein grüner Lauf mit einem
    /// Bild, das niemand im Store sehen will.
    private func durchDenStart() {
        // 1. Die Sprachwahl. Deutsch ist schon angehakt, es fehlt nur
        //    der Knopf.
        _ = tippen(app.buttons["sprachwahl-weiter"])

        // 2. Das Willkommensbild. „Ich habe schon einen Zugang" führt
        //    zur Anmeldung; die beiden anderen Wege legen ein neues
        //    Konto an, und das soll ein Bilderlauf nicht tun.
        _ = tippen(app.buttons["zum-anmelden"])
    }

    private func anmelden() throws {
        let benutzer = ausDerUmgebung("PRUEF_BENUTZER")
        let passwort = ausDerUmgebung("PRUEF_PASSWORT")
        try XCTSkipIf(benutzer.isEmpty || passwort.isEmpty,
                      "Kein Prüfzugang am Lauf: PRUEF_BENUTZER oder "
                      + "PRUEF_PASSWORT fehlt. Am Lauf heissen sie mit "
                      + "Vorsatz TEST_RUNNER_.")

        durchDenStart()

        let feld = app.textFields["feld-benutzername"]
        guard feld.waitForExistence(timeout: wartezeit) else {
            // Schon angemeldet? Dann ist hier nichts zu tun -- aber nur,
            // wenn auch wirklich eine Liste dasteht. Sonst steht der
            // Durchgang irgendwo, und das soll auffallen.
            guard app.cells.firstMatch.waitForExistence(timeout: 5) else {
                XCTFail("Weder Anmeldemaske noch Liste. Auf dem Schirm: "
                        + sichtbares())
                return
            }
            return
        }
        guard schreiben(feld, benutzer) else {
            XCTFail("Der Benutzername kam nicht ins Feld.")
            return
        }

        let geheim = app.secureTextFields["feld-passwort"]
        guard geheim.waitForExistence(timeout: 5) else {
            XCTFail("Kein Passwortfeld auf der Anmeldemaske.")
            return
        }

        // INS PASSWORTFELD ÜBER DIE RETURN-TASTE, NICHT ÜBER EINEN TIPP.
        //
        // **Zweimal daran gescheitert, und beim zweiten Mal an meiner
        // eigenen Prüfung vorbei.** Ein Tipp auf das Geheimfeld setzte
        // den Fokus nicht: Der Benutzername stand da, das Passwortfeld
        // blieb leer, der Server bekam ein leeres Passwort und die App
        // meldete „Die Anmeldung gilt nicht mehr." -- eine Absage, die
        // nach einem falschen Passwort aussieht und keins war.
        //
        // Die eingebaute Prüfung sah das NICHT: Ein leeres `SecureField`
        // meldet als Wert seinen PLATZHALTER („Passwort"), und der ist
        // nicht leer. Sie meldete „gefüllt" und log dabei.
        //
        // Die Maske selbst kennt den Weg: Das Namensfeld trägt
        // `submitLabel(.next)` und springt bei Return ins Passwortfeld
        // (`onSubmit { feld = .passwort }`). Danach tippt
        // `app.typeText` in das, was den Fokus hat -- ohne Tipp, ohne
        // Koordinate, ohne Raten.
        feld.typeText("\n")
        app.typeText(passwort)

        guard tippen(app.buttons["anmelden"]) else {
            XCTFail("Der Anmeldeknopf war nicht antippbar. Auf dem "
                    + "Schirm: " + sichtbares())
            return
        }

        // DER NACHWEIS, DASS ES GEKLAPPT HAT. Ohne ihn lief der
        // Durchgang am 15.09.2026 grün durch die gescheiterte Anmeldung
        // hindurch und lieferte vier Fotos der Anmeldemaske.
        guard app.cells.firstMatch.waitForExistence(timeout: wartezeit) else {
            knipsen("99-anmeldung-gescheitert")
            // WAS IN DEN FELDERN STEHT, GEHÖRT IN DIE MELDUNG.
            //
            // Zweimal hiess es hier nur „Anmeldung gescheitert", und
            // zweimal war die Ursache ein LEERES Passwortfeld -- was
            // auf dem Foto aussieht wie ein falsches Passwort. Steht
            // der Benutzername samt Länge dabei, ist beim nächsten Mal
            // in einer Zeile klar, ob die Zeichen angekommen sind und
            // ob sie im richtigen Feld gelandet sind.
            let name = (feld.value as? String) ?? "(nichts)"
            let geheimwert = (geheim.value as? String) ?? "(nichts)"
            XCTFail("Anmeldung gescheitert. Benutzerfeld: \(name) "
                    + "| Geheimfeld: \(geheimwert.count) Zeichen "
                    + "| Auf dem Schirm: " + sichtbares())
            return
        }
    }

    /// Ein Schritt durch die App: tippen und nachsehen, ob es ankam.
    ///
    /// **Der Kern ist die Wiederholung, und die hat einen Grund.** Ein
    /// Blatt, das gerade hereinfährt, hat seine Knöpfe schon in der
    /// Hierarchie; `exists` ist wahr, `isHittable` ist wahr -- und ein
    /// Tipp darauf verfällt trotzdem, weil die Ansicht noch in
    /// Bewegung ist. Genau das ist am 15.09.2026 auf dem Kontoblatt
    /// passiert: Die Vereinszeile wurde angetippt, die Kaufseite kam
    /// nie, und die Meldung hiess „Die Kaufseite kam nicht" -- richtig,
    /// aber am falschen Ende.
    ///
    /// Deshalb wird nicht das Tippen geprüft, sondern die WIRKUNG: Kam
    /// `marke` nicht, wird noch einmal getippt. Dreimal, dann ist es
    /// kein Zeitproblem mehr, sondern ein Fehler -- und dann fällt der
    /// Durchgang um, mit einem Foto von der Stelle.
    @discardableResult
    private func schritt(_ was: String, tippt ziel: XCUIElement,
                         bis marken: XCUIElement...) -> Bool {
        for _ in 1...3 {
            guard ziel.waitForExistence(timeout: wartezeit),
                  antippbar(ziel) else { break }
            ziel.tap()
            if let erste = marken.first,
               erste.waitForExistence(timeout: wartezeit) { return true }
            // Die weiteren Marken nur kurz: Sie sind der Fall, in dem
            // derselbe Bildschirm anders aussieht, nicht der Fall, in
            // dem er noch lädt.
            if marken.dropFirst().contains(where: {
                $0.waitForExistence(timeout: 3) }) { return true }
            warten(1)
        }
        knipsen("99-" + was)
        // DEN GANZEN BAUM MITGEBEN, nicht nur die sichtbaren Texte.
        //
        // Am 15.09.2026 stand dreimal dieselbe Frage im Raum: Ist das
        // Blatt gar nicht aufgegangen, oder sieht es nur anders aus, als
        // ich erwarte? Ein Foto beantwortet das nicht -- der Baum schon,
        // und er kostet nichts ausser einem Anhang.
        let baum = XCTAttachment(string: app.debugDescription)
        baum.name = "99-" + was + "-baum"
        baum.lifetime = .keepAlways
        add(baum)
        // UND IN DIE MELDUNG, nicht nur als Anhang. `xcparse screenshots`
        // holt nur Bilder aus dem Ergebnisbuendel -- der Anhang blieb
        // darin liegen, und der Lauf kostete eine halbe Stunde ohne die
        // eine Auskunft, wegen der er lief.
        //
        // EINZEILIG, und das ist der zweite Anlauf. Der erste schrieb
        // den Baum mit Zeilenumbruechen in die Meldung; GitHub schneidet
        // eine `::error`-Zeile am ersten Umbruch ab, und im Protokoll
        // stand alles bis zum Wort „Baum". Die Auskunft war da und
        // trotzdem weg -- noch eine halbe Stunde.
        //
        // NUR DIE KNOEPFE, nicht der ganze Baum. Der Baum eines
        // SwiftUI-Bildschirms sind Hunderte verschachtelter `Other`;
        // neuntausend Zeichen davon endeten mitten im Hauptfenster, und
        // das Blatt, um das es ging, kam gar nicht mehr vor. Was hier
        // gebraucht wird, ist die Liste der Knoepfe mit Kennung,
        // Beschriftung und ob sie antippbar sind.
        let knoepfe = app.buttons.allElementsBoundByIndex
            .map { "[\($0.identifier)|\($0.label)|"
                   + ($0.isHittable ? "tippbar]" : "verdeckt]") }
            .joined(separator: " ")
            .prefix(5000)
        XCTFail("\(was): hat nicht geklappt. Auf dem Schirm: "
                + sichtbares() + " ||| KNOEPFE: " + knoepfe)
        return false
    }

    /// Tippen und nachsehen, ob eine der Marken kommt -- dreimal.
    ///
    /// Dasselbe wie `schritt`, nur ohne das Umfallen am Ende: für die
    /// Stellen, an denen der Durchgang nach einem Fehlschlag noch etwas
    /// zu tun hat.
    private func tippenUndWarten(_ ziel: XCUIElement,
                                 bis marken: XCUIElement...) -> Bool {
        for versuch in 1...3 {
            guard ziel.waitForExistence(timeout: wartezeit),
                  antippbar(ziel) else { return false }
            if versuch == 2 {
                // ÜBER DIE STELLE STATT ÜBER DAS ELEMENT.
                //
                // `element.tap()` schickt den Tipp an das
                // Bedienungshilfen-Element. Wenn dessen Rahmen nicht
                // dort liegt, wo die Ansicht wirklich hinhört, geht der
                // Tipp ins Leere -- und zwar lautlos, denn das Element
                // gibt es ja. Ein Tipp auf die Mitte des Rahmens nimmt
                // den anderen Weg.
                ziel.coordinate(withNormalizedOffset:
                                    CGVector(dx: 0.5, dy: 0.5)).tap()
            } else {
                ziel.tap()
            }
            if let erste = marken.first,
               erste.waitForExistence(timeout: wartezeit) { return true }
            if marken.dropFirst().contains(where: {
                $0.waitForExistence(timeout: 3) }) { return true }
            warten(1)
        }
        return false
    }

    /// In ein KLARTEXTFELD schreiben und nachsehen, ob es ankam.
    ///
    /// **Nur für Klartext, und das ist der Punkt.** Hier stand
    /// „nicht mehr der Platzhalter" als Beweis, dass etwas im Feld
    /// steht -- und für ein Geheimfeld ist das falsch: Ein leeres
    /// `SecureField` meldet als Wert seinen Platzhalter NICHT, sondern
    /// einen leeren Text, und ein gefülltes meldet Punkte. Die Prüfung
    /// gab „gefüllt" zurück, während das Feld leer war, und der
    /// Durchgang meldete danach eine Anmeldung, die nie eine war.
    ///
    /// Ein Klartextfeld gibt seinen Inhalt heraus. Dort lässt sich
    /// vergleichen, was drinsteht -- und nur dort.
    /// Schreibt einen Text in ein Feld -- und zwar GENAU einmal.
    ///
    /// **Der Fund vom 30.09.2026.** Im Benutzerfeld stand
    /// `apple-prueferapple-pruefer`, und die Anmeldung scheiterte mit
    /// „Die Anmeldung gilt nicht mehr." -- einer Absage, die nach
    /// einem falschen Passwort aussieht und keins war.
    ///
    /// Zwei Fehler haben zusammengewirkt:
    ///
    /// 1. Der Wiederholungsversuch tippte in ein Feld, das er nicht
    ///    geleert hat. `typeText` haengt an, es ersetzt nicht.
    /// 2. Geprueft wurde mit `contains`. Ein verdoppelter Wert ENTHAELT
    ///    den Text -- die Pruefung meldete Erfolg und log dabei.
    ///
    /// Beides ist behoben: geleert wird vor jedem Versuch, und
    /// verglichen wird auf GLEICHHEIT. Ein zu langer Wert faellt damit
    /// genauso auf wie ein zu kurzer.
    private func schreiben(_ feld: XCUIElement, _ text: String) -> Bool {
        for _ in 1...3 {
            guard feld.waitForExistence(timeout: wartezeit),
                  antippbar(feld) else { return false }
            feld.tap()
            leeren(feld)
            feld.typeText(text)
            if ((feld.value as? String) ?? "") == text { return true }
            warten(1)
        }
        return false
    }

    /// Raeumt ein Feld leer, Zeichen fuer Zeichen.
    ///
    /// **Ein leeres Textfeld meldet als Wert seinen PLATZHALTER**, nicht
    /// den leeren Text -- dieselbe Falle, die beim Passwortfeld schon
    /// einmal zugeschlagen hat. Wer den Platzhalter fuer Inhalt haelt,
    /// schickt genauso viele Ruecktasten los, wie der Platzhalter lang
    /// ist; die gehen ins Leere, aber sie kosten Zeit und sie verwirren
    /// beim Lesen des Protokolls.
    private func leeren(_ feld: XCUIElement) {
        guard let jetzt = feld.value as? String, !jetzt.isEmpty,
              jetzt != feld.placeholderValue
        else { return }
        feld.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                             count: jetzt.count))
    }

    /// Warten, bis ein Element wirklich antippbar ist.
    private func antippbar(_ element: XCUIElement) -> Bool {
        if element.isHittable { return true }
        let bedingung = expectation(
            for: NSPredicate(format: "isHittable == true"),
            evaluatedWith: element)
        return XCTWaiter().wait(for: [bedingung], timeout: 10) == .completed
    }

    /// Tippt, wenn es das Element gibt. Zurück kommt, ob getippt wurde.
    ///
    /// Für die Stellen, an denen die Wirkung kein eigenes Element hat
    /// -- etwa die Anmeldung, wo der Nachweis danach separat kommt.
    @discardableResult
    private func tippen(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 6), antippbar(element) else {
            return false
        }
        element.tap()
        return true
    }

    /// Zurueck -- ueber die Kennung, sonst ueber die Stelle.
    ///
    /// **Die Stelle allein reicht nicht.** Der Editor versteckt den
    /// System-Zurueckknopf (`navigationBarBackButtonHidden`) und setzt
    /// einen eigenen; `element(boundBy: 0)` traf am 30.09.2026 das
    /// Dreipunktmenue statt des Pfeils. Der Durchgang blieb im Editor
    /// und bekam ein Menue mit einem einzigen Eintrag.
    ///
    /// Ueber die Beschriftung geht es nicht: „Zurück", „Atrás",
    /// „Indietro".
    ///
    /// Der Rueckfall auf die Stelle BLEIBT -- die meisten Blaetter
    /// haben den gewoehnlichen Systemknopf, und der traegt keine
    /// eigene Kennung.
    private func zurueck() {
        let benannt = app.buttons["zurueck"].firstMatch
        if benannt.exists, benannt.isHittable { benannt.tap(); return }
        let zurueck = app.navigationBars.buttons.element(boundBy: 0)
        if zurueck.exists, zurueck.isHittable { zurueck.tap() }
    }

    /// Zurueck, und NACHSEHEN, ob es gewirkt hat.
    ///
    /// **Der Fund vom 30.09.2026.** Nach dem Bild vom Spielzug stand
    /// hier ein blankes `zurueck()`: tippen und hoffen. Es hat nicht
    /// gewirkt -- der Durchgang blieb im Editor, tippte dort auf das
    /// naechste Ding und bekam ein Menue mit einem einzigen Eintrag
    /// („Report"). Der Fehlschlag wurde dann dem Uebungsmodus
    /// angelastet, der nie an der Reihe war.
    ///
    /// **Ein Schritt, der nicht nachsieht, verschiebt seinen Fehler
    /// auf den naechsten.** Das ist dieselbe Lehre wie bei der
    /// Anmeldung, nur eine Ebene tiefer: Dort stand „geklappt", weil
    /// das Feld den Text ENTHIELT; hier stand „zurueck", weil getippt
    /// wurde.
    ///
    /// Bis zu drei Anlaeufe: Ein Blatt, das sich gerade schliesst,
    /// verschluckt den ersten Tipp.
    @discardableResult
    private func zurueckBis(_ marke: XCUIElement, was: String) -> Bool {
        for _ in 1...3 {
            if marke.waitForExistence(timeout: 3) { return true }
            zurueck()
            if marke.waitForExistence(timeout: wartezeit) { return true }
        }
        knipsen("99-" + was)
        let baum = XCTAttachment(string: app.debugDescription)
        baum.name = "elementbaum-" + was
        baum.lifetime = .keepAlways
        add(baum)
        XCTFail("Zurueck hat nicht gewirkt (\(was)). Auf dem Schirm: "
                + sichtbares())
        return false
    }

    /// Stillhalten, damit ein Bildschirm fertig wird.
    ///
    /// **Ungern, aber hier richtig.** Auf ein Element zu warten sagt
    /// „der Bildschirm ist da"; es sagt nicht „er ist fertig gezeichnet".
    /// Zwölf Kachelvorschauen kommen einzeln vom Server, und der Preis
    /// kommt von StoreKit -- beides hat kein Element, dessen
    /// Erscheinen das Ende anzeigt.
    private func warten(_ sekunden: TimeInterval) {
        _ = XCTWaiter.wait(for: [expectation(description: "ruhig")],
                           timeout: sekunden)
    }

    /// Was gerade auf dem Schirm steht, als ein Satz.
    ///
    /// Für Fehlermeldungen. „Anmeldung gescheitert" allein schickt
    /// jemanden auf den Läufer; „Anmeldung gescheitert, auf dem Schirm
    /// steht ‚Die Anmeldung gilt nicht mehr.'" beantwortet die Frage
    /// gleich mit.
    private func sichtbares() -> String {
        let texte = app.staticTexts.allElementsBoundByIndex
            .prefix(20)
            .map(\.label)
            .filter { !$0.isEmpty }
        return texte.isEmpty ? "(nichts lesbar)" : texte.joined(separator: " | ")
    }

    /// Ein Bild an den Lauf hängen.
    ///
    /// `keepAlways`, weil ein Anhang sonst nur bei einem FEHLSCHLAG
    /// aufbewahrt wird -- und dieser Lauf soll ja gelingen.
    private func knipsen(_ name: String) {
        let bild = XCUIScreen.main.screenshot()
        let anhang = XCTAttachment(screenshot: bild)
        anhang.name = name
        anhang.lifetime = .keepAlways
        add(anhang)
    }
}
