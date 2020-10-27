variable "name" {
    description = "Name to use"
}
variable "location" {
    description = "Region to deploy to"
    default = "westus2"
}
variable "docker_image" {
    description = "Docker image to deploy"
}