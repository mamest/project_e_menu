# Google Authentication Setup Guide

This guide will help you set up Google Authentication for your Flutter app with Supabase.

## Prerequisites

- A Supabase project (if you don't have one, create it at https://supabase.com)
- A Google Cloud Console account
- Flutter project with the dependencies already installed

## Part 1: Google Cloud Console Setup

### Step 1: Create a Google Cloud Project

1. Go to https://console.cloud.google.com/
2. Click on the project dropdown at the top and select "New Project"
3. Name your project (e.g., "Digital Menu App")
4. Click "Create"

### Step 2: Enable Google+ API

1. In the Google Cloud Console, go to "APIs & Services" > "Library"
2. Search for "Google+ API"
3. Click on it and click "Enable"

### Step 3: Create OAuth 2.0 Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth client ID"
3. If prompted, configure the OAuth consent screen first:
   - Choose "External" for user type
   - Fill in the app name: "Digital Menu App"
   - Add your email as the support email
   - Add authorized domains if deploying (e.g., your-domain.com)
   - Click "Save and Continue" through the remaining steps

### Step 4: Create OAuth Client IDs

You'll need to create separate OAuth client IDs for each platform:

#### For Web Application:
1. Click "Create Credentials" > "OAuth client ID"
2. Select "Web application"
3. Name it "Digital Menu Web"
4. Add authorized JavaScript origins:
   - `http://localhost:3000` (for local testing)
   - Your Supabase project URL (found in Supabase dashboard)
5. Add authorized redirect URIs:
   - `https://YOUR_SUPABASE_PROJECT_REF.supabase.co/auth/v1/callback`
   - Replace `YOUR_SUPABASE_PROJECT_REF` with your project reference from Supabase
6. Click "Create"
7. **Copy the Client ID** - you'll need this

#### For Android (if deploying to Android):
1. Click "Create Credentials" > "OAuth client ID"
2. Select "Android"
3. Name it "Digital Menu Android"
4. Get your SHA-1 certificate fingerprint:
   ```bash
   # For debug keystore:
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

   # For release keystore:
   keytool -list -v -keystore /path/to/your/keystore.jks -alias your_alias_name
   ```
5. Enter your package name (e.g., `com.example.project_e_menu`)
6. Enter the SHA-1 certificate fingerprint
7. Click "Create"

#### For iOS (if deploying to iOS):
1. Click "Create Credentials" > "OAuth client ID"
2. Select "iOS"
3. Name it "Digital Menu iOS"
4. Enter your iOS bundle ID (found in Xcode or `ios/Runner/Info.plist`)
5. Click "Create"
6. **Copy the Client ID** - you'll need this

## Part 2: Supabase Configuration

### Step 1: Enable Google Auth Provider

1. Go to your Supabase project dashboard: https://supabase.com/dashboard/project/YOUR_PROJECT_ID
2. Navigate to "Authentication" > "Providers"
3. Scroll down to find "Google"
4. Toggle it to "Enabled"
5. Enter the **Web Client ID** from Google Cloud Console
6. Enter the **Client Secret** from Google Cloud Console (you can find this in the credentials page)
7. Add your authorized redirect URL (should be pre-filled):
   - `https://YOUR_SUPABASE_PROJECT_REF.supabase.co/auth/v1/callback`
8. Click "Save"

### Step 2: Configure Redirect URLs

1. Still in "Authentication" settings in Supabase
2. Go to "URL Configuration"
3. Add your site URL (e.g., `http://localhost:3000` for development)
4. Add redirect URLs:
   - `http://localhost:3000/**`
   - Your production URLs when ready

## Part 3: Flutter Project Configuration

### Step 1: Update Environment Variables

Create or update your `.env` file in the project root:

```env
SUPABASE_URL=https://YOUR_SUPABASE_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here
GOOGLE_WEB_CLIENT_ID=your_web_client_id.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=your_ios_client_id.apps.googleusercontent.com
```

Replace with your actual values from Google Cloud Console and Supabase.

### Step 2: Platform-Specific Setup

#### Android Setup:
1. Open `android/app/build.gradle`
2. Make sure minSdkVersion is at least 21:
   ```gradle
   defaultConfig {
       minSdkVersion 21
       // ... other config
   }
   ```

#### iOS Setup:
1. Open `ios/Runner/Info.plist`
2. Add the following URL scheme:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleTypeRole</key>
           <string>Editor</string>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID</string>
           </array>
       </dict>
   </array>
   ```
   Replace `YOUR_IOS_CLIENT_ID` with your iOS client ID (reverse format, without the `.apps.googleusercontent.com` part)

#### Web Setup:
1. Open `web/index.html`
2. Add Google Sign-In meta tag in the `<head>` section:
   ```html
   <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
   ```

### Step 3: Install Dependencies

Run the following command to install the new dependencies:

```bash
flutter pub get
```

### Step 4: Add Google Logo (Optional)

For a better-looking Google sign-in button, add the Google logo:

1. Download the Google logo from Google's brand guidelines
2. Save it as `assets/google_logo.png`
3. Update `pubspec.yaml` to include it:
   ```yaml
   flutter:
     assets:
       - assets/menu.json
       - assets/google_logo.png
       - .env
   ```

## Part 4: Testing

### Test the Authentication Flow:

1. Run your Flutter app:
   ```bash
   flutter run -d chrome  # for web
   # or
   flutter run  # for mobile
   ```

2. Click the "Sign In" button in the app bar
3. Click "Sign in with Google"
4. Select your Google account
5. Grant permissions when prompted
6. You should be redirected back to the app and see your profile in the app bar

### Verify in Supabase:

1. Go to your Supabase dashboard
2. Navigate to "Authentication" > "Users"
3. You should see your user listed with the Google provider

## Part 5: Security Considerations

### Production Checklist:

- [ ] Use environment variables for all sensitive keys (never commit them to Git)
- [ ] Add `.env` to your `.gitignore` file
- [ ] Update authorized domains in Google Cloud Console
- [ ] Update redirect URLs in Supabase for production
- [ ] Enable email verification in Supabase if required
- [ ] Set up Row Level Security (RLS) policies in Supabase:

```sql
-- Example RLS policy for restaurants table
-- Allow anyone to read restaurants
CREATE POLICY "Allow public read access" ON restaurants
  FOR SELECT USING (true);

-- Allow only authenticated users to insert restaurants
CREATE POLICY "Allow authenticated users to insert" ON restaurants
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
```

## Part 6: Troubleshooting

### Common Issues:

1. **"Google Sign-In failed" Error**
   - Check that your Web Client ID is correct in `.env`
   - Verify that the Client ID is enabled in Google Cloud Console
   - Check browser console for detailed error messages

2. **"Invalid redirect URI" Error**
   - Make sure redirect URIs match exactly in Google Cloud Console
   - Check Supabase redirect URL configuration
   - Verify no trailing slashes or typos

3. **"API not enabled" Error**
   - Enable Google+ API in Google Cloud Console
   - Wait a few minutes for the changes to propagate

4. **iOS/Android specific issues**
   - For iOS: Check bundle ID matches
   - For Android: Verify SHA-1 fingerprint is correct
   - Make sure platform-specific client IDs are created

5. **User not authenticated after sign-in**
   - Check Supabase logs for errors
   - Verify JWT token is being stored correctly
   - Check that auth state changes are being listened to

## Features Implemented

### Anonymous Access:
- Users can view the list of restaurants without signing in
- Location-based filtering works for all users
- Restaurant details and menus are publicly accessible

### Authenticated Access:
- Upload menu PDFs (AI-powered extraction)
- Manage restaurant data
- Access to admin features
- User profile display in app bar

### Future Enhancements:
- Save favorite restaurants
- Order history
- User reviews and ratings
- Restaurant owner dashboard
- Analytics for restaurant owners

## Support

For issues related to:
- **Supabase**: https://supabase.com/docs
- **Google Sign-In**: https://developers.google.com/identity
- **Flutter Google Sign-In**: https://pub.dev/packages/google_sign_in

## Additional Resources

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Google Sign-In Flutter Plugin](https://pub.dev/packages/google_sign_in)
- [Supabase Flutter SDK](https://pub.dev/packages/supabase_flutter)
