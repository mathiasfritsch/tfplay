variable "http_port" {
  description = "HTTP port for the web server"
  type        = number
  default     = 8080
}

 variable "db_username" {
   description = "Database administrator username"
   type        = string
   default     = "dbadmin"
   sensitive   = true
 }

 variable "db_password" {
   description = "Database administrator password"
   type        = string
   default     = "ChangeMe123!"
   sensitive   = true
 }
