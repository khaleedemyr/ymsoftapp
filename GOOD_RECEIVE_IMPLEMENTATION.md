# Good Receive Implementation Guide

## Overview
Fitur Good Receive untuk YMSoftApp telah diimplementasikan secara lengkap dengan kemampuan scan PO, input quantity received, dan manajemen good receive.

## Files Created

### Models
- `lib/models/good_receive_models.dart`
  - `FoodGoodReceive`: Model untuk good receive
  - `FoodGoodReceiveItem`: Model untuk item good receive
  - `PurchaseOrderFood`: Model untuk purchase order
  - `POFoodItem`: Model untuk item purchase order

### Services
- `lib/services/good_receive_service.dart`
  - `getGoodReceives()`: Get list good receives dengan pagination dan filtering
  - `getGoodReceive(id)`: Get detail good receive
  - `fetchPO(poNumber)`: Scan/fetch PO by number
  - `createGoodReceive()`: Create new good receive
  - `updateGoodReceive()`: Update existing good receive
  - `deleteGoodReceive()`: Delete good receive

### Screens
- `lib/screens/good_receive/good_receive_index_screen.dart`
  - List semua good receives
  - Filter by search, date range
  - Pagination support
  - Pull to refresh
  
- `lib/screens/good_receive/good_receive_detail_screen.dart`
  - Detail informasi good receive
  - List items yang diterima
  - Display qty ordered vs qty received

- `lib/screens/good_receive/good_receive_form_screen.dart`
  - **Scan PO using native camera** (Google ML Kit)
  - Auto-load PO items
  - Input qty received per item
  - Notes per item
  - Submit good receive

### Native Scanner
- `lib/services/native_barcode_scanner.dart`
  - Platform Channel service untuk native barcode scanner
  - Call native camera via Google ML Kit
  
- `android/app/src/main/kotlin/com/example/ymsoftapp/MainActivity.kt`
  - Kotlin implementation untuk barcode scanner
  - Menggunakan Google Play Services Code Scanner

### Navigation
- Updated `lib/widgets/app_sidebar.dart`:
  - Added import for `GoodReceiveIndexScreen`
  - Added route `/food-good-receive`
  - Added navigation handler

### Backend API
- Updated `routes/api.php`:
  - Added routes in `approval-app` group:
    - `GET /api/approval-app/food-good-receives`
    - `POST /api/approval-app/food-good-receives`
    - `GET /api/approval-app/food-good-receives/{id}`
    - `PUT /api/approval-app/food-good-receives/{id}`
    - `DELETE /api/approval-app/food-good-receives/{id}`
    - `POST /api/approval-app/food-good-receives/fetch-po`

- Updated `app/Http/Controllers/FoodGoodReceiveController.php`:
  - Modified `index()` method to support JSON response for API calls
  - Modified `show()` method to include all required fields
  - `fetchPO()` already returns JSON
  - `store()` already returns JSON
  - `update()` needs to be verified

## Usage Flow

1. **List Good Receives**:
   - Navigate to "Warehouse Management" > "Good Receive"
   - View list of all good receives
   - Use filters to search or filter by date

2. **Create Good Receive**:
   - Click "Tambah GR" FAB button
   - Select receive date
   - Click "Scan PO" button (opens native camera scanner)
   - Scan barcode/QR code PO number
   - PO data automatically loaded
   - Review PO items
   - Enter qty received for each item
   - Add notes if needed
   - Click "Simpan" to submit

3. **View Detail**:
   - Click on any good receive card in list
   - View complete information
   - View all items with qty ordered vs qty received

## API Endpoints Used

### Mobile App → Backend

1. **Fetch PO**: `POST /food-good-receive/fetch-po`
   - Request: `{ "po_number": "PO-20260127-0001" }`
   - Response: `{ "po": {...}, "items": [...] }`

2. **Create GR**: `POST /food-good-receive/store`
   - Request:
     ```json
     {
       "receive_date": "2026-01-27",
       "po_id": 123,
       "supplier_id": 45,
       "notes": "Optional notes",
       "items": [
         {
           "po_item_id": 456,
           "item_id": 789,
           "unit_id": 12,
           "qty_ordered": 100.0,
           "qty_received": 100.0,
           "notes": "Optional item notes"
         }
       ]
     }
     ```
   - Response: `{ "success": true, "message": "..." }`

3. **List GR**: `GET /api/approval-app/food-good-receives?search=...&from=...&to=...&page=1&per_page=20`
   - Response: 
     ```json
     {
       "data": [...],
       "current_page": 1,
       "last_page": 5,
       "per_page": 20,
       "total": 95
     }
     ```

4. **Detail GR**: `GET /food-good-receive/{id}`
   - Response: Good receive object with items

5. **Delete GR**: `DELETE /food-good-receive/{id}`
   - Response: `{ "success": true, "message": "..." }`

## Features

- ✅ **Native Barcode/QR Scanner** (Google ML Kit via Platform Channel)
- ✅ Auto-load PO items from backend after scan
- ✅ Support ro_supplier type POs (Perishable division)
- ✅ Support regular POs (from PR Foods)
- ✅ Input qty received per item
- ✅ Add notes for GR and per item
- ✅ Validation: PO must exist, PO not already received
- ✅ List with pagination
- ✅ Filter by search and date range
- ✅ Pull to refresh
- ✅ Detail view
- ✅ Delete functionality
- ✅ Automatic GR number generation (backend)
- ✅ Inventory update (backend)
- ✅ No Flutter package dependencies for scanner (stable solution)

## Notes

- Menu Good Receive sudah tersedia di menu Warehouse Management
- **Barcode scanner menggunakan native camera** via Platform Channel dan Google ML Kit
- **No Flutter package dependencies** untuk scanner = lebih stabil, no build errors
- Endpoint menggunakan web routes yang sudah ada untuk avoid permission issues
- Index endpoint tetap menggunakan approval-app route
- Validation handled both on client and server side
- Supports both ro_supplier and regular PO types
- Automatically updates inventory when GR is created
- Scanner works offline (tidak perlu internet untuk scan)
- Scanner supports semua format barcode/QR code (QR, EAN, Code-128, dll)

## Testing Checklist

- [ ] Open Good Receive from menu
- [ ] List displays correctly
- [ ] Filter by search works
- [ ] Filter by date range works
- [ ] Pagination loads more data
- [ ] Click FAB to create new GR
- [ ] Click "Scan PO" button
- [ ] Native camera scanner opens (Google ML Kit UI)
- [ ] Scan QR code or barcode PO number
- [ ] PO Number auto-fills after scan
- [ ] PO data automatically fetched
- [ ] PO items load correctly
- [ ] Enter qty received for each item
- [ ] Submit creates GR successfully
- [ ] Detail view shows all information
- [ ] Delete works correctly
- [ ] Backend inventory updated after GR created

## Scanner Specific Tests

- [ ] Scan valid QR code
- [ ] Scan valid barcode (EAN-13, Code-128, etc)
- [ ] User cancel scan (back button)
- [ ] Scan from various distances
- [ ] Scan in low light conditions
- [ ] Multiple scans in sequence
