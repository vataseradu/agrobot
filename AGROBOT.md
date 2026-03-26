# AgroBot — Asistent Agricol Inteligent pentru România

## Ce este AgroBot?

AgroBot este un chatbot agricol bazat pe [Open WebUI](https://github.com/open-webui/open-webui) (v0.8.10), personalizat complet pentru fermierii și specialiștii din agricultura românească. Folosește modelul **Mistral Large** (`mistral-large-latest`) prin API-ul Mistral pentru a oferi consultanță agricolă în limba română.

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
| **Model principal** | `mistral-large-latest` via Mistral API |
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
- **Forțare model** (~linia 2150): Userii non-admin folosesc obligatoriu `mistral-large-latest`
- **Limită mesaj** (~linia 2157): Max 2000 caractere/mesaj pentru non-admin
- **Parametri model** (~linia 2275): temperature=0.1, top_p=0.85, max_tokens=8192, frequency_penalty=0.3

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
ENABLE_SIGNUP=false
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
| Selectare model | ✅ Orice model | ❌ Forțat pe mistral-large-latest |
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
| `max_tokens` | 8192 | Limită maximă de răspuns (~6000 cuvinte) |
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
| `AGROBOT_FORCED_MODEL` | `mistral-large-latest` | Modelul forțat pentru non-admin |
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
| „Model not found" pt. non-admin | Verifică că AGROBOT_FORCED_MODEL din .env/cod corespunde cu un model real din Admin Panel → Connections. Modelul trebuie să existe în `request.app.state.MODELS` |
| Arena Model apare by default | Șterge `arena-model` din `model_order_list` în tabela `config` din SQLite (vezi secțiunea PersistentConfig) |

---

## Notă Importantă: PersistentConfig

Open WebUI folosește un pattern numit **PersistentConfig**: valorile din `.env` sunt citite **o singură dată** la prima pornire și salvate în SQLite (`config` table, coloana `data` ca JSON). După aceea, valorile din DB au prioritate.

**Consecință**: Dacă schimbi `.env` după prima pornire, modificarea NU se aplică automat. Trebuie:
1. **Varianta A**: Schimbă din **Admin Panel → Settings** (recomandat)
2. **Varianta B**: Actualizează direct în SQLite cu un script Python:
```python
import sqlite3, json
conn = sqlite3.connect('backend/data/webui.db')
c = conn.cursor()
c.execute('SELECT data FROM config WHERE id=1')
d = json.loads(c.fetchone()[0])
# exemplu: d['ui']['default_models'] = 'mistral-large-latest'
c.execute('UPDATE config SET data=? WHERE id=1', (json.dumps(d),))
conn.commit()
conn.close()
```
Apoi: `systemctl restart agrobot.service`

---

## Istoric Modificări

| Data | Descriere |
|---|---|
| 2026-03-26 | Deploy inițial pe VPS Hostinger (Ubuntu 22.04, 4 CPU, 16GB RAM) |
| 2026-03-26 | Configurare Mistral API (`mistral-large-latest`) ca model principal |
| 2026-03-26 | System prompt complet în română: domenii agricole, instituții, disclaimer-uri |
| 2026-03-26 | Parametri model: temperature=0.1, top_p=0.85, max_tokens=8192 |
| 2026-03-26 | Restricții UI pentru non-admin: model selector ascuns, controls dezactivate |
| 2026-03-26 | Forțare model `mistral-large-latest` pentru non-admin (în `main.py` înainte de validare) |
| 2026-03-26 | Wallpaper background cu overlay gradient |
| 2026-03-26 | Welcome page cu categorii: Culturi, APIA/AFIR, Zootehnie, Legislație |
| 2026-03-26 | Fix: eliminat parametri Ollama-only (top_k, repeat_penalty, seed) incompatibili cu Mistral API |
| 2026-03-26 | Fix: mutat force-model înainte de validare model în `main.py` |
| 2026-03-26 | Fix: BYPASS_MODEL_ACCESS_CONTROL=true pentru acces non-admin |
| 2026-03-26 | Fix: eliminat `arena-model` din `model_order_list`, corectat `default_models` în DB |
| 2026-03-26 | Fix: schimbat model ID de la `mistral-large-2512` la `mistral-large-latest` (modelul real din sistem) |
| 2026-03-26 | Signup dezactivat, max_tokens crescut de la 2048 la 8192 |
| 2026-03-24 | Deploy inițial pe VPS, HTTPS, Nginx, Ollama, Mistral API |
| 2026-03-24 | Fork Open WebUI, rebranding AgroBot, personalizare română |
