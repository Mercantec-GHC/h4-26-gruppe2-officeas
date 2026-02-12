# Schedule Feature - Quick Start Guide

## What Was Added

The calendar page now displays work shifts (schedules) from your backend database. When you open the Calendar page, it automatically:

1. Fetches all shifts from the `/shifts` API endpoint
2. Displays them as cards organized by date
3. Shows useful information like duration, user name, and whether the shift is currently active

## How to Use

### Viewing Shifts

1. Navigate to the Calendar page
2. The page will load and display all shifts as cards
3. Select a date range to see shifts within that period:
   - Click on a date to set the start date
   - Click another date to set the end date
   - Shifts in that range will appear below

4. To view shifts for a single day:
   - Click one date but don't select an end date
   - Shifts for that specific day will appear

### Understanding the Shift Cards

Each shift card displays:
- **User Name**: Who this shift is assigned to
- **Start Date & Time**: When the shift begins
- **Duration**: How long the shift lasts (e.g., "8h 0m")
- **Active Badge** (green): Appears if the shift is currently happening

**Color Coding:**
- **Teal background**: Regular shift
- **Green border**: Currently active shift
- **Gray border**: Past or future shift

### Refreshing Data

Click the **Refresh** button (↻) in the top-right corner to reload the latest shifts from the database.

## How It Works (Technical)

### Clean Architecture Pattern

```
Calendar Page (UI)
    ↓
ShiftRepository (Interface)
    ↓
ShiftRepositoryImpl (Implementation)
    ↓
ShiftRemoteDataSource (API calls)
    ↓
Dio HTTP Client
    ↓
Backend API
```

### Files Added

**Domain Layer (Business Logic):**
- `lib/domain/entities/shift_entity.dart` - Shift data model
- `lib/domain/repositories/shift_repository.dart` - Data access interface

**Data Layer (API Communication):**
- `lib/data/models/shift_model.dart` - JSON serialization
- `lib/data/datasources/shift_remote_datasource.dart` - HTTP requests
- `lib/data/repositories/shift_repository_impl.dart` - Data orchestration

**Configuration:**
- `lib/core/di/injection.dart` - Dependency injection setup (updated)
- `lib/main.dart` - Router configuration (updated)
- `lib/features/calendar/pages/calendar_page.dart` - UI (updated)

## Environment Configuration

The API connects to your backend based on environment:

**Development Mode** (default):
```
API Base URL: http://localhost:8080
```

**Production Mode:**
```
API Base URL: https://h4-api.mercantec.tech/api
```

To switch environments, edit `lib/main.dart`:
```dart
// Development (default)
await AppConfig.initialize(Environment.development);

// Production
// await AppConfig.initialize(Environment.production);
```

## Backend API Requirements

Make sure your backend `/shifts` endpoint returns data in this format:

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "user_id": "550e8400-e29b-41d4-a716-446655440001",
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "name": "John Doe"
    },
    "start_time": "2025-02-04T08:00:00Z",
    "end_time": "2025-02-04T16:00:00Z",
    "created_at": "2025-02-04T10:00:00Z",
    "updated_at": "2025-02-04T10:00:00Z"
  }
]
```

## API Endpoints Used

The implementation connects to these backend routes:

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/shifts` | Get all shifts |
| GET | `/shifts/{id}` | Get specific shift |
| GET | `/shifts/user/{userId}` | Get user's shifts |
| POST | `/shifts` | Create new shift |
| PUT | `/shifts/{id}` | Update shift |
| DELETE | `/shifts/{id}` | Delete shift |

## Error Handling

If shifts fail to load:
- A red error message (SnackBar) will appear at the top
- The error message will tell you what went wrong
- Click refresh to try again
- Check that your backend is running and accessible

## Testing the Feature

1. **Test with existing shifts:**
   - Ensure your database has shift records
   - Open Calendar page and verify shifts appear

2. **Test date filtering:**
   - Select different date ranges
   - Verify correct shifts appear for selected dates

3. **Test error handling:**
   - Stop the backend server
   - Try to load calendar (should show error)
   - Restart backend and refresh

4. **Test real-time updates:**
   - Create a shift in the database directly
   - Click refresh button
   - New shift should appear

## Customization

### Change Colors

Edit `lib/features/calendar/pages/calendar_page.dart`:

```dart
// Find _buildShiftCard() method
const backgroundColor = Colors.teal;  // Change card color
final borderColor = isActive ? Colors.green : Colors.grey;  // Change border
```

### Change Date Format

Edit `lib/features/calendar/pages/calendar_page.dart`:

```dart
// Current format: "HH:mm"
DateFormat('HH:mm').format(shift.startTime)

// Change to other formats:
DateFormat('h:mm a').format(shift.startTime)      // 2:00 PM
DateFormat('HH:mm:ss').format(shift.startTime)    // 14:00:00
```

### Add More Shift Information

Edit `ShiftEntity` in `lib/domain/entities/shift_entity.dart` to add fields like:
- Department
- Notes/Description
- Status
- Break duration
- Location

Then update `ShiftModel` to parse the new fields from JSON.

## FAQ

**Q: Where do the shifts come from?**  
A: They come from your Go backend database, fetched via the `/shifts` API endpoint.

**Q: Can I create/edit shifts from the app?**  
A: Currently, the feature only displays shifts. To add create/edit functionality, see the implementation in `shift_remote_datasource.dart` which has `createShift()` and `updateShift()` methods ready to use.

**Q: Why does it take time to load?**  
A: The app is making a network request to your backend. If it's slow, check:
- Backend server is running
- Network connection is stable
- Backend is not overloaded

**Q: Can I cache shifts offline?**  
A: Yes! The architecture supports it. Implement a local database (SQLite) and create a `ShiftLocalDataSource`, then update `ShiftRepositoryImpl` to use it.

## Next Steps

1. **Test with your backend** - Ensure shifts display correctly
2. **Add UI enhancements** - Customize colors, fonts, layout
3. **Implement create/edit** - Use the prepared API methods
4. **Add caching** - For offline support
5. **Add real-time updates** - Use WebSocket for live updates

## Support

For issues or questions:
1. Check that your backend is running and `/shifts` endpoint works
2. Review error messages in the app
3. Check Flutter console for detailed errors
4. Verify JSON response format matches expected structure
