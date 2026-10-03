// Der Knopf, der ein Blatt schliesst -- als Häkchen (R65).
//
// Niklas am 03.09.2026, dreimal nacheinander: „Mach doch ein häckchen
// als Button" -- „Vielleicht auch ein Häkchen" -- „Alle fertig Button
// bitte zu häckchen Button".
//
// DER ANLASS WAR EIN ABGESCHNITTENES WORT. Auf seinem Bildschirmfoto
// vom Aufstellungsblatt stand „Fe…". Dieselbe Enge wie bei R57, wo aus
// „Sichern" ein „Sic…" wurde: Die Werkzeugleiste von iOS 26 gibt
// weniger Platz her, und deutsche Wörter sind lang.
//
// WARUM EIN HÄKCHEN UND KEIN GEKÜRZTES WORT. „Fe…" heisst nichts. Ein
// Häkchen heisst „das war es" -- in iOS, in Android, auf jedem
// Formular. Es ist die Stelle, an der ein Zeichen mehr sagt als ein
// Wort, weil es eine EINGEFÜHRTE Bedeutung hat.
//
// UND WARUM DAS KEIN RÜCKSCHRITT HINTER B1 IST. Die Untersuchung, um
// die es dort ging (Sadana 2018), misst, ob Menschen eine Funktion
// FINDEN. Dieser Knopf steht oben rechts, wo in jeder iOS-App der
// Abschluss steht; gefunden wird er dort, nicht wegen seines Wortes.
// Was das Wort trug, trägt jetzt die Vorlese-Beschriftung.

import SwiftUI

/// „Fertig", als Häkchen.
///
/// Die Beschriftung ist ein Wort und bleibt es -- sie steht nur nicht
/// mehr auf dem Schirm, sondern im Vorleser. Ohne sie wäre der Knopf
/// für VoiceOver ein Zeichen ohne Zweck.
struct Fertigknopf: View {
    /// Was daneben gesagt wird. Vorgabe „Fertig"; „Ordnen beenden"
    /// braucht ein eigenes Wort, weil es einen MODUS beendet und nicht
    /// ein Blatt.
    var name: String = String(localized: "Fertig")
    let tun: () -> Void

    var body: some View {
        Button(action: tun) {
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                // 44 Punkte, auch wenn das Häkchen kleiner ist: Apples
                // eigene Vorgabe, und ein Knopf am oberen Rand wird mit
                // dem Daumen ungenauer getroffen als einer in der Mitte
                // (Hoober 2017).
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(name))
    }
}

/// „Abbrechen", als Kreuz (R94).
///
/// Niklas am 09.09.2026 mit einem Bild der Play-Leiste, zweimal
/// hintereinander: „Keine Schrift Buttons bitte". Links stand dort
/// „Ab…" -- dieselbe Enge wie bei „Sic…" (R57) und „Fe…" (R65), nur an
/// der dritten Stelle.
///
/// Ein Kreuz heisst abbrechen, in iOS wie überall sonst. „Ab…" heisst
/// nichts. Das Wort bleibt für den Vorleser.
struct Abbruchknopf: View {
    var name: String = String(localized: "Abbrechen")
    let tun: () -> Void

    var body: some View {
        Button(action: tun) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(name))
    }
}

/// „Bearbeiten", als Stift (R97).
///
/// Niklas am 09.09.2026, mit einem Bild der Playansicht: „Überall ein
/// bearbeiten Symbol". Auf dem Bild stand oben rechts „Bearb…" -- neben
/// einem Titel wie „#32 Twins LT / Sweep RT" bleibt für ein
/// elfbuchstabiges Wort kein Platz.
///
/// `square.and.pencil` und nicht `pencil`: Das ist in iOS das Zeichen
/// für „hier etwas ändern oder verfassen", und es steht in Mail, Notizen
/// und Erinnerungen an genau dieser Stelle. Ein blosser Stift bedeutet
/// dort das Zeichenwerkzeug.
///
/// **Nur das Zeichen und kein Knopf.** Mal sitzt es in einem `Button`,
/// mal in einem `NavigationLink` -- was beim Tippen passiert, entscheidet
/// die Ansicht. Das Wort geht als Vorlese-Beschriftung mit, damit der
/// Knopf für einen blinden Trainer nicht ein Zeichen ohne Zweck ist.
struct Bearbeitenzeichen: View {
    var name: String = String(localized: "Bearbeiten")

    var body: some View {
        Image(systemName: "square.and.pencil")
            .font(.body.weight(.semibold))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(name))
    }
}

/// Warum ein grosser Knopf `.contentShape(Rectangle())` braucht (R124).
///
/// **Niklas, 23.09.2026:** „bei jetzt buchen muss der komplette button
/// tippbar sein und nicht nur der text."
///
/// `.frame(maxWidth: .infinity)` macht einen Knopf BREIT, aber nicht
/// treffbar. SwiftUI prüft den Treffer an der Form des INHALTS, und der
/// Inhalt eines `Text` sind die Buchstaben. Die Farbfläche drumherum
/// kommt aus `.paarung()` und ist Anstrich, keine Schaltfläche. Auf
/// einem Knopf über die ganze Breite ist der tote Rand damit breiter
/// als das Wort in der Mitte.
///
/// **Warum das so schwer auffällt:** Es funktioniert ja. Wer die Mitte
/// trifft, merkt nie etwas; wer danebentippt, hält es für sein eigenes
/// Ungeschick und tippt noch einmal. Erst wer es nebeneinander sieht,
/// erkennt das Muster -- und genau deshalb steht es hier und nicht in
/// vier einzelnen Kommentaren.
///
/// **Das Häkchen oben macht es seit R65 richtig** (`minWidth: 44` und
/// `contentShape`), die vier grossen Knöpfe taten es bis heute nicht:
/// Kaufen, Anmelden, Willkommen und Weiter. `test_knopfflaeche.py` hält
/// es fest.
///
/// Diese Hülle ist Dokumentation und kein Bauteil -- die vier Knöpfe
/// bringen ihre eigene Beschriftung mit (Ladeanzeige, wechselnder
/// Text), und ein gemeinsamer Bauteil hätte sie alle gleichmachen
/// müssen. Gemeinsam ist ihnen die REGEL, nicht die Gestalt.
enum Hauptknopfflaeche {
    /// Apples eigene Vorgabe für die kleinste Trefferfläche.
    static let mindestens: CGFloat = 44
}
