# 🔐 Google Sign-In Setup Guide

## ✅ What's Been Configured

Your Google Client ID has been successfully configured:
- **Client ID**: `519598304664-v9cd4488ioj4hptomk6hp30sr7oqppvo.apps.googleusercontent.com`
- **Info.plist**: Created with proper URL schemes and configuration
- **App Configuration**: Updated to handle Google Sign-In callbacks

## 📱 Xcode Setup Required

### Step 1: Add Google Sign-In Package
1. **Open Xcode** and open your `1V1Mobile.xcodeproj`
2. **File → Add Package Dependencies...**
3. **Enter URL**: `https://github.com/google/GoogleSignIn-iOS.git`
4. **Click "Add Package"**
5. **Select "GoogleSignIn" product**
6. **Add to target**: `1V1Mobile`

### Step 2: Configure App Capabilities
1. **Select your project** in Xcode navigator
2. **Select your target** (`1V1Mobile`)
3. **Go to "Signing & Capabilities" tab**
4. **Click "+ Capability"**
5. **Add "Sign in with Apple"** (if not already added)

### Step 3: Verify Info.plist
The `Info.plist` file has been created with:
- ✅ Google Client ID
- ✅ URL schemes for Google Sign-In
- ✅ App URL scheme

## 🌐 Google Cloud Console Setup

### Step 1: Configure OAuth Consent Screen
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. **Select your project**
3. **APIs & Services → OAuth consent screen**
4. **Configure**:
   - App name: `1V1 Mobile`
   - User support email: Your email
   - Developer contact information: Your email

### Step 2: Configure OAuth Credentials
1. **APIs & Services → Credentials**
2. **Find your OAuth 2.0 Client ID**
3. **Edit** the iOS client
4. **Add Bundle ID**: Your app's bundle identifier (e.g., `com.yourcompany.1V1Mobile`)
5. **Save**

### Step 3: Enable Google Sign-In API
1. **APIs & Services → Library**
2. **Search for "Google Sign-In API"**
3. **Enable** the API

## 🔧 Supabase Configuration

### Step 1: Configure Google Provider
1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. **Authentication → Providers**
3. **Enable Google**
4. **Add your Google Client ID and Secret**:
   - Client ID: `519598304664-v9cd4488ioj4hptomk6hp30sr7oqppvo.apps.googleusercontent.com`
   - Client Secret: Get this from Google Cloud Console

### Step 2: Configure Redirect URLs
1. **Authentication → URL Configuration**
2. **Add redirect URL**: `1v1mobile://auth/callback`
3. **Save**

## 🧪 Testing

### Test Google Sign-In
1. **Build and run** your app in Xcode
2. **Tap "Continue with Google"**
3. **Sign in** with your Google account
4. **Verify** you're redirected to onboarding

### Test Session Persistence
1. **Sign in** with Google
2. **Close the app** completely
3. **Reopen the app**
4. **Verify** you're still signed in

## 🚨 Troubleshooting

### Common Issues

**Issue**: "Google Sign-In failed"
- **Solution**: Verify Google Client ID in Info.plist
- **Solution**: Check Google Cloud Console configuration

**Issue**: "No window available"
- **Solution**: Ensure app is running on device/simulator
- **Solution**: Check window scene configuration

**Issue**: "Failed to get Google ID token"
- **Solution**: Verify Google Sign-In API is enabled
- **Solution**: Check OAuth consent screen configuration

### Debug Steps
1. **Check Xcode console** for error messages
2. **Verify Info.plist** contains correct Client ID
3. **Test on physical device** (Google Sign-In works better on device)
4. **Check Supabase logs** for authentication errors

## 📋 Checklist

- [ ] Google Sign-In package added to Xcode
- [ ] Info.plist configured with Client ID
- [ ] URL schemes added
- [ ] Google Cloud Console configured
- [ ] OAuth consent screen set up
- [ ] Bundle ID added to OAuth credentials
- [ ] Google Sign-In API enabled
- [ ] Supabase Google provider configured
- [ ] Redirect URLs configured
- [ ] App tested on device

## 🎯 Next Steps

1. **Test the complete auth flow**
2. **Configure Apple Sign-In** (if needed)
3. **Set up user profile management**
4. **Implement game features**

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review Google Sign-In documentation
3. Check Supabase authentication logs
4. Verify all configuration steps are completed

---

**Your Google Sign-In is now ready to use! 🚀**
