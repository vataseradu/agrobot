# AgroBot — Asistent Agricol Inteligent pentru România

## Ce este AgroBot?

AgroBot este un chatbot agricol bazat pe [Open WebUI](https://github.com/open-webui/open-webui) (v0.9.5), personalizat complet pentru fermierii și specialiștii din agricultura românească. Folosește modelele **Mistral Large** (`mistral-large-latest`) și **GPT-4.1 mini** (`gpt-4.1-mini`) pentru consultanță agricolă în limba română.

## Cazuri de Utilizare (target)

1. **Fermier căutând finanțare** — întrebări despre PNDR, AFIR, APIA, GAL, condiții de eligibilitate, sume, termene. **Necesită precizie maximă** — răspuns greșit poate face fermierul să piardă un dosar. Răspunde pe baza de Knowledge AFIR.
2. **FAQ rapid pentru fermieri** — întrebări generale despre culturi, tratamente, zootehnie, legislație. Răspuns rapid, conversațional, fără sursă obligatorie.

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
| Selectare model | ✅ Orice model | ✅ Poate alege între modelele expuse (gpt-4.1-mini / mistral-large-latest) |
| Model selector (UI) | ✅ Dropdown complet | ✅ Dropdown vizibil (gate eliminat în mai 2026) |
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
| `temperature` | 0.15 | Răspunsuri consistente, puțin creative |
| `top_p` | 0.85 | Restrânge vocabularul la cele mai probabile tokeni |
| `max_tokens` | 4096 | Limită maximă de răspuns (~3000 cuvinte) |
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
git pull
rm -rf build/
nohup npm run build > /tmp/agrobot-build.log 2>&1 &
# Aștept până termină procesul:
while pgrep -f "npm run build" > /dev/null; do sleep 30; done
# Verifică succes:
tail -5 /tmp/agrobot-build.log
ls -lh build/index.html   # timestamp de azi = OK
systemctl restart agrobot.service
```

### Actualizare doar backend (fără rebuild)
```bash
cd /opt/agrobot
git pull
systemctl restart agrobot.service
```

### Upgrade major Open WebUI (procedura validată mai 2026)

Pașii pentru upgrade de versiune (ex. 0.8.x → 0.9.x). **Tot lucrul de merge se face local pe Windows**, pe VPS doar pull + build + restart.

**Pe Windows (local):**
```bash
cd "c:\Users\Vatase Radu\Desktop\GUMAORI"
git remote add upstream https://github.com/open-webui/open-webui.git  # o singură dată
git fetch upstream --tags
git checkout -b upgrade-vX.Y.Z
git merge vX.Y.Z   # va da conflicte pe middleware.py + config.py
# Rezolvă conflicte manual, păstrând personalizările AgroBot
git add . && git commit -m "Merge upstream vX.Y.Z"
git push -u origin upgrade-vX.Y.Z
```

**Pe VPS — BACKUP OBLIGATORIU întâi:**
```bash
cd /opt/agrobot
cp backend/data/webui.db backend/data/webui.db.bak-$(date +%Y%m%d-%H%M%S)
cp .env .env.bak-$(date +%Y%m%d-%H%M%S)

# Verifică NU ai modificări locale necommitate (Navbar, package-lock etc.)
git status
# Dacă da: investighează (poate fi editare deliberată) și commit/push local înainte

git fetch origin
git checkout upgrade-vX.Y.Z
git pull

# Reinstall Python deps (pot fi schimbări mari între versiuni)
source venv/bin/activate
pip install -r backend/requirements.txt --upgrade

# Reinstall + rebuild frontend
npm install --legacy-peer-deps
rm -rf build/
nohup npm run build > /tmp/agrobot-build.log 2>&1 &
while pgrep -f "npm run build" > /dev/null; do sleep 30; done
tail -5 /tmp/agrobot-build.log
ls -lh build/index.html   # timestamp de azi = OK

# Restart (migrațiile DB rulează aici la primul start)
systemctl restart agrobot.service
journalctl -u agrobot.service -f --no-pager
# Caută în log: "Running upgrade XXX -> YYY", "Application startup complete", banner versiune nouă
```

**Rollback rapid dacă ceva nu merge:**
```bash
systemctl stop agrobot.service
cd /opt/agrobot
git checkout main
cp backend/data/webui.db.bak-XXX backend/data/webui.db
systemctl start agrobot.service
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
| `AGROBOT_MAX_MESSAGE_LENGTH` | `2000` | Limita de caractere per mesaj (non-admin) |
| `AGROBOT_SYSTEM_PROMPT` | (prompt complet) | Suprascrie system prompt-ul din cod |

> **Notă**: `AGROBOT_FORCED_MODEL` a fost eliminat în mai 2026 — userii pot alege liber între modelele expuse de admin.

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
| Build frontend cade pe `@internationalized/date` | Bug upstream: `bits-ui ^2.x` cere peer dep dar nu o declară. E adăugată explicit în `package.json` din mai 2026. Dacă reapare pe alt pachet: `npm install <pachet> --legacy-peer-deps` apoi pune în package.json. |
| Frontend nu se încarcă (index.html lipsește) | NU seta `STATIC_DIR` în .env, lasă doar `FRONTEND_BUILD_DIR` |
| Model nu răspunde | Verifică loguri: `journalctl -u agrobot.service -f`. Verifică cheia API în Admin Panel → Connections |
| Cont blocat pe „pending" | Admin Panel → Users → Aprobă userul |
| webui.db deteriorat | **NU ȘTERGE!** Conține toți userii și setările. Backup: `cp webui.db webui.db.bak` |
| Arena Model apare by default | Șterge `arena-model` din `model_order_list` în tabela `config` din SQLite (vezi secțiunea PersistentConfig) |
| Banner-ul zice versiunea veche după upgrade | Nu ai făcut `git checkout upgrade-vX.Y.Z` pe VPS. Verifică `git branch --show-current`. |
| `git checkout upgrade-vX.Y.Z` zice „local changes would be overwritten" | Verifică `git diff <fișier>` pe fiecare fișier modificat. Dacă e editare deliberată (ex. Navbar modificat direct pe VPS), commit-o local sau salvează patch. Apoi `git checkout -- <fișier>` ca să discard, după care checkout pe noul branch. |
| RAG returnează `[[]] [[]]` (retrieval empty), model halucinează | **Bug în Open WebUI 0.9.5 hybrid search.** EnsembleRetriever cu BM25+vector returnează empty silent. **Fix: dezactivează Hybrid Search** (Settings → Documents → Hybrid Search OFF). Vector-only retrieval cu OpenAI 3-large e suficient ca precizie. Documentat în secțiunea „Bug Hybrid Search 0.9.5" mai jos. |
| Knowledge attached dar răspuns halucinează | 1) Chat vechi cu referințe stale → folosește „+ New Chat". 2) Embeddings dim mismatch (uploaded cu un model, query cu altul) → șterge fișiere, reupload după ce embedding model e setat. 3) Hybrid search bug → dezactivează. |
| Docling OOM-killed la upload paralel | Crește `MemoryMax` în `/etc/systemd/system/docling.service` (de la 6G la 10G). Upload max 1-3 PDF-uri odată, nu lotul întreg. |
| OOM după multiple uploads | Service-ul Docling: `systemctl restart docling.service`. Folosește `MemoryMax=10G` și upload în batch-uri. |
| Open WebUI delete knowledge collection nu cascade-deletes vectori/files | Bug cunoscut. Curățenie manuală: `DELETE FROM file WHERE id NOT IN (SELECT file_id FROM chat_file...);` + `rm -rf /opt/agrobot/backend/data/vector_db/*`. Vezi secțiunea „Cleanup knowledge complet" mai jos. |
| `Failed to fetch collection file-XXX` în logs | Referință stale după delete. Identifică sursa cu `grep` în tabelele file/knowledge/model.meta/chat.chat/user.settings, apoi curăță. |

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

## Roadmap Producție

Plan deschis pentru sesiuni viitoare. **Status: în lucru.**

### Prioritate 1 — Knowledge Base AFIR (anti-halucinație) ✅ FUNCȚIONAL

**Stack tehnic configurat (mai 2026):**
- [x] **Docling-serve ca serviciu HTTP separat** la `http://127.0.0.1:5001` (systemd: `docling.service`)
  - Instalat în `/opt/docling` cu venv, pip install `docling-serve[cpu]`
  - Dependențe sistem: `apt install libgl1 libglib2.0-0 tesseract-ocr tesseract-ocr-ron`
  - `MemoryMax=10G` în systemd unit (de la 6G default — OOM-killed la upload paralel)
- [x] **OpenAI embeddings: `text-embedding-3-large`** (3072 dim)
  - Admin → Settings → Documents → Embedding Engine: OpenAI
  - Cost real: ~$0.02-$0.20 pentru lotul AFIR (~100 PDF-uri)
- [x] **Content Extractor: Docling** cu OCR auto (RapidOCR)
  - Setting: Content Extraction Engine = Docling, URL = `http://127.0.0.1:5001`
- [x] **Setări RAG**:
  - Text Splitter: **Token (Tiktoken)** ⭐
  - Markdown Header Text Splitter: **ON** (Docling produce markdown structurat)
  - Chunk Size: 1500, Chunk Overlap: 250
  - Top K: 8, Top K Reranker: 3
  - Relevance Threshold: **0** (cu 0.15-0.2 filtra prea agresiv pe RO)
  - **Hybrid Search: OFF** ⚠️ (bug 0.9.5 — vezi mai jos)
  - Reranker: dezactivat momentan (lent pe CPU)
- [x] **RAG Template custom** (strict, cu surse obligatorii — vezi secțiunea „RAG Template" mai jos)
- [x] **Test E2E reușit**: query „Ce modifică Hotărârea 81/2026?" pe `hg-81-2026.pdf` → răspuns precis cu page citations

**De făcut:**
- [ ] Upload restul ~96 PDF-urilor AFIR (în batch-uri de 2-3, ~1-2 min/PDF)
- [ ] Test query pe 5-10 PDF-uri random după upload (anti-halucinație)
- [ ] Attach colecția la modelul „AgroBot Finanțări" (vezi mai jos)
- [ ] **Patch sau așteptăm fix upstream pentru Hybrid Search bug** (vector-only e suficient deocamdată)

### Prioritate 2 — Două modele virtuale (FAQ vs Finanțări)
Configurare în Admin Panel → Workspace → Models → Create:

| Model virtual | Bază | Prompt | RAG | Citare sursă | Use case |
|---|---|---|---|---|---|
| **AgroBot FAQ** | `gpt-4.1-mini` | Cald, conversațional, completare cu cunoștințe generale OK | Opțional | Nu | Întrebări generale: culturi, tratamente, zootehnie, legislație |
| **AgroBot Finanțări** | `mistral-large-latest` | Strict: „dacă nu e în documente, spune că nu știi" | Forțat pe colecția AFIR | **DA** (numele PDF + secțiunea) | Finanțări PNDR/AFIR/APIA/GAL |

### Prioritate 3 — Evaluare model Claude Haiku 4.5
- [ ] Adaugă API key Anthropic în Admin → Connections
- [ ] Testează pe ~10 întrebări reale fermieri (mix FAQ + finanțări)
- [ ] Compară cu Mistral Large pe: precizie, română, viteză, cost
- [ ] Decide dacă merge ca default sau rămâne backup

### Prioritate 4 — Hardening producție
- [ ] HTTPS cu certificat real (Let's Encrypt) — în loc de self-signed
- [ ] Rate limiting per user (nu doar limită caractere) — config Nginx sau middleware
- [ ] Backup automat zilnic webui.db (cron + scp/rsync off-site)
- [ ] Monitoring: log retention, alertă disk space, alertă crash service
- [ ] Migrare DB de la SQLite la Postgres (când > 100 useri activi)

---

## Bug Hybrid Search 0.9.5 (CRITICAL)

**Simptom:** Cu Hybrid Search ON, `query_doc_with_hybrid_search` returnează `result [[]] [[]]` chiar dacă chunks-urile există în Chroma cu embeddings corecte.

**Cauză:** `EnsembleRetriever` (LangChain) cu BM25 + Vector pică silent în 0.9.5 — combinația returnează listă goală. Probabil bug în interacțiunea BM25Retriever + RRF.

**Fix temporar:** Dezactivează Hybrid Search.
- Admin Panel → Settings → Documents → **Hybrid Search: OFF**
- SAU direct DB: `UPDATE config SET data = json_set(data, '$.rag.enable_hybrid_search', json('false'));`

**Impact:** Vector search OpenAI 3-large e suficient pentru RO. BM25 ar fi îmbunătățit pe termeni exacți (gen „submăsura 4.1.a") dar nu blocant.

**Fix definitiv (viitor):** patch în `backend/open_webui/retrieval/utils.py` linia ~395 — înlocuim EnsembleRetriever cu RRF manual. Sau așteptăm fix upstream în 0.9.6+.

---

## RAG Template (strict, cu surse — pentru finanțări)

Configurat în Admin Panel → Settings → Documents → RAG Template:

```
Ești AgroAsistent — răspunzi fermierilor români pe baza documentelor agricole oficiale primite mai jos.

REGULI:

1. Sursă obligatorie: răspunzi DOAR pe baza fragmentelor din <context>. Nu adăuga informații din cunoștințele tale generale despre AFIR, APIA, PNDR.

2. Când răspunsul E în context: prezintă-l complet — sume, termene, condiții, articole de lege, procente, coduri de submăsuri.

3. Când răspunsul NU E în context: spune EXACT „Nu am această informație în documentele oficiale pe care le am la dispoziție. Cel mai bine verifici direct pe afir.ro sau apia.org.ro." Atât. NU completa cu cunoștințe generale.

4. NU inventa niciodată: sume exacte, termene-limită, numere de articole, procente sau coduri pe care nu le vezi explicit în <context>.

5. Citează sursa la final: după răspuns, adaugă „📄 Surse:" cu documentele + pagina.

6. Limba: română, ton clar, prietenos dar profesional. tu/ție, nu dumneavoastră.

7. Format: bullet-uri, liste numerotate, tabele. Maximum 400-500 cuvinte pentru întrebări complexe.

<context>
{{CONTEXT}}
</context>

Întrebare: {{QUERY}}
```

---

## Setup Docling-serve (PDF extractor)

Open WebUI 0.9.5 cere Docling ca serviciu HTTP separat (NU librărie Python integrată). Default URL `http://docling:5001` e pentru Docker compose; pe instalare nativă trebuie pornit standalone.

### Install one-time

```bash
# 1. Dependențe sistem
apt install -y libgl1 libglib2.0-0 tesseract-ocr tesseract-ocr-ron

# 2. Folder + venv
mkdir -p /opt/docling
cd /opt/docling
python3.11 -m venv venv
source venv/bin/activate
pip install "docling-serve[cpu]"  # ~2GB deps (torch + transformers)

# 3. Systemd service
cat > /etc/systemd/system/docling.service <<'EOF'
[Unit]
Description=Docling-Serve PDF Extraction Service for AgroBot
After=network.target
Before=agrobot.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/docling

# Async-friendly + paralel processing (3 PDF-uri simultan)
Environment="DOCLING_SERVE_MAX_SYNC_WAIT=900"
Environment="DOCLING_SERVE_ENG_LOC_NUM_WORKERS=3"
Environment="DOCLING_SERVE_MAX_NUM_TASKS=5"
Environment="DOCLING_SERVE_TASKS_PER_USER_LIMIT=10"

ExecStart=/usr/local/bin/docling-serve run --host 127.0.0.1 --port 5001
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

# 12G pentru 3 workers + modele OCR; default 6G = OOM la upload paralel
MemoryMax=12G
CPUQuota=350%

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now docling.service
sleep 60  # warm-up modele
curl http://127.0.0.1:5001/health  # {"status":"ok"}
```

### Configurare în Open WebUI

Admin Panel → Settings → Documents → Content Extraction:
- Engine: **Docling**
- URL: `http://127.0.0.1:5001`
- (Docling API Key gol)

### Limitări observate

- **CPU only**: ~1-2 min/PDF cu OCR (RapidOCR + Tesseract pentru română)
- **Gateway Timeout pe fișiere mari** (>120s default) → setat `DOCLING_SERVE_MAX_SYNC_WAIT=900` (15 min)
- **OOM kill la upload paralel**: a fost necesar `MemoryMax=12G` (default 6G OOM, 10G OOM cu workers paralel)
- **Workers paralel**: `DOCLING_SERVE_ENG_LOC_NUM_WORKERS=3` permite 3 PDF-uri simultan; mai mult = OOM
- **Recomandare upload**: batch-uri de 3-5 PDF-uri (queue absoarbe), max 3 procesate concurent

### Tuning env vars

| Variable | Valoare | Scop |
|---|---|---|
| `DOCLING_SERVE_MAX_SYNC_WAIT` | 900 | Timeout sync (15 min pentru PDF-uri mari/scanate) |
| `DOCLING_SERVE_ENG_LOC_NUM_WORKERS` | 3 | Workers paraleli pentru conversie |
| `DOCLING_SERVE_MAX_NUM_TASKS` | 5 | Coadă tasks (acceptă cereri când workers sunt ocupați) |
| `DOCLING_SERVE_TASKS_PER_USER_LIMIT` | 10 | Limită rate-limit per user |

---

## Cleanup Knowledge complet (pentru reset)

Open WebUI 0.9.5 NU cascade-deletes când ștergi o knowledge collection — rămân orfani în `file`, vector_db, etc. Procedură reset complet:

```bash
# 1. Backup
systemctl stop agrobot.service
cp /opt/agrobot/backend/data/webui.db /opt/agrobot/backend/data/webui.db.bak-$(date +%Y%m%d-%H%M)

# 2. Curățenie SQL
sqlite3 /opt/agrobot/backend/data/webui.db <<'EOF'
DELETE FROM knowledge_file;
DELETE FROM knowledge;
DELETE FROM document;
DELETE FROM file 
  WHERE id NOT IN (SELECT file_id FROM chat_file WHERE file_id IS NOT NULL)
  AND id NOT IN (SELECT file_id FROM channel_file WHERE file_id IS NOT NULL);
EOF

# 3. Nuke vector DB (Chroma se recreează la pornire)
rm -rf /opt/agrobot/backend/data/vector_db/*

# 4. Curățenie fizică
rm -f /opt/agrobot/backend/data/uploads/*.pdf
rm -f /opt/agrobot/backend/data/uploads/*.md
rm -f /opt/agrobot/backend/data/uploads/*.txt

# 5. Restart
systemctl start agrobot.service
```

---

## Istoric Modificări

| Data | Descriere |
|---|---|
| 2026-05-15 (târziu) | **Pipeline RAG complet funcțional** end-to-end. Stack final: Docling (`http://127.0.0.1:5001`) + OpenAI `text-embedding-3-large` + Chroma vector store + custom RAG template strict. Test E2E OK: query pe `hg-81-2026.pdf` → răspuns precis cu page citations. Setări RAG: chunk 1500/overlap 250, Token splitter, Markdown header splitter ON, threshold 0, Hybrid OFF (bug 0.9.5). |
| 2026-05-15 (târziu) | **Bug identificat:** Hybrid Search în Open WebUI 0.9.5 returnează `[[]]` empty silent → model halucinează. Cauză: `EnsembleRetriever` cu BM25 fail silent. Workaround: Hybrid OFF, vector-only retrieval. Documentat în secțiunea „Bug Hybrid Search". |
| 2026-05-15 (târziu) | **Bug identificat:** Open WebUI delete colecție în UI NU cascade-deletes orfani în `file`/`vector_db`. Stale file IDs causează „Failed to fetch collection" errors. Procedură curățenie completă documentată. |
| 2026-05-15 (târziu) | **Bug identificat:** chat sessions stochează file IDs în propriul JSON — chat-uri deschise după delete colecție au referințe stale, retrieval pică. Fix: forțat „+ New Chat", nu reutiliza chat-uri vechi. |
| 2026-05-15 (târziu) | Install Docling-serve pe `/opt/docling` ca systemd `docling.service`. Deps sistem: `libgl1`, `libglib2.0-0`, `tesseract-ocr-ron`. `MemoryMax=10G` necesar (6G default = OOM la upload paralel). |
| 2026-05-15 (târziu) | Eliminat reranker `bge-reranker-v2-m3` (lent pe CPU, ~30-60s/query). Decis că hybrid search + reranking se pot reactiva după patch bug + GPU sau cu reranker mai mic. |
| 2026-05-15 (târziu) | Definite use cases: fermier finanțări (anti-halucinație critical) + FAQ rapid. Modele virtuale planificate: AgroBot Finanțări (Mistral + AFIR knowledge) + AgroBot FAQ (gpt-4.1-mini, fără knowledge forțat). |
| 2026-05-15 | Upgrade Open WebUI **v0.8.10 → v0.9.5** (vezi entry-uri anterioare). |
| 2026-05-15 | Fix: `bits-ui ^2.0.0` cere peer dep `@internationalized/date ^3.8.1` — adăugat explicit în `package.json` (upstream uită s-o declare). |
| 2026-05-15 | Sync `Navbar.svelte`: eliminat gate `$user?.role === 'admin'` pe model selector — userii pot alege liber între modele (consistent cu commit `9a9828b` care a eliminat forțarea modelului). Editarea fusese făcută direct pe VPS în trecut, acum în git. |
| 2026-05-15 | Upgrade Open WebUI **v0.8.10 → v0.9.5** (backend async cu psycopg v3, Calendar/Automations/Skills/Channels, RAG hybrid + reranking, `{{USER_GROUPS}}` în prompts, SSRF redirect blocking, iframe CSP). Re-portate: limită mesaj non-admin, injecție system prompt RO (cu `await apply_system_prompt_to_body` — funcția e async din 0.9.0), parametri model. 8 migrații DB noi rulează automat la primul start. Branch `upgrade-v0.9.5` păstrat în git pentru referință. |
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
