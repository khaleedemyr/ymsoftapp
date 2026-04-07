# Analisis Retail Non Food (versi Web → Mobile)

## Ringkasan Web (ymsofterp)

### Route & Controller
- **Web:** `Route::resource('retail-non-food', RetailNonFoodController::class)` → index, create, store, show, destroy
- **Tambahan:** dailyTotal, getCategoryBudgets, getBudgetInfo (POST), upload invoice di store

### Index (List)
- **Filter:** search (no. transaksi, outlet), date_from, date_to
- **Aturan outlet:** user `id_outlet = 1` lihat semua; selain itu hanya `outlet_id = user.id_outlet`
- **Kolom:** Tanggal, No. Transaksi, Outlet, Category Budget, Total, Status, Aksi (Lihat, Hapus untuk role tertentu)
- **Data:** retail_number, transaction_date, outlet, creator, items, categoryBudget

### Form Create
- **Field wajib:**
  - Tanggal transaksi (`transaction_date`)
  - Outlet (`outlet_id`) — user non-1 hanya outlet sendiri
  - Category Budget (`category_budget_id`) — dari PR category budget_type GLOBAL (dan PER_OUTLET jika ada)
  - Metode Pembayaran (`payment_method`: cash / contra_bon)
  - Supplier (`supplier_id`) — **wajib**, pilih dari daftar (searchable di web)
- **Items:** array minimal 1; tiap item: `item_name`, `qty`, `unit`, `price` (input manual, bukan search item seperti Retail Food)
- **Opsional:** Catatan (`notes`), Upload Bon/Invoice (multiple image)
- **Budget:** getBudgetInfo dipanggil saat pilih category; validasi budget di backend sebelum simpan (BudgetCalculationService)

### Detail
- Tampil: retail_number, transaction_date, outlet, category_budget (name, division, subcategory), status, total_amount, creator, created_at
- Tabel items: no, item_name, qty, unit, price, subtotal
- Notes, list invoice (gambar) jika ada

### Store (Backend)
- Validasi: outlet_id, transaction_date, category_budget_id, payment_method, **supplier_id (required)**, items[] (item_name, qty, unit, price), notes
- Generate `retail_number`: prefix RNF + Ymd + 4 digit sequence
- Validasi budget (GLOBAL/PER_OUTLET) via BudgetCalculationService; tolak jika melebihi
- Create RetailNonFood (status `approved`), RetailNonFoodItem per row
- Upload invoice disimpan ke retail_non_food_invoices (opsional)
- Response JSON: message, data (retail with items)

### Model
- **RetailNonFood:** retail_number, outlet_id, warehouse_outlet_id, category_budget_id, supplier_id, payment_method, created_by, transaction_date, total_amount, notes, status, jurnal_created. Relasi: outlet, creator, items, categoryBudget, supplier, invoices
- **RetailNonFoodItem:** retail_non_food_id, item_name, qty, unit, price, subtotal

## Perbedaan dengan Retail Food
| Aspek | Retail Food | Retail Non Food |
|-------|-------------|-----------------|
| Category / Budget | Tidak ada | **Category Budget** (wajib) |
| Supplier | Opsional | **Wajib** |
| Warehouse | Warehouse Outlet (wajib) | Tidak dipakai di form web |
| Item | Search item + getItemUnits (qty, unit, price dari master) | **Input manual** (item_name, qty, unit, price) |
| Invoice | - | Upload bon/invoice (opsional) |

## Yang Diimplementasi di Mobile (Flutter)

1. **API approval-app** (backend): GET list, GET create-data, GET show/:id, POST store — dengan auth & filter outlet seperti Retail Food API.
2. **Service:** `RetailNonFoodService` — getList, getCreateData, getDetail, store.
3. **Screen:** Index (filter expand/collapse, outlet filter untuk id_outlet=1), Form (tanggal, outlet, category budget, payment, supplier searchable, items manual), Detail.
4. **Menu:** Tambah "Retail Non Food" di sidebar (route `/retail-non-food`).
5. **Upload invoice:** Bisa di-skip di fase pertama atau ditambah nanti; getBudgetInfo opsional (bisa panggil untuk tampilkan sisa budget).
