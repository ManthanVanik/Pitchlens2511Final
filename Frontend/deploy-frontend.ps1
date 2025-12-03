# PITCHLENS FRONTEND DEPLOYMENT SCRIPT
# Service: pitchlens-frontend
# This script builds and deploys the Next.js frontend to Google Cloud Run

$SERVICE_NAME = "pitchlens-frontend"
$REGION = "us-central1"
$PROJECT_ID = "hackathon-472304"

Write-Host ""
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "      DEPLOYING PITCHLENS FRONTEND TO CLOUD RUN           " -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify in project folder
Write-Host "Step 1: Verifying project..." -ForegroundColor Yellow
if (-Not (Test-Path "package.json")) {
    Write-Host "[ERROR] package.json not found! Are you in the Frontend folder?" -ForegroundColor Red
    exit 1
}
if (-Not (Test-Path "next.config.ts")) {
    Write-Host "[ERROR] next.config.ts not found!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Found Next.js project files" -ForegroundColor Green
Write-Host ""

# Step 2: Check for backend URL
Write-Host "Step 2: Checking environment configuration..." -ForegroundColor Yellow
if (-Not (Test-Path ".env.production")) {
    Write-Host "[INFO] .env.production not found!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Creating .env.production template..." -ForegroundColor Gray
    
    # Read backend URL from file if it exists
    $BACKEND_URL = "YOUR_BACKEND_URL_HERE"
    if (Test-Path "..\Backend\backend-url.txt") {
        $BACKEND_URL = Get-Content "..\Backend\backend-url.txt" -Raw
        $BACKEND_URL = $BACKEND_URL.Trim()
    }
    
    @"
# Production Environment Variables
NEXT_PUBLIC_API_BASE_URL=$BACKEND_URL
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyCwStJGzCz-GCQIn3qHCEJB4TvytF19vFM
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=hackathon-472304.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=hackathon-472304
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=hackathon-472304.firebasestorage.app
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=390550640662
NEXT_PUBLIC_FIREBASE_APP_ID=1:390550640662:web:d18dca3f82ee3535137d37
NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID=G-VGBW466CFP
"@ | Out-File -FilePath ".env.production" -Encoding UTF8
    
    Write-Host "[OK] Created .env.production" -ForegroundColor Green
    Write-Host ""
    Write-Host "[INFO] IMPORTANT: Update NEXT_PUBLIC_API_BASE_URL in .env.production" -ForegroundColor Yellow
    Write-Host "   with your backend URL before deploying!" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to continue or Ctrl+C to cancel"
}
Write-Host "[OK] Environment configuration ready" -ForegroundColor Green
Write-Host ""

# Step 3: Set project
Write-Host "Step 3: Setting GCP project..." -ForegroundColor Yellow
gcloud config set project $PROJECT_ID --quiet
gcloud config set compute/region $REGION --quiet
Write-Host "[OK] Project: $PROJECT_ID" -ForegroundColor Green
Write-Host "[OK] Region: $REGION" -ForegroundColor Green
Write-Host ""

# Step 4: Create Dockerfile if not exists
Write-Host "Step 4: Checking Dockerfile..." -ForegroundColor Yellow
if (-Not (Test-Path "Dockerfile")) {
    Write-Host "Creating optimized Next.js Dockerfile..." -ForegroundColor Gray
    
    @"
# Multi-stage build for Next.js on Cloud Run
FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package*.json ./
RUN npm ci

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build Next.js
RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV PORT 8080

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Create empty public folder (since we don't have static assets yet)
RUN mkdir -p ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 8080

CMD ["node", "server.js"]
"@ | Out-File -FilePath "Dockerfile" -Encoding UTF8
    
    Write-Host "[OK] Created Dockerfile" -ForegroundColor Green
}
Write-Host "[OK] Dockerfile ready" -ForegroundColor Green
Write-Host ""

# Step 5: Update next.config for standalone build
Write-Host "Step 5: Verifying Next.js configuration..." -ForegroundColor Yellow
Write-Host "[INFO] Ensure next.config.ts has: output: 'standalone'" -ForegroundColor Yellow
Write-Host ""

# Step 6: Deploy
Write-Host "Step 6: Deploying frontend (3-5 minutes)..." -ForegroundColor Yellow
Write-Host "Building and deploying..." -ForegroundColor Gray
Write-Host ""

# Construct environment variables string
$ENV_VARS = "NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyCwStJGzCz-GCQIn3qHCEJB4TvytF19vFM,NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=hackathon-472304.firebaseapp.com,NEXT_PUBLIC_FIREBASE_PROJECT_ID=hackathon-472304,NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=hackathon-472304.firebasestorage.app,NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=390550640662,NEXT_PUBLIC_FIREBASE_APP_ID=1:390550640662:web:d18dca3f82ee3535137d37,NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID=G-VGBW466CFP"

# Read backend URL from file if it exists to add to env vars
if (Test-Path "frontend-url.txt") {
    # This is just a placeholder, we actually need the backend URL here.
    # The script earlier creates .env.production with the backend URL.
    # Let's try to read it from .env.production or backend-url.txt
}

$BACKEND_URL_VAL = ""
if (Test-Path "..\Backend\backend-url.txt") {
    $BACKEND_URL_VAL = Get-Content "..\Backend\backend-url.txt" -Raw
    $BACKEND_URL_VAL = $BACKEND_URL_VAL.Trim()
    $ENV_VARS = "$ENV_VARS,NEXT_PUBLIC_API_BASE_URL=$BACKEND_URL_VAL"
}

gcloud run deploy $SERVICE_NAME `
  --source . `
  --platform managed `
  --region $REGION `
  --allow-unauthenticated `
  --memory 1Gi `
  --cpu 1 `
  --timeout 300 `
  --max-instances 10 `
  --set-build-env-vars="NODE_OPTIONS=--max_old_space_size=4096,$ENV_VARS" `
  --set-env-vars="$ENV_VARS" `
  --quiet

# Check result
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[SUCCESS] Frontend deployment successful!" -ForegroundColor Green
    Write-Host ""
    
    # Get URL
    Write-Host "Step 7: Getting service URL..." -ForegroundColor Yellow
    $FRONTEND_URL = gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)'
    
    Write-Host ""
    Write-Host "=============================================================" -ForegroundColor Green
    Write-Host "             FRONTEND DEPLOYMENT COMPLETE!                " -ForegroundColor Green
    Write-Host "=============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Frontend App URL:" -ForegroundColor Cyan
    Write-Host "   $FRONTEND_URL" -ForegroundColor Green
    Write-Host ""
    Write-Host "IMPORTANT NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "   1. Update Backend/deploy-backend.ps1:" -ForegroundColor White
    Write-Host "      Change FRONTEND_URL to: $FRONTEND_URL" -ForegroundColor Gray
    Write-Host "   2. Re-deploy backend to update CORS settings:" -ForegroundColor White
    Write-Host "      cd ..\Backend" -ForegroundColor Gray
    Write-Host "      .\deploy-backend.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Your app is now live at:" -ForegroundColor Cyan
    Write-Host "   $FRONTEND_URL" -ForegroundColor Green
    Write-Host ""
    Write-Host "View logs:" -ForegroundColor Cyan
    Write-Host "   gcloud run logs read $SERVICE_NAME --region $REGION --follow" -ForegroundColor Gray
    Write-Host ""
    
    # Save URL to file
    $FRONTEND_URL | Out-File -FilePath "frontend-url.txt" -Encoding UTF8
    Write-Host "[SAVED] Frontend URL saved to: frontend-url.txt" -ForegroundColor Green
    Write-Host ""
    
} else {
    Write-Host ""
    Write-Host "[ERROR] Deployment failed!" -ForegroundColor Red
    Write-Host "Check the error messages above for details." -ForegroundColor Red
    exit 1
}
