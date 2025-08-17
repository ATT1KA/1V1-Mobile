# Authentication Setup for 1V1 Mobile

Configure authentication settings in your Supabase project to work with your iOS app.

## 1. Navigate to Authentication Settings

1. Go to your Supabase dashboard
2. Click on "Authentication" in the left sidebar
3. Click on "Settings" tab

## 2. Configure Site URL

In the "Site URL" field, enter:
- For development: `http://localhost:3000`
- For production: Your actual domain (e.g., `https://yourdomain.com`)

## 3. Configure Redirect URLs

Add the following redirect URLs:

### For Development:
- `http://localhost:3000/auth/callback`
- `1v1mobile://auth/callback`

### For Production:
- `https://yourdomain.com/auth/callback`
- `1v1mobile://auth/callback`

**Note**: The `1v1mobile://` scheme is a custom URL scheme for your iOS app. You can change this to match your app's bundle identifier.

## 4. Email Templates

Customize the email templates for better user experience:

### Confirm Signup Email
**Subject**: `Confirm your signup for 1V1 Mobile`
**Content**:
```
Welcome to 1V1 Mobile!

Please confirm your email address by clicking the link below:

{{ .ConfirmationURL }}

If you didn't create an account, you can safely ignore this email.

Best regards,
The 1V1 Mobile Team
```

### Reset Password Email
**Subject**: `Reset your password for 1V1 Mobile`
**Content**:
```
Hello!

You requested to reset your password for 1V1 Mobile. Click the link below to set a new password:

{{ .ConfirmationURL }}

If you didn't request this, you can safely ignore this email.

Best regards,
The 1V1 Mobile Team
```

### Magic Link Email
**Subject**: `Sign in to 1V1 Mobile`
**Content**:
```
Hello!

Click the link below to sign in to 1V1 Mobile:

{{ .ConfirmationURL }}

This link will expire in 1 hour.

Best regards,
The 1V1 Mobile Team
```

## 5. Configure Auth Providers

### Email Provider (Default)
- ✅ Enable email confirmations
- ✅ Enable secure email change
- ✅ Enable double confirm changes
- ✅ Enable email confirmations on sign up

### Phone Provider (Optional)
If you want to support phone number authentication:
1. Click on "Phone" provider
2. Enable "Enable phone confirmations"
3. Configure SMS provider (Twilio, etc.)

### Social Providers (Optional)

#### Google OAuth
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google+ API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URI: `https://your-project.supabase.co/auth/v1/callback`
6. Copy Client ID and Client Secret
7. In Supabase, enable Google provider and enter credentials

#### Apple OAuth
1. Go to [Apple Developer Console](https://developer.apple.com/)
2. Create App ID with Sign In with Apple capability
3. Create Service ID
4. Configure domains and redirect URLs
5. Download private key and get Key ID
6. In Supabase, enable Apple provider and enter credentials

## 6. Session Management

Configure session settings:

- **JWT Expiry**: `3600` (1 hour)
- **Refresh Token Rotation**: ✅ Enabled
- **Refresh Token Reuse Interval**: `10` seconds

## 7. Security Settings

### Password Policy
- **Minimum Length**: `8`
- **Require Uppercase**: ✅ Yes
- **Require Lowercase**: ✅ Yes
- **Require Numbers**: ✅ Yes
- **Require Special Characters**: ❌ No (optional)

### Rate Limiting
- **Sign Up Rate Limit**: `5` per hour
- **Sign In Rate Limit**: `10` per hour
- **Password Reset Rate Limit**: `3` per hour

## 8. Test Authentication

After configuration, test the authentication flow:

1. **Test Sign Up**:
   - Try creating a new account
   - Verify confirmation email is sent
   - Confirm email and sign in

2. **Test Sign In**:
   - Sign in with existing account
   - Verify session is created

3. **Test Password Reset**:
   - Request password reset
   - Verify reset email is sent
   - Reset password and sign in

4. **Test Sign Out**:
   - Sign out and verify session is cleared

## 9. iOS App Configuration

Make sure your iOS app is configured to handle the authentication flow:

1. **Update Config.plist** with your Supabase credentials
2. **Test authentication** in your iOS app
3. **Verify** that users can sign up, sign in, and sign out

## 10. Monitoring

Monitor authentication events in your Supabase dashboard:

1. Go to "Logs" → "Auth"
2. Check for:
   - Successful sign-ups
   - Failed sign-in attempts
   - Password reset requests
   - Suspicious activity

## Troubleshooting

### Common Issues

1. **"Invalid redirect URL" error**
   - Check that your redirect URLs are correctly configured
   - Ensure the URL scheme matches your iOS app

2. **Email not sending**
   - Check Supabase project settings
   - Verify email provider configuration
   - Check logs for email delivery errors

3. **Authentication not working in iOS app**
   - Verify Supabase URL and anon key
   - Check network connectivity
   - Review authentication logs

### Getting Help

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Supabase Community](https://github.com/supabase/supabase/discussions)
- [iOS SDK Documentation](https://supabase.com/docs/reference/swift)
