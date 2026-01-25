# Weather Feature

Denne feature implementerer vejrforudsigelse funktionalitet ved hjælp af MVVM-arkitekturen.

## Struktur

```
weather/
├── model/           # Weather-specifikke modeller
│   └── chart_data.dart
├── view/            # UI-komponenter (Views)
│   └── weather_page.dart
├── view_model/      # ViewModels for weather
│   └── weather_view_model.dart
└── widgets/         # Genanvendelige widgets
    ├── weather_card.dart
    ├── weather_chart.dart
    └── weather_list.dart
```

## Komponenter

### WeatherPage
Hovedview'et der viser vejrforudsigelsen. Bruger Provider til state management og viser forskellige states:
- **Initial**: Viser besked om at trykke opdater
- **Loading**: Viser loading spinner
- **Loaded**: Viser vejrdata i en liste
- **Error**: Viser fejlbesked med mulighed for at prøve igen

### WeatherViewModel
Håndterer business logic og state for weather featuren:
- `loadWeatherData()`: Henter vejrdata fra API
- `refresh()`: Genindlæser data
- State management med `WeatherState` enum
- Chart data processing med `ChartData` model

### WeatherCard
Widget der viser en enkelt vejrforudsigelse med:
- Dato og ugedag
- Temperatur i både Celsius og Fahrenheit
- Vejrbeskrivelse
- Farvekodet temperatur (blå for koldt, rød for varmt)

### WeatherChart
Widget der viser en temperatur graf med:
- Linje graf over temperatur over tid
- Dato labels på x-aksen
- Temperatur labels på y-aksen
- Gennemsnitstemperatur og antal dage i legend
- Responsive design der tilpasser sig data

### WeatherList
Container widget der viser både grafen og en liste af WeatherCard widgets.

## API Integration

Weather featuren bruger `WeatherService` til at kommunikere med backend API'et:
- Endpoint: `GET /WeatherForecast`
- Returnerer liste af `WeatherForecast` objekter
- Håndterer fejl og netværksproblemer

## Chart Features

Weather featuren inkluderer nu en interaktiv temperatur graf:
- **Linje graf** der viser temperatur over tid
- **Automatisk skalering** baseret på min/max temperaturer
- **Dato labels** på x-aksen (dag/måned format)
- **Temperatur labels** på y-aksen i Celsius
- **Gennemsnitstemperatur** beregning og visning
- **Responsive design** der tilpasser sig forskellige skærmstørrelser

## Brug

For at bruge weather featuren:

1. Sørg for at backend API'et kører på `http://localhost:5000`
2. App'en vil automatisk hente vejrdata når WeatherPage indlæses
3. Brug refresh-knappen i app bar til at opdatere data
4. Hvis der opstår fejl, vises en fejlbesked med "Prøv igen" knap

## Konfiguration

API URL'en kan ændres i `lib/core/constants/api_constants.dart`:
```dart
static const String baseUrl = 'http://localhost:5000';
``` 