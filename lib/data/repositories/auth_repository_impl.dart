// lib/data/repositories/auth_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../core/constants/enums.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/auth_local_ds.dart';
import '../datasources/remote/auth_remote_ds.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, UserEntity>> login({
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      final authResponse = await remoteDataSource.login(
        identifier: phone,
        password: password,
      );

      // Save tokens
      await localDataSource.saveToken(authResponse.accessToken);
      await localDataSource.saveRefreshToken(authResponse.refreshToken);

      // Save user
      await localDataSource.saveUser(authResponse.user);

      // Save company if available
      if (authResponse.company != null) {
        await localDataSource.saveCompany(authResponse.company!);
      }

      // Save credentials if remember me
      await localDataSource.saveCredentials(
        phone: phone,
        password: password,
        rememberMe: rememberMe,
      );

      return Right(authResponse.user.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> register({
    required String name,
    required String phone,
    required String password,
    required String companyId,
    UserRole role = UserRole.operator,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      final authResponse = await remoteDataSource.register(
        name: name,
        phone: phone,
        password: password,
        companyId: companyId,
        role: role,
      );

      // Save tokens
      await localDataSource.saveToken(authResponse.accessToken);
      await localDataSource.saveRefreshToken(authResponse.refreshToken);

      // Save user
      await localDataSource.saveUser(authResponse.user);

      // Save company if available
      if (authResponse.company != null) {
        await localDataSource.saveCompany(authResponse.company!);
      }

      return Right(authResponse.user.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.statusCode));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(message: e.message, fieldErrors: e.errors));
    } on NetworkException {
      return Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      // Try to logout on server
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.logout();
        } catch (_) {
          // Ignore server errors during logout
        }
      }

      // Clear local data
      await localDataSource.clearUser();
      await localDataSource.clearToken();
      await localDataSource.clearCompany();

      return const Right(null);
    } catch (e) {
      // Even if there's an error, try to clear local data
      await localDataSource.clearUser();
      await localDataSource.clearToken();
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, bool>> isLoggedIn() async {
    try {
      final isLoggedIn = await localDataSource.isLoggedIn();
      return Right(isLoggedIn);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      // Try to get from local first
      final localUser = await localDataSource.getSavedUser();
      
      if (localUser != null) {
        // If online, try to refresh user data
        if (await networkInfo.isConnected) {
          try {
            final remoteUser = await remoteDataSource.getCurrentUser();
            await localDataSource.saveUser(remoteUser);
            return Right(remoteUser.toEntity());
          } catch (_) {
            // If remote fails, return local data
            return Right(localUser.toEntity());
          }
        }
        return Right(localUser.toEntity());
      }

      // No local user, try remote
      if (await networkInfo.isConnected) {
        final remoteUser = await remoteDataSource.getCurrentUser();
        await localDataSource.saveUser(remoteUser);
        return Right(remoteUser.toEntity());
      }

      return Left(AuthFailure(message: 'User not found'));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.statusCode));
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    String? name,
    String? email,
    String? avatar,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      final updatedUser = await remoteDataSource.updateProfile(
        name: name,
        email: email,
        avatar: avatar,
      );

      await localDataSource.saveUser(updatedUser);
      return Right(updatedUser.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      await remoteDataSource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      
      // Update saved credentials if remember me is enabled
      final savedCreds = await localDataSource.getSavedCredentials();
      if (savedCreds != null && savedCreds['rememberMe'] == true) {
        await localDataSource.saveCredentials(
          phone: savedCreds['phone'],
          password: newPassword,
          rememberMe: true,
        );
      }

      return const Right(true);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> requestPasswordReset(String phone) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      await remoteDataSource.requestPasswordReset(phone);
      return const Right(true);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      await remoteDataSource.verifyOtp(phone: phone, otp: otp);
      return const Right(true);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      await remoteDataSource.resetPassword(
        phone: phone,
        otp: otp,
        newPassword: newPassword,
      );
      return const Right(true);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> resendOtp(String phone) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      await remoteDataSource.resendOtp(phone);
      return const Right(true);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String?>> getToken() async {
    try {
      final token = await localDataSource.getToken();
      return Right(token);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> refreshToken() async {
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      
      if (refreshToken == null) {
        return Left(AuthFailure(message: 'No refresh token available'));
      }

      if (!await networkInfo.isConnected) {
        return Left(NetworkFailure());
      }

      final authResponse = await remoteDataSource.refreshToken(refreshToken);

      await localDataSource.saveToken(authResponse.accessToken);
      await localDataSource.saveRefreshToken(authResponse.refreshToken);
      await localDataSource.saveUser(authResponse.user);

      return Right(authResponse.user.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getSavedCredentials() async {
    try {
      final credentials = await localDataSource.getSavedCredentials();
      return Right(credentials);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CompanyModel?>> getCompany() async {
    try {
      final company = await localDataSource.getSavedCompany();
      
      if (company != null) {
        return Right(company);
      }

      // Try to get from user
      final user = await localDataSource.getSavedUser();
      if (user != null && await networkInfo.isConnected) {
        try {
          final remoteCompany = await remoteDataSource.getCompanyDetails(user.companyId);
          await localDataSource.saveCompany(remoteCompany);
          return Right(remoteCompany);
        } catch (_) {
          return const Right(null);
        }
      }

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> updateFcmToken(String fcmToken) async {
    try {
      await localDataSource.saveFcmToken(fcmToken);
      
      if (await networkInfo.isConnected) {
        await remoteDataSource.updateFcmToken(fcmToken);
      }
      
      return const Right(true);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, bool>> isPhoneRegistered(String phone) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure());
    }

    try {
      final isRegistered = await remoteDataSource.isPhoneRegistered(phone);
      return Right(isRegistered);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DateTime?>> getLastSyncTime() async {
    try {
      final lastSync = await localDataSource.getLastSyncTime();
      return Right(lastSync);
    } catch (e) {
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, void>> saveLastSyncTime(DateTime dateTime) async {
    try {
      await localDataSource.saveLastSyncTime(dateTime);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }
}
