# SSO Configuration Guide

## Google Sign-In Setup

### 1. Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google+ API

### 2. Configure OAuth Consent Screen
1. Navigate to "APIs & Services" > "OAuth consent screen"
2. Choose "External" user type
3. Fill in app name, user support email, and developer contact
4. Add scopes: `email` and `profile`
5. Add test users if in testing mode

### 3. Create OAuth Credentials
1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth client ID"
3. Select application type based on platform:

#### For Android:
- Application type: Android
- Package name: `com.example.flutter_app` (from `android/app/build.gradle`)
- Get SHA-1 from:
  ```bash
  cd android
  ./gradlew signingReport
  ```

#### For iOS:
- Application type: iOS
- Bundle ID: `com.example.flutterApp` (from `ios/Runner.xcodeproj`)

#### For Web:
- Application type: Web application
- Authorized JavaScript origins: `http://localhost:3000`
- Authorized redirect URIs: `http://localhost:3000/auth`

### 4. Download and Configure
1. Download the configuration file
2. For Android: Place `google-services.json` in `android/app/`
3. For iOS: Place `GoogleService-Info.plist` in `ios/Runner/`

### 5. Update Flutter Code
The Google client ID is automatically read from the configuration files.
No code changes needed if files are properly placed.

---

## GitHub OAuth Setup

### 1. Register OAuth Application
1. Go to GitHub Settings > Developer settings > OAuth Apps
2. Click "New OAuth App"
3. Fill in the details:
   - **Application name**: OfficeAs
   - **Homepage URL**: `https://your-app-url.com`
   - **Authorization callback URL**: `officeas://auth`
   - For web testing: `http://localhost:3000/auth`

### 2. Get Credentials
1. After creating the app, note down:
   - **Client ID**
   - **Client Secret** (keep this secure!)

### 3. Update Flutter Configuration
1. Open [`lib/core/services/auth_service.dart`](../../lib/core/services/auth_service.dart)
2. Replace `YOUR_GITHUB_CLIENT_ID` with your actual GitHub Client ID:
   ```dart
   static const String githubClientId = 'your_actual_client_id_here';
   ```

### 4. Backend Integration Required
GitHub OAuth requires a backend token exchange. You need to:

1. Create a backend endpoint to exchange the authorization code for an access token
2. Add this endpoint to your Go backend:

```go
// Add to handlers/auth.go
func (h Auth) GitHubCallback(w http.ResponseWriter, r *http.Request) {
    code := r.URL.Query().Get("code")
    
    // Exchange code for access token
    tokenURL := "https://github.com/login/oauth/access_token"
    data := url.Values{
        "client_id":     {os.Getenv("GITHUB_CLIENT_ID")},
        "client_secret": {os.Getenv("GITHUB_CLIENT_SECRET")},
        "code":          {code},
    }
    
    resp, err := http.PostForm(tokenURL, data)
    // ... handle response and get user info from GitHub API
    // ... then call h.SSOLogin with the user data
}
```

3. Register the route in `main.go`:
```go
router.HandleFunc("/auth/github/callback", handlers.Auth{DB: db}.GitHubCallback).Methods("GET")
```

### 5. Environment Variables
Add to your backend `.env` file:
```env
GITHUB_CLIENT_ID=your_client_id
GITHUB_CLIENT_SECRET=your_client_secret
JWT_SECRET=your_secure_random_secret
```

---

## Platform-Specific Configuration

### Android (android/app/build.gradle)
Make sure your `minSdkVersion` is at least 21:
```gradle
defaultConfig {
    minSdkVersion 21
    targetSdkVersion 33
}
```

### iOS (ios/Runner/Info.plist)
Add URL scheme for GitHub callback:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>officeas</string>
        </array>
    </dict>
</array>
```

### Web
For web support, additional configuration is needed in `web/index.html`.

---

## Testing

### Test Accounts
Make sure to add test accounts in Google Cloud Console if your app is in testing mode.

### Local Testing
1. Start your Go backend:
   ```bash
   cd gobackend
   go run main.go
   ```

2. Update the API URL in Flutter if needed:
   - Edit [`lib/data/repositories/auth_repository.dart`](../../lib/data/repositories/auth_repository.dart)
   - Change `baseUrl` to match your backend

3. Run the Flutter app:
   ```bash
   cd flutter_app
   flutter pub get
   flutter run
   ```

---

## Security Notes

⚠️ **Important Security Considerations:**

1. **Never commit** `google-services.json`, `GoogleService-Info.plist`, or `.env` files to Git
2. **Always use HTTPS** in production
3. **Validate tokens** on the backend
4. **Rotate secrets** regularly
5. **Use environment variables** for sensitive data
6. Add to `.gitignore`:
   ```
   android/app/google-services.json
   ios/Runner/GoogleService-Info.plist
   .env
   ```

---

## Troubleshooting

### Google Sign-In Issues
- Verify SHA-1 fingerprint matches
- Check package name/bundle ID
- Ensure Google+ API is enabled
- Clear app data and try again

### GitHub OAuth Issues
- Verify callback URL matches exactly
- Check that client ID is correct
- Ensure backend can reach GitHub API
- Check CORS settings on backend

### Common Errors
- "PlatformException": Check platform-specific configuration
- "Network error": Verify backend is running and URL is correct
- "Invalid credentials": Double-check OAuth setup
