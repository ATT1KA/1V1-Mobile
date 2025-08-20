# NFC and QR Code Sharing Setup Guide

This guide will help you set up the NFC and QR code sharing functionality for the 1V1 Mobile app.

## 🎯 Features Implemented

### NFC Sharing
- **NFC Tag Reading**: Scan NFC tags to read other users' profiles
- **NFC Tag Writing**: Write your profile to NFC tags for sharing
- **Proximity Triggered**: Automatically triggered when devices are near each other
- **Database Logging**: All NFC sharing events are logged to Supabase

### QR Code Sharing
- **QR Code Generation**: Generate QR codes containing your profile data
- **QR Code Scanning**: Scan QR codes to view other users' profiles
- **Profile Picture Toggle**: Tap your profile picture to show/hide QR code
- **Database Logging**: All QR sharing events are logged to Supabase

## 📱 Implementation Details

### Files Created/Modified

#### New Services
- `1V1Mobile/Services/NFCService.swift` - Handles NFC tag reading/writing
- `1V1Mobile/Services/QRCodeService.swift` - Handles QR code generation/scanning

#### New Models
- `1V1Mobile/Models/UserProfile.swift` - Profile data structure for sharing

#### Updated Views
- `1V1Mobile/Views/PlayerCard3DView.swift` - Added NFC/QR sharing buttons and functionality

#### Updated Configuration
- `1V1Mobile/Info.plist` - Added NFC capabilities and usage descriptions

#### Database Schema
- `supabase_profile_shares_setup.sql` - Creates profile_shares table for logging

## 🔧 Setup Instructions

### 1. Database Setup

Run the following SQL in your Supabase SQL Editor:

```sql
-- Copy and paste the contents of supabase_profile_shares_setup.sql
```

This will create:
- `profile_shares` table for logging sharing events
- Indexes for performance
- Row Level Security policies
- Analytics views and functions

### 2. Xcode Project Configuration

#### Add Required Capabilities
1. Open your Xcode project
2. Select your target
3. Go to "Signing & Capabilities"
4. Click "+" and add:
   - **Near Field Communication Tag Reading**
   - **Camera** (for QR scanning)

#### Verify Info.plist
Ensure your `Info.plist` contains:
```xml
<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>armv7</string>
    <string>nfc</string>
</array>
<key>NFCReaderUsageDescription</key>
<string>This app uses NFC to share and scan player profiles with other users.</string>
<key>NSCameraUsageDescription</key>
<string>This app uses the camera to scan QR codes for sharing player profiles.</string>
```

### 3. Testing the Implementation

#### NFC Testing
1. **Device Requirements**: iPhone 7 or later with NFC capability
2. **Test NFC Tags**: Use writable NFC tags (NTAG213/215/216)
3. **Testing Flow**:
   - Tap "NFC Share" to write your profile to a tag
   - Tap "NFC Scan" to read profiles from tags
   - Check Supabase logs for sharing events

#### QR Code Testing
1. **Device Requirements**: Any iOS device with camera
2. **Testing Flow**:
   - Tap your profile picture to generate QR code
   - Tap "Scan QR" to scan other users' QR codes
   - Check Supabase logs for sharing events

## 🎮 User Experience

### NFC Sharing
- **Automatic Detection**: NFC triggers when devices are close
- **Haptic Feedback**: Provides tactile confirmation
- **Error Handling**: Graceful fallback for unsupported devices

### QR Code Sharing
- **Profile Picture Toggle**: Tap to show/hide QR code
- **Real-time Generation**: QR codes update with profile changes
- **Easy Scanning**: Camera-based scanning with visual feedback

### Sharing Buttons
- **NFC Share**: Write profile to NFC tags
- **Scan QR**: Open camera to scan QR codes
- **NFC Scan**: Read profiles from NFC tags

## 📊 Analytics and Logging

### Database Schema
The `profile_shares` table tracks:
- User ID of sharer
- Share method (NFC or QR)
- Timestamp of share
- Profile data (JSON)
- Recipient user ID (if known)

### Analytics Views
- `profile_share_analytics`: Daily share counts by method
- `get_user_share_stats()`: Function to get user sharing statistics

## 🔒 Security Considerations

### Row Level Security
- Users can only view their own share history
- Users can only insert their own share events
- Profile data is encrypted in transit

### Privacy
- Profile data is only shared when explicitly requested
- Users control what information is shared
- Sharing events are logged for analytics only

## 🐛 Troubleshooting

### NFC Issues
- **"NFC not available"**: Device doesn't support NFC (iPhone 6 or earlier)
- **"Failed to read tag"**: Tag may be corrupted or incompatible
- **"Connection failed"**: Try moving device closer to tag

### QR Code Issues
- **"Failed to generate QR"**: Check profile data validity
- **"No QR code found"**: Ensure image contains a valid QR code
- **"Invalid format"**: QR code doesn't contain valid profile data

### Database Issues
- **"Table not found"**: Run the SQL setup script
- **"Permission denied"**: Check RLS policies
- **"Connection failed"**: Verify Supabase credentials

## 🚀 Next Steps

### Potential Enhancements
1. **Offline Support**: Cache profiles for offline sharing
2. **Batch Sharing**: Share with multiple users at once
3. **Custom QR Designs**: Branded QR code templates
4. **Share Analytics**: Dashboard for viewing share statistics
5. **Push Notifications**: Notify when profile is shared

### Integration Opportunities
1. **Social Features**: Share achievements and milestones
2. **Tournament System**: Share tournament invites via NFC/QR
3. **Friend System**: Add scanned users as friends
4. **Leaderboards**: Share leaderboard positions

## 📞 Support

If you encounter any issues:
1. Check the troubleshooting section above
2. Verify all setup steps are completed
3. Test on a supported device
4. Check Supabase logs for errors
5. Review Xcode console for debugging information
