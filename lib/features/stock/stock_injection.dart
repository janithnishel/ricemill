import 'package:get_it/get_it.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import 'presentation/cubit/stock_cubit.dart';
import 'presentation/cubit/milling_cubit.dart';

/// Register all stock feature dependencies
void initStockInjection(GetIt sl) {
  // Cubits
  sl.registerFactory<StockCubit>(
    () => StockCubit(
      inventoryRepository: sl<InventoryRepository>(),
      authRepository: sl<AuthRepository>(),
    ),
  );

  sl.registerFactory<MillingCubit>(
    () => MillingCubit(
      inventoryRepository: sl<InventoryRepository>(),
    ),
  );
}

/// Dispose stock feature dependencies if needed
void disposeStockInjection(GetIt sl) {
  // Clean up if necessary
}
