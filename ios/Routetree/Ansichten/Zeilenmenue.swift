// Ein sichtbarer, beschrifteter Weg zu den Handgriffen einer Zeile (B1).
//
// WARUM ES DAS GIBT. Am 01.09.2026 hat Cyell die Löschfunktion für Plays
// nicht gefunden -- sie lag auf einer Wischgeste. Die Abhilfe war
// zunächst ein Kontextmenü auf langes Drücken, und das war keine:
//
//   Sadana, Agnihotri und Stasko haben 2018 mit 16 Personen ohne
//   Einweisung gemessen, wer eine Funktion findet.
//
//     Menü, sichtbarer Hinweis ......... 14 von 16
//     Wischgeste, kein Hinweis ..........  1 von 16
//     zusammengesetzte Geste ............  0 von 16
//
// Langes Drücken steht in derselben Spalte wie die Wischgeste. Ein
// zweiter unsichtbarer Weg neben dem ersten ist keine Lösung.
//
// Apple sagt es als Regel (HIG „Gestures"): eine Geste darf „not the
// only way to perform an important action" sein. WCAG 2.5.1 ist
// **Stufe A**, und das Understanding-Dokument zu 2.5.7 sagt
// ausdrücklich, der Zweitweg dürfe „not exclusively rely on a
// path-based gesture" -- eine zweite Geste zählt also nicht.
//
// DIE WISCHGESTE BLEIBT. Bragdon und andere haben 2011 gemessen, dass
// gelernte Gesten am Spielfeldrand überlegen sind: Sie zwangen die
// Nutzer nur in 3,5 Prozent der Fälle zum Hinschauen, Knöpfe in 98,8
// Prozent. Für den, der sie kennt, ist der Wisch der schnellste Weg.
// Er darf nur nicht der einzige sein.

import SwiftUI

/// Der sichtbare Knopf am Ende einer Listenzeile.
///
/// **NUR DAS ZEICHEN, SEIT R72.** Niklas am 03.09.2026, an drei
/// Stellen nacheinander: „Ohne „mehr" nur die 3 Punkte bitte" --
/// „Hier genauso" -- „Hier auch".
///
/// **Das nimmt B1 nichts weg**, und der Unterschied ist der Kern der
/// Sache: Sadana, Agnihotri und Stasko messen SICHTBARE Menüs gegen
/// UNSICHTBARE Gesten (14 von 16 gegen 1 von 16). Die drei Punkte sind
/// ein sichtbares Menü -- in iOS sogar DAS Zeichen dafür, aus der
/// Systemsammlung, an jeder zweiten Stelle des Betriebssystems. Wer es
/// einmal gesehen hat, kennt es überall wieder.
///
/// Das Wort daneben war meine Zugabe. Die A/B-Tests, auf die ich mich
/// dabei berufen habe (plus 20 und plus 61 Prozent Nutzung mit Wort),
/// messen EIGENE Zeichen ohne eingeführte Bedeutung -- ein Zahnrad,
/// ein Stapel Striche. Für ein Systemzeichen sagen sie nichts.
///
/// **Die Vorlese-Beschriftung bleibt** und ist damit die einzige
/// Stelle, an der das Wort noch steht: Ein Zeichen ohne Namen ist für
/// VoiceOver ein Knopf ohne Zweck.
///
/// **Dieselben Handgriffe aus demselben Zustand** wie Wisch und langes
/// Drücken. Drei Listen mit denselben Namen liefen irgendwann
/// auseinander, und dann könnte man über den einen Weg löschen und über
/// den anderen nicht.
struct Zeilenmenue<Inhalt: View>: View {
    @ViewBuilder var inhalt: () -> Inhalt

    var body: some View {
        Menu {
            inhalt()
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body)
                .foregroundStyle(Farben.akzent)
                // MINDESTENS 44 PUNKTE. Apples eigene Angabe: „a button
                // needs a hit region of at least 44x44 pt". Und Hoober
                // hat 2017 gemessen, dass in der Mitte 7 mm reichen, an
                // den Rändern aber rund 12 mm nötig sind -- eine
                // Listenzeile endet am Rand.
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                .contentShape(Rectangle())
        }
        // Ein Menü in einer Zeile, die selbst ein Ziel ist: Ohne das
        // fasst der Tipp die Zeile an, nicht den Knopf.
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Mehr"))
    }
}
