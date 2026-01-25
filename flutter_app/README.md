# H4 Flutter App 🚀

En moderne Flutter applikation bygget med **Clean Architecture**, **BLoC Pattern** og **Repository Pattern**.

## 📚 Indholdsfortegnelse

- [Arkitektur Oversigt](#-arkitektur-oversigt)
- [Lagstruktur](#-lagstruktur)
- [Projektstruktur](#-projektstruktur)
- [Kom i Gang](#-kom-i-gang)
- [Teknologier](#-teknologier)
- [Features](#-features)
- [Dokumentation](#-dokumentation)

---

## 🏗️ Arkitektur Oversigt

Projektet følger **Clean Architecture** principper kombineret med **BLoC Pattern** for state management og **Repository Pattern** for data access.

### Arkitektur Diagram

```
┌─────────────────────────────────────────┐
│     PRESENTATION LAYER                  │
│  ┌──────────────────────────────────┐   │
│  │  UI (Widgets & Pages)            │   │
│  └──────────┬───────────────────────┘   │
│             │ Events ↓                   │
│  ┌──────────▼───────────────────────┐   │
│  │  BLoC (State Management)         │   │
│  └──────────┬───────────────────────┘   │
│             │ States ↑                   │
└─────────────┼─────────────────────────┘
              │ Calls Repository Interface
┌─────────────▼─────────────────────────┐
│     DOMAIN LAYER                      │
│  ┌──────────────────────────────────┐ │
│  │  Entities (Business Objects)     │ │
│  └──────────────────────────────────┘ │
│  ┌──────────────────────────────────┐ │
│  │  Repository Interfaces           │ │
│  └──────────────────────────────────┘ │
└─────────────┬─────────────────────────┘
              │ Implemented by
┌─────────────▼─────────────────────────┐
│     DATA LAYER                        │
│  ┌──────────────────────────────────┐ │
│  │  Repository Implementations      │ │
│  └──────────┬───────────────────────┘ │
│             │                          │
│  ┌──────────▼───────────────────────┐ │
│  │  Data Sources (Remote/Local)    │ │
│  └──────────┬───────────────────────┘ │
│             │                          │
│  ┌──────────▼───────────────────────┐ │
│  │  Models/DTOs (JSON ↔ Object)    │ │
│  └──────────────────────────────────┘ │
└─────────────┬─────────────────────────┘
              │
┌─────────────▼─────────────────────────┐
│     CORE INFRASTRUCTURE               │
│  - API Client (HTTP/Dio)              │
│  - Dependency Injection (get_it)      │
│  - Configuration (Environment)        │
│  - Error Handling (ApiResult<T>)      │
└───────────────────────────────────────┘
```

---

## 🎯 Lagstruktur

### 1️⃣ Presentation Layer (UI + BLoC)

**Ansvar:** Vise data til brugeren og håndtere brugerinteraktioner.

**Komponenter:**
- **Widgets & Pages**: Flutter UI komponenter
- **BLoC**: Business Logic Component til state management
  - **Events**: Input (brugerhandlinger)
  - **States**: Output (UI tilstande)
  - **BLoC**: Processor der omdanner events til states

**Eksempel:**
```dart
// UI dispatcher event
context.read<WeatherBloc>().add(LoadWeatherData());

// BLoC behandler event og emitter state
class WeatherBloc extends Bloc<WeatherEvent, WeatherState> {
  Future<void> _onLoad(LoadWeatherData event, Emitter emit) async {
    emit(WeatherLoading());
    final result = await repository.getWeatherForecast();
    result.when(
      success: (data) => emit(WeatherLoaded(data)),
      failure: (error) => emit(WeatherError(error.userMessage)),
    );
  }
}

// UI reagerer på state
BlocBuilder<WeatherBloc, WeatherState>(
  builder: (context, state) => switch (state) {
    WeatherLoading() => CircularProgressIndicator(),
    WeatherLoaded() => WeatherList(state.weatherData),
    WeatherError() => ErrorWidget(state.message),
    _ => SizedBox(),
  },
)
```

**Vigtige punkter:**
- ✅ BLoC kender IKKE til UI detaljer
- ✅ UI kender IKKE til data source detaljer
- ✅ BLoC afhænger kun af Repository Interface

---

### 2️⃣ Domain Layer (Business Logic)

**Ansvar:** Definere kerneforretningslogik og kontrakter.

**Komponenter:**
- **Entities**: Business objekter (uafhængige af data format)
- **Repository Interfaces**: Kontrakter for data access (abstrakt)

**Eksempel:**
```dart
// Entity - Repræsenterer vejrdata i business logic
class WeatherEntity extends Equatable {
  final DateTime date;
  final int temperatureC;
  final String? summary;
  
  const WeatherEntity({
    required this.date,
    required this.temperatureC,
    this.summary,
  });
}

// Repository Interface - Kontrakt for data access
abstract class WeatherRepository {
  Future<ApiResult<List<WeatherEntity>>> getWeatherForecast();
  Future<ApiResult<WeatherEntity>> getWeatherByDate(DateTime date);
}
```

**Vigtige punkter:**
- ✅ Entities er uafhængige af data source format
- ✅ Interfaces gør det nemt at skifte implementationer
- ✅ Domain layer kender IKKE til implementation detaljer

---

### 3️⃣ Data Layer (Data Access)

**Ansvar:** Håndtere data fra eksterne kilder (API, database, cache).

**Komponenter:**
- **Repository Implementations**: Konkrete implementationer af interfaces
- **Data Sources**: Remote (API) eller Local (Database/Cache)
- **Models/DTOs**: Data transfer objects til JSON serialization

**Eksempel:**
```dart
// Model - Håndterer JSON serialization
class WeatherModel {
  final DateTime date;
  final int temperatureC;
  
  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      date: DateTime.parse(json['date']),
      temperatureC: json['temperatureC'],
    );
  }
  
  // Konverter til Entity
  WeatherEntity toEntity() => WeatherEntity(
    date: date,
    temperatureC: temperatureC,
  );
}

// Data Source - API kald
class WeatherRemoteDataSourceImpl {
  final ApiClient apiClient;
  
  Future<ApiResult<List<WeatherModel>>> getWeatherForecast() async {
    return await apiClient.get<List<WeatherModel>>(
      '/WeatherForecast',
      fromJson: (json) => (json as List)
          .map((e) => WeatherModel.fromJson(e))
          .toList(),
    );
  }
}

// Repository Implementation - Koordinerer data sources
class WeatherRepositoryImpl implements WeatherRepository {
  final WeatherRemoteDataSource remoteDataSource;
  
  @override
  Future<ApiResult<List<WeatherEntity>>> getWeatherForecast() async {
    final result = await remoteDataSource.getWeatherForecast();
    // Konverter Models til Entities
    return result.map((models) => 
      models.map((m) => m.toEntity()).toList()
    );
  }
}
```

**Vigtige punkter:**
- ✅ Models håndterer JSON ↔ Object konvertering
- ✅ Repository konverterer Models til Entities
- ✅ Data Sources kender kun til rå data operationer

---

### 4️⃣ Core Layer (Infrastructure)

**Ansvar:** Provide fælles funktionalitet på tværs af appen.

**Komponenter:**
- **API Client**: Central HTTP klient (Dio)
- **API Result**: Type-safe error handling
- **API Interceptors**: Logging, auth, retry logic
- **Dependency Injection**: get_it container
- **Configuration**: Environment setup (dev/prod)

**Eksempel:**
```dart
// API Client - Central HTTP klient
class ApiClient {
  Future<ApiResult<T>> get<T>(
    String path, {
    required T Function(dynamic json) fromJson,
  }) async {
    try {
      final response = await dio.get(path);
      final data = fromJson(response.data);
      return ApiResult.success(data);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }
}

// API Result - Type-safe result type
sealed class ApiResult<T> {
  factory ApiResult.success(T data) = Success<T>;
  factory ApiResult.failure(ApiException exception) = Failure<T>;
  
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException exception) failure,
  });
}

// Dependency Injection - Setup
Future<void> setupDependencyInjection() async {
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());
  getIt.registerLazySingleton<WeatherRepository>(
    () => WeatherRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<WeatherBloc>(
    () => WeatherBloc(repository: getIt()),
  );
}

// Environment Configuration
await AppConfig.initialize(Environment.development); // eller production
```

**Vigtige punkter:**
- ✅ ApiClient håndterer alle HTTP requests
- ✅ ApiResult eliminerer exceptions i flow control
- ✅ DI gør testing og skalering nemt

---

## 📁 Projektstruktur

```
lib/
├── core/                           # 🔧 Core Infrastructure
│   ├── api/
│   │   ├── api_client.dart         # Central HTTP klient
│   │   ├── api_result.dart         # Type-safe result type
│   │   └── api_interceptor.dart    # Logging, auth, retry
│   ├── config/
│   │   └── app_config.dart         # Environment configuration
│   ├── di/
│   │   └── injection.dart          # Dependency injection setup
│   ├── constants/
│   │   └── api_constants.dart      # API konstanter
│   ├── theme/
│   │   ├── theme.dart              # App tema
│   │   ├── colors.dart             # Farver
│   │   └── typography.dart         # Typografi
│   └── utils/
│       ├── date_utils.dart         # Date hjælpefunktioner
│       └── snackbar_utils.dart     # UI utilities
│
├── domain/                         # 💼 Domain Layer
│   ├── entities/
│   │   └── weather_entity.dart     # Business entities
│   └── repositories/
│       └── weather_repository.dart # Repository interfaces
│
├── data/                           # 💾 Data Layer
│   ├── models/
│   │   └── weather_model.dart      # DTOs (JSON serialization)
│   ├── datasources/
│   │   └── weather_remote_datasource.dart  # Remote data source
│   └── repositories/
│       └── weather_repository_impl.dart    # Repository implementations
│
├── features/                       # 🎨 Features (Presentation)
│   ├── weather/
│   │   ├── bloc/
│   │   │   ├── weather_bloc.dart   # BLoC logic
│   │   │   ├── weather_event.dart  # Events
│   │   │   └── weather_state.dart  # States
│   │   ├── model/
│   │   │   └── chart_data.dart     # View models
│   │   ├── view/
│   │   │   └── weather_page.dart   # Main UI
│   │   └── widgets/
│   │       ├── weather_card.dart
│   │       ├── weather_chart.dart
│   │       └── weather_list.dart
│   └── infographic/
│       └── view/
│           └── infographic_page.dart
│
├── routing/                        # 🗺️ Navigation
├── shared/                         # 🔄 Shared Components
│   ├── extensions/
│   └── widgets/
│
└── main.dart                       # 🚀 App Entry Point
```

---

## 🚀 Kom i Gang

### 1. Installer Dependencies

```bash
flutter pub get
```

### 2. Konfigurer Environment

I `main.dart` vælg environment:

```dart
// Development (localhost:5000)
await AppConfig.initialize(Environment.development);

// Production (deployed API)
await AppConfig.initialize(Environment.production);
```

### 3. Kør Appen

```bash
flutter run
```

---

## 🛠️ Teknologier

### State Management
- **flutter_bloc** (^8.1.3) - BLoC pattern implementation
- **equatable** (^2.0.5) - Value equality

### Networking
- **dio** (^5.4.0) - HTTP klient med interceptors

### Dependency Injection
- **get_it** (^7.6.4) - Service locator

### UI
- **fl_chart** (^0.66.0) - Charts og grafer
- **intl** (^0.19.0) - Internationalization

### Development
- **flutter_dotenv** (^5.1.0) - Environment configuration

---

## ✨ Features

### 📊 Weather Dashboard
- Real-time vejrdata fra API
- Grafisk visning med charts
- Pull-to-refresh funktionalitet
- Error handling med brugervenlige beskeder

### 📖 BLoC Infographic
- Interaktiv forklaring af BLoC pattern
- Arkitektur visualisering
- Code snippets og eksempler

---

## 📖 Dokumentation

### Detaljeret Dokumentation

- **[API_ARCHITECTURE.md](lib/API_ARCHITECTURE.md)** - Komplet API arkitektur guide
- **[QUICK_START.md](lib/QUICK_START.md)** - Quick start guide med templates
- **[API_MIGRATION_NOTES.md](API_MIGRATION_NOTES.md)** - Migration noter og breaking changes
- **[BLOC_DOCUMENTATION.md](BLOC_DOCUMENTATION.md)** - Omfattende BLoC dokumentation

### Quick Reference

**Tilføj ny feature:**
1. Opret entity i `domain/entities/`
2. Opret repository interface i `domain/repositories/`
3. Opret model i `data/models/`
4. Opret data source i `data/datasources/`
5. Implementer repository i `data/repositories/`
6. Opret BLoC i `features/<feature>/bloc/`
7. Registrer i DI (`core/di/injection.dart`)

**Se [QUICK_START.md](lib/QUICK_START.md) for detaljeret guide!**

---

## 🎯 Design Principper

### Clean Architecture
- ✅ Separation of Concerns
- ✅ Dependency Inversion
- ✅ Testability
- ✅ Independence fra frameworks

### BLoC Pattern
- ✅ Reaktiv state management
- ✅ Unidirectional data flow
- ✅ Testbar business logic
- ✅ Platform uafhængig

### Repository Pattern
- ✅ Data source abstraction
- ✅ Nem at skifte implementations
- ✅ Centralized data access
- ✅ Caching support

---

## 🧪 Testing

### Unit Testing BLoC

```dart
blocTest<WeatherBloc, WeatherState>(
  'emits WeatherLoaded when data loads successfully',
  build: () {
    when(() => mockRepository.getWeatherForecast())
        .thenAnswer((_) async => ApiResult.success([...]));
    return WeatherBloc(repository: mockRepository);
  },
  act: (bloc) => bloc.add(LoadWeatherData()),
  expect: () => [WeatherLoading(), WeatherLoaded(...)],
);
```

---

## 🔄 Data Flow Eksempel

```dart
// 1. UI trigger event
context.read<WeatherBloc>().add(LoadWeatherData());

// 2. BLoC modtager event
Future<void> _onLoad(LoadWeatherData event, Emitter emit) async {
  emit(WeatherLoading());
  
  // 3. BLoC kalder Repository Interface
  final result = await _repository.getWeatherForecast();
  
  // 4. Repository Implementation kalder Data Source
  // 5. Data Source kalder API Client
  // 6. API Client laver HTTP request
  
  // 7. Response konverteres: JSON → Model → Entity
  // 8. Repository returnerer ApiResult<Entity>
  
  // 9. BLoC pattern matcher på result
  result.when(
    success: (data) => emit(WeatherLoaded(data)),
    failure: (error) => emit(WeatherError(error.userMessage)),
  );
}

// 10. UI rebuilder baseret på ny state
```

---

## 🌟 Best Practices

### ✅ DO
- Brug Repository Pattern for data access
- Brug ApiResult<T> for error handling
- Separate Entity (domain) og Model (data)
- Inject dependencies via get_it
- Test BLoCs isoleret med mocks

### ❌ DON'T
- Kald API direkte fra BLoC
- Brug try/catch til flow control
- Hardcode API URLs
- Instantier dependencies manuelt
- Bland UI logic med business logic

---

## 🤝 Team & Projekt

Udviklet som del af H4 projektet på Mercantec.

### Bidrag
Når du tilføjer nye features:
1. Følg eksisterende arkitektur
2. Tilføj kommentarer på dansk
3. Opdater dokumentation
4. Test din kode

---

## 📚 Ressourcer

- [Flutter Dokumentation](https://docs.flutter.dev/)
- [BLoC Library](https://bloclibrary.dev/)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Dio HTTP Client](https://pub.dev/packages/dio)
- [Get It](https://pub.dev/packages/get_it)

---

**Happy Coding! 🚀**