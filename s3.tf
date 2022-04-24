resource "aws_s3_bucket" "b" {
  bucket = "t4t-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }
}

variable "s3_folders" {
  type        = list(string)
  description = "The list of S3 folders to create"
  default     = ["saved_emb", "saved_emb/1_1", "saved_emb/1_MANY","saved_emb", "saved_emb/ibsopenapi", "saved_emb/horizon","merged_final_output","merged_final_output/d1_one_merged_mlo"]
}

#Then alter the piece of code you already have:

resource "aws_s3_bucket_object" "folders" {
    count   = "${length(var.s3_folders)}"
    bucket = "${aws_s3_bucket.b.id}"
    acl    = "private"
    key    = "${var.s3_folders[count.index]}/"
    source = "/dev/null"
}
