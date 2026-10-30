# Easy Lesson 2

**L'orario delle lezioni sempre in tasca, anche offline.**
App per telefono, tablet, web e Windows con un'unica codebase Flutter.

> Fork di [Easy Lesson Web](https://github.com/dalonzoo/Easy-Lesson-Web) di Daniele D'Alonzo:
> interfaccia rifatta da zero, orari salvati sul dispositivo e lettura diretta del file Excel della scuola.

## Download

Dalla pagina [Releases](../../releases):

| Piattaforma | File |
|---|---|
| Windows | `EasyLesson-Setup-x.y.z.exe` (installer) oppure `EasyLesson-Windows.zip` (portatile) |
| Android | `EasyLesson.apk` |
| Web | la versione online su GitHub Pages; dal telefono "Aggiungi a schermata Home" la installa come app |

## Cosa fa

- **Il mio orario**: scegli la tua classe (o il tuo nome se sei docente) e l'app si apre direttamente lì.
- **Offline**: gli orari salvati restano sul dispositivo; all'apertura si vede subito la copia salvata e intanto si aggiorna.
- **Card "Adesso"**: la lezione in corso con barra di avanzamento, la prossima, la ricreazione e quando finisci.
- **Telefono**: giorni a schede con swipe; ore consecutive della stessa materia unite.
- **Tablet / PC**: barra laterale e griglia settimanale completa.
- **File Excel della scuola**: si importa dal dispositivo o da un link e tutto viene calcolato in locale.
- **Materie per codice**: A026 = Matematica, AS12 = Italiano e storia… modificabili dalle impostazioni,
  anche per singolo docente.
- Laboratori e sostegno come etichette, colori stabili per materia, tema chiaro / scuro / automatico.

## Orario da file Excel

Formato atteso (vedi l'esempio anonimo in `test/fixtures/orario_esempio.xlsx`):

- una riga con i giorni (Lunedì … Venerdì) e sotto le ore in numeri romani (I … VII);
- una riga per docente: `A026 Cognome` in colonna A, la classe nelle celle giorno/ora;
- una riga titolo con "sostegno" apre i docenti di sostegno, una con "laboratori" i laboratori.

Il numero di ore di ogni giorno viene dall'orario stesso; le fasce orarie predefinite
(7:50 – 14:00 con ricreazioni 10:20 e 12:10) sono in `lib/models.dart`.

## Compilare dal sorgente

Serve [Flutter](https://docs.flutter.dev/get-started/install) stabile; per Windows anche Visual Studio 2022
con "Sviluppo di applicazioni desktop con C++".

```bash
flutter pub get
flutter test
flutter run -d windows      # oppure: -d chrome, oppure un telefono collegato
```

Build:

```bash
flutter build web --release
flutter build apk --release
flutter build windows --release   # su Windows: .\build_windows.ps1 crea zip + installer in dist\
```

Le release si generano da sole con GitHub Actions creando un tag:

```bash
git tag v2.0.0
git push origin v2.0.0
```

## Struttura

```
lib/
  main.dart               avvio app e tema
  api.dart                cloud function di Easy Lesson (Dart puro)
  xlsx.dart               lettore .xlsx (Dart puro)
  timetable.dart          dal file Excel all'orario di classe / docente (Dart puro)
  models.dart             modelli, fasce orarie, codici materia
  store.dart              stato e salvataggio locale
  ui/                     schermate (orario, ricerca, salvati, impostazioni, materie)
test/                     test di parsing e interfaccia
installer/                script Inno Setup per l'installer Windows
.github/workflows/        CI, GitHub Pages e release automatiche
```

## Privacy

Gli orari e il file Excel importato restano sul dispositivo (SharedPreferences / localStorage).
L'app non raccoglie dati e non richiede login.

## Crediti

Progetto originale [Easy Lesson Web](https://github.com/dalonzoo/Easy-Lesson-Web) di
[Daniele D'Alonzo](https://github.com/dalonzoo). Font Hind Siliguri (SIL Open Font License).
