# EffectiveAssets Rails Engine

EffectiveAssets.setup do |config|
  config.assets_table_name = :assets
  config.attachments_table_name = :attachments

  config.uploader = AssetUploader

  # This is your S3 bucket information
  config.aws_bucket = 'as-rails-skeleton'
  config.aws_access_key_id = 'AKIAJOLWUEBMTM5QJTQQ'
  config.aws_secret_access_key = 'xm+J2Y2F/qDwGX2LvpeBjSQm+DYduBefLET3kp/2'

  config.aws_path = 'assets/'
  config.aws_acl = 'public-read'

  config.authorization_method = Proc.new { |controller, action, resource| true }
end

