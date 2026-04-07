import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/approval_models.dart';
import '../screens/approvals/pr_approval_detail_screen.dart';
import '../screens/approvals/po_ops_approval_detail_screen.dart';
import '../screens/approvals/leave_approval_detail_screen.dart';
import '../screens/approvals/category_cost_approval_detail_screen.dart';
import '../screens/approvals/stock_adjustment_approval_detail_screen.dart';
import '../screens/outlet_transfer/outlet_transfer_detail_screen.dart';
import '../screens/stock_opname/stock_opname_detail_screen.dart';
import '../screens/approvals/contra_bon_approval_detail_screen.dart';
import '../screens/approvals/movement_approval_detail_screen.dart';
import '../screens/approvals/coaching_approval_detail_screen.dart';
import '../screens/approvals/correction_approval_detail_screen.dart';
import '../screens/approvals/food_payment_approval_detail_screen.dart';
import '../screens/approvals/non_food_payment_approval_detail_screen.dart';
import '../screens/approvals/pr_food_approval_detail_screen.dart';
import '../screens/approvals/po_food_approval_detail_screen.dart';
import '../screens/approvals/ro_khusus_approval_detail_screen.dart';
import '../screens/approvals/employee_resignation_approval_detail_screen.dart';
import 'approvals/pr_approval_card.dart';
import 'approvals/po_ops_approval_card.dart';
import 'approvals/leave_approval_card.dart';
import 'approvals/category_cost_approval_card.dart';
import 'approvals/stock_adjustment_approval_card.dart';
import 'approvals/stock_opname_approval_card.dart';
import 'approvals/outlet_transfer_approval_card.dart';
import 'app_loading_indicator.dart';
import 'approvals/contra_bon_approval_card.dart';
import 'approvals/movement_approval_card.dart';
import 'approvals/coaching_approval_card.dart';
import 'approvals/correction_approval_card.dart';
import 'approvals/food_payment_approval_card.dart';
import 'approvals/non_food_payment_approval_card.dart';
import 'approvals/pr_food_approval_card.dart';
import 'approvals/po_food_approval_card.dart';
import 'approvals/ro_khusus_approval_card.dart';
import 'approvals/employee_resignation_approval_card.dart';
import '../services/approval_service.dart';

class ApprovalListModal extends StatefulWidget {
  final String title;
  final List<dynamic> approvals;
  final Color color;
  final String type; // 'pr', 'po_ops', 'leave', etc.
  final Function(String)? onRefresh; // Callback to refresh after approve/reject

  const ApprovalListModal({
    super.key,
    required this.title,
    required this.approvals,
    required this.color,
    required this.type,
    this.onRefresh,
  });

  @override
  State<ApprovalListModal> createState() => _ApprovalListModalState();
}

class _ApprovalListModalState extends State<ApprovalListModal> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _approvals = []; // Store approvals in state
  List<dynamic> _filteredApprovals = [];
  final ApprovalService _approvalService = ApprovalService();
  
  // Multi-select state
  bool _isSelecting = false;
  final Set<int> _selectedApprovals = {};
  bool _isApproving = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _approvals = List.from(widget.approvals); // Copy from widget
    _filteredApprovals = List.from(_approvals);
    _searchController.addListener(_filterApprovals);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterApprovals);
    _searchController.dispose();
    super.dispose();
  }

  // Reload approvals from API
  Future<void> _reloadApprovals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<dynamic> approvals = [];
      
      switch (widget.type) {
        case 'pr':
          approvals = await _approvalService.getPendingPrApprovals();
          break;
        case 'po_ops':
          approvals = await _approvalService.getPendingPoOpsApprovals();
          break;
        case 'leave':
          approvals = await _approvalService.getPendingLeaveApprovals();
          break;
        case 'hrd':
          approvals = await _approvalService.getPendingHrdApprovals();
          break;
        case 'category_cost':
          approvals = await _approvalService.getPendingCategoryCostApprovals();
          break;
        case 'stock_adjustment':
          approvals = await _approvalService.getPendingStockAdjustmentApprovals();
          break;
        case 'stock_opname':
          approvals = await _approvalService.getPendingStockOpnameApprovals();
          break;
        case 'outlet_transfer':
          approvals = await _approvalService.getPendingOutletTransferApprovals();
          break;
        case 'contra_bon':
          approvals = await _approvalService.getPendingContraBonApprovals();
          break;
        case 'movement':
          approvals = await _approvalService.getPendingMovementApprovals();
          break;
        case 'coaching':
          approvals = await _approvalService.getPendingCoachingApprovals();
          break;
        case 'correction':
          approvals = await _approvalService.getPendingCorrectionApprovals();
          break;
        case 'food_payment':
          approvals = await _approvalService.getPendingFoodPaymentApprovals();
          break;
        case 'non_food_payment':
          approvals = await _approvalService.getPendingNonFoodPaymentApprovals();
          break;
        case 'pr_food':
          approvals = await _approvalService.getPendingPrFoodApprovals();
          break;
        case 'po_food':
          approvals = await _approvalService.getPendingPoFoodApprovals();
          break;
        case 'ro_khusus':
          approvals = await _approvalService.getPendingROKhususApprovals();
          break;
        case 'employee_resignation':
          approvals = await _approvalService.getPendingEmployeeResignationApprovals();
          break;
      }

      if (mounted) {
        setState(() {
          _approvals = approvals;
          _filterApprovals(); // Re-filter with new data
        });
      }
    } catch (e) {
      print('Error reloading approvals: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterApprovals() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredApprovals = List.from(_approvals);
      } else {
        _filteredApprovals = _approvals.where((approval) {
          // Search logic based on approval type
          switch (widget.type) {
            case 'pr':
              final pr = approval as PurchaseRequisitionApproval;
              return pr.prNumber.toLowerCase().contains(query) ||
                  (pr.title?.toLowerCase().contains(query) ?? false) ||
                  (pr.divisionName?.toLowerCase().contains(query) ?? false) ||
                  (pr.outletName?.toLowerCase().contains(query) ?? false);
            case 'po_ops':
              final po = approval as PurchaseOrderOpsApproval;
              return po.number.toLowerCase().contains(query) ||
                  (po.supplierName?.toLowerCase().contains(query) ?? false) ||
                  (po.prNumber?.toLowerCase().contains(query) ?? false) ||
                  (po.prTitle?.toLowerCase().contains(query) ?? false);
            case 'leave':
            case 'hrd':
              final leave = approval as LeaveApproval;
              return leave.employeeName.toLowerCase().contains(query) ||
                  leave.leaveTypeName.toLowerCase().contains(query);
            case 'category_cost':
              final cc = approval as CategoryCostApproval;
              return (cc.outletName?.toLowerCase().contains(query) ?? false) ||
                  (cc.categoryName?.toLowerCase().contains(query) ?? false);
            case 'stock_adjustment':
              final sa = approval as StockAdjustmentApproval;
              return (sa.outletName?.toLowerCase().contains(query) ?? false) ||
                  (sa.adjustmentType?.toLowerCase().contains(query) ?? false);
            case 'stock_opname':
              final so = approval as StockOpnameApproval;
              return so.opnameNumber.toLowerCase().contains(query) ||
                  (so.outletName?.toLowerCase().contains(query) ?? false) ||
                  (so.creatorName?.toLowerCase().contains(query) ?? false);
            case 'outlet_transfer':
              final ot = approval as OutletTransferApproval;
              return ot.transferNumber.toLowerCase().contains(query) ||
                  (ot.outletName?.toLowerCase().contains(query) ?? false) ||
                  (ot.warehouseFromName?.toLowerCase().contains(query) ?? false) ||
                  (ot.warehouseToName?.toLowerCase().contains(query) ?? false);
            case 'contra_bon':
              final cb = approval as ContraBonApproval;
              return cb.number.toLowerCase().contains(query) ||
                  (cb.supplierName?.toLowerCase().contains(query) ?? false);
            case 'movement':
              final movement = approval as EmployeeMovementApproval;
              return movement.employeeName.toLowerCase().contains(query) ||
                  (movement.employmentType?.toLowerCase().contains(query) ?? false);
            case 'coaching':
              final coaching = approval as CoachingApproval;
              return coaching.employeeName.toLowerCase().contains(query) ||
                  coaching.supervisorName.toLowerCase().contains(query) ||
                  coaching.violationDetails.toLowerCase().contains(query);
            case 'correction':
              final correction = approval as CorrectionApproval;
              return correction.employeeName.toLowerCase().contains(query) ||
                  correction.outletName.toLowerCase().contains(query) ||
                  (correction.reason?.toLowerCase().contains(query) ?? false);
            case 'food_payment':
              final fp = approval as FoodPaymentApproval;
              return (fp.number?.toLowerCase().contains(query) ?? false) ||
                  (fp.supplierName?.toLowerCase().contains(query) ?? false);
            case 'non_food_payment':
              final nfp = approval as NonFoodPaymentApproval;
              return (nfp.number?.toLowerCase().contains(query) ?? false) ||
                  (nfp.supplierName?.toLowerCase().contains(query) ?? false);
            case 'pr_food':
              final prf = approval as PRFoodApproval;
              return (prf.prNumber?.toLowerCase().contains(query) ?? false) ||
                  (prf.title?.toLowerCase().contains(query) ?? false);
            case 'po_food':
              final pof = approval as POFoodApproval;
              return (pof.number?.toLowerCase().contains(query) ?? false) ||
                  (pof.supplierName?.toLowerCase().contains(query) ?? false);
            case 'ro_khusus':
              final ro = approval as ROKhususApproval;
              return (ro.number?.toLowerCase().contains(query) ?? false) ||
                  (ro.outletName?.toLowerCase().contains(query) ?? false);
            case 'employee_resignation':
              final er = approval as EmployeeResignationApproval;
              return er.employeeName.toLowerCase().contains(query) ||
                  (er.reason?.toLowerCase().contains(query) ?? false);
            default:
              return true;
          }
        }).toList();
      }
    });
  }

  String _getSearchPlaceholder() {
    switch (widget.type) {
      case 'pr':
        return 'Cari PR Number, Title, Division, atau Outlet...';
      case 'po_ops':
        return 'Cari PO Number, Supplier, atau PR Number...';
      case 'leave':
      case 'hrd':
        return 'Cari Nama Karyawan atau Tipe Cuti...';
      case 'category_cost':
        return 'Cari Outlet atau Category...';
      case 'stock_adjustment':
        return 'Cari Outlet atau Tipe Adjustment...';
      case 'stock_opname':
        return 'Cari No. Opname atau Outlet...';
      case 'outlet_transfer':
        return 'Cari No. Transfer atau Outlet...';
      case 'contra_bon':
        return 'Cari Number atau Supplier...';
      case 'movement':
        return 'Cari Nama Karyawan atau Tipe Employment...';
      case 'coaching':
        return 'Cari Nama Karyawan, Supervisor, atau Detail...';
      case 'correction':
        return 'Cari Nama Karyawan, Outlet, atau Alasan...';
      case 'food_payment':
      case 'non_food_payment':
        return 'Cari Number atau Supplier...';
      case 'pr_food':
        return 'Cari PR Number atau Title...';
      case 'po_food':
        return 'Cari PO Number atau Supplier...';
      case 'ro_khusus':
        return 'Cari Number atau Outlet...';
      case 'employee_resignation':
        return 'Cari Nama Karyawan atau Alasan...';
      default:
        return 'Cari...';
    }
  }

  int _getApprovalId(dynamic approval) {
    switch (widget.type) {
      case 'pr':
        return (approval as PurchaseRequisitionApproval).id;
      case 'po_ops':
        return (approval as PurchaseOrderOpsApproval).id;
      case 'leave':
      case 'hrd':
        return (approval as LeaveApproval).id;
      case 'category_cost':
        return (approval as CategoryCostApproval).id;
      case 'stock_adjustment':
        return (approval as StockAdjustmentApproval).id;
      case 'stock_opname':
        return (approval as StockOpnameApproval).id;
      case 'outlet_transfer':
        return (approval as OutletTransferApproval).id;
      case 'contra_bon':
        return (approval as ContraBonApproval).id;
      case 'movement':
        return (approval as EmployeeMovementApproval).id;
      case 'coaching':
        return (approval as CoachingApproval).id;
      case 'correction':
        return (approval as CorrectionApproval).id;
      case 'food_payment':
        return (approval as FoodPaymentApproval).id;
      case 'non_food_payment':
        return (approval as NonFoodPaymentApproval).id;
      case 'pr_food':
        return (approval as PRFoodApproval).id;
      case 'po_food':
        return (approval as POFoodApproval).id;
      case 'ro_khusus':
        return (approval as ROKhususApproval).id;
      case 'employee_resignation':
        return (approval as EmployeeResignationApproval).id;
      default:
        return 0;
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedApprovals.contains(id)) {
        _selectedApprovals.remove(id);
      } else {
        _selectedApprovals.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedApprovals.clear();
      for (var approval in _filteredApprovals) {
        _selectedApprovals.add(_getApprovalId(approval));
      }
    });
  }

  Future<void> _approveMultiple() async {
    if (_selectedApprovals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu approval untuk di-approve'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: widget.color, size: 24),
            const SizedBox(width: 8),
            const Text('Approve Multiple?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Apakah Anda yakin ingin approve ${_selectedApprovals.length} approval?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Approve'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isApproving = true;
    });

    try {
      int success = 0;
      int failed = 0;

      // Approve all selected approvals in parallel
      final futures = _selectedApprovals.map((id) async {
        try {
          Map<String, dynamic> result;
          switch (widget.type) {
            case 'pr':
              result = await _approvalService.approvePr(id);
              break;
            case 'po_ops':
              result = await _approvalService.approvePoOps(id);
              break;
            case 'leave':
            case 'hrd':
              result = await _approvalService.approveLeave(id);
              break;
            case 'contra_bon':
              result = await _approvalService.approveContraBon(id);
              break;
            case 'category_cost':
              // Category Cost may require approvalFlowId, but for multi-approve we'll use null
              result = await _approvalService.approveCategoryCost(id, approvalFlowId: null);
              break;
            case 'stock_adjustment':
              // Stock Adjustment may require approvalFlowId, but for multi-approve we'll use null
              result = await _approvalService.approveStockAdjustment(id, approvalFlowId: null);
              break;
            case 'stock_opname':
              // Stock opname approval is done in detail screen only
              return {'success': false};
            case 'outlet_transfer':
              // Outlet transfer approval is done in detail screen only
              return {'success': false};
            case 'movement':
              // Movement may require approvalFlowId, but for multi-approve we'll use null
              result = await _approvalService.approveMovement(id, approvalFlowId: null);
              break;
            case 'coaching':
              // Coaching requires approverId, but for multi-approve we'll use null (will be handled by backend)
              result = await _approvalService.approveCoaching(id, approverId: null);
              break;
            case 'correction':
              result = await _approvalService.approveCorrection(id);
              break;
            case 'food_payment':
              result = await _approvalService.approveFoodPayment(id);
              break;
            case 'non_food_payment':
              result = await _approvalService.approveNonFoodPayment(id);
              break;
            case 'pr_food':
              // PR Food requires approvalLevel, but for multi-approve we'll use null (will use default)
              result = await _approvalService.approvePrFood(id, approvalLevel: null);
              break;
            case 'po_food':
              // PO Food requires approvalLevel, but for multi-approve we'll use null (will use default)
              result = await _approvalService.approvePoFood(id, approvalLevel: null);
              break;
            case 'ro_khusus':
              // RO Khusus may require approvalFlowId, but for multi-approve we'll use null
              result = await _approvalService.approveROKhusus(id, approvalFlowId: null);
              break;
            case 'employee_resignation':
              // Employee Resignation may require approvalFlowId, but for multi-approve we'll use null
              result = await _approvalService.approveEmployeeResignation(id, approvalFlowId: null);
              break;
            default:
              return {'success': false};
          }
          return result['success'] == true ? 'success' : 'failed';
        } catch (e) {
          print('Error approving $id: $e');
          return 'failed';
        }
      });

      final results = await Future.wait(futures);
      for (var result in results) {
        if (result == 'success') {
          success++;
        } else {
          failed++;
        }
      }

      // Show result
      if (mounted) {
        if (failed == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$success approval berhasil disetujui'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$success berhasil, $failed gagal'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Reset selection and refresh
      setState(() {
        _selectedApprovals.clear();
        _isSelecting = false;
        _isApproving = false;
      });

      // Reload approvals in modal
      await _reloadApprovals();

      // Also notify parent to refresh
      if (widget.onRefresh != null) {
        widget.onRefresh!(widget.type);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isApproving = false;
      });
    }
  }

  Widget _buildApprovalCard(dynamic approval) {
    final id = _getApprovalId(approval);
    final isSelected = _selectedApprovals.contains(id);

    Widget card;
    switch (widget.type) {
      case 'pr':
        card = PRApprovalCard(
          approval: approval as PurchaseRequisitionApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'po_ops':
        card = POOpsApprovalCard(
          approval: approval as PurchaseOrderOpsApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'leave':
      case 'hrd':
        card = LeaveApprovalCard(
          approval: approval as LeaveApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'category_cost':
        card = CategoryCostApprovalCard(
          approval: approval as CategoryCostApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'stock_adjustment':
        card = StockAdjustmentApprovalCard(
          approval: approval as StockAdjustmentApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'stock_opname':
        card = StockOpnameApprovalCard(
          approval: approval as StockOpnameApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'outlet_transfer':
        card = OutletTransferApprovalCard(
          approval: approval as OutletTransferApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'contra_bon':
        card = ContraBonApprovalCard(
          approval: approval as ContraBonApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'movement':
        card = MovementApprovalCard(
          approval: approval as EmployeeMovementApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'coaching':
        card = CoachingApprovalCard(
          approval: approval as CoachingApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'correction':
        card = CorrectionApprovalCard(
          approval: approval as CorrectionApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'food_payment':
        card = FoodPaymentApprovalCard(
          approval: approval as FoodPaymentApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'non_food_payment':
        card = NonFoodPaymentApprovalCard(
          approval: approval as NonFoodPaymentApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'pr_food':
        card = PRFoodApprovalCard(
          approval: approval as PRFoodApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'po_food':
        card = POFoodApprovalCard(
          approval: approval as POFoodApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'ro_khusus':
        card = ROKhususApprovalCard(
          approval: approval as ROKhususApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      case 'employee_resignation':
        card = EmployeeResignationApprovalCard(
          approval: approval as EmployeeResignationApproval,
          onTap: _isSelecting ? () => _toggleSelection(id) : () => _navigateToDetail(approval),
        );
        break;
      default:
        return const SizedBox.shrink();
    }

    if (_isSelecting) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? widget.color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) => _toggleSelection(id),
              activeColor: widget.color,
            ),
            Expanded(child: card),
          ],
        ),
      );
    }

    return card;
  }

  void _navigateToDetail(dynamic approval) async {
    Widget? detailScreen;
    
    switch (widget.type) {
      case 'pr':
        detailScreen = PRApprovalDetailScreen(prId: (approval as PurchaseRequisitionApproval).id);
        break;
      case 'po_ops':
        detailScreen = POOpsApprovalDetailScreen(poId: (approval as PurchaseOrderOpsApproval).id);
        break;
      case 'leave':
        detailScreen = LeaveApprovalDetailScreen(leaveId: (approval as LeaveApproval).id, isHrd: false);
        break;
      case 'hrd':
        detailScreen = LeaveApprovalDetailScreen(leaveId: (approval as LeaveApproval).id, isHrd: true);
        break;
      case 'category_cost':
        detailScreen = CategoryCostApprovalDetailScreen(headerId: (approval as CategoryCostApproval).id);
        break;
      case 'stock_adjustment':
        detailScreen = StockAdjustmentApprovalDetailScreen(adjustmentId: (approval as StockAdjustmentApproval).id);
        break;
      case 'stock_opname':
        detailScreen = StockOpnameDetailScreen(opnameId: (approval as StockOpnameApproval).id);
        break;
      case 'outlet_transfer':
        detailScreen = OutletTransferDetailScreen(transferId: (approval as OutletTransferApproval).id);
        break;
      case 'contra_bon':
        detailScreen = ContraBonApprovalDetailScreen(cbId: (approval as ContraBonApproval).id);
        break;
      case 'movement':
        detailScreen = MovementApprovalDetailScreen(movementId: (approval as EmployeeMovementApproval).id);
        break;
      case 'coaching':
        detailScreen = CoachingApprovalDetailScreen(coachingId: (approval as CoachingApproval).id);
        break;
      case 'correction':
        detailScreen = CorrectionApprovalDetailScreen(correctionId: (approval as CorrectionApproval).id);
        break;
      case 'food_payment':
        detailScreen = FoodPaymentApprovalDetailScreen(paymentId: (approval as FoodPaymentApproval).id);
        break;
      case 'non_food_payment':
        detailScreen = NonFoodPaymentApprovalDetailScreen(paymentId: (approval as NonFoodPaymentApproval).id);
        break;
      case 'pr_food':
        detailScreen = PRFoodApprovalDetailScreen(prFoodId: (approval as PRFoodApproval).id);
        break;
      case 'po_food':
        detailScreen = POFoodApprovalDetailScreen(poFoodId: (approval as POFoodApproval).id);
        break;
      case 'ro_khusus':
        detailScreen = ROKhususApprovalDetailScreen(roKhususId: (approval as ROKhususApproval).id);
        break;
      case 'employee_resignation':
        detailScreen = EmployeeResignationApprovalDetailScreen(resignationId: (approval as EmployeeResignationApproval).id);
        break;
    }

    if (detailScreen != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => detailScreen!),
      );

      // If approval/reject was successful, reload the list
      if (result == true) {
        await _reloadApprovals();
        
        // Also notify parent to refresh
        if (widget.onRefresh != null) {
          widget.onRefresh!(widget.type);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: widget.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_filteredApprovals.length} approval',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (_isLoading)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Multi-approve controls
            if (_isSelecting) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Use column layout for small screens, row for larger screens
                    if (constraints.maxWidth < 400) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${_selectedApprovals.length} item dipilih',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: _selectAll,
                                  icon: const Icon(Icons.select_all, size: 16),
                                  label: const Text('Select All', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: widget.color,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isApproving ? null : _approveMultiple,
                                  icon: _isApproving
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Icon(Icons.check, size: 16),
                                  label: const Text('Approve', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.color,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${_selectedApprovals.length} item dipilih',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: widget.color,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: TextButton.icon(
                              onPressed: _selectAll,
                              icon: const Icon(Icons.select_all, size: 16),
                              label: const Text('Select All', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: widget.color,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: ElevatedButton.icon(
                              onPressed: _isApproving ? null : _approveMultiple,
                              icon: _isApproving
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.check, size: 16),
                              label: const Text('Approve', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.color,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Search bar and Multi Approve button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _getSearchPlaceholder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isSelecting ? Icons.close : Icons.check_box),
                  onPressed: () {
                    setState(() {
                      _isSelecting = !_isSelecting;
                      if (!_isSelecting) {
                        _selectedApprovals.clear();
                      }
                    });
                  },
                  tooltip: _isSelecting ? 'Cancel' : 'Multi Approve',
                  color: widget.color,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Approval list
            Expanded(
              child: _isLoading && _approvals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: AppLoadingIndicator(size: 24, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Memuat ulang...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _filteredApprovals.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'Tidak ada approval yang sesuai dengan pencarian'
                                    : 'Tidak ada approval',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _filteredApprovals.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildApprovalCard(_filteredApprovals[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

