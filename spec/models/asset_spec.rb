require 'spec_helper'

# Attributes
describe Effective::Asset do
  let(:asset) { FactoryGirl.create(:asset) }

  it 'should be valid' do
    asset.valid?.should eq true
  end
end

describe Effective::Asset do
  let(:image_url) { 'http://cdn.sstatic.net/stackoverflow/img/sprites.png?v=1' }

  it 'should be creatable from URL' do
    asset = Effective::Asset.create_from_url(image_url, {:title => 'a title', :description => 'a description', :tags => 'a tags', :user_id => 1})

    # A new asset should exist, and it should be unprocessed
    asset.upload_file.should eq image_url
    asset.processed.should eq false

    # It should have queued up a process_asset task with delayed job
    Delayed::Job.count.should eq 1

    job = Psych.load(Delayed::Job.first.handler)
    job.method_name.should eq :process_asset_without_delay
    job.args.first.should eq asset

    # Run DelayedJob
    Delayed::Worker.new(:max_priority => nil, :min_priority => nil, :quiet => true).work_off
    Delayed::Job.count.should eq 0

    # We should have a totally processed Asset
    asset = Effective::Asset.find(asset.id)
    asset.processed.should eq true
    asset.data.kind_of?(AssetUploader).should eq true
    asset.title.should eq 'a title'
    asset.description.should eq 'a description'
    asset.tags.should eq 'a tags'
    asset.user_id.should eq 1
    asset.versions_info.present?.should eq true
    asset.content_type.should eq 'image/png'
    asset.height.should eq 1073
    asset.width.should eq 238
  end
end
