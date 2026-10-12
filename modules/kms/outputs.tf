output "data_key_arn" {
  value = aws_kms_key.data.arn
}

output "data_key_id" {
  value = aws_kms_key.data.key_id
}

output "cosign_key_arn" {
  value = aws_kms_key.cosign.arn
}

output "cosign_key_id" {
  value = aws_kms_key.cosign.key_id
}
