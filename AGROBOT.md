# AgroBot — Asistent Agricol Inteligent pentru România

## Ce este AgroBot?

AgroBot este un chatbot agricol bazat pe [Open WebUI](https://github.com/open-webui/open-webui) (v0.8.10), personalizat complet pentru fermierii și specialiștii din agricultura românească. Folosește modelul **Mistral Large** (mistral-large-2512) prin API-ul Mistral pentru a oferi consultanță agricolă în limba română.

---

## Arhitectură

```
┌─────────────┐     HTTPS (443)     ┌───────────┐     HTTP (8080)     ┌────────────────┐
│  Browser    │ ──────────────────► │  Nginx    │ ──────────────────► │  Open WebUI    │
│  (Client)   │ ◄────────────────── │  Reverse  │ ◄────────────────── │  (Uvicorn)     │
└─────────────┘                     │  Proxy    │                     │                │
                                    └───────────┘                     │  ┌──────────┐  │
                                                                      │  │ SQLite DB│  │
                                                                      │  └──────────┘  │
                                                                      └───────┬────────┘
                                                                              │
                                                        ┌─────────────────────┼──────────────┐
                                                        │                     │              │
                                                   ┌────▼─────┐     ┌────────▼───┐   ┌──────▼──────┐
                                                   │ Mistral  │     │  Ollama    │   │ HuggingFace │
                                                   │ API      │     │ (local)    │   │ Embeddings  │
                                                   │ (cloud)  │     │ CPU-only   │   │             │
                                                   └──────────┘     └────────────┘   └─────────────┘
```

## Infrastructură

| Componentă | Detalii |
|---|---|
| **VPS** | Hostinger, IP `72.61.136.166`, Ubuntu 22.04 |
| **Hardware** | 4 CPU cores, 16 GB RAM, 200 GB disk |
| **Python** | 3.11.15 (deadsnakes PPA) |
| **Node.js** | 22.x (nodesource) |
| **Web Server** | Nginx reverse proxy (port 80/443 → 8080) |
| **HTTPS** | Certificat SSL self-signed |
| **Service** | systemd (`agrobot.service`), auto-start, auto-restart |
| **Baza de date** | SQLite (`backend/data/webui.db`) |
| **Model principal** | `mistral-large-2512` via Mistral API |
| **Ollama** | Instalat nativ (CPU-only), modele: qwen2.5:14b, mistral-nemo:12b, llama3.2:3b |
| **Repo GitHub** | https://github.com/vataseradu/agrobot |

---

## Fișiere Modificate (față de Open WebUI standard)

### Backend

#### `backend/open_webui/utils/middleware.py`
- **System Prompt AgroBot** (~linia 2196): Prompt complet în română cu:
  - Identitate și ton adaptabil (formal pt. legislație, prietenos pt. sfaturi practice)
  - Domenii: agricultură, zootehnie, apicultură, silvicultură, legislație, APIA, AFIR, fiscalitate
  - Reguli stricte: nu inventează date, redirecționează către instituții cu contact
  - Instituții cu date de contact: APIA, AFIR, MADR, ANSVSA, DSV, OJSPA
  - Personalizare geografică (întreabă zona pedoclimatică)
  - Context sezonier (sfaturi + termene APIA/AFIR)
  - Disclaimer-uri obligatorii: pesticide, legislație, veterinar
- **Forțare model** (~linia 2150): Userii non-admin folosesc obligatoriu `mistral-large-2512`
- **Limită mesaj** (~linia 2157): Max 2000 caractere/mesaj pentru non-admin
- **Parametri model** (~linia 2275): temperature=0.1, top_p=0.85, max_tokens=2048, frequency_penalty=0.3

#### `backend/open_webui/config.py`
- **Sugestii chat** (6 prompturi): Culturi, APIA, Tratamente, AFIR tineri fermieri, Zootehnie, Legislație
- **Rolul implicit**: `pending` (necesită aprobare admin)
- **Overlay pending**: Mesaj în română pentru conturi noi
- **Permisiuni useri**: Controls, System Prompt, Params, Web Upload → dezactivate pentru useri normali
- **RAG**: chunk_size=1024, top_k=5

### Frontend

#### `src/lib/components/chat/Chat.svelte`
- **Wallpaper background**: Imagine `/assets/wallpaper.jpg` cu overlay gradient subtil (opacity 12% imagine + gradient alb 95% / gri 97%)

#### `src/lib/components/chat/ChatPlaceholder.svelte`
- **Welcome page**: „Bună ziua! Sunt AgroBot 🌾" + subtitlu „Asistentul tău agricol inteligent"
- **Tag-uri categorie**: 🌾 Culturi | 📋 APIA/AFIR | 🐄 Zootehnie | ⚖️ Legislație

#### `src/lib/components/chat/Navbar.svelte`
- **Selector model ascuns** pentru non-admin: afișează doar „AgroBot 🌾" în loc de dropdown-ul de modele

#### `src/lib/constants.ts`
- `APP_NAME = 'AgroBot'`

#### `src/app.html`
- `<title>AgroBot</title>`

#### `static/assets/wallpaper.jpg`
- Imagine de fundal pentru interfața de chat

---

## Configurare (.env pe VPS)

Fișierul `/opt/agrobot/.env`:
```env
OLLAMA_BASE_URL=http://localhost:11434
WEBUI_NAME=AgroBot
ENABLE_SIGNUP=true
WEBUI_AUTH=true
ENV=prod
PORT=8080
WEBUI_SECRET_KEY=<secret>
FRONTEND_BUILD_DIR=/opt/agrobot/build
ENABLE_OPENAI_API=true
```

> **Notă**: Conexiunea Mistral API (URL + cheie) este configurată din **Admin Panel → Settings → Connections**, NU din .env. Open WebUI salvează aceste setări în SQLite (PersistentConfig).

---

## Restricții Utilizatori (non-admin)

| Funcționalitate | Admin | User normal |
|---|---|---|
| Selectare model | ✅ Orice model | ❌ Forțat pe mistral-large-2512 |
| Model selector (UI) | ✅ Dropdown complet | ❌ Ascuns, vede „AgroBot 🌾" |
| Chat controls (temperatura, etc.) | ✅ | ❌ |
| System prompt custom | ✅ | ❌ |
| Parametri model custom | ✅ | ❌ |
| Upload fișiere web (URL) | ✅ | ❌ |
| Upload fișiere locale | ✅ | ✅ |
| Workspace (modele, knowledge) | ✅ | ❌ |
| Temă (dark/light) | ✅ | ✅ |
| Istoric chaturi | ✅ | ✅ |
| Profil | ✅ | ✅ |
| Limită mesaj | Nelimitat | 2000 caractere |

---

## Parametri Model Injectați

Acești parametri sunt aplicați automat la fiecare cerere de chat:

| Parametru | Valoare | Scop |
|---|---|---|
| `temperature` | 0.1 | Răspunsuri foarte consistente, puțin creative |
| `top_p` | 0.85 | Restrânge vocabularul la cele mai probabile tokeni |
| `max_tokens` | 2048 | Limită maximă de răspuns |
| `frequency_penalty` | 0.3 | Reduce repetiția cuvintelor |
| `presence_penalty` | 0.0 | Nu penalizează subiecte noi |

---

## Comenzi Administrare VPS

### Restart serviciu
```bash
systemctl restart agrobot.service
```

### Verificare status
```bash
systemctl status agrobot.service
```

### Vizualizare loguri
```bash
journalctl -u agrobot.service -f --no-pager
```

### Rebuild frontend (după modificări Svelte)
```bash
cd /opt/agrobot
git pull origin main
nohup npm run build > /tmp/agrobot-build.log 2>&1 &
# Așteaptă ~2-3 minute, verifică:
tail -f /tmp/agrobot-build.log
# Când vezi "✔ done":
systemctl restart agrobot.service
```

### Actualizare doar backend (fără rebuild)
```bash
cd /opt/agrobot
git pull origin main
systemctl restart agrobot.service
```

### Nginx
```bash
nginx -t                    # Verifică configurare
systemctl reload nginx      # Reîncarcă config
```

---

## Variabile de Mediu AgroBot (opționale)

Se pot seta în `.env` sau ca variabile de mediu systemd:

| Variabilă | Default | Descriere |
|---|---|---|
| `AGROBOT_FORCED_MODEL` | `mistral-large-2512` | Modelul forțat pentru non-admin |
| `AGROBOT_MAX_MESSAGE_LENGTH` | `2000` | Limita de caractere per mesaj (non-admin) |
| `AGROBOT_SYSTEM_PROMPT` | (prompt complet) | Suprascrie system prompt-ul din cod |

---

## Structura de Fișiere Importantă

```
/opt/agrobot/
├── backend/
│   ├── open_webui/
│   │   ├── config.py              # Configurări PersistentConfig
│   │   ├── main.py                # Endpoint-uri API FastAPI
│   │   └── utils/
│   │       └── middleware.py       # System prompt, parametri, forțare model
│   ├── data/
│   │   └── webui.db               # Baza de date SQLite (NU ȘTERGE!)
│   └── requirements.txt
├── src/
│   ├── app.html                   # Template HTML principal
│   ├── lib/
│   │   ├── constants.ts           # APP_NAME, URL-uri
│   │   ├── components/
│   │   │   ├── chat/
│   │   │   │   ├── Chat.svelte         # Componenta principală chat + wallpaper
│   │   │   │   ├── ChatPlaceholder.svelte  # Pagina de bun venit
│   │   │   │   ├── Navbar.svelte       # Bară navigare + selector model
│   │   │   │   └── ModelSelector.svelte # Dropdown selectare model
│   │   │   └── layout/
│   │   │       └── Sidebar.svelte      # Sidebar cu workspace/settings
│   │   └── stores/
│   │       └── index.ts           # Store-uri Svelte (user, settings, etc.)
│   └── routes/
│       └── (app)/
│           └── +layout.svelte     # Layout principal aplicație
├── static/
│   └── assets/
│       └── wallpaper.jpg          # Imagine de fundal
├── build/                         # Output build frontend (generat)
├── .env                           # Configurare mediu
└── AGROBOT.md                     # Acest fișier
```

---

## Probleme Cunoscute & Soluții

| Problemă | Soluție |
|---|---|
| Modificări .env nu au efect | Open WebUI cache-uiește în SQLite. Schimbă din Admin Panel → Settings |
| Build frontend eșuează | Rulează `npm install --legacy-peer-deps` apoi `npm run build` |
| Frontend nu se încarcă (index.html lipsește) | NU seta `STATIC_DIR` în .env, lasă doar `FRONTEND_BUILD_DIR` |
| Model nu răspunde | Verifică loguri: `journalctl -u agrobot.service -f`. Verifică cheia API în Admin Panel → Connections |
| Cont blocat pe „pending" | Admin Panel → Users → Aprobă userul |
| webui.db deteriorat | **NU ȘTERGE!** Conține toți userii și setările. Backup: `cp webui.db webui.db.bak` |

---

## Istoric Modificări

| Data | Descriere |
|---|---|
| 2026-03-26 | Wallpaper background cu overlay subtil |
| 2026-03-26 | Configurare completă: system prompt, parametri model, restricții UI, sugestii, forțare model |
| 2026-03-24 | Deploy inițial pe VPS, HTTPS, Nginx, Ollama, Mistral API |
| 2026-03-24 | Fork Open WebUI, rebranding AgroBot, personalizare română |
