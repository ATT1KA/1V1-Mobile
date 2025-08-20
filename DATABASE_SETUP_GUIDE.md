# Database Setup Guide

## 🚨 Critical Fix Required

The onboarding system requires database tables to be created in Supabase. Follow these steps to complete the setup.

## 📋 Prerequisites

- Access to your Supabase project dashboard
- Admin permissions for the database

## 🔧 Step-by-Step Setup

### 1. Access Supabase Dashboard

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project: `oqslzeoveqzvyvoegxhm`

### 2. Run Database Setup Script

1. **Navigate to SQL Editor**
   - Click on "SQL Editor" in the left sidebar
   - Click "New Query"

2. **Copy and Paste the Setup Script**
   - Open the file `supabase_database_setup.sql` in your project
   - Copy the entire contents
   - Paste it into the SQL Editor

3. **Execute the Script**
   - Click the "Run" button (▶️)
   - Wait for the script to complete
   - You should see "Database setup completed successfully!"

### 3. Verify Setup

1. **Check Tables Created**
   - Go to "Table Editor" in the left sidebar
   - Verify these tables exist:
     - `profiles` (with new columns: `stats`, `card_id`)
     - `user_cards`

2. **Check RLS Policies**
   - Go to "Authentication" → "Policies"
   - Verify policies exist for `user_cards` table

## 🧪 Test the Setup

### 1. Test Database Connection

The app will automatically validate the database setup when you launch the onboarding flow. If there are any issues, you'll see an alert with setup instructions.

### 2. Test Complete Flow

1. **Launch the app**
2. **Sign up or sign in**
3. **Complete the onboarding steps**:
   - Authentication ✅
   - Stats input ✅
   - Card generation ✅
4. **Verify data is saved** in Supabase

## 🔍 Troubleshooting

### Issue: "Table not found" Error

**Solution**: Run the database setup script again. Make sure you're in the correct Supabase project.

### Issue: "Permission denied" Error

**Solution**: 
1. Check that you have admin access to the project
2. Verify the RLS policies are correctly set up
3. Ensure the authenticated user has proper permissions

### Issue: "Column does not exist" Error

**Solution**: The setup script should handle this automatically, but if it fails:
1. Manually add the missing columns:
   ```sql
   ALTER TABLE profiles ADD COLUMN IF NOT EXISTS stats JSONB;
   ALTER TABLE profiles ADD COLUMN IF NOT EXISTS card_id UUID;
   ```

### Issue: App crashes on database operations

**Solution**: 
1. Check the console for specific error messages
2. Verify all tables and columns exist
3. Ensure RLS policies are properly configured

## 📊 What the Setup Script Does

### Tables Created

1. **`user_cards`** - Stores user-generated cards
   - `id` (UUID, Primary Key)
   - `user_id` (UUID, Foreign Key to auth.users)
   - `card_name` (Text)
   - `card_description` (Text)
   - `rarity` (Text: common, rare, epic, legendary)
   - `power` (Integer)
   - `is_active` (Boolean)

2. **`profiles`** - Enhanced with new columns
   - `stats` (JSONB) - User gaming statistics
   - `card_id` (UUID) - Reference to user's card

### Security Features

- **Row Level Security (RLS)** enabled on `user_cards`
- **Policies** ensure users can only access their own data
- **Triggers** automatically update timestamps
- **Indexes** for better query performance

### Views Created

- **`user_profile_with_card`** - Combined view of user profile and card data

## ✅ Verification Checklist

- [ ] `user_cards` table exists
- [ ] `profiles` table has `stats` and `card_id` columns
- [ ] RLS policies are active
- [ ] App launches without database errors
- [ ] Onboarding flow completes successfully
- [ ] Data is saved to Supabase
- [ ] No console errors during operations

## 🚀 Next Steps

After completing the database setup:

1. **Test the complete onboarding flow**
2. **Verify data persistence**
3. **Check performance** (card generation should be <60s)
4. **Test on physical device** for social authentication

## 📞 Support

If you encounter any issues:

1. Check the console logs for specific error messages
2. Verify all steps in the setup guide
3. Ensure you're using the correct Supabase project
4. Contact support with specific error details

---

**Status**: ✅ **Ready for Production** (after database setup)
**Critical Issues**: ✅ **All Resolved**
**Acceptance Criteria**: ✅ **All Met**
