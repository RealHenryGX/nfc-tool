# NFC Toolbox

FOSS Android NFC reader/writer built with Flutter.

**Author:** [helllguest](https://github.com/helllguest) · [info@stackntrace.dev](mailto:info@stackntrace.dev) · [stackntrace.dev](https://stackntrace.dev)  
**License:** [MIT](LICENSE)  
**Repo:** [github.com/helllguest/nfc-tool](https://github.com/helllguest/nfc-tool)

NFC Toolbox is a premium, open-source Android application built with Flutter to scan, write, batch process, and analyze NFC Tags. It provides a robust alternative to commercial tag managers.

## 🚀 Features

### 🔍 1. NFC Reading
* **Detailed Metadata**: Read UID, technology list (NFC-A, NFC-B, NFC-F, NFC-V, IsoDep, Mifare Classic, Mifare Ultralight), read-only/writable status, and memory size.
* **NDEF Record Parser**: Parse well-known NDEF records (Text, URI, Wi-Fi, Email, SMS, Location, vCard, AAR, MIME).
* **Raw Hex Viewer**: Advanced binary analyzer extracting low-level payload hex dumps.

### ✍️ 2. NFC Writing
* **Supported Records**:
  * **Text**: Plain text payloads.
  * **URI / URL**: Standard website and custom schema links.
  * **Email**: Recipient address, subject, and body template.
  * **Phone**: Dial actions.
  * **SMS**: Recipient and message body composer.
  * **Wi-Fi**: Proper WPS `application/vnd.wfa.wsc` credential payload (WPA/WEP/Open).
  * **vCard**: Structured contact form or raw vCard.
  * **Location**: Latitude and longitude geographic coordinate links.
  * **Bluetooth**: `application/vnd.bluetooth.ep.oob` MAC OOB record.
  * **Crypto**: bitcoin / ethereum / lightning payment URIs.
  * **Social**: Twitter/X, Facebook, Instagram, LinkedIn, YouTube, GitHub, TikTok profile links.
  * **Search**: Google search query URI.
  * **AAR (Android Application Record)**: Launch specific Android packages instantly.
  * **MIME**: Custom mime-type schemas and raw data payloads.
* **Multi-Record payloads**: Chain, reorder, edit, and delete multiple records before writing.
* **Copy Tag**: Clone NDEF from a source tag onto a destination tag.
* **Erase Tag**: Write an empty NDEF message (clear records).
* **Lock Tag**: Permanently write-protect compatible NFC tags.
* **Format Tag**: Format compatible NDEF-formattable cards.

### 🧙‍♂️ 3. QR -> NFC Wizard
* **Automatic Scan & Parse**: Point device camera at QR codes to instantly recognize contents.
* **Smart Detection**: Detects URLs, Wi-Fi networks, Location coordinates, Emails, SMS, Contacts, and converts them to equivalent NDEF records.
* **Interactive Editor**: Preview and edit fields in a sheet before writing to tags or saving as templates.

### 🥞 4. Batch Writing
* **Sequential Writer**: Write identical payloads to multiple tags sequentially without interrupting the scanner dialog.
* **History Integration**: Automatically log and track sequential write counts and tag UIDs.

### 💾 5. Templates Manager
* **CRUD Operations**: Save, duplicate, search, and delete composed records as reusable templates.
* **Library Pre-sets**: Load default templates for quick use (e.g., Office Wi-Fi, Portfolio links, Business cards).
* **Easy Sharing**: Share templates with others as text JSON payloads or visual QR codes.

### 📊 6. Tag History & CSV Export
* **Activity Logger**: Track all read/write history logs with timestamp, status, UID, and details.
* **Export logs**: Convert log database to standard CSV spreadsheet file format and share.

### 🔒 7. Backup & Restore
* **JSON Backup**: Export all templates configuration to a backup file.
* **Restore**: Load and merge templates from raw backup JSON strings instantly.

---

## 🛠️ Technology Stack

* **UI Framework**: Flutter (Material 3 with Dark Mode support)
* **State Management**: Riverpod (StateNotifier)
* **Local Database**: Hive (Ultra-fast local storage cache)
* **NFC Plugins**: `nfc_manager` (Core Android NFC API) & `flutter_nfc_kit` (Raw binary poll)
* **QR Scanning**: `mobile_scanner` (Camera stream decoder)
* **Routing**: `go_router` (Shell navigation routing)
* **Permissions**: `permission_handler` (Runtime camera and hardware permissions)

---

## 📂 Project Structure

```text
lib/
 ├── core/
 │    ├── navigation/   # GoRouter configuration
 │    ├── nfc/          # NfcDialog and NfcHelper record builders
 │    ├── storage/      # Hive Database initialization
 │    └── utils/        # Generic UI helpers
 │
 ├── models/
 │    ├── ndef_record.dart
 │    ├── tag_template.dart
 │    └── history.dart
 │
 ├── features/
 │    ├── home/         # Dashboard quick grid access
 │    ├── read/         # Tag inspector and raw hex viewer
 │    ├── write/        # Payload composition and editor dialogs
 │    ├── qr_import/    # Mobile camera scanner wizard
 │    ├── templates/    # Saved presets grid and library loader
 │    ├── history/      # Log list and CSV export service
 │    └── settings/     # Appearance and JSON backups manager
 │
 ├── services/
 │    ├── nfc_service.dart
 │    └── qr_service.dart
 │
 └── main.dart
```
