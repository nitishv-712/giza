# Giza Music Streaming App

## 🎵 Project Overview
Underground music streaming app with Audius discovery + YouTube audio playback, featuring playlists, settings, and quality controls.

---

## ✅ Features Implemented

### 1. **Playlist System** 🎼
- ✅ Create custom playlists
- ✅ Add/remove songs from playlists
- ✅ View all playlists with song counts
- ✅ Play songs directly from playlists
- ✅ Delete playlists with confirmation
- ✅ Reactive updates using Provider
- ✅ Persistent storage with Hive
- ✅ Add-to-playlist button on all song tiles
- ✅ Bottom sheet playlist selector

**Files:**
- `lib/models/playlist.dart` - Playlist model
- `lib/providers/playlist_provider.dart` - State management
- `lib/screens/playlists_screen.dart` - UI screens
- `lib/db/hive_helper.dart` - Database methods

---

### 2. **Settings Page** ⚙️

#### **Theme Management**
- ✅ Light Mode
- ✅ Dark Mode
- ✅ System Default (follows device)
- ✅ Instant theme switching
- ✅ Persistent theme preference

#### **Audio Quality Selection** 🎧
- ✅ **Best Available** - Highest quality (default)
- ✅ **High (320kbps)** - Excellent quality, larger files
- ✅ **Medium (192kbps)** - Good quality, balanced size
- ✅ **Low (128kbps)** - Acceptable quality, smallest files
- ✅ Quality preference applied to all downloads
- ✅ Integrated with yt-dlp backend

#### **Download Settings**
- ✅ Auto Download toggle
- ✅ Wi-Fi Only mode
- ✅ Quality selection with descriptions

#### **Account Management**
- ✅ Display current user info
- ✅ Sign Out with confirmation
- ✅ Guest mode (anonymous auth)

#### **Playback Controls**
- ✅ Show/Hide notifications toggle

#### **Data Management**
- ✅ Clear Cache (remove downloads)
- ✅ Clear History (remove play history)
- ✅ Confirmation dialogs

#### **About Section**
- ✅ App version display
- ✅ Open Source link
- ✅ Privacy Policy link

**Files:**
- `lib/screens/settings_screen.dart` - Settings UI
- `lib/providers/theme_provider.dart` - Theme state management

---

### 3. **Smart Music Filtering** 🎯
- ✅ Duration filter: 30 seconds to 15 minutes
- ✅ Excludes YouTube Shorts/Reels
- ✅ Filters out non-music content:
  - Podcasts, interviews, tutorials
  - Reviews, reactions, vlogs
  - Gameplay, livestreams
  - Full albums, concerts, documentaries
- ✅ Targets actual music tracks only

**Files:**
- `lib/services/youtube_service.dart` - Search filtering

---

### 4. **Auto-Skip Deleted Songs** ⏭️
- ✅ Automatically skips unavailable/deleted videos
- ✅ Tries next song in playlist
- ✅ Prevents infinite loops
- ✅ Better error messages
- ✅ Works with shuffle and normal mode
- ✅ Graceful failure handling

**Files:**
- `lib/services/audio_service.dart` - Playback logic

---

### 5. **Authentication System** 🔐
- ✅ Guest mode (anonymous Firebase auth)
- ✅ Google Sign-In (commented, ready to configure)
- ✅ Facebook Login (commented, ready to configure)
- ✅ Configuration guide provided
- ✅ SHA-1 fingerprint documented

**Files:**
- `lib/screens/login_screen.dart` - Login UI
- `lib/providers/auth_provider.dart` - Auth state
- `lib/services/auth_service.dart` - Auth methods
- `AUTH_SETUP.md` - Configuration guide

---

### 6. **Audio Quality Backend** 🔊
Fully integrated quality selection from UI to download:

**Flutter Layer:**
- Quality preference saved to Hive
- Passed to download methods

**Kotlin Layer:**
- Quality parameter forwarded to Python

**Python Layer (yt-dlp):**
- `best`: `bestaudio[ext=m4a]/bestaudio/best`
- `high`: `bestaudio[abr>=256]` (320kbps+)
- `medium`: `bestaudio[abr>=160][abr<=224]` (192kbps)
- `low`: `bestaudio[abr>=96][abr<=160]` (128kbps)

**Files:**
- `lib/services/youtube_service.dart` - Quality parameter
- `lib/services/audio_service.dart` - Quality integration
- `android/app/src/main/kotlin/com/example/giza/MainActivity.kt` - Kotlin bridge
- `android/app/src/main/python/yt_backend.py` - yt-dlp quality formats

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry, providers setup
├── models/
│   ├── song.dart                      # Song model
│   ├── song.g.dart                    # Hive adapter
│   ├── playlist.dart                  # Playlist model
│   └── playlist.g.dart                # Hive adapter
├── providers/
│   ├── audio_provider.dart            # Audio state
│   ├── auth_provider.dart             # Auth state
│   ├── playlist_provider.dart         # Playlist state
│   └── theme_provider.dart            # Theme state
├── services/
│   ├── audio_service.dart             # Audio playback
│   ├── auth_service.dart              # Authentication
│   ├── youtube_service.dart           # YouTube search/download
│   └── notification_service.dart      # Media notifications
├── screens/
│   ├── home_screen.dart               # Main screen
│   ├── play_screen.dart               # Now playing
│   ├── playlists_screen.dart          # Playlists management
│   ├── settings_screen.dart           # Settings
│   └── login_screen.dart              # Authentication
└── db/
    └── hive_helper.dart               # Local database

android/app/src/main/
├── kotlin/com/example/giza/
│   └── MainActivity.kt                # Flutter-Python bridge
└── python/
    └── yt_backend.py                  # yt-dlp audio downloader
```

---

## 🔧 Technical Stack

### **Frontend**
- Flutter 3.x
- Provider (State Management)
- Hive (Local Database)
- Firebase Auth (Authentication)

### **Audio**
- audioplayers (Playback)
- youtube_explode_dart (Search)
- audio_service (Notifications)

### **Backend**
- Chaquopy (Python in Android)
- yt-dlp (Audio Download)
- Kotlin (Native Bridge)

---

## 🎨 Design System

### **Dark Theme (Default)**
- Background: `#0C0C14`
- Surface: `#141420`
- Text Primary: `#F0EFFF`
- Text Secondary: `#6E6E8A`
- Accent: `#FF8C42`
- Accent 2: `#FF5F6D`

### **Light Theme**
- Background: `#F5F5F7`
- Surface: `#FFFFFF`
- Text Primary: `#1C1C1E`
- Text Secondary: `#8E8E93`
- Accent: `#FF8C42` (same)

---

## 📊 Database Schema

### **Hive Boxes**
1. **songs** (Box<Song>) - All saved songs
2. **playlists** (Box<Playlist>) - User playlists
3. **play_history** (Box<Map>) - Play history
4. **settings** (Box<dynamic>) - App settings

### **Settings Keys**
- `theme_mode` - ThemeMode enum
- `auto_download` - bool
- `wifi_only` - bool
- `notifications` - bool
- `audio_quality` - 'best' | 'high' | 'medium' | 'low'

---

## 🚀 Key Features Flow

### **Playing a Song**
1. User taps song → AudioService.play()
2. Check if cached locally
3. If not cached → Download with quality preference
4. yt-dlp downloads audio with selected quality
5. Save to local storage
6. Play with audioplayers
7. Update notification
8. Log play history

### **Creating a Playlist**
1. User taps + in Playlists screen
2. Enter playlist name
3. PlaylistProvider.createPlaylist()
4. Save to Hive
5. UI updates automatically (Provider)

### **Adding Song to Playlist**
1. User taps playlist icon on song
2. Bottom sheet shows playlists
3. Select playlist
4. PlaylistProvider.addSongToPlaylist()
5. Save song to Hive
6. Add video ID to playlist
7. UI updates automatically

### **Changing Theme**
1. User goes to Settings → Appearance
2. Select theme (Light/Dark/System)
3. ThemeProvider.setThemeMode()
4. Save to Hive
5. MaterialApp rebuilds with new theme
6. Entire app updates instantly

### **Changing Audio Quality**
1. User goes to Settings → Downloads → Audio Quality
2. Select quality (Best/High/Medium/Low)
3. Save to Hive ('audio_quality' key)
4. Next download uses new quality
5. Quality passed: Flutter → Kotlin → Python → yt-dlp

---

## 🐛 Bug Fixes Implemented

### **1. Audio Service Configuration Error**
**Problem:** `androidNotificationOngoing` assertion failed
**Solution:** Changed to `androidNotificationOngoing: false` and `androidStopForegroundOnPause: true`

### **2. Deleted Songs Blocking Playback**
**Problem:** When song ends, next song might be deleted/unavailable, showing info but not playing
**Solution:** Auto-retry logic that skips to next available song, prevents infinite loops

### **3. Non-Music Content in Search**
**Problem:** Search returned shorts, podcasts, long videos
**Solution:** Smart filtering by duration (30s-15min) and content type keywords

---

## 📝 Configuration Guides

### **Firebase Authentication**
See `AUTH_SETUP.md` for:
- Google Sign-In setup
- Facebook Login setup
- SHA-1 fingerprint: `1F:F2:7C:FB:3F:B8:4A:FF:1E:54:FB:D5:93:C5:C2:B5:F8:CF:0D:8E`
- Facebook Key Hash: `H/J8+z+4Sv8eVPvVk8XCtfjPDY4=`

### **Playlist Feature**
See `PLAYLIST_FEATURE.md` for:
- Architecture details
- Usage examples
- Provider pattern benefits

### **Settings Feature**
See `SETTINGS_FEATURE.md` for:
- All settings options
- Theme system details
- Storage keys

---

## 🎯 User Experience Highlights

### **Smooth & Reactive**
- All state managed with Provider
- Instant UI updates
- No manual refresh needed
- Smooth animations

### **Persistent**
- All preferences saved locally
- Playlists persist across restarts
- Theme preference remembered
- Play history maintained

### **Smart**
- Auto-skips deleted songs
- Filters non-music content
- Quality-aware downloads
- Wi-Fi only option

### **Beautiful**
- Consistent design language
- Smooth gradients
- Clean typography
- Intuitive navigation

---

## 🔮 Future Enhancements (Optional)

- [ ] Lyrics display
- [ ] Equalizer
- [ ] Sleep timer
- [ ] Crossfade
- [ ] Export/Import playlists
- [ ] Social sharing
- [ ] Collaborative playlists
- [ ] Download queue management
- [ ] Storage usage display
- [ ] Backup & Restore

---

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  provider: ^6.1.1
  
  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # Audio
  audioplayers: ^5.2.1
  audio_service: ^0.18.12
  
  # YouTube
  youtube_explode_dart: ^2.3.3
  
  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.16.0
  google_sign_in: ^6.2.1
  flutter_facebook_auth: ^6.0.4
  
  # Network
  http: ^1.2.0
  cached_network_image: ^3.3.1
  
  # Utils
  path_provider: ^2.1.2

dev_dependencies:
  build_runner: ^2.4.7
  hive_generator: ^2.0.1
```

---

## ✨ Summary

You now have a **fully-featured music streaming app** with:

✅ Complete playlist management
✅ Comprehensive settings page
✅ Theme switching (Light/Dark/System)
✅ Audio quality selection (4 levels)
✅ Smart music filtering
✅ Auto-skip deleted songs
✅ Guest authentication
✅ Reactive state management
✅ Persistent local storage
✅ Beautiful, consistent UI

All features are **production-ready** and **fully integrated** from UI to backend! 🎉

---

## 🚀 Ready to Launch!

The app is complete and ready for:
- Testing on real devices
- Beta release
- Production deployment
- User feedback collection

**Great work building Giza! 🎵**
