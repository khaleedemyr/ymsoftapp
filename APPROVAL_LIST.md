# Daftar Approval di Home.vue

Berdasarkan analisis `Home.vue`, berikut adalah semua jenis approval yang perlu diimplementasikan:

## 1. Purchase Requisition (PR) Approvals
- **Variable**: `pendingPrApprovals`
- **Modal**: `showPrApprovalModal`
- **Features**:
  - Multi-select approval
  - Budget info display
  - PR modes: `pr_ops`, `purchase_payment`, `travel_application`, `kasbon`
  - Approval flow dengan comments
  - Image lightbox untuk attachments

## 2. Purchase Order Ops Approvals
- **Variable**: `pendingPoOpsApprovals`
- **Modal**: `showPoOpsApprovalModal`
- **Features**:
  - Multi-select approval
  - Budget info display
  - Approval flow dengan comments
  - Image lightbox untuk attachments

## 3. Category Cost Outlet Approvals
- **Variable**: `pendingCategoryCostApprovals`
- **Modal**: `showCategoryCostApprovalModal`
- **Features**:
  - Multi-select approval
  - Rejection reason required

## 4. Outlet Stock Adjustment Approvals
- **Variable**: `pendingStockAdjustmentApprovals`
- **Modal**: `showStockAdjustmentApprovalModal`
- **Features**:
  - Multi-select approval

## 5. Contra Bon Approvals
- **Variable**: `pendingContraBonApprovals`
- **Modal**: `showContraBonApprovalModal`
- **Features**:
  - Multi-select approval
  - Filter: status, date, source type, approval level
  - Sort: newest, oldest, number, amount
  - Pagination

## 6. Employee Movement Approvals
- **Variable**: `pendingMovementApprovals`
- **Modal**: `showMovementDetailModal`
- **Features**:
  - Approval flow system (new & legacy)
  - Multiple approval levels

## 7. Coaching Approvals
- **Variable**: `pendingCoachingApprovals`
- **Features**:
  - Violation details
  - Supervisor information
  - Approval level

## 8. Leave/Izin/Cuti Approvals
- **Variable**: `pendingApprovals` (supervisor)
- **Variable**: `pendingHrdApprovals` (HRD)
- **Features**:
  - Leave type
  - Duration
  - Date range
  - HRD approval flow

## 9. Correction Approvals
- **Variable**: `pendingCorrectionApprovals`
- **Features**:
  - Types: schedule, attendance, manual
  - Reason display
  - Outlet information

## 10. Food Payment Approvals
- **Component**: `FoodPaymentApprovalCard`
- **Features**:
  - Payment details
  - Supplier information

## 11. Non Food Payment Approvals
- **Component**: `NonFoodPaymentApprovalCard`
- **Features**:
  - Payment details
  - Supplier information

## 12. PR Food Approvals
- **Component**: `PRFoodApprovalCard`
- **Features**:
  - PR details
  - Food items

## 13. PO Food Approvals
- **Component**: `POFoodApprovalCard`
- **Features**:
  - PO details
  - Food items

## 14. RO Khusus Approvals
- **Component**: `ROKhususApprovalCard`
- **Features**:
  - RO details

## 15. Employee Resignation Approvals
- **Component**: `EmployeeResignationApprovalCard`
- **Features**:
  - Resignation details
  - Approval flow

---

## Struktur File untuk Flutter App

```
lib/
├── screens/
│   ├── home_screen.dart (existing)
│   ├── approvals/
│   │   ├── pr_approval_detail_screen.dart
│   │   ├── po_ops_approval_detail_screen.dart
│   │   ├── category_cost_approval_detail_screen.dart
│   │   ├── stock_adjustment_approval_detail_screen.dart
│   │   ├── contra_bon_approval_detail_screen.dart
│   │   ├── movement_approval_detail_screen.dart
│   │   ├── coaching_approval_detail_screen.dart
│   │   ├── leave_approval_detail_screen.dart
│   │   ├── correction_approval_detail_screen.dart
│   │   ├── food_payment_approval_detail_screen.dart
│   │   ├── non_food_payment_approval_detail_screen.dart
│   │   ├── pr_food_approval_detail_screen.dart
│   │   ├── po_food_approval_detail_screen.dart
│   │   ├── ro_khusus_approval_detail_screen.dart
│   │   └── employee_resignation_approval_detail_screen.dart
│   └── approvals_list_screen.dart (untuk melihat semua approval)
├── widgets/
│   └── approvals/
│       ├── pr_approval_card.dart
│       ├── po_ops_approval_card.dart
│       ├── category_cost_approval_card.dart
│       ├── stock_adjustment_approval_card.dart
│       ├── contra_bon_approval_card.dart
│       ├── movement_approval_card.dart
│       ├── coaching_approval_card.dart
│       ├── leave_approval_card.dart
│       ├── correction_approval_card.dart
│       ├── food_payment_approval_card.dart
│       ├── non_food_payment_approval_card.dart
│       ├── pr_food_approval_card.dart
│       ├── po_food_approval_card.dart
│       ├── ro_khusus_approval_card.dart
│       └── employee_resignation_approval_card.dart
├── services/
│   └── approval_service.dart
└── models/
    └── approval_models.dart
```

## Fitur Umum Setiap Detail Screen

1. **AppBar dengan tombol back**
2. **Informasi lengkap approval** (sesuai modal di web)
3. **Tombol Approve** (hijau)
4. **Tombol Reject** (merah, dengan reason jika diperlukan)
5. **Loading state** saat approve/reject
6. **Success/Error handling**
7. **Auto refresh** setelah approve/reject

## Prioritas Implementasi

### Phase 1 (High Priority):
1. Purchase Requisition (PR) Approvals
2. Purchase Order Ops Approvals
3. Leave/Izin/Cuti Approvals

### Phase 2 (Medium Priority):
4. Contra Bon Approvals
5. Employee Movement Approvals
6. Category Cost Outlet Approvals

### Phase 3 (Lower Priority):
7. Outlet Stock Adjustment Approvals
8. Coaching Approvals
9. Correction Approvals
10. Food Payment Approvals
11. Non Food Payment Approvals
12. PR Food Approvals
13. PO Food Approvals
14. RO Khusus Approvals
15. Employee Resignation Approvals

