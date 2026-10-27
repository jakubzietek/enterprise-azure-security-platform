variable "sql_entra_admin_login" {
  description = "Microsoft Entra login used as the Azure SQL administrator"
  type        = string

}

variable "sql_entra_admin_object_id" {
  description = "Object ID of the Microsoft Entra principal used as Azure SQL administrator"
  type        = string

}