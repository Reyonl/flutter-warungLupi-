# AUDIT — Rekapan Warung (Warung Lupi) → Flutter

> Sumber: `C:\laragon\www\Rekapan_Warung` (source of truth, Laravel 13 + React 19 SPA)
> Tanggal audit: 2026-09-29

---

## A. SCREEN MAP

```
(No login — aplikasi langsung terbuka)

Dashboard
├── Buat Bon (bon/buat)                 ──(simpan header)──▶ Edit Bon (bon/:id/edit)
├── Riwayat Bon (bon)                   ──Lihat──▶ Detail Bon / Preview (bon/:id)
│                                            ├── Edit (bon/:id/edit)
│                                            ├── Cetak Bluetooth
│                                            ├── Export PDF (print)
│                                            ├── Download PNG (html2canvas)
│                                            ├── Copy Struk
│                                            └── RawBT intent
├── Pelanggan (pelanggan)
│   ├── Tambah Pelanggan (pelanggan/tambah)
│   └── Edit Pelanggan (pelanggan/:id/edit)          [klik nama → Riwayat Bon per pelanggan]
├── Item (item)
│   ├── Tambah/Edit Item (modal)
│   └── Kategori (item/kategori)         ──tambah/edit inline──▶ (modal/row)
└── Pengaturan (pengaturan)
    ├── Pair / Ganti Printer Bluetooth
    ├── Tes Cetak
    └── Ukuran Kertas (58mm / 80mm)
```

Route React Router yang wajib dipetakan ke Flutter:
`/` `/bon/buat` `/bon/:id/edit` `/bon` `/bon/:id` `/pelanggan` `/pelanggan/tambah` `/pelanggan/:id/edit` `/item` `/item/kategori` `/pengaturan`

---

## B. FEATURE MAP

### 1. Dashboard
| Aspek | Detail |
|---|---|
| Halaman | `/` |
| Input | — (read-only) |
| Output | Kartu statistik + tabel 10 bon terbaru |
| API | `GET /api/dashboard` |
| Response | `{ stats: { bon_hari_ini, total_hari_ini, lunas_hari_ini, lunas_total, masih_hutang, total_pelanggan }, recent_transactions: [{ id, transaction_number, customer_name, transaction_date 'd M Y', total_amount, status, payment_status }] }` |
| Business logic | Total hari ini = sum `total_amount` transaksi tanggal hari ini; lunas = sum `payment_status=paid`; hutang = sum `unpaid`; pelanggan aktif count |
| State | loading, error |
| UI | 4 kartu: Bon Hari Ini (count), Total Hari Ini (Rp), **Sudah Lunas** (hijau, `lunas_total`), **Masih Hutang** (merah); tombol "+ Buat Bon"; tabel terbaru dengan badge Lunas/Hutang, baris klik → detail |
| Error handling | log/error state |

### 2. Buat / Edit Bon (CreateTransaction)
| Aspek | Detail |
|---|---|
| Halaman | `/bon/buat`, `/bon/:id/edit` |
| Input | Pelanggan (select/search), Tanggal, Catatan, lalu item: Item (pilih produk / manual), Keterangan, Qty, Harga |
| API | `POST /transactions` (buat header), `PUT /transactions/{id}` (update header/status), `POST /transactions/{id}/items`, `PUT /transaction-items/{id}`, `DELETE /transaction-items/{id}` |
| Validation (client) | Pelanggan & tanggal wajib; Item/Qty≥1/Harga valid |
| Validation (server) | `customer_id required|exists`, `transaction_date required|date`, `notes max:500`; item: `product_name required max:255`, `quantity required int min:1`, `unit_price required int`, `unit max:50` |
| Business logic | **Wajib dipertahankan**: alur header pertama → setelah tersimpan baru bisa tambah item; subtotal otomatis = qty×harga; **promo**: nama mengandung `gorengan` → tiap 3 pcs subtotal 5000; nama mengandung `donat|nagasari|lemper|jajanan` → tiap 2 pcs subtotal 5000; `payment_status` unpaid/paid; tombol Simpan Bon disabled saat 0 item; status `completed` saat finalisasi |
| State | headerSaved (pelanggan/tanggal terkunci setelah save), editingItemId, isManualItem, items, totalAmount, loading, error |
| Perilaku khusus | set produk terpilih → isi harga dari `default_price`; input harga diformat `1.234` (id-ID) & di-parse; edit item → scroll ke form |
| Error handling | pesan `e.response.data.message` atau 'Gagal...' |

### 3. Riwayat Bon
| Aspek | Detail |
|---|---|
| Halaman | `/bon` |
| Input | search, date_from, date_to; pagination |
| API | `GET /api/transactions?search=&date_from=&date_to=&page=` (paginate 20) |
| Response | Laravel paginator: `{ data: [...], current_page, last_page, ... }` — **Flutter harus handle format ini** |
| Business logic | search filter `transaction_number` like + `customer.name` like; status badge: `completed`→Selesai (gray), `draft`→Draft (outline) |
| State | transactions, meta, page, loading, deleting |
| Aksi | Lihat → detail; Edit → edit; Hapus → confirm (`window.confirm` teks: 'Hapus bon ini? Semua catatan di dalamnya akan ikut terhapus.') |

### 4. Detail Bon / Preview & Cetak
| Aspek | Detail |
|---|---|
| Halaman | `/bon/:id` |
| API | `GET /api/transactions/{id}` → `{ ...transaction, customer, items[] }` |
| Output | Thermal receipt preview + aksi cetak/export |
| Business logic | Ukuran 58mm (32 char) / 80mm (48 char) tersimpan di `localStorage.thermalSize`; teks struk: header WARUNG LUPI + tagline, No/Tgl/Plg, item (wrap, bold), TOTAL, catatan, QRIS, footer |
| Native | **Bluetooth BLE GATT print** (ESC/POS), export PDF (`window.print`), download PNG (html2canvas), copy teks (clipboard), RawBT intent `ru.a402d.rawbtprinter` |
| State | transaction, loading, error, thermalSize, isPrinting, printError |

### 5. Pelanggan
| Aspek | Detail |
|---|---|
| Halaman | `/pelanggan`, `/pelanggan/tambah`, `/pelanggan/:id/edit` |
| API | `GET /api/customers?search&is_active`, `POST`, `PUT`, `DELETE`, `GET /api/customers/{id}/transactions` |
| Validation | name required max:255; phone max:20; notes max:500; client: nama wajib |
| Business logic | Delete diblokir server jika punya riwayat bon (422); toggle is_active; filter Aktif/Semua (default Aktif); debounce search 350ms; klik nama → list bon pelanggan |
| State | customers, search, filterActive, loading, toasts, confirm dialog, togglingId |
| Extra UI | Toast success/error (auto-hilang 4s), ConfirmDialog merah |

### 6. Item (Produk)
| Aspek | Detail |
|---|---|
| Halaman | `/item` |
| API | `GET /api/products?search&category_id&is_active`, `POST`, `PUT`, `DELETE`; `GET /api/categories` |
| Validation | category_id required exists; name required max:255; default_price required int min:0; unit required max:50; client: kategori wajib, nama wajib, harga ≥0, satuan wajib |
| Business logic | filter kategori + status (Semua/Aktif/Nonaktif); toggle aktif; delete confirm; modal tambah/edit |
| State | products, categories, search (debounce 400ms), filterCategory, filterActive, modal, deleteTarget, toasts |

### 7. Kategori
| Aspek | Detail |
|---|---|
| Halaman | `/item/kategori` |
| API | `GET /api/categories` (with `products_count`), `POST`, `PUT`, `DELETE` |
| Validation | name required max:100 **unique** |
| Business logic | Delete disabled jika `products_count > 0`; tambah inline form; edit inline per-row; jumlah kategori + total item |
| State | categories, search (client-side filter), editingId, deleteTarget, toasts |

### 8. Pengaturan (Printer)
| Aspek | Detail |
|---|---|
| Halaman | `/pengaturan` |
| API | — (semua lokal browser) |
| Business logic | Pair via Web Bluetooth (acceptAllDevices + 3 service UUID: `000018f0...`, `e7810a71...`, `49535343...`); simpan `savedPrinterName` & `savedPrinterId` di localStorage; Tes Cetak kirim ESC/POS "TES PRINTER BERHASIL"; ukuran 58/80mm di localStorage |
| Native | BLE pairing + GATT write ber-chunk (100 byte, delay 20ms) |
| State | size, savedPrinter, isTesting, testError, testSuccess |

---

## C. USER FLOW (single role — pemilik warung)

### Alur 1: Buat Bon (core)
```
Dashboard → [+ Buat Bon]
→ isi Pelanggan + Tanggal → [Mulai Input Catatan] (POST /transactions → draft)
→ pilih Item / input manual → Qty → Harga (auto dari default_price)
→ [+ Tambah] (POST /transactions/{id}/items) → refresh total
→ atur [Sudah Dibayar/Berhutang] (PUT payment_status)
→ [Simpan Bon] (PUT status=completed) → Detail Bon
```

### Alur 2: Cetak / Export Bon
```
Riwayat → Lihat → pilih ukuran 58/80
→ [CETAK] BLE langsung / [Export PDF] / [Download] PNG / [Copy] / [RawBT]
```

### Alur 3: Kelola Data
```
Pelanggan: list → cari/toggle → tambah/edit (form) → hapus (confirm, diblokir jika ada bon)
Item: list → cari/filter → tambah/edit (modal) → hapus (confirm) → toggle aktif
Kategori: list → tambah inline/edit inline → hapus (disabled jika ada item)
```

### Alur 4: Pengaturan Printer
```
Pengaturan → [Pair/Pilih Printer] (BLE) → Tes Cetak → pilih ukuran → Simpan
```

---

## D. DATA FLOW

```
Flutter UI (screens/widgets)
   │  Provider (state)
   ▼
ApiClient (Dio, baseUrl dari env --dart-define)
   │  JSON (Accept: application/json)
   ▼
Laravel API routes (/api/*)
   │  Controller (validasi + business logic)
   ▼
Eloquent Model
   ▼
MySQL (warung_lupi / hostinger) — source of truth
```

- **Tidak perlu backend baru**: seluruh 26 endpoint sudah mencakup semua kebutuhan Flutter.
- **Error response eksternal**: 422 → `{message, errors:{field:[...]}}`; 404 → laravel default; 500 → laravel default.
- **Pagination**: `GET /api/transactions` mengembalikan struktur Laravel paginator.

---

## E. API REFERENSI LENGKAP (untuk implementasi)

```
GET    /api/dashboard
GET    /api/customers?search=&is_active=1|0|bool
POST   /api/customers                {name*, phone?, notes?}
GET    /api/customers/{id}           (loadCount transactions)
PUT    /api/customers/{id}           {name?, phone?, notes?, is_active?}
DELETE /api/customers/{id}           422 jika punya transaksi
GET    /api/customers/{id}/transactions → {customer, transactions:[{id,transaction_number,transaction_date 'd M Y',total_amount,status}]}
GET    /api/categories               (withCount products)
POST   /api/categories               {name* unique}
GET    /api/categories/{id}          (load products)
PUT    /api/categories/{id}          {name*}
DELETE /api/categories/{id}          422 jika ada products
GET    /api/products?search=&category_id=&is_active=
POST   /api/products                 {category_id*, name*, default_price* int, unit*, is_active?}
GET    /api/products/{id}
PUT    /api/products/{id}
DELETE /api/products/{id}
GET    /api/transactions?search=&date_from=&date_to=&status=&customer_id=&page=  (paginate 20, with customer)
POST   /api/transactions             {customer_id*, transaction_date*, notes?} → {status:'draft', payment_status:'unpaid', total_amount:0, transaction_number:'INV-YYYYMMDD-NNN'}
GET    /api/transactions/{id}        (with customer, items)
PUT    /api/transactions/{id}        {customer_id?, transaction_date?, status? in:draft,completed, payment_status? in:unpaid,paid, notes?}
DELETE /api/transactions/{id}        (hapus items dulu)
POST   /api/transactions/{id}/items  {product_id?, product_name*, description?, quantity* int min:1, unit? default pcs, unit_price* int, subtotal?}
PUT    /api/transaction-items/{id}   (sama, partial)
DELETE /api/transaction-items/{id}
```

---

## F. TEMA / DESAIN (dari app.css — wajib ditiru di Flutter)

| Token | Nilai | Penggunaan |
|---|---|---|
| `--color-background` | `#F7F7F5` | latar halaman |
| `--color-surface` | `#FFFFFF` | kartu |
| `--color-border` | `#E5E5E5` | border kartu/input |
| `--color-text-main` | `#171717` | teks utama |
| `--color-text-muted` | `#737373` | teks sekunder |
| `--color-brand-600` | `#EA580C` | tombol utama (Buat Bon, Simpan, CETAK) |
| `--color-brand-700` | `#C2410C` | hover |
| `--color-brand-50` | `#fff7ed` | latar aksen tipis |
| Font | Inter (fallback system) | — |
| Badge hijau | `green-100/green-700` → Lunas/Aktif | `#dcfce7`/`#15803d` |
| Badge merah | `red-100/red-600` → Hutang | `#fee2e2`/`#dc2626` |
| Badge gray | `gray-100/gray-800` → Selesai/Status | — |
| Tombol dark | `gray-900` `#171717` | aksi sekunder (Tambah Pelanggan, Simpan Pengaturan) |

Detail penting layout:
- Sidebar kiri (desktop) / drawer (mobile) dengan brand "Warung Lupi", grup menu **Bon** (Buat Bon ← tombol brand, Riwayat Bon), **Data** (Pelanggan, Item), **Pengaturan** bawah.
- Halaman utama max-width ~`max-w-4xl`/`max-w-6xl` mx-auto, padding.
- Kartu statistik `bg-white border rounded-lg p-4 shadow-sm`.

---

## G. FITUR NATIVE FLUTTER YANG DIBUTUHKAN

| Fitur Laravel/Web | Flutter |
|---|---|
| Cetak thermal BLE (ESC/POS) | `flutter_blue_plus` — GATT write chunk 100B/20ms, same raw bytes |
| QRIS statis di struk | `qr_flutter` (value QRIS di-hardcode di TransactionDetail.jsx) |
| Export PNG struk | `RepaintBoundary` + `screenshot` → galeri (`image_gallery_saver` / share) |
| Export PDF (`window.print`) | `pdf` package → `Printing.sharePdf` |
| Copy struk | `Clipboard.setData` + `Share` |
| RawBT intent | `url_launcher` (`intent:...#Intent;scheme=rawbt;package=ru.a402d.rawbtprinter;end;`) |
| localStorage (thermalSize, printer) | `shared_preferences` |

> ⚠️ **PENTING**: Web Bluetooth tidak tersedia di Android WebView biasa; Flutter harus pakai `flutter_blue_plus` dengan flow pairing yang sama (requestDevice → gatt.connect → cari characteristic write/writeWithoutResponse → write chunk).

---

## H. KEPUTUSAN ARSITEKTUR (Phase 3)

- **State management**: `Provider` (ringan, app single-user).
- **HTTP**: `dio`.
- **baseUrl**: `--dart-define=API_BASE_URL=...`, default fallback ke config. Production: domain Hostinger; dev: `http://10.0.2.2:8000` (emulator) / `http://<ip-lan>:8000` (fisik).
- **Storage**: `shared_preferences`.
- **Struktur**:
```
lib/
├── main.dart
├── core/
│   ├── api/api_client.dart
│   ├── theme/app_theme.dart
│   └── storage/prefs.dart
├── models/
├── providers/
├── screens/
├── widgets/
└── utils/format.dart
```

- **CORS**: perlu tambah origin untuk domain Hostinger (saat ini hanya localhost:5173). Backward-compatible, tidak mengubah logic.