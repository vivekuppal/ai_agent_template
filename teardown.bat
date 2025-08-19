REM @echo off
setlocal EnableExtensions EnableDelayedExpansion
REM ===========================================================
REM  Teardown for AI Agent (Windows CMD)
REM  - Deletes Pub/Sub subs & DLQs, topic
REM  - Removes GCS->Pub/Sub notifications (only those for %TOPIC%)
REM  - Removes IAM bindings and deletes Cloud Run service
REM  - Deletes service accounts (runtime + push)
REM ===========================================================

REM ========== CONFIG (EDIT ME) ==========
set "PROJECT_ID=lappuai-prod"
set "REGION=us-east1"

REM Cloud Run service (one component). If you deployed multiple, run per service or duplicate this section.
set "SERVICE=ai-agent-spoofing"

REM Pub/Sub topic that GCS publishes to
set "TOPIC=gcs.dmarc-report-file"

REM Subscriptions to delete (space-separated)
set "SUBS=sub-ai-find-spoof-indicators"

REM If DLQs follow "dlq.<subscription>", leave DLQ_TOPICS empty to auto-derive.
REM Otherwise set explicitly, e.g.: set "DLQ_TOPICS=dlq.sub-ai-scorer custom-dlq"
set "DLQ_TOPICS="

REM Bucket used for notifications and bucket-level IAM (no gs:// prefix)
set "BUCKET=lai-dmarc-aggregate-reports"

REM Service accounts (names, not full emails)
set "RUNTIME_SA_NAME=ai-agent-spoofing"
set "PUSH_SA_NAME=pubsub-spoofing-push-sa"

REM ========== DERIVED ==========
for /f %%P in ('gcloud projects describe "%PROJECT_ID%" --format^=value^(projectNumber^)') do set "PROJECT_NUMBER=%%P"
set "RUNTIME_SA=%RUNTIME_SA_NAME%@%PROJECT_ID%.iam.gserviceaccount.com"
set "PUSH_SA=%PUSH_SA_NAME%@%PROJECT_ID%.iam.gserviceaccount.com"
set "PUBSUB_SERVICE_AGENT=service-%PROJECT_NUMBER%@gcp-sa-pubsub.iam.gserviceaccount.com"
set "GCS_SERVICE_AGENT=service-%PROJECT_NUMBER%@gs-project-accounts.iam.gserviceaccount.com"

REM If DLQ_TOPICS is empty, derive from SUBS
set "DLQ_DERIVED="
if "%DLQ_TOPICS%"=="" (
  for %%S in (%SUBS%) do (
    set "DLQ_DERIVED=!DLQ_DERIVED! dlq.%%S"
  )
) else (
  set "DLQ_DERIVED=%DLQ_TOPICS%"
)

echo === Teardown starting for project: %PROJECT_ID% (region: %REGION%) ===

REM 1) Delete GCS notifications on %BUCKET% that reference %TOPIC%
echo -> Deleting GCS bucket notifications on gs://%BUCKET% that target topic "%TOPIC%"
for /f %%I in ('gcloud storage buckets notifications list gs://%BUCKET% --project "%PROJECT_ID%" --format^=value^(id^) 2^>nul') do (
  for /f "usebackq delims=" %%T in (`gcloud storage buckets notifications describe projects/_/buckets/%BUCKET%/notificationConfigs/%%I --project "%PROJECT_ID%" --format^=value^(topic^) 2^>nul`) do (
    if /I "%%T"=="%TOPIC%" (
      echo    - deleting notification ID %%I
      gcloud storage buckets notifications delete projects/_/buckets/%BUCKET%/notificationConfigs/%%I --project "%PROJECT_ID%" --quiet >nul 2>&1
    )
  )
)

REM 2) Remove bucket-level IAM for runtime SA
echo -> Removing bucket IAM for runtime SA on gs://%BUCKET%
REM gcloud storage buckets remove-iam-policy-binding "gs://%BUCKET%" --member="serviceAccount:%RUNTIME_SA%" --role="roles/storage.objectViewer"  --project "%PROJECT_ID%" >nul 2>&1
REM gcloud storage buckets remove-iam-policy-binding "gs://%BUCKET%" --member="serviceAccount:%RUNTIME_SA%" --role="roles/storage.objectCreator" --project "%PROJECT_ID%" >nul 2>&1
REM gcloud storage buckets remove-iam-policy-binding "gs://%BUCKET%" --member="serviceAccount:%RUNTIME_SA%" --role="roles/storage.objectAdmin"   --project "%PROJECT_ID%" >nul 2>&1

REM 3) Remove Pub/Sub IAM bindings (publisher on DLQs & topic)
echo -> Removing Pub/Sub IAM bindings
gcloud pubsub topics remove-iam-policy-binding "%TOPIC%" --member="serviceAccount:%GCS_SERVICE_AGENT%"   --role="roles/pubsub.publisher" --project "%PROJECT_ID%" 

for %%D in (%DLQ_DERIVED%) do (
  gcloud pubsub topics remove-iam-policy-binding "%%D" --member="serviceAccount:%PUBSUB_SERVICE_AGENT%" --role="roles/pubsub.publisher" --project "%PROJECT_ID%"
)

REM 4) Delete subscriptions
echo -> Deleting Pub/Sub subscriptions
for %%S in (%SUBS%) do (
  echo    - deleting subscription %%S
  gcloud pubsub subscriptions delete "%%S" --project "%PROJECT_ID%" --quiet >nul 2>&1
)

REM 5) Delete DLQ topics
echo -> Deleting DLQ topics
for %%D in (%DLQ_DERIVED%) do (
  echo    - deleting topic %%D
  gcloud pubsub topics delete "%%D" --project "%PROJECT_ID%" --quiet >nul 2>&1
)

REM 6) Delete main topic
echo -> Deleting main topic: %TOPIC%
gcloud pubsub topics delete "%TOPIC%" --project "%PROJECT_ID%" --quiet >nul 2>&1

REM 7) Remove Cloud Run run.invoker binding for push SA (harmless if service missing)
echo -> Removing Cloud Run run.invoker binding for %PUSH_SA%
gcloud run services remove-iam-policy-binding "%SERVICE%" --region "%REGION%" --project "%PROJECT_ID%" ^
  --member="serviceAccount:%PUSH_SA%" --role="roles/run.invoker" >nul 2>&1

REM 8) Delete Cloud Run service
echo -> Deleting Cloud Run service: %SERVICE%
gcloud run services delete "%SERVICE%" --region "%REGION%" --project "%PROJECT_ID%" --quiet >nul 2>&1

REM 9) Remove token-creator binding on push SA
echo -> Removing token-creator binding from push SA
gcloud iam service-accounts remove-iam-policy-binding "%PUSH_SA%" --member="serviceAccount:%PUBSUB_SERVICE_AGENT%" ^
  --role="roles/iam.serviceAccountTokenCreator" --project "%PROJECT_ID%" >nul 2>&1

REM 10) Delete service accounts
echo -> Deleting service accounts
gcloud iam service-accounts delete "%RUNTIME_SA%" --project "%PROJECT_ID%" --quiet >nul 2>&1
gcloud iam service-accounts delete "%PUSH_SA%"    --project "%PROJECT_ID%" --quiet >nul 2>&1

REM 11) (Optional) Delete container images (uncomment ONE of the blocks below)

REM ---- (a) Google Container Registry: gcr.io ----
REM for /f %%G in ('gcloud container images list-tags "gcr.io/%PROJECT_ID%/%SERVICE%" --format^=get^(digest^) 2^>nul') do (
REM   echo -> Deleting image digest %%G from gcr.io/%PROJECT_ID%/%SERVICE%
REM   gcloud container images delete -q "gcr.io/%PROJECT_ID%/%SERVICE%@%%G" --force-delete-tags >nul 2>&1
REM )

REM ---- (b) Artifact Registry (example repo "services" in us-east1) ----
REM for /f "tokens=*" %%I in ('gcloud artifacts docker images list "us-east1-docker.pkg.dev/%PROJECT_ID%/services/%SERVICE%" --format^=get^(version^) 2^>nul') do (
REM   echo -> Deleting AR image %%I
REM   gcloud artifacts docker images delete "%%I" --quiet >nul 2>&1
REM )

echo === Teardown complete. ===
endlocal
