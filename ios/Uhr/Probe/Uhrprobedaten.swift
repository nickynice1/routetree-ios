// ERZEUGT -- nicht von Hand ändern.
//
//     scripts/uhrprobe_bauen.py
//
// Das Probepaket für die Uhr. Die Plays kommen aus `bibliothek.py`,
// derselben Quelle, aus der ein neues Playbook seine Konzepte bekommt;
// gezeichnet sind sie mit denselben Koordinaten wie im Editor.
//
// Warum als Text im Quelltext und nicht als Datei im Bündel: Eine
// JSON-Datei unter `Uhr/` reiste in JEDEN Bau mit, auch in den
// hochgeladenen. So steht sie in `#if DEBUG` und ist im Store-Bau
// nicht vorhanden.

#if DEBUG
import Foundation

enum Uhrprobedaten {

    /// Das Paket, wortwörtlich wie `Uhrpaket` es liest.
    ///
    /// **Eines und nicht fünf.** Kurz gab es je Sprache eins, weil die
    /// Kategorien „Pass kurz" und „Pass tief" hießen und auf einem
    /// englischen Uhrbild deutscher Text nichts zu suchen hat. Seit
    /// dem 30.09.2026 ist die Bibliothek global englisch (Niklas:
    /// „plays bitte global einfach englisch ist das beste") -- die
    /// fünf Fassungen waren danach Zeichen für Zeichen gleich.
    static let json = #"""
{
 "fassung": 1,
 "stand": "2026-09-30T11:35:08Z",
 "hefte": [
  {
   "id": "probe-heft",
   "name": "2026",
   "spielform": "flag5",
   "feld": {
    "spielLaenge": 50.0,
    "endzone": 10.0,
    "breite": 25.0,
    "keinLauf": 5.0,
    "rush": 7.0
   },
   "kategorien": [
    {
     "id": "kat-0",
     "name": "Short Pass",
     "farbe": "#7BB8D4",
     "plays": [
      {
       "id": "probe-1",
       "name": "#10 Spread Mesh",
       "los": 25.0,
       "richtung": 1,
       "zeichnung": {
        "players": [
         {
          "id": "o_c",
          "side": "off",
          "role": "C",
          "label": "C",
          "x": 25.0,
          "y": 12.5,
          "color": ""
         },
         {
          "id": "o_qb",
          "side": "off",
          "role": "QB",
          "label": "Q",
          "x": 20.0,
          "y": 12.5,
          "color": ""
         },
         {
          "id": "o_x",
          "side": "off",
          "role": "X",
          "label": "X",
          "x": 25.0,
          "y": 22.5,
          "color": ""
         },
         {
          "id": "o_y",
          "side": "off",
          "role": "Y",
          "label": "Y",
          "x": 25.0,
          "y": 7.5,
          "color": ""
         },
         {
          "id": "o_z",
          "side": "off",
          "role": "Z",
          "label": "Z",
          "x": 25.0,
          "y": 2.5,
          "color": ""
         }
        ],
        "routes": [
         {
          "player": "o_x",
          "kind": "route",
          "label": "Mesh",
          "points": [
           {
            "x": 25.0,
            "y": 22.5
           },
           {
            "x": 28.0,
            "y": 19.5
           },
           {
            "x": 28.5,
            "y": 7.5
           }
          ],
          "curve": false
         },
         {
          "player": "o_z",
          "kind": "route",
          "label": "Mesh",
          "points": [
           {
            "x": 25.0,
            "y": 2.5
           },
           {
            "x": 28.0,
            "y": 5.5
           },
           {
            "x": 28.5,
            "y": 17.5
           }
          ],
          "curve": false
         },
         {
          "player": "o_y",
          "kind": "route",
          "label": "Corner",
          "points": [
           {
            "x": 25.0,
            "y": 7.5
           },
           {
            "x": 33.0,
            "y": 7.5
           },
           {
            "x": 41.0,
            "y": 2.5
           }
          ],
          "curve": false
         },
         {
          "player": "o_c",
          "kind": "route",
          "label": "Check",
          "points": [
           {
            "x": 25.0,
            "y": 12.5
           },
           {
            "x": 29.0,
            "y": 10.5
           }
          ],
          "curve": false
         }
        ]
       }
      },
      {
       "id": "probe-2",
       "name": "#20 Twins Right Slant & Flat",
       "los": 25.0,
       "richtung": 1,
       "zeichnung": {
        "players": [
         {
          "id": "o_c",
          "side": "off",
          "role": "C",
          "label": "C",
          "x": 25.0,
          "y": 12.5,
          "color": ""
         },
         {
          "id": "o_qb",
          "side": "off",
          "role": "QB",
          "label": "Q",
          "x": 20.0,
          "y": 12.5,
          "color": ""
         },
         {
          "id": "o_x",
          "side": "off",
          "role": "X",
          "label": "X",
          "x": 25.0,
          "y": 2.5,
          "color": ""
         },
         {
          "id": "o_y",
          "side": "off",
          "role": "Y",
          "label": "Y",
          "x": 25.0,
          "y": 6.5,
          "color": ""
         },
         {
          "id": "o_z",
          "side": "off",
          "role": "Z",
          "label": "Z",
          "x": 25.0,
          "y": 22.0,
          "color": ""
         }
        ],
        "routes": [
         {
          "player": "o_x",
          "kind": "route",
          "label": "Slant",
          "points": [
           {
            "x": 25.0,
            "y": 2.5
           },
           {
            "x": 27.5,
            "y": 5.5
           },
           {
            "x": 32.0,
            "y": 10.5
           }
          ],
          "curve": false
         },
         {
          "player": "o_y",
          "kind": "route",
          "label": "Flat",
          "points": [
           {
            "x": 25.0,
            "y": 6.5
           },
           {
            "x": 27.0,
            "y": 1.5
           }
          ],
          "curve": false
         },
         {
          "player": "o_z",
          "kind": "route",
          "label": "Go",
          "points": [
           {
            "x": 25.0,
            "y": 22.0
           },
           {
            "x": 41.0,
            "y": 22.0
           }
          ],
          "curve": false
         }
        ]
       }
      },
      {
       "id": "probe-3",
       "name": "#30 Twins Right Stick",
       "los": 25.0,
       "richtung": 1,
       "zeichnung": {
        "players": [
         {
          "id": "o_c",
          "side": "off",
          "role": "C",
          "label": "C",
          "x": 25.0,
          "y": 12.5,
          "color": ""
         },
         {
          "id": "o_qb",
          "side": "off",
          "role": "QB",
          "label": "Q",
          "x": 20.0,
          "y": 12.5,
          "color": ""
         },
         {
          "id": "o_x",
          "side": "off",
          "role": "X",
          "label": "X",
          "x": 25.0,
          "y": 2.5,
          "color": ""
         },
         {
          "id": "o_y",
          "side": "off",
          "role": "Y",
          "label": "Y",
          "x": 25.0,
          "y": 6.5,
          "color": ""
         },
         {
          "id": "o_z",
          "side": "off",
          "role": "Z",
          "label": "Z",
          "x": 25.0,
          "y": 22.0,
          "color": ""
         }
        ],
        "routes": [
         {
          "player": "o_y",
          "kind": "route",
          "label": "Stick",
          "points": [
           {
            "x": 25.0,
            "y": 6.5
           },
           {
            "x": 30.0,
            "y": 6.5
           },
           {
            "x": 30.0,
            "y": 3.5
           }
          ],
          "curve": false
         },
         {
          "player": "o_x",
          "kind": "route",
          "label": "Go",
          "points": [
           {
            "x": 25.0,
            "y": 2.5
           },
           {
            "x": 42.0,
            "y": 2.5
           }
          ],
          "curve": false
         },
         {
          "player": "o_z",
          "kind": "route",
          "label": "Drag",
          "points": [
           {
            "x": 25.0,
            "y": 22.0
           },
           {
            "x": 29.0,
            "y": 17.0
           },
           {
            "x": 29.5,
            "y": 9.0
           }
          ],
          "curve": false
         }
        ]
       }
      }
     ]
    },
    {
     "id": "kat-1",
     "name": "Deep Pass",
     "farbe": "#D9A441",
     "plays": [
      {
       "id": "probe-4",
       "name": "#40 Spread Verticals",
       "los": 25.0,
       "richtung": 1,
       "zeichnung": {
        "players": [
         {
          "id": "o_c",
          "side": "off",
          "role": "C",
          "label": "C",
          "x": 25.0,
          "y": 12.5,
          "color": ""
         },
         {
          "id": "o_qb",
          "side": "off",
          "role": "QB",
          "label": "Q",
          "x": 20.0,
          "y": 12.5,
          "color": ""
         },
         {
          "id": "o_x",
          "side": "off",
          "role": "X",
          "label": "X",
          "x": 25.0,
          "y": 22.5,
          "color": ""
         },
         {
          "id": "o_y",
          "side": "off",
          "role": "Y",
          "label": "Y",
          "x": 25.0,
          "y": 7.5,
          "color": ""
         },
         {
          "id": "o_z",
          "side": "off",
          "role": "Z",
          "label": "Z",
          "x": 25.0,
          "y": 2.5,
          "color": ""
         }
        ],
        "routes": [
         {
          "player": "o_x",
          "kind": "route",
          "label": "Go",
          "points": [
           {
            "x": 25.0,
            "y": 22.5
           },
           {
            "x": 45.0,
            "y": 22.5
           }
          ],
          "curve": false
         },
         {
          "player": "o_y",
          "kind": "route",
          "label": "Seam",
          "points": [
           {
            "x": 25.0,
            "y": 7.5
           },
           {
            "x": 31.0,
            "y": 9.0
           },
           {
            "x": 43.0,
            "y": 9.5
           }
          ],
          "curve": false
         },
         {
          "player": "o_z",
          "kind": "route",
          "label": "Go",
          "points": [
           {
            "x": 25.0,
            "y": 2.5
           },
           {
            "x": 45.0,
            "y": 2.5
           }
          ],
          "curve": false
         }
        ]
       }
      },
      {
       "id": "probe-5",
       "name": "#50 Bunch Right Smash",
       "los": 25.0,
       "richtung": 1,
       "zeichnung": {
        "players": [
         {
          "id": "o_c",
          "side": "off",
          "role": "C",
          "label": "C",
          "x": 25.0,
          "y": 12.5,
          "color": ""
         },
         {
          "id": "o_qb",
          "side": "off",
          "role": "QB",
          "label": "Q",
          "x": 20.0,
          "y": 12.5,
          "color": ""
         },
         {
          "id": "o_x",
          "side": "off",
          "role": "X",
          "label": "X",
          "x": 25.0,
          "y": 3.5,
          "color": ""
         },
         {
          "id": "o_y",
          "side": "off",
          "role": "Y",
          "label": "Y",
          "x": 23.5,
          "y": 6.0,
          "color": ""
         },
         {
          "id": "o_z",
          "side": "off",
          "role": "Z",
          "label": "Z",
          "x": 22.5,
          "y": 4.0,
          "color": ""
         }
        ],
        "routes": [
         {
          "player": "o_x",
          "kind": "route",
          "label": "Hitch",
          "points": [
           {
            "x": 25.0,
            "y": 3.5
           },
           {
            "x": 30.0,
            "y": 3.5
           },
           {
            "x": 29.5,
            "y": 2.0
           }
          ],
          "curve": false
         },
         {
          "player": "o_y",
          "kind": "route",
          "label": "Corner",
          "points": [
           {
            "x": 23.5,
            "y": 6.0
           },
           {
            "x": 30.5,
            "y": 7.0
           },
           {
            "x": 37.5,
            "y": 1.0
           }
          ],
          "curve": false
         },
         {
          "player": "o_z",
          "kind": "route",
          "label": "Flat",
          "points": [
           {
            "x": 22.5,
            "y": 4.0
           },
           {
            "x": 24.0,
            "y": 0.5
           }
          ],
          "curve": false
         }
        ]
       }
      }
     ]
    }
   ]
  }
 ]
}
"""#
}
#endif
