# NFC Toolbox — Full Feature Parity TODO

Source APK: NFC Tools `com.wakdev.wdnfc` v9.5 (`/home/songoku/Downloads/nfc_tool.apk`)

Legend: `[ ]` pending · `[~]` partial · `[x]` done + verify · `[!]` blocked (OEM/root/device)

Status: **parity backlog closed for shippable FOSS surface** (2026-07-15). Root/device-owner-only and OEM-private hooks remain `[!]`.

---

## 0. Infra / Architecture

- [x] Fact-check existing README vs code
- [x] Core NDEF helper
- [x] NfcDialog modes: read/write/erase/lock/format
- [x] Hive templates + history + ThemeMode (system/light/dark) + QR wizard + CSV + backup
- [x] Copy tag
- [x] Record-type registry
- [x] Task registry (90+ kinds)
- [x] Android MethodChannel (`pickBytes`/`saveBytes`/`runTask`/`listLaunchableApps`)
- [x] Unit tests
- [x] Nav: Home / Read / Write / Tasks / Tools / More
- [x] Onboarding gate
- [x] GoRouter shell + `/record` route (`app_router.dart`)
- [x] Riverpod feature providers (home, read, tools, tasks)
- [x] NFC core: `NfcPort`, `nfc_errors.dart`, `NfcTagDetails` model
- [x] Shared batch-write dialog + hex utils

---

## 1. NDEF Record Types

- [x] Text, URI, Custom URI, Email (+cc/bcc), Phone, SMS, Emergency
- [x] Wi-Fi WSC, Bluetooth OOB, vCard, Location, Address, Destination
- [x] Custom Geo, Street View, Proximity, Search, Social, Video
- [x] Crypto, AAR/Application (+ app picker), Unit Link, File, MIME, Custom TNF
- [x] Task MIME payload
- [x] Record Information detail screen

---

## 2. Tag Operations

- [x] Read / Write / Batch / Erase / Format / Lock
- [x] Raw hex via flutter_nfc_kit
- [x] Copy + Infinite copy
- [x] Ultralight dump + grid UI + text UI
- [x] UL `.bin` export/import (SAF) + write-back
- [x] Advanced transceive
- [x] UL PWD_AUTH / set / unset
- [x] Mifare Classic dump (Key A/B)
- [x] Classic block write UI
- [x] Classic `.bin` export + import&write
- [!] Raw OEM memory-format beyond NDEF/NTAG pages (chip-proprietary)

---

## 3. NFC Tasks

### Framework
- [x] Model / picker / write / on-read run / history

### Handlers
- [x] Connectivity intents + WiFi/BT toggles (where OS allows)
- [x] BT bond/unpair best-effort reflection
- [x] Sound / volume / brightness / flashlight / notifications / TTS / vibrate / Morse / media keys / speaker / tone
- [x] Launch app / details / uninstall / custom intent / alarm / timer / calendar / wallpaper / print settings
- [x] Clipboard, file/folder ops, zip/unzip (Dart `archive`), download, HTTP, ping/lookup, WoL, UDP
- [x] Maps URL tasks, variables, conditions, profiles, dice
- [!] Enable/disable/kill-root packages (device-owner/root)
- [!] True system screenshot / multi-window / car-mode OEM APIs

---

## 4. UX / Product Polish

- [x] Tools / Tasks / More tabs
- [x] Permissions matrix
- [x] App label
- [x] Package picker
- [x] Memory grid UI
- [x] Classic dump write UI + `.bin`
- [x] Onboarding
- [x] About & licenses
- [x] Preset template library
- [x] Debug console (NFC/APDU/platform/task logs + FlutterError + VS Code launch)
- [x] UI/UX polish (shared theme, grouped settings, empty states, NFC dialog)
- [x] Premium UX pass (NFC bottom sheet + radar, sticky task groups, hex fields, OLED dark)

---

## 5. Verification Log

| ID | Feature | Verify | Result | Date |
|----|---------|--------|--------|------|
| V0 | Baseline analyze | `dart analyze lib` | PASS | 2026-07-15 |
| V1 | NDEF/task unit tests | `flutter test test/ndef_and_tasks_test.dart` | PASS 6/6 | 2026-07-15 |
| V2–V5 | Tools/Classic/UL/batch | analyze clean | PASS | 2026-07-15 |
| V6 | Full remaining batch | `dart analyze lib` + unit tests (+email cc/bcc) | PASS | 2026-07-15 |
| V7 | Debug console | `flutter test` (+debug_log_test) | PASS 17/17 | 2026-07-15 |
| V8 | UI + About/MIT/GitHub | analyze + test + debug APK | PASS | 2026-07-15 |
| V9 | Premium UX pass | analyze + `flutter test` 20/20 + debug APK | PASS | 2026-07-15 |
| V10 | UI + NFC refactor | `flutter analyze lib` + `flutter test` 33/33 | PASS | 2026-08-13 |

---

## Working notes

- No wakdev DEX/smali copy — FOSS reimplementation only.
- `[!]` items cannot be completed without root/device-owner/OEM APIs; UI documents the limitation.
- Keep analyze + tests green before further changes.
