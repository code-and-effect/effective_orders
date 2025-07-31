module EffectiveHelcimHelper
  def helcim_initialize_request(order)
    Effective::HelcimApi.new.initialize_request(order)
  end

end
