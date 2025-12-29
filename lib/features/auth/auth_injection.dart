// lib/features/auth/auth_injection.dart

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_service.dart';
import '../../core/network/network_info.dart';
import '../../data/datasources/local/auth_local_ds.dart';
import '../../data/datasources/remote/auth_remote_ds.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import 'presentation/cubit/auth_cubit.dart';

/// Auth feature dependency injection
class AuthInjection {
  static final GetIt _sl = GetIt.instance;

  /// Register all auth dependencies
  static Future<void> init() async {
    // ==================== DATA SOURCES ====================

    // Local Data Source
    _sl.registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(
        sharedPreferences: _sl<SharedPreferences>(),
      ),
    );

    // Remote Data Source
    _sl.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(
        apiService: _sl<ApiService>(),
      ),
    );

    // ==================== REPOSITORY ====================

    _sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: _sl<AuthRemoteDataSource>(),
        localDataSource: _sl<AuthLocalDataSource>(),
        networkInfo: _sl<NetworkInfo>(),
      ),
    );

    // ==================== CUBIT ====================

    _sl.registerFactory<AuthCubit>(
      () => AuthCubit(
        authRepository: _sl<AuthRepository>(),
      ),
    );
  }

  /// Get AuthCubit instance
  static AuthCubit get authCubit => _sl<AuthCubit>();

  /// Get AuthRepository instance
  static AuthRepository get authRepository => _sl<AuthRepository>();

  /// Reset auth (for testing)
  static Future<void> reset() async {
    if (_sl.isRegistered<AuthCubit>()) {
      await _sl.unregister<AuthCubit>();
    }
    if (_sl.isRegistered<AuthRepository>()) {
      await _sl.unregister<AuthRepository>();
    }
    if (_sl.isRegistered<AuthRemoteDataSource>()) {
      await _sl.unregister<AuthRemoteDataSource>();
    }
    if (_sl.isRegistered<AuthLocalDataSource>()) {
      await _sl.unregister<AuthLocalDataSource>();
    }
  }
}