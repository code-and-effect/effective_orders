class AssetUploader < EffectiveAssetsUploader
  # resize_to_fit
  # Resize the image to fit within the specified dimensions while retaining the
  # original aspect ratio. The image may be shorter or narrower than specified in the smaller dimension
  # but will not be larger than the specified values.
  #
  # Probably best for taking a big image and making it smaller.
  # Keeps the aspect ratio
  # An uploaded image that is smaller will not be made bigger.

  # resize_to_fill
  # Resize the image to fit within the specified dimensions while retaining the
  # aspect ratio of the original image. If necessary, crop the image in the larger dimension.

  # resize_to_limit
  # http://stackoverflow.com/questions/8570181/carrierwave-resizing-images-to-fixed-width
  # Keep in mind, resize_to_fit will scale up images if they are smaller than 100px.
  # If you don't want it to do that, then replace that with resize_to_limit.

  version :thumb, :if => :image? do
    process :resize_to_fit => [70, 70]
    process :record_info => :thumb
  end

end
