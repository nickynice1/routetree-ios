// Die Angaben am Play, die nicht die Zeichnung sind (B7, R41).
//
// Cyell am 01.09.2026, nach dem ersten TestFlight-Bau: „Mann will ein
// Play erstellen und kann die Formation, Katalogisieren auswählen,
// allgemeine Play Notiz erstellen." Genau das ging in der App nicht.
// Der Editor konnte zeichnen und sonst nichts: Name, Nummer, Seite,
// Kategorie, Situationen und Hinweise ließen sich nur im Browser
// setzen. Der Server nimmt sie seit jeher entgegen (`_play_felder`) --
// es fehlte allein die Oberfläche.
//
// WARUM EIN BLATT UND KEINE ZWEITE SPALTE. Im Browser stehen die Felder
// dauerhaft neben dem Feld; auf einem Telefon gibt es diese Spalte
// nicht. Sie unter das Feld zu legen, hieße: scrollen zwischen
// Zeichnen und Schreiben, und das ist genau die Beschwerde, die Niklas
// am 28.08.2026 über den Browser auf dem Handy hatte („richtig
// kacke"). Ein Blatt kommt ganz, geht ganz und lässt die Zeichnung in
// Ruhe.
//
// WARUM ES NICHT SELBST SPEICHERT. Der Editor hat EINEN Sichern-Knopf,
// und der schickt Zeichnung und Angaben zusammen. Zwei Speicherwege
// nebeneinander erzeugen zwei Fassungsnummern, und die zweite läuft
// dann in den Konflikt mit der ersten -- ausgelöst von einem einzigen
// Menschen an einem einzigen Gerät. „Übernehmen" heißt hier also:
// zurück in den Editor, ungesichert wie eine gezogene Route.

import SwiftUI

/// Ein Blatt für Name, Nummer, Seite, Kategorie, Situationen, Hinweise.
struct Playangaben: View {

    /// Was auf dem Blatt steht -- der Typ wohnt seit R110.7 in
    /// `Modelle/Playangabenstand.swift`, weil auch der Verlauf ihn
    /// braucht. Der alte Name bleibt: Achtzehn Stellen heissen so.
    typealias Stand = Playangabenstand

    @Binding var stand: Stand
    /// Die Kategorien des Heftes. Leer heißt: Es gibt keine, und dann
    /// steht der Abschnitt gar nicht erst da (ADR-0007).
    let kategorien: [Modell.Kategorie]
    /// Was diese Mannschaft spielt (R110.8).
    ///
    /// **Weil die Situationen daran hängen.** „No-Run-Zone" gibt es nur
    /// da, wo vor der Endzone gepasst werden muss: im Flag und im
    /// 5er-Tackle. In jeder anderen Tackle-Form ist ein Kästchen mit
    /// dieser Aufschrift kein Angebot, sondern eine falsche Auskunft
    /// über die Regeln -- und wer es anhakt, sortiert seinen Play im
    /// Call Sheet unter eine Lage, die es im Spiel nicht gibt.
    let spielform: String
    /// Ob hier etwas geändert werden darf. Sagt der Server über den
    /// Play, nicht die App.
    let darfAendern: Bool
    let schliessen: () -> Void

    /// Der Stand beim Aufmachen -- für „Abbrechen".
    @State private var beginn = Stand()
    @State private var gemerkt = false

    var body: some View {
        NavigationStack {
            ZStack {
                Farben.flaeche.ignoresSafeArea()
                formular
            }
            .navigationTitle("Play")
            .navigationBarTitleDisplayMode(.inline)
            // ZEICHEN STATT WOERTER (R94).
            //
            // Niklas am 09.09.2026 mit einem Bild dieser Leiste, zweimal
            // hintereinander: „Keine Schrift Buttons bitte". Auf seinem
            // Bild steht links „Ab…" -- die Leiste von iOS 26 gibt
            // weniger Platz her, und deutsche Wörter sind lang. Eine
            // abgeschnittene Beschriftung sagt weniger als ein Zeichen:
            // „Ab…" heisst nichts, ein Kreuz heisst abbrechen.
            //
            // Es ist derselbe Fund wie bei „Sic…" (R57) und bei „Fe…"
            // (R65), nur an der dritten Stelle. Kreuz und Haken sind in
            // iOS die eingeführten Zeichen für genau diese beiden
            // Handgriffe.
            //
            // DER TEXT BLEIBT FUER DEN VORLESER (`accessibilityLabel`).
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Abbruchknopf {
                        stand = beginn
                        schliessen()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Fertigknopf(name: String(localized: "Übernehmen")) {
                        schliessen()
                    }
                    .disabled(!stand.taugt)
                }
            }
            .onAppear {
                // Nur beim ERSTEN Erscheinen. SwiftUI ruft `onAppear`
                // auch nach einem Wechsel in den Hintergrund wieder auf,
                // und dann stünde als „Beginn" der halb getippte Name.
                guard !gemerkt else { return }
                beginn = stand
                gemerkt = true
            }
            // SOLANGE ETWAS NICHT TAUGT, GEHT DAS BLATT NICHT VON
            // SELBST ZU.
            //
            // „Übernehmen" ist bei leerem Namen aus -- ein Wisch nach
            // unten wäre sonst der Weg daran vorbei. Der leere Name
            // käme in den Editor, „Ungesichert" ginge an, und beim
            // Sichern antwortete der Server mit „Der Play braucht einen
            // Namen." Der Trainer stünde dann vor einer Absage zu einem
            // Feld, das er gar nicht mehr sieht.
            //
            // „Abbrechen" bleibt der Ausgang und ist immer offen: Es
            // legt den alten Stand zurück, und der taugt.
            .interactiveDismissDisabled(!stand.taugt)
        }
    }

    private var formular: some View {
        Form {
            Section {
                TextField("Name", text: $stand.name)
                    .disabled(!darfAendern)
                if stand.name.trimmingCharacters(
                        in: .whitespacesAndNewlines).isEmpty {
                    Text("Der Play braucht einen Namen.")
                        .font(.footnote)
                        .foregroundStyle(Farben.fehler)
                } else if !stand.nameTaugt {
                    // ZWEI VERSCHIEDENE MELDUNGEN, weil es zwei
                    // verschiedene Fehler sind. „Der Play braucht einen
                    // Namen" zu jemandem zu sagen, der gerade einen zu
                    // langen getippt hat, ist keine Auskunft.
                    Text("Der Name ist zu lang: höchstens \(Playgrenzen.nameLaenge) Zeichen.")
                        .font(.footnote)
                        .foregroundStyle(Farben.fehler)
                }
            } header: {
                Text("Name")
            } footer: {
                Text("So heißt der Play in der Liste und auf dem Ausdruck.")
            }

            Section {
                TextField("ohne", text: $stand.nummer)
                    .keyboardType(.numberPad)
                    .disabled(!darfAendern)
                if !stand.nummerTaugt {
                    Text("Die Nummer muss zwischen 1 und \(Playgrenzen.nummerMax) liegen.")
                        .font(.footnote)
                        .foregroundStyle(Farben.fehler)
                }
            } header: {
                Text("Nummer")
            } footer: {
                Text("""
                    Die Nummer, die du rufst und der Spieler am Armband \
                    nachschlägt. Sie darf leer bleiben.
                    """)
            }

            Section {
                Picker("Seite", selection: $stand.seite) {
                    ForEach(Seite.alle) { seite in
                        Text(seite.name).tag(seite.wert)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!darfAendern)
            } header: {
                Text("Seite")
            }

            // NUR WENN ES KATEGORIEN GIBT. Eine Auswahl mit dem
            // einzigen Eintrag „keine" ist ein toter Knopf (ADR-0007) --
            // und sie sähe aus, als hätte die App die Kategorien nicht
            // geladen.
            if !kategorien.isEmpty {
                Section {
                    Picker("Kategorie", selection: $stand.kategorie) {
                        Text("keine").tag(Int?.none)
                        ForEach(kategorien) { k in
                            // MIT DEM PUNKT, wie in der Playliste und
                            // wie im Browser. Die Farbe IST das, woran
                            // man eine Kategorie auf der Kachel und auf
                            // dem Armband wiedererkennt; eine Auswahl,
                            // die nur den Namen zeigt, sagt weniger als
                            // die Liste zwei Bildschirme weiter.
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Farbvorschlaege.farbe(k.farbe))
                                    .frame(width: 9, height: 9)
                                Text(k.name)
                            }
                            .tag(Int?.some(k.id))
                        }
                    }
                    .disabled(!darfAendern)
                } header: {
                    Text("Kategorie")
                } footer: {
                    Text("Die Ordnung im Playbook. Ein Play steht in höchstens einer.")
                }
            }

            Section {
                // EINE ZEILE JE SITUATION MIT HAKEN, keine Reihe von
                // Kacheln: Auf dem Telefon passen zehn Kacheln nur
                // gekürzt nebeneinander, und der Satz darunter -- „Wann
                // rufst du diesen Play?" -- ist die halbe Auskunft. In
                // der Zeile steht er mit.
                ForEach(Situation.fuer(schluessel: spielform)) { situation in
                    Button {
                        if stand.situationen.contains(situation.wert) {
                            stand.situationen.remove(situation.wert)
                        } else {
                            stand.situationen.insert(situation.wert)
                        }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName:
                                stand.situationen.contains(situation.wert)
                                  ? "checkmark.square.fill" : "square")
                                .foregroundStyle(
                                    stand.situationen.contains(situation.wert)
                                    ? Farben.akzent : Farben.inkStill)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(situation.name)
                                    .foregroundStyle(Farben.ink)
                                Text(situation.hinweis)
                                    .font(.footnote)
                                    .foregroundStyle(Farben.inkStill)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!darfAendern)
                    // NUR `.isSelected`: `.isButton` bringt der
                    // `Button` selbst mit, und eine Verzweigung
                    // zwischen einem Sammelwert und einem einzelnen
                    // Merkmal ist genau die Art Ausdruck, die ohne
                    // Compiler danebengehen kann.
                    .accessibilityAddTraits(
                        stand.situationen.contains(situation.wert)
                        ? .isSelected : [])
                }
            } header: {
                Text("Situationen")
            } footer: {
                Text("""
                    Wann rufst du diesen Play? Danach ist das Call Sheet \
                    gegliedert. Mehrere sind erlaubt.
                    """)
            }

            Section {
                TextField("Hinweise", text: $stand.hinweise,
                          axis: .vertical)
                    .lineLimit(3...8)
                    .disabled(!darfAendern)
                // DER ZÄHLER ERST KURZ VOR SCHLUSS. Eine Zahl, die von
                // 2000 herunterzählt, während jemand zwei Sätze
                // schreibt, ist Lärm; eine, die bei 100 auftaucht, ist
                // eine Warnung. Ab null steht sie in Rot und
                // „Übernehmen" ist aus -- der Server schneidet nämlich
                // stillschweigend ab und antwortet trotzdem mit 200.
                if stand.hinweiseUebrig <= 100 {
                    Text(stand.hinweiseTaugt
                         ? String(localized:
                            "Noch \(stand.hinweiseUebrig) Zeichen.")
                         : String(localized:
                            "Zu lang. Höchstens \(Playgrenzen.hinweiseLaenge) Zeichen."))
                        .font(.footnote)
                        .foregroundStyle(stand.hinweiseTaugt
                                         ? Farben.inkStill : Farben.fehler)
                }
            } header: {
                Text("Hinweise")
            } footer: {
                Text("""
                    Was zu diesem Play noch zu sagen ist. Steht auf der \
                    Playcard unter der Zeichnung.
                    """)
            }
        }
        .scrollContentBackground(.hidden)
    }
}
