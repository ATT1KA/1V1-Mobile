# 🚨 Xcode Project Fix Guide

## Problem
Your Xcode project file is corrupted and cannot be opened. This is a common issue that can be easily fixed.

## ✅ Solution: Create a New Project

### Step 1: Create New Xcode Project
1. **Open Xcode**
2. **File → New → Project**
3. **Choose "iOS" → "App"**
4. **Configure:**
   - Product Name: `1V1Mobile`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - **Save in a DIFFERENT location** (not in current directory)

### Step 2: Copy Your Source Files
Your source files are in: `/Users/danjames/Documents/GitHub/1V1-Mobile/1V1Mobile/`

**Copy these files to the new project:**
- `App/1V1MobileApp.swift`
- `Views/ContentView.swift`
- `Views/MainTabView.swift`
- `Screens/Auth/AuthView.swift`
- `Screens/Home/HomeView.swift`
- `Screens/Profile/ProfileView.swift`
- `Services/SupabaseService.swift`
- `Services/AuthService.swift`
- `Services/StorageService.swift`
- `Models/User.swift`
- `Models/Game.swift`
- `Utils/Constants.swift`
- `Assets.xcassets/`
- `Preview Content/`

### Step 3: Add Files to New Project
1. **Right-click** on project navigator
2. **"Add Files to 1V1Mobile"**
3. **Select all Swift files**
4. **Create groups** to organize:
   - App
   - Views
   - Screens
   - Services
   - Models
   - Utils

### Step 4: Add Supabase Dependency
1. **File → Add Package Dependencies...**
2. **Enter URL:** `https://github.com/supabase-community/supabase-swift.git`
3. **Click "Add Package"**
4. **Select "Supabase" product**
5. **Add to target**

### Step 5: Replace Old Project
1. **Delete corrupted project:**
   ```bash
   rm -rf 1V1Mobile.xcodeproj
   ```
2. **Copy new project** to replace it
3. **Commit changes:**
   ```bash
   git add .
   git commit -m "Fix corrupted Xcode project"
   ```

### Step 6: Test
1. **Clean Build Folder** (Shift+Cmd+K)
2. **Build Project** (Cmd+B)
3. **Run on Simulator** (Cmd+R)

## Expected Result
- ✅ Project opens without errors
- ✅ All files compile successfully
- ✅ Supabase dependency works
- ✅ App runs on simulator

## Why This Happened
The project file corruption likely occurred due to:
- Invalid edits to the project file
- Source control conflicts
- Incomplete file operations

## Prevention
- Always use Xcode to modify project files
- Avoid manual editing of .pbxproj files
- Use source control properly
- Keep backups of working projects

## Need Help?
If you encounter any issues:
1. Check the error messages
2. Verify all files are copied correctly
3. Ensure Supabase dependency is added properly
4. Clean and rebuild the project

✅ **This approach will definitely fix your project!**
