# Member History - Voucher & Challenge Update

## 🆕 Update Summary
Fixed header layout issue dan menambahkan 2 tab baru: **Voucher** dan **Challenge** dengan progress tracking.

## ✅ What's Fixed

### 1. Header Layout - FIXED
**Problem**: Header dan tab bertumpuk
**Solution**: 
- Reduced `expandedHeight` dari 180 → 160
- Adjusted padding dari `fromLTRB(16, 50, 16, 16)` → `fromLTRB(16, 40, 16, 12)`
- Changed from Column to Row layout untuk better horizontal spacing
- Reduced font size dari 20 → 18
- Added maxLines dan overflow handling

### 2. Points Display - ADDED
**Location**: Di samping tier (SILVER badge)
**Design**:
```dart
Container dengan gold gradient background
Icon: stars (white)
Text: "151 pts" (white, bold)
```

## 🆕 New Features

### Tab 1: Voucher 🎁
**Purpose**: Menampilkan voucher yang dimiliki member dan kapan expire

**Features**:
- ✅ Voucher stats card (jumlah voucher aktif)
- ✅ List voucher tersedia
- ✅ List voucher kadaluarsa
- ✅ Countdown days left
- ✅ Status badges (Active, Expiring Soon, Expired)
- ✅ Voucher code display
- ✅ Reward description

**Voucher Card Components**:
```dart
Left Side:
- Gradient background (purple/orange/grey based on status)
- Voucher code (e.g., "DISC50K")
- Icon (local_offer / block)

Right Side:
- Title: "Diskon Rp 50.000"
- Description: "Minimum belanja Rp 200.000"
- Status Badge: "Segera Expired" / "Expired"
- Countdown: "5 hari lagi"
```

**Sample Data**:
```dart
1. DISC50K - Diskon Rp 50.000 (Active)
2. CASHBACK20 - Cashback 20% (Active)
3. FREESHIP - Gratis Ongkir (Expiring Soon - orange)
4. BIRTHDAY50 - Birthday Promo (Expired - grey)
```

### Tab 2: Challenge 🏆
**Purpose**: Menampilkan challenge yang dimiliki dan progress tracking

**Features**:
- ✅ Challenge stats card (jumlah challenge aktif)
- ✅ Progress bar for each challenge
- ✅ Challenge types (Transaction, Spending, Referral, Streak)
- ✅ Reward information
- ✅ Countdown timer
- ✅ Completion status with check icon
- ✅ Color-coded by type

**Challenge Card Components**:
```dart
Header:
- Type icon dengan gradient background
- Challenge title
- Description
- Completion checkmark (if completed)

Progress Section:
- Current progress vs Target
- Percentage display
- Linear progress bar (color-coded by type)

Footer:
- Reward info (e.g., "100 Points", "Voucher 20%")
- Days left countdown
```

**Challenge Types & Colors**:
```dart
1. Transaction (Blue): Shopping cart icon
2. Spending (Green): Payments icon
3. Referral (Purple): People icon
4. Streak (Orange): Fire icon
```

**Sample Challenges**:
```dart
1. "Transaksi 5x Minggu Ini"
   - Progress: 3/5 (60%)
   - Reward: 100 Points
   - Days left: 5 hari

2. "Belanja Total Rp 500K"
   - Progress: Rp 350K / Rp 500K (70%)
   - Reward: Voucher 20%
   - Days left: 24 hari

3. "Ajak 3 Teman Baru"
   - Progress: 1/3 (33%)
   - Reward: 50 Points
   - Days left: 39 hari

4. "Weekly Spender"
   - Progress: 4/7 (57%)
   - Reward: Free Item
   - Days left: 3 hari
```

## 🎨 Design Updates

### Color Palette
```dart
Voucher Tab: Primary Purple (#6C63FF)
Challenge Tab: Secondary Green (#4CAF50)
Warning (Expiring): Orange
Expired: Grey
Transaction: Blue
Spending: Green
Referral: Purple
Streak: Orange
```

### Tab Icons
```dart
Info: person_outline
History: receipt_long
Preferences: favorite_border
Voucher: card_giftcard (NEW)
Challenge: emoji_events (NEW)
```

## 📱 Layout Structure

### Header (Fixed)
```
[Avatar]  [Name]
          [SILVER] [151 pts]
```

### Tabs (5 tabs now)
```
Info | History | Preferences | Voucher | Challenge
```

## 🔧 Technical Implementation

### Files Modified
- `lib/screens/member_history_detail_screen.dart`

### Key Changes
```dart
1. TabController length: 3 → 5
2. Added _buildVoucherTab() method
3. Added _buildChallengeTab() method
4. Added _buildVoucherCard() helper
5. Added _buildChallengeCard() helper
6. Added _getChallengeIcon() helper
7. Fixed header layout (expandedHeight, padding, Row instead of Column)
8. Added points display badge next to tier
```

### State Variables (Mock Data)
Currently using mock data for:
- Voucher list with expiry dates
- Challenge list with progress tracking

### Future Backend Integration
To connect with real API, replace mock data with:
```dart
// For Vouchers
final response = await _memberHistoryService.getMemberVouchers(memberId);

// For Challenges
final response = await _memberHistoryService.getMemberChallenges(memberId);
```

## 📊 Progress Calculation

### Voucher Status Logic
```dart
- active: expiry_date > today
- expiring_soon: expiry_date <= today + 7 days
- expired: expiry_date < today
```

### Challenge Progress
```dart
progressPercent = progress / target
Display as: "3 / 5" or "Rp 350K / Rp 500K"
Progress bar value: 0.0 to 1.0
```

## 🎯 User Experience

### Voucher Tab
1. See all active vouchers at a glance
2. Quick identification of expiring vouchers (orange badge)
3. Easy to read voucher codes
4. Clear expiry information with countdown

### Challenge Tab
1. Visual progress bars for quick understanding
2. Color-coded by challenge type
3. Clear reward display
4. Countdown creates urgency
5. Completion status visible with checkmark

## ✨ Visual Improvements

### Before
- Header bertumpuk dengan tabs
- No points display
- Only 3 tabs (Info, History, Preferences)

### After
- ✅ Clean header dengan proper spacing
- ✅ Points displayed next to tier badge
- ✅ 5 tabs dengan Voucher dan Challenge
- ✅ Modern progress bars
- ✅ Status badges dengan colors
- ✅ Countdown timers
- ✅ Gradient backgrounds
- ✅ Color-coded challenges

## 🔮 Future Enhancements

1. **Backend API Integration**
   - GET /api/member-history/vouchers
   - GET /api/member-history/challenges
   - POST /api/member-history/use-voucher
   - POST /api/member-history/claim-reward

2. **Interactive Features**
   - Copy voucher code button
   - Share voucher functionality
   - Challenge detail modal
   - Reward claim button

3. **Notifications**
   - Alert when voucher expiring soon
   - Notify when challenge completed
   - Remind to use unused vouchers

4. **Analytics**
   - Track voucher usage rate
   - Monitor challenge completion
   - Member engagement metrics

---

**Status**: ✅ Complete
**Version**: 1.0
**Date**: February 4, 2026
