// lib/features/buy/presentation/screens/add_stock_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:rice_mill_erp/core/shared_widgets/custom_keyboard/custom_keyboard.dart';
import 'package:rice_mill_erp/core/shared_widgets/custom_keyboard/keyboard_controller.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/shared_widgets/custom_button.dart';
import '../../../../core/shared_widgets/custom_text_field.dart';
import '../../../../core/shared_widgets/loading_overlay.dart';
import '../../../../core/shared_widgets/confirmation_dialog.dart';
import '../../../../data/models/inventory_item_model.dart';
import '../../../stock/presentation/cubit/stock_cubit.dart';
import '../../../stock/presentation/cubit/stock_state.dart';

/// Add Stock Screen - For manual stock adjustments and additions
class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _varietyController = TextEditingController();
  final _quantityController = KeyboardController(decimalPlaces: 3, allowDecimal: true);
  final _bagsController = KeyboardController(decimalPlaces: 0, allowDecimal: false);
  final _priceController = KeyboardController(decimalPlaces: 2, allowDecimal: true);
  final _notesController = TextEditingController();
  
  // Focus nodes
  final _varietyFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  final _bagsFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();
  
  // State variables
  ItemType _selectedType = ItemType.paddy;
  String? _selectedVariety;
  bool _isNewVariety = false;
  bool _showCustomKeyboard = false;
  KeyboardController? _activeController;
  String _activeField = '';
  
  // Predefined varieties
  final List<String> _paddyVarieties = [
    'Samba',
    'Nadu',
    'Keeri Samba',
    'Suwandel',
    'Kuruluthuda',
    'Pachchaperumal',
    'Rathu Heenati',
    'Madathawalu',
    'Other',
  ];
  
  final List<String> _riceVarieties = [
    'Samba Rice',
    'Nadu Rice',
    'Keeri Samba Rice',
    'Red Rice',
    'White Rice',
    'Basmati',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
  }

  void _setupFocusListeners() {
    _quantityFocusNode.addListener(() {
      if (_quantityFocusNode.hasFocus) {
        _showNumericKeyboard(_quantityController, 'quantity');
      }
    });
    
    _bagsFocusNode.addListener(() {
      if (_bagsFocusNode.hasFocus) {
        _showNumericKeyboard(_bagsController, 'bags');
      }
    });
    
    _priceFocusNode.addListener(() {
      if (_priceFocusNode.hasFocus) {
        _showNumericKeyboard(_priceController, 'price');
      }
    });
  }

  void _showNumericKeyboard(KeyboardController controller, String field) {
    setState(() {
      _showCustomKeyboard = true;
      _activeController = controller;
      _activeField = field;
    });
  }

  void _hideKeyboard() {
    setState(() {
      _showCustomKeyboard = false;
      _activeController = null;
      _activeField = '';
    });
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _varietyController.dispose();
    _quantityController.dispose();
    _bagsController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _varietyFocusNode.dispose();
    _quantityFocusNode.dispose();
    _bagsFocusNode.dispose();
    _priceFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  List<String> get _currentVarieties =>
      _selectedType == ItemType.paddy ? _paddyVarieties : _riceVarieties;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StockCubit, StockState>(
      listenWhen: (previous, current) =>
          previous?.stockAddStatus != current?.stockAddStatus,
      listener: (context, state) {
        if (state?.stockAddStatus == StockAddStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stock added successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        } else if (state?.stockAddStatus == StockAddStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state?.errorMessage ?? 'Failed to add stock'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        return LoadingOverlay(
          isLoading: state?.stockAddStatus == StockAddStatus.adding,
          message: 'Adding stock...',
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildAppBar(),
            body: GestureDetector(
              onTap: _hideKeyboard,
              child: Column(
                children: [
                  // Form content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(AppDimensions.paddingMedium),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item Type Selection
                            _buildTypeSelection(),
                            const SizedBox(height: 24),

                            // Variety Selection
                            _buildVarietySection(),
                            const SizedBox(height: 24),

                            // Quantity & Bags Row
                            _buildQuantityBagsRow(),
                            const SizedBox(height: 24),

                            // Price per KG
                            _buildPriceSection(),
                            const SizedBox(height: 24),

                            // Notes
                            _buildNotesSection(),
                            const SizedBox(height: 24),

                            // Preview Card
                            _buildPreviewCard(),
                            const SizedBox(height: 32),

                            // Add Stock Button
                            _buildAddButton(state),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Custom Keyboard
                  if (_showCustomKeyboard)
                    CustomKeyboard(
                      controller: _activeController!,
                      onDone: _hideKeyboard,
                      showDecimal: _activeField != 'bags',
                      displayLabel: _getKeyboardTitle(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Stock'),
          Text(
            'තොගයට එක් කරන්න',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: () {
            // TODO: Show stock history
            _showStockHistory();
          },
          tooltip: 'Stock History',
        ),
      ],
    );
  }

  Widget _buildTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Type',
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'වර්ගය තෝරන්න',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TypeSelectionCard(
                title: 'Paddy',
                subtitle: 'වී',
                icon: Icons.grass,
                color: AppColors.warning,
                isSelected: _selectedType == ItemType.paddy,
                onTap: () {
                  setState(() {
                    _selectedType = ItemType.paddy;
                    _selectedVariety = null;
                    _varietyController.clear();
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TypeSelectionCard(
                title: 'Rice',
                subtitle: 'සහල්',
                icon: Icons.rice_bowl,
                color: AppColors.primary,
                isSelected: _selectedType == ItemType.rice,
                onTap: () {
                  setState(() {
                    _selectedType = ItemType.rice;
                    _selectedVariety = null;
                    _varietyController.clear();
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVarietySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Variety',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'ප්‍රභේදය',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isNewVariety = !_isNewVariety;
                  if (!_isNewVariety) {
                    _varietyController.clear();
                  } else {
                    _selectedVariety = null;
                  }
                });
              },
              icon: Icon(
                _isNewVariety ? Icons.list : Icons.add,
                size: 18,
              ),
              label: Text(_isNewVariety ? 'Select Existing' : 'Add New'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (_isNewVariety)
          // New variety text field
          CustomTextField(
            controller: _varietyController,
            focusNode: _varietyFocusNode,
            hint: 'Enter new variety name',
            prefixIcon: Icons.eco,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if ((value == null || value.isEmpty) && _selectedVariety == null) {
                return 'Please enter a variety name';
              }
              return null;
            },
          )
        else
          // Variety dropdown
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ...List.generate(_currentVarieties.length, (index) {
                  final variety = _currentVarieties[index];
                  final isSelected = _selectedVariety == variety;
                  final isLast = index == _currentVarieties.length - 1;
                  
                  return Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (variety == 'Other') {
                              _isNewVariety = true;
                              _selectedVariety = null;
                            } else {
                              _selectedVariety = variety;
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textHint,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  variety,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast) const Divider(height: 1),
                    ],
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuantityBagsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantity Details',
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ප්‍රමාණය සහ මල්ල',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Quantity field
            Expanded(
              flex: 3,
              child: _buildInputCard(
                label: 'Weight (kg)',
                controller: _quantityController,
                focusNode: _quantityFocusNode,
                icon: Icons.scale,
                hint: '0.00',
                suffix: 'kg',
                onTap: () => _showNumericKeyboard(_quantityController, 'quantity'),
              ),
            ),
            const SizedBox(width: 12),
            // Bags field
            Expanded(
              flex: 2,
              child: _buildInputCard(
                label: 'Bags',
                controller: _bagsController,
                focusNode: _bagsFocusNode,
                icon: Icons.shopping_bag,
                hint: '0',
                suffix: 'bags',
                onTap: () => _showNumericKeyboard(_bagsController, 'bags'),
              ),
            ),
          ],
        ),
        
        // Average weight per bag indicator
        if (_quantityController.value.isNotEmpty &&
            _bagsController.value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildAverageWeightIndicator(),
          ),
      ],
    );
  }

  Widget _buildInputCard({
    required String label,
    required KeyboardController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hint,
    String? suffix,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: focusNode.hasFocus ? AppColors.primary : AppColors.border,
            width: focusNode.hasFocus ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    controller.isEmpty ? hint : controller.value,
                    style: AppTextStyles.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: controller.isEmpty
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (suffix != null)
                  Text(
                    suffix,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageWeightIndicator() {
    final quantity = double.tryParse(_quantityController.value) ?? 0;
    final bags = int.tryParse(_bagsController.value) ?? 0;
    
    if (bags == 0) return const SizedBox.shrink();
    
    final avgWeight = quantity / bags;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.info, size: 18),
          const SizedBox(width: 8),
          Text(
            'Average weight per bag: ',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '${avgWeight.toStringAsFixed(2)} kg',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.info,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price per KG (Optional)',
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'කිලෝවකට මිල',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _showNumericKeyboard(_priceController, 'price'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _priceFocusNode.hasFocus
                    ? AppColors.primary
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    color: AppColors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Rs.',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _priceController.isEmpty
                        ? '0.00'
                        : _priceController.value,
                    style: AppTextStyles.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _priceController.isEmpty
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '/kg',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Total value indicator
        if (_quantityController.value.isNotEmpty &&
            _priceController.value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildTotalValueIndicator(),
          ),
      ],
    );
  }

  Widget _buildTotalValueIndicator() {
    final quantity = double.tryParse(_quantityController.value) ?? 0;
    final price = double.tryParse(_priceController.value) ?? 0;
    final total = quantity * price;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Value:',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'Rs. ${_formatNumber(total)}',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'සටහන්',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _notesController,
          focusNode: _notesFocusNode,
          hint: 'Add any notes about this stock...',
          prefixIcon: Icons.notes,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          onTap: _hideKeyboard,
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    final variety = _isNewVariety
        ? _varietyController.text
        : _selectedVariety ?? '';
    final quantity = double.tryParse(_quantityController.value) ?? 0;
    final bags = int.tryParse(_bagsController.value) ?? 0;
    final price = double.tryParse(_priceController.value) ?? 0;
    
    if (variety.isEmpty && quantity == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _selectedType == ItemType.paddy
                ? AppColors.warning
                : AppColors.primary,
            _selectedType == ItemType.paddy
                ? AppColors.warning.withOpacity(0.8)
                : AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_selectedType == ItemType.paddy
                    ? AppColors.warning
                    : AppColors.primary)
                .withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _selectedType == ItemType.paddy
                      ? Icons.grass
                      : Icons.rice_bowl,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Preview',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      variety.isEmpty ? 'Select variety' : variety,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedType == ItemType.paddy ? 'Paddy' : 'Rice',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPreviewItem(
                  icon: Icons.scale,
                  value: '${quantity.toStringAsFixed(2)} kg',
                  label: 'Weight',
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.white.withOpacity(0.3),
                ),
                _buildPreviewItem(
                  icon: Icons.shopping_bag,
                  value: '$bags',
                  label: 'Bags',
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.white.withOpacity(0.3),
                ),
                _buildPreviewItem(
                  icon: Icons.attach_money,
                  value: price > 0 ? 'Rs.${price.toStringAsFixed(0)}' : '-',
                  label: 'Per KG',
                ),
              ],
            ),
          ),
          if (quantity > 0 && price > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Value:',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white.withOpacity(0.8),
                  ),
                ),
                Text(
                  'Rs. ${_formatNumber(quantity * price)}',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.white.withOpacity(0.8), size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTextStyles.titleSmall.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(StockState? state) {
    return CustomButton(
      label: 'Add Stock',
      icon: Icons.add_circle,
      onPressed: _validateAndSubmit,
      height: 56,
      isLoading: state?.stockAddStatus == StockAddStatus.adding,
    );
  }

  void _validateAndSubmit() async {
    // Hide keyboard
    _hideKeyboard();

    // Validate variety
    final variety = _isNewVariety
        ? _varietyController.text.trim()
        : _selectedVariety;
    
    if (variety == null || variety.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a variety'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate quantity
    final quantity = double.tryParse(_quantityController.value) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate bags
    final bags = int.tryParse(_bagsController.value) ?? 0;
    if (bags <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the number of bags'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Add Stock',
        message: 'Are you sure you want to add $quantity kg of $variety ${_selectedType == ItemType.paddy ? "paddy" : "rice"} ($bags bags) to inventory?',
        confirmLabel: 'Add Stock',
        confirmColor: AppColors.success,
        icon: Icons.inventory_2,
      ),
    );

    if (confirmed != true) return;

    // Get price
    final price = double.tryParse(_priceController.value) ?? 0;

    // Add stock
    context.read<StockCubit>().addStock(
      type: _selectedType,
      variety: variety,
      quantity: quantity,
      bags: bags,
      pricePerKg: price,
      notes: _notesController.text.trim(),
    );
  }

  String _getKeyboardTitle() {
    switch (_activeField) {
      case 'quantity':
        return 'Enter Weight (kg)';
      case 'bags':
        return 'Enter Number of Bags';
      case 'price':
        return 'Enter Price per KG';
      default:
        return '';
    }
  }

  void _showStockHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.history, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Recent Stock Additions',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content - placeholder
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No recent additions',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(2);
  }
}

/// Type selection card widget
class _TypeSelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeSelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? color : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.white : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}
