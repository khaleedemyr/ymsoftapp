# Member History & Preferences Implementation

## Overview
Fitur Member History & Preferences memungkinkan user untuk melihat history transaksi dan preferensi member (menu favorit) dengan cara input ID Member atau No HP member.

## Features

### 1. Member Search
- Input ID Member atau No HP untuk mencari member
- Validasi input sebelum melakukan pencarian
- Error handling untuk member tidak ditemukan

### 2. Member Information
- Menampilkan informasi lengkap member:
  - Nama Lengkap
  - Member ID
  - Email
  - No HP
  - Member Level (Silver/Gold/Platinum)
  - Points
  - Total Spending
  - Status (Aktif/Tidak Aktif)
  - Exclusive Member Badge

### 3. Transaction History
- Daftar transaksi member yang sudah paid
- Informasi per transaksi:
  - Outlet name
  - Order ID
  - Grand Total
  - Tanggal transaksi
  - Points earned/redeemed
- Total transaksi dan total spending
- Detail order dengan list items

### 4. Member Preferences
- **Outlet Favorit**: Outlet yang paling sering dikunjungi
  - Jumlah kunjungan
  - Total belanja
  - Tanggal kunjungan terakhir
  
- **Menu Favorit**: Item yang paling sering dipesan
  - Ranking berdasarkan frekuensi pemesanan
  - Jumlah pemesanan
  - Total porsi
  - Average price
  - Tanggal pemesanan terakhir

## Technical Implementation

### Backend (Laravel)

#### API Endpoints
Semua endpoint berada di route group `approval-app` yang memerlukan authentication token.

**Base URL**: `https://ymsoft.justusku.co.id/api/approval-app`

1. **Get Member Info**
   ```
   GET /member-history/info?search={member_id_or_phone}
   ```
   - Parameter: `search` (ID Member atau No HP)
   - Response: Informasi lengkap member

2. **Get Member History**
   ```
   GET /member-history/transactions?member_id={member_id}&limit={limit}&offset={offset}
   ```
   - Parameters:
     - `member_id` (required): ID Member
     - `limit` (optional, default: 20): Jumlah data per request
     - `offset` (optional, default: 0): Offset untuk pagination
   - Response: List transaksi member

3. **Get Order Detail**
   ```
   GET /member-history/order/{orderId}
   ```
   - Parameter: `orderId` (ID atau Order ID)
   - Response: Detail order dengan items

4. **Get Member Preferences**
   ```
   GET /member-history/preferences?member_id={member_id}&limit={limit}
   ```
   - Parameters:
     - `member_id` (required): ID Member
     - `limit` (optional, default: 10): Jumlah item favorit
   - Response: Favorite items dan favorite outlet

#### Controller
File: `app/Http/Controllers/Api/MemberHistoryController.php`

Methods:
- `getMemberInfo()`: Get member information by ID or phone
- `getMemberHistory()`: Get member transaction history
- `getOrderDetail()`: Get detailed order information
- `getMemberPreferences()`: Get favorite items and outlet

#### Data Source
- Member data: `member_apps_members` table (database default)
- Transaction data: `orders` dan `order_items` tables (database `db_justus`)
- Outlet data: `tbl_data_outlet` table (database `db_justus`)

### Frontend (Flutter)

#### Models
File: `lib/models/member_history_models.dart`

Classes:
- `MemberHistoryModels`: Member information
- `OrderHistoryModel`: Order in history list
- `OrderDetailModel`: Detailed order with items
- `OrderItemModel`: Order item detail
- `FavoriteItemModel`: Favorite menu item
- `FavoriteOutletModel`: Favorite outlet
- `MemberPreferencesModel`: Container for preferences data

#### Service
File: `lib/services/member_history_service.dart`

Methods:
- `getMemberInfo(String search)`: Search member by ID or phone
- `getMemberHistory()`: Get transaction history with pagination
- `getOrderDetail(String orderId)`: Get order details
- `getMemberPreferences()`: Get member preferences

#### Screens

1. **MemberHistorySearchScreen**
   - File: `lib/screens/member_history_search_screen.dart`
   - Input search form
   - Validation dan error handling
   - Panduan pencarian

2. **MemberHistoryDetailScreen**
   - File: `lib/screens/member_history_detail_screen.dart`
   - Tab layout dengan 3 tabs:
     - Info: Member information
     - History: Transaction history list
     - Preferences: Favorite items dan outlet
   - Automatic data loading saat screen dibuka

3. **MemberOrderDetailScreen**
   - File: `lib/screens/member_order_detail_screen.dart`
   - Order header dengan outlet dan tanggal
   - List order items
   - Order summary (subtotal, tax, service charge, discount, total)
   - Points information
   - Payment method

#### Navigation
Menu ditambahkan di App Drawer:
- Menu Utama > Member History
- Icon: history
- Color: Green (#10B981)

## Usage Flow

1. User membuka menu "Member History" dari drawer
2. User memasukkan ID Member atau No HP di search screen
3. Klik tombol "Cari"
4. Jika member ditemukan, akan diarahkan ke detail screen
5. Di detail screen, user dapat melihat:
   - Tab "Info": Informasi member
   - Tab "History": Daftar transaksi (tap untuk detail)
   - Tab "Preferences": Menu favorit dan outlet favorit
6. Dari history list, user dapat tap untuk melihat detail order

## Error Handling

### Backend
- Validation error (422): Input tidak valid
- Not found (404): Member atau order tidak ditemukan
- Server error (500): Error saat query database

### Frontend
- Connection timeout (30 detik)
- Token tidak ditemukan (redirect ke login)
- Error message ditampilkan di UI dengan opsi "Coba Lagi"

## Database Connections

### Default Connection (ymsofterp)
- `member_apps_members`: Data member

### db_justus Connection (POS Database)
- `orders`: Transaction orders
- `order_items`: Order detail items
- `tbl_data_outlet`: Outlet information

## Security
- Semua endpoint memerlukan authentication token
- Token didapat dari login approval app
- Menggunakan middleware `approval.app.auth`

## Future Enhancements
- Export history to PDF/Excel
- Filter by date range
- Filter by outlet
- Search by item name in history
- Add favorite items to cart (if integrated with ordering system)
- Push notification for favorite item promotions

## Testing
1. Test dengan ID Member yang valid
2. Test dengan No HP yang valid
3. Test dengan ID Member/No HP yang tidak ada
4. Test dengan member yang belum pernah transaksi
5. Test detail order dengan berbagai status
6. Test pagination untuk member dengan banyak transaksi

## Notes
- Data transaksi hanya menampilkan order dengan status "paid"
- Points earned/redeemed dapat bernilai 0 jika tidak ada
- Photo member bersifat opsional
- Favorite outlet dapat null jika belum pernah transaksi
- Average price menggunakan average dari semua pemesanan item tersebut
