# NFC and QR Code Testing Guide

## 🧪 Testing Overview

This guide provides comprehensive testing procedures for the NFC and QR code sharing functionality.

## 📱 Device Requirements

### NFC Testing
- **Required**: iPhone 7 or later with iOS 11+
- **Optional**: NFC tags (NTAG213/215/216) for writing tests
- **Fallback**: Error handling for unsupported devices

### QR Code Testing
- **Required**: Any iOS device with camera
- **Optional**: QR code generator for creating test codes
- **Fallback**: Image-based QR scanning

## 🔍 Test Scenarios

### 1. NFC Functionality Tests

#### Test 1.1: NFC Availability Check
**Objective**: Verify NFC capability detection
**Steps**:
1. Launch app on supported device (iPhone 7+)
2. Navigate to player card
3. Tap "NFC Scan" button
4. **Expected**: NFC scanner should start
5. **Expected**: No error about NFC unavailability

#### Test 1.2: NFC Availability Check (Unsupported Device)
**Objective**: Verify graceful fallback on unsupported devices
**Steps**:
1. Launch app on unsupported device (iPhone 6 or earlier)
2. Navigate to player card
3. Tap "NFC Scan" button
4. **Expected**: Error message "NFC is not available on this device"

#### Test 1.3: NFC Tag Reading
**Objective**: Test reading profile data from NFC tags
**Prerequisites**: NFC tag with valid profile data
**Steps**:
1. Prepare NFC tag with profile data
2. Tap "NFC Scan" button
3. Hold device near NFC tag
4. **Expected**: Profile data should be parsed and displayed
5. **Expected**: Sharing event should be logged to database

#### Test 1.4: NFC Tag Writing
**Objective**: Test writing profile data to NFC tags
**Prerequisites**: Writable NFC tag
**Steps**:
1. Tap "NFC Share" button
2. Hold device near writable NFC tag
3. **Expected**: Profile should be written to tag
4. **Expected**: Success message should appear

### 2. QR Code Functionality Tests

#### Test 2.1: QR Code Generation
**Objective**: Verify QR code generation from profile data
**Steps**:
1. Navigate to player card
2. Tap profile picture to show QR code
3. **Expected**: QR code should be generated and displayed
4. **Expected**: QR code should contain profile data

#### Test 2.2: QR Code Scanning
**Objective**: Test scanning QR codes with camera
**Prerequisites**: QR code with valid profile data
**Steps**:
1. Tap "Scan QR" button
2. Point camera at QR code
3. **Expected**: QR code should be detected and parsed
4. **Expected**: Profile data should be displayed
5. **Expected**: Sharing event should be logged to database

#### Test 2.3: Camera Permission Handling
**Objective**: Test camera permission request
**Steps**:
1. Reset camera permissions for app
2. Tap "Scan QR" button
3. **Expected**: Camera permission request should appear
4. Grant permission
5. **Expected**: QR scanner should open

#### Test 2.4: Invalid QR Code Handling
**Objective**: Test error handling for invalid QR codes
**Steps**:
1. Create invalid QR code (random data)
2. Tap "Scan QR" button
3. Point camera at invalid QR code
4. **Expected**: Error message should appear
5. **Expected**: No crash or unexpected behavior

### 3. UI Integration Tests

#### Test 3.1: Profile Picture QR Toggle
**Objective**: Verify profile picture tap toggles QR display
**Steps**:
1. Navigate to player card
2. Tap profile picture
3. **Expected**: QR code sheet should open
4. Tap "Done" to close
5. Tap profile picture again
6. **Expected**: QR code sheet should open again

#### Test 3.2: Sharing Buttons Visibility
**Objective**: Verify all sharing buttons are visible
**Steps**:
1. Navigate to player card
2. Scroll to bottom of card
3. **Expected**: Should see "NFC Share", "Scan QR", "NFC Scan" buttons
4. **Expected**: Buttons should be properly styled and positioned

#### Test 3.3: Error Message Display
**Objective**: Test error message display
**Steps**:
1. Trigger an error (e.g., NFC on unsupported device)
2. **Expected**: Error alert should appear
3. **Expected**: Error message should be clear and actionable

### 4. Database Integration Tests

#### Test 4.1: Sharing Event Logging
**Objective**: Verify sharing events are logged to database
**Steps**:
1. Perform NFC or QR sharing
2. Check Supabase database
3. **Expected**: New record in `profile_shares` table
4. **Expected**: Correct user_id, share_method, and timestamp

#### Test 4.2: Profile Data Serialization
**Objective**: Test profile data encoding/decoding
**Steps**:
1. Generate QR code
2. Scan QR code with another device
3. **Expected**: Profile data should be identical
4. **Expected**: All fields should be preserved

### 5. Performance Tests

#### Test 5.1: QR Code Generation Speed
**Objective**: Test QR code generation performance
**Steps**:
1. Time QR code generation
2. **Expected**: Should complete within 1 second
3. **Expected**: No UI freezing or lag

#### Test 5.2: NFC Response Time
**Objective**: Test NFC tag detection speed
**Steps**:
1. Time NFC tag detection
2. **Expected**: Should detect within 2 seconds
3. **Expected**: Smooth user experience

## 🐛 Common Issues & Solutions

### NFC Issues
- **Issue**: "NFC not available"
  - **Solution**: Use iPhone 7+ device
  - **Workaround**: Show error message to user

- **Issue**: "Failed to read tag"
  - **Solution**: Ensure tag contains valid data
  - **Workaround**: Try different tag or position

### QR Code Issues
- **Issue**: "Failed to generate QR"
  - **Solution**: Check profile data validity
  - **Workaround**: Refresh profile data

- **Issue**: "No QR code found"
  - **Solution**: Ensure QR code is clear and well-lit
  - **Workaround**: Adjust camera position

### Database Issues
- **Issue**: "Table not found"
  - **Solution**: Run database setup script
  - **Workaround**: Check Supabase connection

## 📊 Test Results Template

### Test Execution Log
```
Date: _______________
Device: _______________
iOS Version: _______________
Tester: _______________

Test Results:
□ NFC Availability Check (Supported Device)
□ NFC Availability Check (Unsupported Device)
□ NFC Tag Reading
□ NFC Tag Writing
□ QR Code Generation
□ QR Code Scanning
□ Camera Permission Handling
□ Invalid QR Code Handling
□ Profile Picture QR Toggle
□ Sharing Buttons Visibility
□ Error Message Display
□ Sharing Event Logging
□ Profile Data Serialization
□ QR Code Generation Speed
□ NFC Response Time

Issues Found:
1. ________________
2. ________________
3. ________________

Recommendations:
1. ________________
2. ________________
3. ________________
```

## ✅ Success Criteria

All tests should pass with the following criteria:
- ✅ No crashes or unexpected behavior
- ✅ All functionality works as expected
- ✅ Error handling is graceful
- ✅ Database logging is accurate
- ✅ UI is responsive and intuitive
- ✅ Performance is acceptable

## 🚀 Post-Testing Actions

1. **Document Issues**: Record any bugs or issues found
2. **Performance Analysis**: Review performance metrics
3. **User Feedback**: Gather feedback on usability
4. **Optimization**: Implement any necessary improvements
5. **Deployment**: Prepare for production release
