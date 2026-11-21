# Learnix AI - fast-loading build and deploy (run from this folder in PowerShell)
# 1) Build the Flutter web app (release, no offline service worker)
Set-Location learnix_flutter
flutter build web --release --pwa-strategy=none
Set-Location ..

# 2) Deploy to Cloud Run with one instance always warm and extra CPU at start-up
gcloud run deploy learnix-ai --source . `
  --region asia-southeast1 --project learnix-ai-515213 `
  --min-instances 1 --cpu-boost --memory 1Gi
