# MyTEDx

App Flutter (Android / iOS) per esplorare, cercare e guardare **TEDx Talks**, con interfaccia dark in stile cinematografico e accenti rosso TED.

**Versione:** `1.0.0+1`  
**Package ID:** `com.unibg.mytedx_app`

### Contesto universitario

Questo progetto è stato realizzato presso l’**Università degli Studi di Bergamo (UniBG)** per il corso:

- **Codice insegnamento:** `21069`
- **Insegnamento:** *Piattaforme cloud e mobile*
- **Anno accademico:** `2025/26`
- **Docente:** Prof. **Mauro Pelucchi**

---

## Panoramica

MyTEDx si collega a un **backend REST** e offre:

- feed personalizzato basato su interessi e cronologia
- ricerca per parola chiave e tag
- riproduzione in-app tramite player TED incorporato (WebView)
- mini-player persistente mentre navighi
- profilo con History e Watch later

---

## Funzionalità

### Navigazione
- Tre schede: **Home**, **Search**, **Profile**
- Mini-player globale: continua a navigare mentre il video è attivo
- Tocca di nuovo **Home** (o il titolo TEDx) → aggiorna il feed e torna in alto

### Home
- Sezione **Suggested for you** (interessi + cronologia)
- Sezione **Discover more** (contenuti nuovi)
- Scroll infinito per caricare altri talk
- Pull-to-refresh / refresh che preferisce video diversi da quelli già in lista
- Card con immagine, durata, titolo, speaker e **tag**

### Search
- Ricerca per keyword e/o tag
- Molti tag popolari su **due righe** scorrevoli
- Scroll infinito sui risultati
- Tap su un tag (nella lista o nei dettagli) → apre Search con quel filtro

### Riproduzione video
- Player TED via **WebView** (`embed.ted.com`)
- Mini-player ed espansione **senza ricaricare** il video
- Scorri in basso per ridurre / in alto per espandere (solo due stati: pieno o mini)
- Doppio tap sinistra/destra: **−10s / +10s**
- Modalità **Landscape**
- Controlli nativi TED (play, sottotitoli, impostazioni, scrubber)
- Pulsante **Open in browser**
- Salvataggio della posizione e ripresa dalla History

### Profile
- **History**: talk visti con barra di avanzamento; tap per continuare da dove eri rimasto
- **Watch later**: salvati dal menu **⋮** accanto al titolo (anche dalla lista Home/Search, senza aprire il player)

### Personalizzazione
- Dialogo al primo avvio: *What are your interests?* (`OK` / `Later`)
- Suggerimenti basati su interessi scelti, watch history e tag condivisi
- Sezione **Up Next** con talk simili

### Pulsante Indietro (Android)
1. Esci dalla modalità landscape  
2. Riduci il player  
3. Aggiorna la Home  
4. Esci dall’app  

---

## Architettura

| Layer | Ruolo |
|--------|--------|
| **Views** | UI (Home, Search, Profile, Main shell) |
| **ViewModels** | Stato e logica (`Provider` / `ChangeNotifier`) |
| **Services** | API HTTP, raccomandazioni, persistenza locale, cache tag |
| **Models** | `Talk`, `TalkDetails`, history, Watch later |

Pattern: **MVVM** con **Provider**.

### Backend REST
L’app comunica con un servizio remoto tramite endpoint HTTP (feed, dettagli talk, ricerca).  
La **base URL** e eventuali credenziali **non** sono documentate qui: vanno configurate in modo privato nel codice / ambiente di sviluppo del corso.

| Risorsa (logica) | Descrizione |
|------------------|-------------|
| Feed | Lista talk per la Home / discovery |
| Details | Dettagli talk (descrizione, tag, related, URL video) |
| Search | Ricerca per query e/o tag |

### Persistenza locale (`SharedPreferences`)
- Cronologia di visione + progresso
- Lista Watch later
- Interessi utente
- Cache suggerimenti e ID già mostrati

---

## Stack tecnologico

- Flutter / Dart
- `provider`
- `http`
- `webview_flutter` (+ Android / WKWebView)
- `miniplayer`
- `cached_network_image`, `shimmer`
- `shared_preferences`
- `url_launcher`, `intl`

---

## Struttura progetto (sintesi)

```text
lib/
  main.dart
  models/
  services/        # API, raccomandazioni, history, cache tag
  viewmodels/      # Home, Search, Details, Library, VideoPlayer
  views/           # Home, Search, Profile, MainScreen
  widgets/         # TalkCard, player, dialoghi, chip…
  theme/
```

---

## Come avviare

### Requisiti
- Flutter SDK (compatibile con `sdk: ^3.12.2`)
- Dispositivo/emulatore **Android** o **iOS** (il player in-app usa WebView)

### Comandi

```bash
flutter pub get
flutter run
```

### Build APK (release)

```bash
flutter build apk --release
```

Output tipico:

```text
build/app/outputs/flutter-apk/app-release.apk
```

> Dopo un cambio di `applicationId`, l’APK si installa come app distinta dalla precedente.

---

## Note

- Il player web **Chrome / Flutter web** non è supportato allo stesso modo di Android/iOS (dipende da WebView).
- Non c’è login cloud: tutto il profilo locale resta sul dispositivo.
- Non pubblicare URL di backend, chiavi o configurazioni private nel repository.
- Progetto didattico **UniBG** — corso `21069` *Piattaforme cloud e mobile* (a.a. `2025/26`), Prof. Mauro Pelucchi.

---

## Licenza

Progetto a scopo didattico / dimostrativo nell’ambito del corso universitario sopra indicato. I contenuti video appartengono a **TED / TEDx** e restano soggetti ai rispettivi termini d’uso.
