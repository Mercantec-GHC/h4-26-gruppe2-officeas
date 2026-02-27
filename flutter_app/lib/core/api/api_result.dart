/// Type-safe Result type til håndtering af API responses
/// 
/// Inspiration fra Rust's Result<T, E> og Kotlin's Result
/// Undgår at bruge exceptions til flow control og giver bedre type safety.
/// 
/// Usage:
/// ```dart
/// Future<ApiResult<List<User>>> getUsers() async {
///   try {
///     final response = await api.get('/users');
///     return ApiResult.success(users);
///   } catch (e) {
///     return ApiResult.failure(ApiException.network(e.toString()));
///   }
/// }
/// 
/// // I BLoC:
/// final result = await repository.getUsers();
/// result.when(
///   success: (users) => emit(UsersLoaded(users)),
///   failure: (error) => emit(UsersError(error.message)),
/// );
/// ```
sealed class ApiResult<T> {
  const ApiResult();

  /// Success case - indeholder data af type T
  factory ApiResult.success(T data) = Success<T>;
  
  /// Failure case - indeholder ApiException med fejldetaljer
  factory ApiResult.failure(ApiException exception) = Failure<T>;

  /// Pattern matching helper
  /// 
  /// Tvinger dig til at håndtere både success og failure cases
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException exception) failure,
  }) {
    if (this is Success<T>) {
      return success((this as Success<T>).data);
    } else {
      return failure((this as Failure<T>).exception);
    }
  }

  /// Map success value til ny type
  ApiResult<R> map<R>(R Function(T data) transform) {
    return when(
      success: (data) => ApiResult.success(transform(data)),
      failure: (error) => ApiResult.failure(error),
    );
  }

  /// Check om result er success
  bool get isSuccess => this is Success<T>;
  
  /// Check om result er failure
  bool get isFailure => this is Failure<T>;

  /// Hent data (null hvis failure)
  T? get dataOrNull => isSuccess ? (this as Success<T>).data : null;
  
  /// Hent exception (null hvis success)
  ApiException? get exceptionOrNull => 
      isFailure ? (this as Failure<T>).exception : null;
}

/// Success case
final class Success<T> extends ApiResult<T> {
  final T data;
  const Success(this.data);

  @override
  String toString() => 'Success($data)';
}

/// Failure case
final class Failure<T> extends ApiResult<T> {
  final ApiException exception;
  const Failure(this.exception);

  @override
  String toString() => 'Failure($exception)';
}

/// API Exception typer
/// 
/// Forskellige fejltyper der kan opstå ved API kald.
/// Gør det nemt at vise brugervenlige fejlbeskeder.
sealed class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException(this.message, {this.statusCode, this.data});

  /// Netværksfejl (ingen internet, timeout, osv.)
  factory ApiException.network(String message) = NetworkException;
  
  /// Server fejl (500, 502, 503, osv.)
  factory ApiException.server(String message, {int? statusCode, dynamic data}) = 
      ServerException;
  
  /// Klient fejl (400, 401, 403, 404, osv.)
  factory ApiException.client(String message, {int? statusCode, dynamic data}) = 
      ClientException;
  
  /// Parsing fejl (ugyldig JSON response)
  factory ApiException.parsing(String message) = ParsingException;
  
  /// Ukendt fejl
  factory ApiException.unknown(String message) = UnknownException;
  
  /// Unauthorized (401) - bruges til at håndtere login redirect
  factory ApiException.unauthorized(String message) = UnauthorizedException;

  /// User-friendly error message
  String get userMessage {
    return when(
      network: (_) => 'No internet connection. Check your network connection.',
      server: (_) => 'A server error occurred. Please try again later.',
      client: (e) => e.statusCode == 404
          ? 'Data was not found.'
          : e.statusCode == 403
              ? 'You do not have access to this resource.'
              : message,
      parsing: (_) => 'Could not read data from the server.',
      unauthorized: (_) => 'Please sign in again.',
      unknown: (_) => 'An unexpected error occurred.',
    );
  }

  /// Pattern matching for exception type
  R when<R>({
    required R Function(NetworkException) network,
    required R Function(ServerException) server,
    required R Function(ClientException) client,
    required R Function(ParsingException) parsing,
    required R Function(UnauthorizedException) unauthorized,
    required R Function(UnknownException) unknown,
  }) {
    return switch (this) {
      NetworkException() => network(this as NetworkException),
      ServerException() => server(this as ServerException),
      ClientException() => client(this as ClientException),
      ParsingException() => parsing(this as ParsingException),
      UnauthorizedException() => unauthorized(this as UnauthorizedException),
      UnknownException() => unknown(this as UnknownException),
    };
  }

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// Netværksfejl
final class NetworkException extends ApiException {
  const NetworkException(super.message) : super(statusCode: null);
}

/// Server fejl (5xx)
final class ServerException extends ApiException {
  const ServerException(super.message, {super.statusCode, super.data});
}

/// Klient fejl (4xx)
final class ClientException extends ApiException {
  const ClientException(super.message, {super.statusCode, super.data});
}

/// Parsing fejl
final class ParsingException extends ApiException {
  const ParsingException(super.message) : super(statusCode: null);
}

/// Unauthorized fejl (401)
final class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message) : super(statusCode: 401);
}

/// Ukendt fejl
final class UnknownException extends ApiException {
  const UnknownException(super.message) : super(statusCode: null);
}

