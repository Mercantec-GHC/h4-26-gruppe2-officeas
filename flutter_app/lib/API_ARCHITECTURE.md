# API Kommunikations Arkitektur 📡

Denne dokumentation beskriver den nye API kommunikations arkitektur i vores Flutter app.

## 🎯 Overordnet Arkitektur

Vi følger **Clean Architecture** principper med **Repository Pattern** og **BLoC** for state management.

```
┌─────────────────────────────────────────┐
│  PRESENTATION LAYER                     │
│  - BLoC (State Management)              │
│  - Pages/Widgets (UI)                   │
└──────────────┬──────────────────────────┘
               │ depends on
┌──────────────▼──────────────────────────┐
│  DOMAIN LAYER                           │
│  - Entities (Business Objects)          │
│  - Repository Interfaces (Contracts)    │
└──────────────┬──────────────────────────┘
               │ implemented by
┌──────────────▼──────────────────────────┐
│  DATA LAYER                             │
│  - Repository Implementations           │
│  - Data Sources (Remote/Local)          │
│  - Models/DTOs                          │
└─────────────────────────────────────────┘
```

## 📁 Folder Struktur

```
lib/
├── core/
│   ├── api/
│   │   ├── api_client.dart          # Central HTTP klient (Dio)
│   │   ├── api_interceptor.dart     # Logging, auth, retry logic
│   │   └── api_result.dart          # Type-safe result type
│   ├── config/
│   │   └── app_config.dart          # Environment configuration
│   └── di/
│       └── injection.dart           # Dependency injection setup
│
├── domain/
│   ├── entities/
│   │   └── weather_entity.dart      # Business objects
│   └── repositories/
│       └── weather_repository.dart  # Repository interfaces
│
├── data/
│   ├── models/
│   │   └── weather_model.dart       # DTOs (JSON serialization)
│   ├── datasources/
│   │   └── weather_remote_datasource.dart
│   └── repositories/
│       └── weather_repository_impl.dart
│
└── features/
    └── weather/
        ├── bloc/                     # BLoC for state management
        ├── view/                     # UI components
        └── widgets/                  # Reusable widgets
```

## 🔄 Data Flow

### Request Flow (UI → API)
```
1. UI triggers event
   ↓
2. BLoC receives event
   ↓
3. BLoC calls Repository (interface)
   ↓
4. Repository Impl calls DataSource
   ↓
5. DataSource calls ApiClient
   ↓
6. ApiClient makes HTTP request
   ↓
7. API responds
```

### Response Flow (API → UI)
```
1. API response received
   ↓
2. ApiClient wraps in ApiResult<T>
   ↓
3. DataSource returns ApiResult<Model>
   ↓
4. Repository converts Model → Entity
   ↓
5. Repository returns ApiResult<Entity>
   ↓
6. BLoC pattern matches result
   ↓
7. BLoC emits new state
   ↓
8. UI rebuilds
```

## 🧩 Komponenter

### 1. ApiClient (`core/api/api_client.dart`)

Central HTTP klient der håndterer alle API requests.

**Features:**
- ✅ Type-safe responses med `ApiResult<T>`
- ✅ Automatic error handling
- ✅ Logging (kun i development)
- ✅ Retry logic ved fejl
- ✅ Timeout configuration
- ✅ Support for GET, POST, PUT, DELETE

**Usage:**
```dart
final apiClient = ApiClient();

final result = await apiClient.get<List<Weather>>(
  '/weather',
  fromJson: (json) => (json as List)
      .map((e) => Weather.fromJson(e))
      .toList(),
);
```

### 2. ApiResult (`core/api/api_result.dart`)

Type-safe result type til error handling uden exceptions.

**Success/Failure:**
```dart
sealed class ApiResult<T> {
  factory ApiResult.success(T data);
  factory ApiResult.failure(ApiException exception);
}
```

**Pattern Matching:**
```dart
result.when(
  success: (data) => print('Success: $data'),
  failure: (error) => print('Error: ${error.userMessage}'),
);
```

**Exception Types:**
- `NetworkException` - Ingen internet, timeout
- `ServerException` - 5xx fejl
- `ClientException` - 4xx fejl (400, 404, osv.)
- `UnauthorizedException` - 401 fejl
- `ParsingException` - Ugyldig JSON
- `UnknownException` - Ukendt fejl

### 3. Repository Pattern

**Interface (Domain Layer):**
```dart
abstract class WeatherRepository {
  Future<ApiResult<List<WeatherEntity>>> getWeatherForecast();
}
```

**Implementation (Data Layer):**
```dart
class WeatherRepositoryImpl implements WeatherRepository {
  final WeatherRemoteDataSource remoteDataSource;
  
  @override
  Future<ApiResult<List<WeatherEntity>>> getWeatherForecast() async {
    final result = await remoteDataSource.getWeatherForecast();
    return result.map((models) => 
      models.map((m) => m.toEntity()).toList()
    );
  }
}
```

### 4. BLoC Integration

BLoC afhænger kun af repository interface:

```dart
class WeatherBloc extends Bloc<WeatherEvent, WeatherState> {
  final WeatherRepository _repository; // Interface!

  WeatherBloc({required WeatherRepository repository})
      : _repository = repository,
        super(WeatherInitial()) {
    on<LoadWeatherData>(_onLoad);
  }

  Future<void> _onLoad(LoadWeatherData event, Emitter emit) async {
    emit(WeatherLoading());
    
    final result = await _repository.getWeatherForecast();
    
    result.when(
      success: (data) => emit(WeatherLoaded(data)),
      failure: (error) => emit(WeatherError(error.userMessage)),
    );
  }
}
```

### 5. Dependency Injection

Setup i `core/di/injection.dart`:

```dart
Future<void> setupDependencyInjection() async {
  // Core
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());
  
  // Data Sources
  getIt.registerLazySingleton<WeatherRemoteDataSource>(
    () => WeatherRemoteDataSourceImpl(apiClient: getIt()),
  );
  
  // Repositories (register as interface!)
  getIt.registerLazySingleton<WeatherRepository>(
    () => WeatherRepositoryImpl(remoteDataSource: getIt()),
  );
  
  // BLoCs (factory for new instances)
  getIt.registerFactory<WeatherBloc>(
    () => WeatherBloc(repository: getIt()),
  );
}
```

**Usage:**
```dart
// I main.dart
await setupDependencyInjection();

// I app
final weatherBloc = getIt<WeatherBloc>();
```

### 6. Environment Configuration

Skift nemt mellem localhost og deployed API:

```dart
// Development (localhost)
await AppConfig.initialize(Environment.development);

// Production (deployed)
await AppConfig.initialize(Environment.production);
```

**Environments:**
- `development` - http://localhost:5000/api
- `production` - https://h4-api.mercantec.tech/api
- `staging` - https://h4-api-staging.mercantec.tech/api

## 🚀 Sådan tilføjer du ny API endpoint

### 1. Opret Entity (Domain Layer)

```dart
// lib/domain/entities/user_entity.dart
class UserEntity extends Equatable {
  final String id;
  final String name;
  final String email;
  
  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
  });
  
  @override
  List<Object?> get props => [id, name, email];
}
```

### 2. Opret Repository Interface

```dart
// lib/domain/repositories/user_repository.dart
abstract class UserRepository {
  Future<ApiResult<List<UserEntity>>> getUsers();
  Future<ApiResult<UserEntity>> getUserById(String id);
  Future<ApiResult<UserEntity>> createUser(UserEntity user);
}
```

### 3. Opret Model (Data Layer)

```dart
// lib/data/models/user_model.dart
class UserModel {
  final String id;
  final String name;
  final String email;
  
  UserModel({
    required this.id,
    required this.name,
    required this.email,
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
  };
  
  UserEntity toEntity() => UserEntity(
    id: id,
    name: name,
    email: email,
  );
}
```

### 4. Opret DataSource

```dart
// lib/data/datasources/user_remote_datasource.dart
abstract class UserRemoteDataSource {
  Future<ApiResult<List<UserModel>>> getUsers();
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final ApiClient apiClient;
  
  UserRemoteDataSourceImpl({required this.apiClient});
  
  @override
  Future<ApiResult<List<UserModel>>> getUsers() async {
    return await apiClient.get<List<UserModel>>(
      '/users',
      fromJson: (json) => (json as List)
          .map((e) => UserModel.fromJson(e))
          .toList(),
    );
  }
}
```

### 5. Implementer Repository

```dart
// lib/data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;
  
  UserRepositoryImpl({required this.remoteDataSource});
  
  @override
  Future<ApiResult<List<UserEntity>>> getUsers() async {
    final result = await remoteDataSource.getUsers();
    return result.map((models) => 
      models.map((m) => m.toEntity()).toList()
    );
  }
  
  @override
  Future<ApiResult<UserEntity>> getUserById(String id) async {
    return await apiClient.get<UserEntity>(
      '/users/$id',
      fromJson: (json) => UserModel.fromJson(json).toEntity(),
    );
  }
  
  @override
  Future<ApiResult<UserEntity>> createUser(UserEntity user) async {
    return await apiClient.post<UserEntity>(
      '/users',
      body: UserModel.fromEntity(user).toJson(),
      fromJson: (json) => UserModel.fromJson(json).toEntity(),
    );
  }
}
```

### 6. Registrer i DI

```dart
// lib/core/di/injection.dart
Future<void> setupDependencyInjection() async {
  // ... existing registrations ...
  
  // User DataSource
  getIt.registerLazySingleton<UserRemoteDataSource>(
    () => UserRemoteDataSourceImpl(apiClient: getIt()),
  );
  
  // User Repository
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(remoteDataSource: getIt()),
  );
  
  // User BLoC
  getIt.registerFactory<UserBloc>(
    () => UserBloc(repository: getIt()),
  );
}
```

### 7. Brug i BLoC

```dart
class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository _repository;
  
  UserBloc({required UserRepository repository})
      : _repository = repository,
        super(UserInitial()) {
    on<LoadUsers>(_onLoadUsers);
  }
  
  Future<void> _onLoadUsers(LoadUsers event, Emitter emit) async {
    emit(UserLoading());
    
    final result = await _repository.getUsers();
    
    result.when(
      success: (users) => emit(UserLoaded(users)),
      failure: (error) => emit(UserError(error.userMessage)),
    );
  }
}
```

## ✅ Best Practices

### DO ✅

1. **Brug Repository Pattern**
   - BLoC afhænger kun af repository interface
   - Repository håndterer data source koordination

2. **Brug ApiResult for error handling**
   - Type-safe, ingen exceptions i flow control
   - Pattern matching tvinger dig til at håndtere errors

3. **Separate Entity og Model**
   - Entity: Business logic (domain layer)
   - Model: Data transfer (data layer)

4. **Dependency Injection**
   - Register dependencies ved app start
   - Inject via getIt<T>()

5. **Environment Configuration**
   - Brug AppConfig til API URLs
   - Nem at skifte mellem dev/prod

### DON'T ❌

1. **Kald API direkte fra BLoC**
   ```dart
   // ❌ FORKERT
   class WeatherBloc {
     Future<void> load() async {
       final response = await http.get('...');
     }
   }
   ```

2. **Brug try/catch overalt**
   ```dart
   // ❌ FORKERT
   try {
     final data = await api.get();
   } catch (e) {
     // Exceptions til flow control
   }
   
   // ✅ RIGTIGT
   final result = await api.get();
   result.when(
     success: (data) => ...,
     failure: (error) => ...,
   );
   ```

3. **Hardcode API URLs**
   ```dart
   // ❌ FORKERT
   final url = 'http://localhost:5000/api';
   
   // ✅ RIGTIGT
   final url = AppConfig.instance.apiBaseUrl;
   ```

4. **Instantier dependencies manuelt**
   ```dart
   // ❌ FORKERT
   final bloc = WeatherBloc(
     repository: WeatherRepositoryImpl(
       dataSource: WeatherRemoteDataSourceImpl(
         apiClient: ApiClient(),
       ),
     ),
   );
   
   // ✅ RIGTIGT
   final bloc = getIt<WeatherBloc>();
   ```

## 🧪 Testing

### Mock Repository i Tests

```dart
class MockWeatherRepository extends Mock implements WeatherRepository {}

void main() {
  late WeatherBloc bloc;
  late MockWeatherRepository mockRepository;
  
  setUp(() {
    mockRepository = MockWeatherRepository();
    bloc = WeatherBloc(repository: mockRepository);
  });
  
  test('emits WeatherLoaded when data is fetched successfully', () async {
    // Arrange
    final weatherData = [WeatherEntity(...)];
    when(() => mockRepository.getWeatherForecast())
        .thenAnswer((_) async => ApiResult.success(weatherData));
    
    // Act
    bloc.add(LoadWeatherData());
    
    // Assert
    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<WeatherLoading>(),
        isA<WeatherLoaded>(),
      ]),
    );
  });
}
```

## 📚 Yderligere Ressourcer

- [Clean Architecture by Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [BLoC Pattern Documentation](https://bloclibrary.dev/)
- [Dio HTTP Client](https://pub.dev/packages/dio)
- [Get It Dependency Injection](https://pub.dev/packages/get_it)

## 🤝 Bidrag

Når I tilføjer nye features:
1. Følg eksisterende arkitektur
2. Tilføj kommentarer på dansk
3. Opdater denne dokumentation
4. Test din kode

---

**Spørgsmål?** Kontakt teamet! 🚀

