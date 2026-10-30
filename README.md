# Easy Lesson 2

**L'orario delle lezioni sempre in tasca, anche senza internet.**

Easy Lesson 2 mostra l'orario della tua classe (o di un docente) dell'IIS Rosselli di Aprilia:
la lezione in corso, la prossima, le ricreazioni, i laboratori e il sostegno.
Funziona su **Android, Windows e web** e legge direttamente il file Excel dell'orario pubblicato dalla scuola.

### Crediti

Questo progetto è un fork di **[Easy Lesson Web](https://github.com/dalonzoo/Easy-Lesson-Web)**
di [Daniele D'Alonzo](https://github.com/dalonzoo), da cui nasce l'idea e il servizio originale.
Easy Lesson 2 ne riscrive l'interfaccia e aggiunge il funzionamento offline e la lettura del file Excel.
Font: Hind Siliguri (SIL Open Font License).

---

## Installazione

Tutti i file si trovano nella pagina **[Releases](../../releases)**.

| Dispositivo | Cosa scaricare | Come installare |
|---|---|---|
| **Windows** | `EasyLesson-Setup-x.y.z.exe` | Apri il file e segui l'installazione. Se Windows mostra "PC protetto", clicca *Ulteriori informazioni → Esegui comunque*. |
| **Windows (senza installare)** | `EasyLesson-Windows.zip` | Estrai la cartella e apri `easy_lesson.exe`. |
| **Android** | `EasyLesson.apk` | Apri il file dal telefono e consenti l'installazione da "origini sconosciute". |

**Primo avvio:** cerca la tua classe, aprila e tocca *"È il tuo orario?"*: da quel momento l'app si apre
direttamente sul tuo orario, anche offline.

### Temi

Dal menu **⋮ → Temi** scegli tra oltre 20 temi: chiari e scuri classici, **Pure Black / OLED / AMOLED**
(nero vero, che sugli schermi OLED consuma meno batteria), temi naturali come **Deserto**, **Oceano** e **Sakura**,
e temi **animati** con sfondi in movimento (**Tramonto**, **Aurora**, **Lava**, **Notte stellata**, **Onde**, **Tinta viva**…).
Le animazioni si fermano da sole se nel sistema è attivo "riduci animazioni".

### Aggiornamenti

- **Android e Windows**: all'avvio l'app controlla se c'è una nuova versione e mostra *"È disponibile Easy Lesson x.y.z — Aggiorna"*.
  Tocca *Aggiorna*, scarica il file e aprilo: si installa sopra la versione vecchia senza perdere i tuoi orari.
  Puoi controllare anche da *Impostazioni → Cerca aggiornamenti*.
- **Web**: si aggiorna da sola, basta ricaricare la pagina.

---

## Versione web

La versione web è online su **https://andrea-nonloso.github.io/Easy-lesson-v2/**: si apre dal browser,
senza installare nulla.

- **Come un'app:** dal telefono apri il link e scegli *Aggiungi a schermata Home*.
- **Offline:** gli orari che apri vengono salvati nel browser; restano disponibili anche senza connessione
  finché non cancelli i dati del sito.
- **File Excel:** da *Impostazioni → Importa file Excel* puoi caricare il file dell'orario scaricato dal sito della scuola.
  Il download diretto da link, dal browser, può essere bloccato dal sito della scuola: in quel caso scarica il file e importalo.
- **Privacy:** nessun account, nessun dato raccolto. Tutto resta sul tuo dispositivo.

---

## Prossime aggiunte

Idee su cui sto lavorando o che vorrei aggiungere:

- **Assenze e sostituzioni**: vedere quali docenti sono assenti oggi e quali ore della tua classe
  cambiano (supplenza, ora libera, ingresso posticipato o uscita anticipata), evidenziate direttamente nell'orario.
- **Notifiche**: avviso la sera prima o la mattina se il tuo orario cambia per un'assenza,
  e promemoria qualche minuto prima della lezione successiva.
- **Aggiornamento automatico** dell'orario quando la scuola pubblica un nuovo file Excel.
- **Condivisione dell'orario come immagine**, da mandare nel gruppo della classe.
- **Bot per Microsoft Teams**: un servizio (Docker) che ogni mattina pubblica l'orario del giorno,
  con le eventuali sostituzioni, nel canale della classe.
- **Widget** per la schermata Home con la lezione in corso e la prossima.
- **Esportazione nel calendario** (Google Calendar, Outlook) in formato `.ics`.
- **Agenda della classe**: verifiche e compiti segnati direttamente sulle ore di lezione.

Hai un'idea o hai trovato un errore? Apri una [issue](../../issues).

**DISCLAIMER**
    Si, in questo progetto ho usato l'ia, ho usato l'ia per fare la nuova ui, ma la base flutter è presa da easy lesson e
    modificata da me a mano, l'unica cosa fatta dall'ia è la grafica(e la parte sociale: readme, commit etcc). Le mie competenze     sono limitate e ho fatto il possibile per usare il più possibile il mio cervello, ma purtroppo tutto quello che usciva non       mi piaceva e secondo me un'ia e un programmatore è molto meglio di un solo programmatore, perche l'ia scrive codice molto        velocemente e l'umano può capire ciò che accade, se questa cosa non piace, siete liberi di prendere e usare la versione          "ufficiale" di easy lesson. Grazie a tutti.

---

<details>
<summary><b>Per sviluppatori: compilare dal sorgente</b></summary>

Serve [Flutter](https://docs.flutter.dev/get-started/install) (canale stabile); per Windows anche
Visual Studio 2022 con "Sviluppo di applicazioni desktop con C++".

```bash
flutter pub get
flutter test
flutter run -d windows      # oppure -d chrome, oppure un telefono collegato
```

Release automatiche con GitHub Actions: `git tag v2.0.1 && git push origin v2.0.1`
crea installer Windows, APK e zip web nella pagina Releases.

</details>

