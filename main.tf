provider "google" {
  credentials = file(var.service_account_file_name)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

provider "google-beta" {
  credentials = file(var.service_account_file_name)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

provider "snowflake" {
  username = var.snowflake_username
  password = var.snowflake_password
  account  = var.snowflake_account
  region   = var.snowflake_region
}

resource "google_project_service" "vertex-api" {
  project = var.project_id
  service = "aiplatform.googleapis.com"
}

resource "google_project_service" "notebooks-api" {
  project = var.project_id
  service = "notebooks.googleapis.com"
}

resource "google_notebooks_instance" "notebook-instance" {
  provider     = google-beta
  name         = "notebook-feature-store"
  location     = var.zone
  machine_type = "e2-medium"
  container_image {
    repository = "gcr.io/deeplearning-platform-release/base-cpu"
    tag        = "latest"
  }
  depends_on = [google_project_service.vertex-api, google_project_service.notebooks-api]
}

resource "google_storage_bucket" "data-ingestion-bucket" {
  name          = "${var.project_id}-data-ingestion-bucket"
  location      = var.bucket_region
  force_destroy = true
}

resource "google_storage_bucket" "feature-bucket" {
  name          = "${var.project_id}-feature-bucket"
  location      = var.bucket_region
  force_destroy = true
}

resource "google_pubsub_topic" "data-ingestion-bucket-notification-topic" {
  name = "data_ingestion_bucket_notification_topic"
}

data "google_storage_project_service_account" "gcs_account" {
}

resource "google_pubsub_topic_iam_binding" "data-ingestion-bucket-notification-topic-binding" {
  topic   = google_pubsub_topic.data-ingestion-bucket-notification-topic.name
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_pubsub_subscription" "data-ingestion-bucket-notification-subscription" {
  name  = "data_ingestion_bucket_notification_sub"
  topic = google_pubsub_topic.data-ingestion-bucket-notification-topic.name
}

resource "google_storage_notification" "data-ingestion-bucket-notification" {
  bucket         = google_storage_bucket.data-ingestion-bucket.name
  payload_format = "JSON_API_V1"
  event_types    = ["OBJECT_FINALIZE"]
  topic          = google_pubsub_topic.data-ingestion-bucket-notification-topic.id
  depends_on     = [google_pubsub_topic_iam_binding.data-ingestion-bucket-notification-topic-binding]
}

resource "google_project_iam_custom_role" "gcp-gcs-snowflake-integration-role" {
  role_id     = "gcs_snowflake_integration_role"
  title       = "GCS Snowflake integration role"
  description = "The role allows Snowflake to load/unload data from/to GCS buckets"
  permissions = [
    "storage.buckets.get",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.list"
  ]
}

resource "google_storage_bucket_iam_member" "ingestion-bucket-snowflake-service-account-member" {
  bucket = google_storage_bucket.data-ingestion-bucket.name
  role   = google_project_iam_custom_role.gcp-gcs-snowflake-integration-role.id
  member = "serviceAccount:${snowflake_storage_integration.gcp-ingestion-bucket-integration.storage_gcp_service_account}"
}

resource "google_storage_bucket_iam_member" "feature-bucket-snowflake-service-account-member" {
  bucket = google_storage_bucket.feature-bucket.name
  role   = google_project_iam_custom_role.gcp-gcs-snowflake-integration-role.id
  member = "serviceAccount:${snowflake_storage_integration.gcp-feature-bucket-integration.storage_gcp_service_account}"
}

resource "google_pubsub_subscription_iam_binding" "data-ingestion-bucket-notification-subscription-snowflake-binding-subscriber" {
  subscription = google_pubsub_subscription.data-ingestion-bucket-notification-subscription.name
  role         = "roles/pubsub.subscriber"
  members = [
    "serviceAccount:${snowflake_notification_integration.ingestion-bucket-notification-integration.gcp_pubsub_service_account}"
  ]
}

resource "google_project_iam_binding" "project-binding-monitoring" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  members = [
    "serviceAccount:${snowflake_notification_integration.ingestion-bucket-notification-integration.gcp_pubsub_service_account}"
  ]
}

resource "snowflake_warehouse" "data-pipeline-warehouse" {
  name           = "data-pipeline-warehouse"
  comment        = "Warehouse for the data-pipeline"
  warehouse_size = "small"
}

resource "snowflake_storage_integration" "gcp-ingestion-bucket-integration" {
  name                      = "gcp_ingestion_bucket_integration"
  comment                   = "Integration with GCS bucket: ${google_storage_bucket.data-ingestion-bucket.id} in project: ${var.project_id}"
  type                      = "EXTERNAL_STAGE"
  enabled                   = true
  storage_provider          = "GCS"
  storage_allowed_locations = ["gcs://${google_storage_bucket.data-ingestion-bucket.id}"]
}

resource "snowflake_storage_integration" "gcp-feature-bucket-integration" {
  name                      = "gcp_feature_bucket_integration"
  comment                   = "Integration with GCS bucket: ${google_storage_bucket.feature-bucket.id} in project: ${var.project_id}"
  type                      = "EXTERNAL_STAGE"
  enabled                   = true
  storage_provider          = "GCS"
  storage_allowed_locations = ["gcs://${google_storage_bucket.feature-bucket.id}"]
}

resource "snowflake_database" "github-archive-events-db" {
  name    = "github_archive_events"
  comment = "The DB contains events from GitHub archive"
}

resource "snowflake_database_grant" "github-archive-events-db-grant" {
  database_name = snowflake_database.github-archive-events-db.name
  privilege     = "USAGE"
}

resource "snowflake_schema" "github-archive-events-staging-schema" {
  database = snowflake_database.github-archive-events-db.name
  name     = "staging"
  comment  = "The schema contains RAW events from GitHub"
}

resource "snowflake_schema_grant" "github-archive-events-staging-schema-grant" {
  database_name = snowflake_database.github-archive-events-db.name
  schema_name   = snowflake_schema.github-archive-events-staging-schema.name
  privilege     = "USAGE"
}

resource "snowflake_schema" "github-archive-events-features-schema" {
  database = snowflake_database.github-archive-events-db.name
  name     = "features"
  comment  = "The schema contains features extracted from GitHub"
}

resource "snowflake_schema_grant" "github-archive-events-features-schema-grant" {
  database_name = snowflake_database.github-archive-events-db.name
  schema_name   = snowflake_schema.github-archive-events-features-schema.name
  privilege     = "USAGE"
}

resource "snowflake_schema" "github-archive-events-development-schema" {
  database = snowflake_database.github-archive-events-db.name
  name     = "development"
  comment  = "The schema contains experiment models created by developers"
}

resource "snowflake_schema_grant" "github-archive-events-development-schema-grant" {
  database_name = snowflake_database.github-archive-events-db.name
  schema_name   = snowflake_schema.github-archive-events-development-schema.name
  privilege     = "USAGE"
}

resource "snowflake_table" "github-archive-events-table" {
  database = snowflake_database.github-archive-events-db.name
  schema   = snowflake_schema.github-archive-events-staging-schema.name
  name     = "events"
  comment  = "The table contains events from GitHub archive"

  column {
    name     = "event"
    type     = "VARIANT"
    nullable = false
  }
}

resource "snowflake_file_format" "github-archive-events-file-format" {
  name             = "github_archive_events_file_format"
  database         = snowflake_database.github-archive-events-db.name
  schema           = snowflake_schema.github-archive-events-staging-schema.name
  compression      = "AUTO"
  binary_format    = "UTF-8"
  date_format      = "AUTO"
  time_format      = "AUTO"
  timestamp_format = "AUTO"
  format_type      = "JSON"
}

resource "snowflake_file_format" "features-file-format" {
  name             = "features_file_format"
  database         = snowflake_database.github-archive-events-db.name
  schema           = snowflake_schema.github-archive-events-features-schema.name
  compression      = "NONE"
  binary_format    = "UTF-8"
  date_format      = "AUTO"
  time_format      = "AUTO"
  timestamp_format = "AUTO"
  format_type      = "CSV"
}

resource "snowflake_file_format_grant" "github-archive-events-file-format-grant" {
  database_name    = snowflake_database.github-archive-events-db.name
  schema_name      = snowflake_schema.github-archive-events-staging-schema.name
  file_format_name = snowflake_file_format.github-archive-events-file-format.name
}

resource "snowflake_file_format_grant" "features-file-format-grant" {
  database_name    = snowflake_database.github-archive-events-db.name
  schema_name      = snowflake_schema.github-archive-events-features-schema.name
  file_format_name = snowflake_file_format.features-file-format.name
}


resource "snowflake_stage" "github-archive-events-stage" {
  name                = "github_archive_events_stage"
  url                 = "gcs://${google_storage_bucket.data-ingestion-bucket.id}"
  database            = snowflake_database.github-archive-events-db.name
  schema              = snowflake_schema.github-archive-events-staging-schema.name
  file_format         = "format_name = \"${snowflake_database.github-archive-events-db.name}\".\"${snowflake_schema.github-archive-events-staging-schema.name}\".\"${snowflake_file_format.github-archive-events-file-format.name}\""
  storage_integration = "\"${snowflake_storage_integration.gcp-ingestion-bucket-integration.id}\""
}

resource "snowflake_stage" "features-stage" {
  name                = "features_stage"
  url                 = "gcs://${google_storage_bucket.feature-bucket.id}"
  database            = snowflake_database.github-archive-events-db.name
  schema              = snowflake_schema.github-archive-events-features-schema.name
  file_format         = "format_name = \"${snowflake_database.github-archive-events-db.name}\".\"${snowflake_schema.github-archive-events-features-schema.name}\".\"${snowflake_file_format.features-file-format.name}\""
  storage_integration = "\"${snowflake_storage_integration.gcp-feature-bucket-integration.id}\""
}

resource "snowflake_stage_grant" "github-archive-events-stage-grant" {
  database_name = snowflake_database.github-archive-events-db.name
  schema_name   = snowflake_schema.github-archive-events-staging-schema.name
  stage_name    = snowflake_stage.github-archive-events-stage.name
  privilege     = "USAGE"
}

resource "snowflake_stage_grant" "feature-stage-grant" {
  database_name = snowflake_database.github-archive-events-db.name
  schema_name   = snowflake_schema.github-archive-events-features-schema.name
  stage_name    = snowflake_stage.features-stage.name
  privilege     = "USAGE"
}

resource "snowflake_notification_integration" "ingestion-bucket-notification-integration" {
  name                         = "ingestion_bucket_notification_integration"
  comment                      = "A notification integration for events from GCP data ingestion bucket."
  enabled                      = true
  type                         = "QUEUE"
  notification_provider        = "GCP_PUBSUB"
  gcp_pubsub_subscription_name = google_pubsub_subscription.data-ingestion-bucket-notification-subscription.id
  depends_on                   = [google_pubsub_subscription.data-ingestion-bucket-notification-subscription]
}

resource "snowflake_pipe" "github-archive-events-pipe" {
  database       = snowflake_database.github-archive-events-db.name
  schema         = snowflake_schema.github-archive-events-staging-schema.name
  name           = "github_archive_events_pipe"
  comment        = "A pipe to load data from ingestion bucket into events table"
  copy_statement = "COPY INTO \"${snowflake_database.github-archive-events-db.name}\".\"${snowflake_schema.github-archive-events-staging-schema.name}\".\"${snowflake_table.github-archive-events-table.name}\" FROM @\"${snowflake_database.github-archive-events-db.name}\".\"${snowflake_schema.github-archive-events-staging-schema.name}\".\"${snowflake_stage.github-archive-events-stage.name}\" FILE_FORMAT = (format_name = \"${snowflake_database.github-archive-events-db.name}\".\"${snowflake_schema.github-archive-events-staging-schema.name}\".\"${snowflake_file_format.github-archive-events-file-format.name}\")"
  auto_ingest    = true
  integration    = snowflake_notification_integration.ingestion-bucket-notification-integration.name
  depends_on = [
    google_pubsub_subscription_iam_binding.data-ingestion-bucket-notification-subscription-snowflake-binding-subscriber,
    google_project_iam_binding.project-binding-monitoring
  ]
}

resource "snowflake_pipe_grant" "grant" {
  database_name = snowflake_database.github-archive-events-db.name
  schema_name   = snowflake_schema.github-archive-events-staging-schema.name
  pipe_name     = snowflake_pipe.github-archive-events-pipe.name
  privilege     = "OPERATE"
}

resource "google_vertex_ai_featurestore" "github-featurestore" {
  provider = google-beta
  name     = "github_features"
  region   = var.region
  online_serving_config {
    fixed_node_count = 1
  }
  depends_on    = [google_project_service.vertex-api, google_project_service.notebooks-api]
  force_destroy = true
}

resource "google_vertex_ai_featurestore_entitytype" "user-entity" {
  provider     = google-beta
  name         = "user_entity"
  featurestore = google_vertex_ai_featurestore.github-featurestore.id
  monitoring_config {
    snapshot_analysis {
      disabled            = false
      monitoring_interval = "86400s"
    }
  }
}