provider "aws" {
 region = "us-east-1"
}


resource "aws_s3_bucket" "b" {
  bucket = "a-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }
}

variable "s3_folders" {
  type        = list(string)
  description = "The list of S3 folders to create"
  default     = [""]
}

#Then alter the piece of code you already have:

resource "aws_s3_bucket_object" "folders" {
    count   = "${length(var.s3_folders)}"
    bucket = "${aws_s3_bucket.b.id}"
    acl    = "private"
    key    = "${var.s3_folders[count.index]}/"
    source = "/dev/null"
}
