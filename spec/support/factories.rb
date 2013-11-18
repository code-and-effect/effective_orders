require 'factory_girl'

FactoryGirl.define do
  factory :asset, :class => Effective::Asset do
    user_id 1

    sequence(:title) { |n| "Title #{n}" }
    content_type 'image/jpg'
    processed true

    sequence(:upload_file) { |n| "http://#{EffectiveAssets.aws_bucket}.s3.amazonaws.com/uploads/asset#{n}.jpg"}
    sequence(:data) { |n| "asset#{n}.jpg" }

    data_size 123456
    width 600
    height 480
    versions_info Hash.new(:thumb => {:data_size => 123456, :width => 128, :height => 128}, :main => {:data_size => 123456, :width => 400, :height => 400})
  end

  # factory :attachment do
  #   association :asset
  #   association :attachable, :factory => :user

  #   position 0
  #   box 'featured_images'
  # end

end
