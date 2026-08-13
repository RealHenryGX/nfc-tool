# NFC Toolbox

FOSS Android NFC reader/writer built with Flutter.

**Author:** [helllguest](https://github.com/helllguest) · [info@stackntrace.dev](mailto:info@stackntrace.dev) · [stackntrace.dev](https://stackntrace.dev)  
**License:** [MIT](LICENSE)  
**Repo:** [github.com/helllguest/nfc-tool](https://github.com/helllguest/nfc-tool)

NFC Toolbox scans, writes, batch-processes, and analyzes NFC tags. It is a privacy-first alternative to commercial tag managers: no accounts, no telemetry, local storage only.

## Features

### Reading

- UID, tech list (NFC-A/B/F/V, IsoDep, Mifare Classic, Ultralight, NDEF), writable flag, capacity
- NDEF parser: Text, URI, Wi‑Fi, Email, SMS, Location, vCard, AAR, MIME, and more
- Raw hex view via `flutter_nfc_kit` poll
- Optional task auto-run when NDEF records encode NFC Toolbox tasks

### Writing

- Compose multi-record NDEF payloads (reorder, edit, delete before write)
- **Copy tag** — clone NDEF from source to destination (see [Tag types & cloning](#tag-types--cloning))
- Erase (empty NDEF), lock (read-only), format (NDEF-formattable tags)
- Record types: Text, URI, Email, Phone, SMS, Wi‑Fi, vCard, Location, Bluetooth OOB, crypto URIs, social links, AAR, MIME, custom

### Tools (advanced)

- **Mifare Classic** — sector dump and block write (default key `FF FF FF FF FF FF` unless changed)
- **Ultralight / NTAG** — page read/write, memory grid, `.bin` import/export
- **Transceive** — raw hex APDU-style commands
- **Password** — Ultralight EV1 PWD auth / set / unset (chip-specific pages)
- **Infinite copy** — batch-write the same NDEF template to many tags in one session

### QR → NFC wizard

Camera scan, smart type detection, editable preview, write or save as template.

### Templates, history, backup

- Templates CRUD, preset library, share as JSON or QR
- Read/write/task history with CSV export
- JSON backup/restore of templates (Settings)

### Tasks

Catalog of Android automation tasks (Wi‑Fi, Bluetooth, URLs, etc.) runnable from NDEF or the Tasks tab.

### Navigation

Six bottom tabs: **Home**, **Read**, **Write**, **Tasks**, **Tools**, **More**.

| Tab | Purpose |
|-----|---------|
| Home | Quick read/write, batch write, copy tag, erase |
| Read | Scan details, NDEF records, raw hex, lock/format/erase |
| Write | Compose records, load templates, write to tag |
| Tasks | Searchable task catalog — run now or write to tag |
| Tools | Classic, Ultralight, transceive, infinite copy |
| More | Templates, history (incl. task runs), theme, settings, about, debug |

Full-screen routes (outside the tab shell): onboarding, QR wizard. Record info (`/record`) keeps the bottom nav (Read tab).

---

## Tag types & cloning

NFC tags are **not interchangeable**. The app detects the chip type on read; use the right workflow.

| Chip | What it is | Clone / copy in this app |
|------|------------|---------------------------|
| **NDEF** (NTAG, Ultralight with NDEF, Type 2) | URLs, Wi‑Fi, text, vCard | **Home → Copy tag** or Write tab |
| **MIFARE Classic 1K** | 16 sectors × 4 blocks, sector keys | **Tools → Mifare Classic** dump → write to another **Classic** blank |
| **Raw Classic (no NDEF)** | Access cards, hotel keys, many door fobs | No NDEF to copy; use Classic dump/write only |

### Classic → Classic (sector clone)

1. **Tools → Mifare Classic → Read dump** on the source (hold tag until dump completes).
2. Export `.bin` if you want a backup.
3. Write to destination: **Write block** or import `.bin` on a **Classic 1K** blank with the same keys (often factory `FF FF FF FF FF FF`).

Verify destination chip type in **Read** (must show **MIFARE Classic**, not Ultralight). After **Tools → Mifare Classic → Dump all sectors**, confirm **16 sectors / 64 blocks** for a 1K blank. If you see **Ultralight** or `Not Mifare Classic` on write, the blank is the wrong chip type.

### What does *not* work

| Attempt | Why |
|---------|-----|
| Classic → NTAG / Ultralight | Different memory layout and protocol; not a byte copy |
| Classic → phone emulation | Android HCE does not emulate MIFARE Classic (Crypto1, UID, sectors) |
| Copy tag on Classic with no NDEF | Copy tag only moves **NDEF records**; raw sector data is ignored |
| UID clone on standard blanks | Normal Classic/NTAG blanks have a **factory-fixed UID**; readers that whitelist UID need **UID-changeable (CUID)** cards |

### Buying blank tags (avoid mislabeled listings)

Many marketplaces say “1K RFID” but ship **NTAG213/215/216** stickers. For Classic clone destinations, look for:

- **MIFARE Classic 1K**, **S50**, **MF1**, or **M1** — ISO14443A PVC card or fob  
- **Not** NTAG, Ultralight, “215 bytes”, “504 bytes”, or “NFC sticker for phone”

Example product class: blank **MF1 Classic 1K** cards (e.g. Amazon ASIN `B0BYMXQ6N6` — Fudan-compatible S50, fixed UID, default key `FF FF FF FF FF FF`). Always confirm with **Read** or **Classic dump** after delivery.

When **Copy tag** cannot run, the app shows a hint (e.g. Classic with no NDEF → use **Tools → Mifare Classic**).

---

## Technology stack

| Layer | Packages |
|-------|----------|
| UI | Flutter, Material 3 ([stackntrace](https://stackntrace.dev) tokens) |
| State | Riverpod 3 (`Notifier` / providers per feature) |
| Storage | Hive via `StorageService` |
| NDEF sessions | `nfc_manager` — read, write, erase, lock, format, Classic |
| Raw / UL | `flutter_nfc_kit` — poll, transceive, Ultralight pages (see `NfcPort`) |
| QR | `mobile_scanner` |
| Routing | `go_router` — shell + 6-tab nav |
| Share / files | `share_plus`, platform channel for `.bin` pick/save |

Both NFC plugins are used intentionally: **never** start a kit poll while an `nfc_manager` session is open (`NfcPort.prepareKitPath` / `prepareManagerPath`).

Feature screens use Riverpod `Notifier` providers (`home_provider`, `read_provider`, `tools_provider`, etc.) for NFC actions and UI state.

---

## Project structure

```text
lib/
├── core/
│   ├── routing/          # app_router.dart, scaffold_with_nav_bar.dart
│   ├── nfc/              # session UI, helper, batch dialog, errors, port
│   ├── debug/            # AppDebug ring buffer
│   ├── storage/          # Hive / StorageService
│   ├── theme/            # AppTheme, stackntrace_tokens
│   ├── widgets/          # app_ui, hex_field, radar_pulse
│   └── utils/            # hex.dart
├── models/               # ndef_record, tag_template, history, nfc_tag_details, nfc_task
├── features/
│   ├── home/             # dashboard + home_provider actions
│   ├── read/             # read_provider, widgets, record info route
│   ├── write/            # compose + record editor modules
│   ├── tools/            # Classic, UL, transceive panels + tools_provider
│   ├── tasks/            # task catalog, filter, param dialog
│   ├── templates/ history/ settings/ qr_import/ more/ onboarding/
├── services/
│   ├── nfc_service.dart
│   ├── mifare_classic_service.dart
│   ├── tag_memory_service.dart
│   ├── task_runner.dart
│   └── qr_service.dart
└── main.dart             # boot, ProviderScope, theme
```

---

## Build & test

Requires a **physical Android device with NFC** (emulators have no NFC).

```bash
flutter pub get
flutter analyze lib
flutter test          # 33 tests
flutter run
# or
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

In-app **Debug console** (More → Debug console) logs NFC/APDU lines; use the tag filter chips (e.g. **NFC**) when diagnosing reads and Classic dumps.

### Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `Not Mifare Classic` on write | Destination is NTAG/Ultralight, not Classic | Use a Classic 1K blank; verify chip in **Read** |
| Copy tag does nothing / error on Classic | No NDEF on source | **Tools → Mifare Classic** dump → write |
| `pickBytes ok=false` | Import cancelled or SAF denied | Retry import; grant storage permission if prompted |
| Dump shows 0 sectors / wrong type | Tag moved early or wrong chip | Hold tag steady until session completes |

App icon sources: `assets/branding/` (stackntrace amber `#E0A458` on dark `#0A0C0E`).

---

## Privacy

All templates and history stay on device. No analytics, accounts, or network calls except optional share/export actions you trigger.
