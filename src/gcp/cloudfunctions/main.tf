terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    bucket = "oh-test"
    prefix = "terraform/state_functions"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# resource "google_storage_bucket" "function_code_bucket" {
#   name          = "gcf-v2-sources-${var.project_number}-${var.region}"
#   location      = var.region
#   uniform_bucket_level_access = true
# }

resource "google_storage_bucket_object" "function_source" {
  name   = "manual-input-data-triggerer/function-source.zip"
  bucket = "gcf-v2-sources-${var.project_number}-${var.region}"  # google_storage_bucket.function_code_bucket.name
  source = "${path.module}/manual-input-data-triggerer/function-source.zip"
}

resource "google_cloudfunctions2_function" "default" {
  name        = "manual-input-data-triggerer" # 表示する関数名
  location    = var.region
  description = "Manual input data triggerer"

  build_config {
    runtime     = "python311"
    entry_point = "main"
    source {
      storage_source {
        bucket = "gcf-v2-sources-${var.project_number}-${var.region}"
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
    environment_variables = {
        LOG_EXECUTION_ID = true
        PROJECT_ID = var.project_id
    }
  }

  event_trigger {
    event_type = "google.cloud.storage.object.v1.finalized"
    retry_policy = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = var.service_account
    event_filters {
      attribute = "bucket"
      value = "trigger_test_ou"
    }
  }
}
