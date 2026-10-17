# Phase 9: External REST API Integration Documentation

## 1. Overview & Capabilities

Phase 9 integrates reliable, external REST APIs into TourMate, providing real-time meteorological information and worldwide destination geocoding without requiring paid API keys or exposing sensitive credentials.

Key capabilities introduced:
- **Real-Time Weather**: Current temperature, apparent temperature ("feels like"), relative humidity, wind speed, precipitation, and human-readable weather conditions.
- **Multi-Day Weather Forecasts**: 7-day daily forecasts including daily high/low temperatures, precipitation likelihood, and weather conditions.
- **WMO 4677 Weather Code Interpretation**: Mapping from standard international WMO codes to human-readable descriptions and Material weather icons.
- **Worldwide Destination Geocoding**: Search any city or destination globally to retrieve normalized coordinates, administrative regions, country information, and elevations.
- **Smart Trip Itinerary Weather Correlation**: Correlates scheduled trip days with the 7-day forecast horizon, indicating when trip departure dates exceed available forecast coverage.
- **In-Memory Caching & Performance**: Normalized coordinate caching (15-minute TTL for weather, 30-minute TTL for geocoding) and concurrent in-flight request deduplication.
- **Offline / Graceful Degradation**: Retains stale cache for offline fallback when network connectivity fails, with explicit user retry and refresh capabilities.

---

## 2. API Providers & Official Documentation

| Provider | Service | Endpoint | Documentation Link |
| :--- | :--- | :--- | :--- |
| **Open-Meteo** | Weather Forecast API | `https://api.open-meteo.com/v1/forecast` | [Open-Meteo Forecast Docs](https://open-meteo.com/en/docs) |
| **Open-Meteo** | Geocoding API | `https://geocoding-api.open-meteo.com/v1/search` | [Open-Meteo Geocoding Docs](https://open-meteo.com/en/docs/geocoding-api) |

---

## 3. Data Fields Retrieved & Processed

### 3.1 Weather Forecast Data
- **Location**: `latitude`, `longitude`, `elevation`, `timezone`, `timezone_abbreviation`.
- **Current Observation (`current`)**:
  - `temperature_2m` (°C)
  - `apparent_temperature` (°C)
  - `relative_humidity_2m` (%)
  - `precipitation` (mm)
  - `weather_code` (WMO code)
  - `wind_speed_10m` (km/h)
  - `time` (ISO 8601 string)
- **Daily Forecast (`daily`)**:
  - `time` (array of dates)
  - `weather_code` (array of WMO codes)
  - `temperature_2m_max` (array of daily highs in °C)
  - `temperature_2m_min` (array of daily lows in °C)
  - `precipitation_sum` (array of expected precipitation in mm)

### 3.2 Destination Geocoding Data
- `id` (int): Unique geographic identifier.
- `name` (String): Place / city name.
- `latitude` (double), `longitude` (double): Geographic coordinates.
- `country` (String), `country_code` (String): Country name and 2-letter ISO code.
- `admin1` (String): State / province / department.
- `elevation` (double): Elevation in meters.
- `timezone` (String): Local IANA timezone name.

---

## 4. WMO 4677 Weather-Code Mapping

Open-Meteo utilizes the World Meteorological Organization (WMO) Code Table 4677:

| WMO Code | Condition Label | Icon |
| :--- | :--- | :--- |
| **0** | Clear sky | `Icons.wb_sunny_rounded` |
| **1** | Mainly clear | `Icons.wb_sunny_outlined` |
| **2** | Partly cloudy | `Icons.wb_cloudy_rounded` |
| **3** | Overcast | `Icons.cloud_rounded` |
| **45, 48** | Fog / Depositing rime fog | `Icons.blur_on_rounded` / `Icons.blur_linear_rounded` |
| **51, 53, 55** | Light / Moderate / Dense drizzle | `Icons.grain_rounded` / `Icons.water_drop_outlined` |
| **56, 57** | Freezing drizzle | `Icons.ac_unit_rounded` |
| **61, 63, 65** | Slight / Moderate / Heavy rain | `Icons.water_drop_outlined` / `Icons.water_drop_rounded` / `Icons.thunderstorm_outlined` |
| **66, 67** | Freezing rain | `Icons.ac_unit_rounded` |
| **71, 73, 75, 77** | Slight / Moderate / Heavy snow / Grains | `Icons.cloudy_snowing` / `Icons.ac_unit_rounded` |
| **80, 81, 82** | Slight / Moderate / Violent rain showers | `Icons.water_drop_outlined` / `Icons.thunderstorm_rounded` |
| **85, 86** | Snow showers | `Icons.cloudy_snowing` |
| **95, 96, 99** | Thunderstorm / Thunderstorm with hail | `Icons.thunderstorm_rounded` |
| *Other/Unknown* | Weather condition fallback | `Icons.wb_cloudy_outlined` |

---

## 5. Caching Strategy & Expiration

1. **Normalized Coordinate Caching**:
   - Coordinates are normalized to 3 decimal places (`~110m` resolution) using `latitude.toStringAsFixed(3),longitude.toStringAsFixed(3)`.
   - Small variations in GPS readings within the same attraction or tourist precinct share the exact same cached payload.
2. **Configurable TTL**:
   - Weather forecasts: **15 minutes** default TTL.
   - Geocoding queries: **30 minutes** default TTL.
3. **In-Flight Request Deduplication**:
   - Concurrent identical calls share the exact same active `Future`, completely eliminating redundant network calls.
4. **Offline Resilience**:
   - If an explicit refresh or network call fails, the client falls back to `getStaleWeather` and alerts the user with an "Offline — Showing cached weather" banner.

---

## 6. Error Handling & Robustness

- **Status Code Validation**: Differentiates 400 Bad Request, 429 Rate Limit Exceeded, and 500+ Server Errors with friendly user messaging.
- **Safe JSON Parsing**: All numeric values support both `num` and `String` representations, protecting against malformed types.
- **Fail-Safe UI**: Failed requests never crash screens. Components display inline error states with retry actions (`weather_retry_button`).

---

## 7. Security, Privacy & Attribution

- **No Secret API Keys**: Standard Open-Meteo endpoints require no secret tokens, ensuring zero risk of API key leakage in web builds.
- **No Private Data Transmitted**: Only public geographic coordinates or city names are transmitted. No user identity, tokens, or email addresses are sent to external APIs.
- **Attribution Display**: The required attribution `"Weather data by Open-Meteo"` is prominently rendered with a clickable link pointing to `https://open-meteo.com/`.

---

## 8. Limitations & Important Notes

- **Forecast Horizons**: Weather forecasts are mathematical estimates subject to atmospheric variation. Open-Meteo forecasts cover up to 7 to 14 days in advance. Trips scheduled beyond the 7-day horizon display current destination weather with an explicit notice.
- **Historical Weather**: Past trip dates display an informational notice that historical weather is not available from the standard forecast endpoint.
- **Fair-Use Limits**: Open-Meteo provides free access for non-commercial use up to 10,000 daily API calls. Commercial high-volume deployment requires a commercial license.

