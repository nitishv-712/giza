# Firebase Authentication Setup Guide

## Features

✅ Google & Facebook Authentication with Provider
✅ Background playback with media notification
✅ Notification controls: Play, Pause, Next, Previous, Seek
✅ Lock screen controls
✅ Headphone button controls

## 1. Install Dependencies

```bash
flutter pub get
```

## 2. Firebase Console Setup

### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: "Giza"
4. Follow the setup wizard

### Enable Authentication Methods
1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Enable **Google** sign-in
3. Enable **Facebook** sign-in (requires Facebook App ID and Secret)

## 3. Android Configuration

### Add Firebase to Android
1. In Firebase Console, click **Android icon** to add Android app
2. Enter package name: `com.example.giza` (or your package name from `android/app/build.gradle`)
3. Download `google-services.json`
4. Place it in `android/app/` directory

### Update android/build.gradle
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

### Update android/app/build.gradle
```gradle
apply plugin: 'com.google.gms.google-services'

android {
    defaultConfig {
        minSdkVersion 21  // Changed from 17
    }
}
```

### Google Sign-In SHA-1
1. Get SHA-1 fingerprint:
```bash
cd android
./gradlew signingReport
```
2. Copy SHA-1 from output
3. In Firebase Console → Project Settings → Your Android app → Add fingerprint

## 4. iOS Configuration (if needed)

### Add Firebase to iOS
1. In Firebase Console, click **iOS icon** to add iOS app
2. Enter bundle ID from `ios/Runner.xcodeproj`
3. Download `GoogleService-Info.plist`
4. Open `ios/Runner.xcworkspace` in Xcode
5. Drag `GoogleService-Info.plist` into Runner folder

### Update ios/Runner/Info.plist
Add before `</dict>`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

## 5. Facebook Authentication Setup

### Create Facebook App
1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Create new app → Consumer
3. Add **Facebook Login** product

### Configure Facebook App
1. Settings → Basic:
   - Copy **App ID** and **App Secret**
2. Facebook Login → Settings:
   - Add OAuth redirect URI: `https://YOUR-PROJECT-ID.firebaseapp.com/__/auth/handler`

### Add to Firebase
1. Firebase Console → Authentication → Sign-in method → Facebook
2. Paste App ID and App Secret
3. Copy OAuth redirect URI to Facebook app settings

### Android - Update strings.xml
Create/update `android/app/src/main/res/values/strings.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Giza</string>
    <string name="facebook_app_id">YOUR_FACEBOOK_APP_ID</string>
    <string name="fb_login_protocol_scheme">fbYOUR_FACEBOOK_APP_ID</string>
</resources>
```

### Android - Update AndroidManifest.xml
Add inside `<application>` tag in `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data 
    android:name="com.facebook.sdk.ApplicationId" 
    android:value="@string/facebook_app_id"/>
    
<activity 
    android:name="com.facebook.FacebookActivity"
    android:configChanges="keyboard|keyboardHidden|screenLayout|screenSize|orientation"
    android:label="@string/app_name" />
    
<activity
    android:name="com.facebook.CustomTabActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="@string/fb_login_protocol_scheme" />
    </intent-filter>
</activity>
```

## 6. Run the App

```bash
flutter run
```

## Features Implemented

✅ Google Sign-In with loading states
✅ Facebook Sign-In with loading states  
✅ AuthProvider for smooth state management
✅ Automatic navigation based on auth state
✅ Sign-out with loading indicator
✅ Error handling with snackbar notifications
✅ Persistent authentication across app restarts
✅ Background playback with media notification
✅ Notification controls: Play/Pause, Next, Previous, Stop
✅ Lock screen media controls
✅ Headphone/Bluetooth button controls
✅ Album artwork in notification
✅ Seek control from notification

## Architecture

```
lib/
├── providers/
│   ├── auth_provider.dart      # Auth state management
│   └── audio_provider.dart     # Audio state management
├── services/
│   ├── auth_service.dart       # Firebase Auth wrapper
│   └── notification_service.dart # Background playback notifications
└── screens/
    ├── login_screen.dart       # Google & Facebook sign-in
    └── home_screen.dart        # Sign-out button
```
