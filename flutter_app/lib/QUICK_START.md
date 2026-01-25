# 🚀 Quick Start Guide

Hurtig guide til at komme i gang med den nye API arkitektur.

## 📋 Prerequisites

Sørg for at have installeret packages:

```bash
flutter pub get
```

## ⚙️ Environment Setup

### 1. Vælg Environment

I `lib/main.dart`, skift environment baseret på dit behov:

```dart
// Development (localhost)
await AppConfig.initialize(Environment.development);

// Production (deployed API)
await AppConfig.initialize(Environment.production);
```

### 2. Environment Configuration

Environments er defineret i `lib/core/config/app_config.dart`:

**Development:**
- API URL: `http://localhost:5000/api`
- Logging: Aktiveret
- Brug til lokal udvikling

**Production:**
- API URL: `https://h4-api.mercantec.tech/api`
- Logging: Deaktiveret
- Brug til deployed version

## 🔧 Sådan bruger du API'en

### 1. Simple GET Request

```dart
// I din BLoC:
class WeatherBloc extends Bloc<WeatherEvent, WeatherState> {
  final WeatherRepository _repository;

  WeatherBloc({required WeatherRepository repository})
      : _repository = repository,
        super(WeatherInitial());

  Future<void> _onLoad(LoadWeatherData event, Emitter emit) async {
    emit(WeatherLoading());
    
    // Kald repository
    final result = await _repository.getWeatherForecast();
    
    // Håndter result
    result.when(
      success: (data) => emit(WeatherLoaded(data)),
      failure: (error) => emit(WeatherError(error.userMessage)),
    );
  }
}
```

### 2. POST Request (Eksempel)

```dart
Future<ApiResult<User>> createUser(User user) async {
  return await apiClient.post<User>(
    '/users',
    body: user.toJson(),
    fromJson: (json) => User.fromJson(json),
  );
}
```

### 3. Brug BLoC i UI

```dart
BlocProvider(
  create: (context) => getIt<WeatherBloc>()..add(LoadWeatherData()),
  child: BlocBuilder<WeatherBloc, WeatherState>(
    builder: (context, state) {
      return switch (state) {
        WeatherLoading() => CircularProgressIndicator(),
        WeatherLoaded() => WeatherList(state.weatherData),
        WeatherError() => ErrorWidget(state.message),
        _ => SizedBox(),
      };
    },
  ),
)
```

## 🆕 Tilføj Ny Feature

### Quick Template

1. **Opret Entity:**
```dart
// lib/domain/entities/my_entity.dart
class MyEntity extends Equatable {
  final String id;
  final String name;
  
  const MyEntity({required this.id, required this.name});
  
  @override
  List<Object?> get props => [id, name];
}
```

2. **Opret Repository Interface:**
```dart
// lib/domain/repositories/my_repository.dart
abstract class MyRepository {
  Future<ApiResult<List<MyEntity>>> getAll();
}
```

3. **Opret Model:**
```dart
// lib/data/models/my_model.dart
class MyModel {
  final String id;
  final String name;
  
  factory MyModel.fromJson(Map<String, dynamic> json) => MyModel(
    id: json['id'],
    name: json['name'],
  );
  
  MyEntity toEntity() => MyEntity(id: id, name: name);
}
```

4. **Opret DataSource:**
```dart
// lib/data/datasources/my_remote_datasource.dart
class MyRemoteDataSourceImpl implements MyRemoteDataSource {
  final ApiClient apiClient;
  
  MyRemoteDataSourceImpl({required this.apiClient});
  
  @override
  Future<ApiResult<List<MyModel>>> getAll() async {
    return await apiClient.get<List<MyModel>>(
      '/my-endpoint',
      fromJson: (json) => (json as List)
          .map((e) => MyModel.fromJson(e))
          .toList(),
    );
  }
}
```

5. **Implementer Repository:**
```dart
// lib/data/repositories/my_repository_impl.dart
class MyRepositoryImpl implements MyRepository {
  final MyRemoteDataSource remoteDataSource;
  
  MyRepositoryImpl({required this.remoteDataSource});
  
  @override
  Future<ApiResult<List<MyEntity>>> getAll() async {
    final result = await remoteDataSource.getAll();
    return result.map((models) => 
      models.map((m) => m.toEntity()).toList()
    );
  }
}
```

6. **Registrer i DI:**
```dart
// lib/core/di/injection.dart
getIt.registerLazySingleton<MyRemoteDataSource>(
  () => MyRemoteDataSourceImpl(apiClient: getIt()),
);

getIt.registerLazySingleton<MyRepository>(
  () => MyRepositoryImpl(remoteDataSource: getIt()),
);

getIt.registerFactory<MyBloc>(
  () => MyBloc(repository: getIt()),
);
```

7. **Opret BLoC:**
```dart
// lib/features/my_feature/bloc/my_bloc.dart
class MyBloc extends Bloc<MyEvent, MyState> {
  final MyRepository _repository;
  
  MyBloc({required MyRepository repository})
      : _repository = repository,
        super(MyInitial()) {
    on<LoadMyData>(_onLoad);
  }
  
  Future<void> _onLoad(LoadMyData event, Emitter emit) async {
    emit(MyLoading());
    final result = await _repository.getAll();
    result.when(
      success: (data) => emit(MyLoaded(data)),
      failure: (error) => emit(MyError(error.userMessage)),
    );
  }
}
```

## 🐛 Debugging

### Enable Logging

Logging er automatisk aktiveret i development mode.

Se logs i console:
```
╔═══════════════════════════════════════════════════════════════
║ 🚀 REQUEST
╠═══════════════════════════════════════════════════════════════
║ Method: GET
║ URL: http://localhost:5000/api/weather
...
```

### Common Issues

**Problem: "AppConfig er ikke initialiseret"**
```dart
// Løsning: Kald initialize i main.dart før runApp
await AppConfig.initialize(Environment.development);
```

**Problem: "Type mismatch in fromJson"**
```dart
// Løsning: Check at din fromJson matcher API response structure
fromJson: (json) {
  print('Debug JSON: $json'); // Debug print
  return MyModel.fromJson(json);
}
```

**Problem: "Connection refused"**
```dart
// Løsning: Sørg for at API kører lokalt på localhost:5000
// Eller skift til production environment
```

## 📊 Status Check

Test at alt virker:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup
  await AppConfig.initialize(Environment.development);
  await setupDependencyInjection();
  
  // Test DI
  final apiClient = getIt<ApiClient>();
  final repository = getIt<WeatherRepository>();
  final bloc = getIt<WeatherBloc>();
  
  print('✅ ApiClient: ${apiClient != null}');
  print('✅ Repository: ${repository != null}');
  print('✅ BLoC: ${bloc != null}');
  
  runApp(const MyApp());
}
```

## 📚 Næste Skridt

1. Læs [API_ARCHITECTURE.md](./API_ARCHITECTURE.md) for detaljeret arkitektur
2. Se eksempler i `features/weather/` for reference
3. Tilføj dine egne features følgende samme pattern

## 💡 Tips & Tricks

### Tip 1: Brug Pattern Matching
```dart
// I stedet for if/else
result.when(
  success: (data) => handleSuccess(data),
  failure: (error) => handleError(error),
);
```

### Tip 2: Dependency Injection Shortcuts
```dart
// I stedet for at håndtere DI manuelt
final bloc = getIt<MyBloc>();
```

### Tip 3: Environment Switching
```dart
// Quick switch mellem environments
const bool isProduction = bool.fromEnvironment('PRODUCTION');
await AppConfig.initialize(
  isProduction ? Environment.production : Environment.development
);
```

### Tip 4: Error Handling
```dart
// ApiException har brugervenlige beskeder
exception.userMessage // "Ingen internetforbindelse..."
```

## ❓ Hjælp

Hvis du sidder fast:
1. Check console logs (aktiveret i development)
2. Læs API_ARCHITECTURE.md
3. Se eksempler i weather feature
4. Spørg teamet!

---

**Happy Coding til jeres gruppe! 🎉**

