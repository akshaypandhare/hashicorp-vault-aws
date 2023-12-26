variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "tags" {
  type    = map(any)
  default = {}
}