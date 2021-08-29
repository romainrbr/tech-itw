variable "aws_region" {
  description = "The AWS region to deploy the resources into."
  default     = "eu-central-1"
}

variable "GBFS_endpoints" {
  type        = map(any)
  description = "Endpoints to be scrapped, key will be used as bucket folder name, as well as script suffix"
  default = {
    bird = {
      "url" = "https://mds.bird.co/gbfs/tempe/free_bike_status.json"
    }
    bergen = {
      "url"  = "http://gbfs.urbansharing.com/bergenbysykkel.no/station_information.json"
      "name" = "bergen"
    }
  }
}
variable "GBFS_bucket" {
  description = "Name of the bucket to store the GBFS files"
  default     = "gbfsdata"
}

variable "wipe_bucket_on_destroy" {
  description = "Allows us to wipe all data in the bucket with a `terraform destroy`, not suitable for production"
  default     = true
}