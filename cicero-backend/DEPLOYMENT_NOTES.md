# Deployment Notes

## Environment Variables Required

Before deploying to Render, ensure you have all these environment variables set:

### API Keys
- `GROQ_API_KEY`
- `GEMINI_API_KEY`
- `PINECONE_API_KEY`
- `COURTLISTENER_API_KEY`
- `LEGISCAN_API_KEY`
- `CONGRESS_GOV_API_KEY`

### Database
- `DATABASE_URL` - Automatically set by Render from the database service

### Firebase
- `FIREBASE_CREDENTIALS` - JSON string of Firebase service account credentials

### Stripe
- `STRIPE_SECRET_KEY` - Your Stripe secret key
- `STRIPE_WEBHOOK_SECRET` - Stripe webhook signing secret
- `STRIPE_PREMIUM_PRICE_ID` - Stripe Price ID for Premium subscription

### CORS
- `ALLOWED_ORIGINS` - Comma-separated list (e.g., "https://yourdomain.com,https://app.yourdomain.com")

## Database Migrations

Run migrations on first deploy:
```bash
alembic upgrade head
```

This is automatically included in the Render build command.

## Stripe Webhook Setup

1. Create a webhook endpoint in Stripe Dashboard
2. Point it to: `https://your-backend-url.onrender.com/subscription/webhook`
3. Select events:
   - `checkout.session.completed`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
4. Copy the webhook signing secret to `STRIPE_WEBHOOK_SECRET`

## Firebase Setup

1. Create a Firebase project
2. Enable Email/Password authentication
3. Create a service account and download the JSON
4. Either:
   - Upload the JSON file and set `FIREBASE_CREDENTIALS` to the file path, OR
   - Copy the JSON content and set `FIREBASE_CREDENTIALS` to the JSON string

## Mobile App Configuration

### Android
1. Update `applicationId` in `android/app/build.gradle.kts` to your package name
2. Generate production keystore:
   ```bash
   keytool -genkey -v -keystore cicero-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cicero
   ```
3. Create `android/key.properties`:
   ```properties
   storePassword=your_store_password
   keyPassword=your_key_password
   keyAlias=cicero
   storeFile=../cicero-release-key.jks
   ```
4. Update `build.gradle.kts` to use production signing (see Android documentation)

### iOS
1. Update bundle identifier in Xcode
2. Configure signing with Apple Developer account
3. Create App ID in Apple Developer Portal
4. Generate distribution certificates

## Next Steps

1. Set up Firebase project and add credentials
2. Set up Stripe account and create Premium price
3. Configure all environment variables in Render
4. Deploy backend to Render
5. Update mobile/web apps with production API URL
6. Build and test production mobile apps
7. Submit to app stores

