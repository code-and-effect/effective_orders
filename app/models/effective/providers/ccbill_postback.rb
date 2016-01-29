# https://www.ccbill.com/cs/wiki/tiki-index.php?page=Background+Post
class Effective::Providers::CcbillPostback
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def verified?
    params[:responseDigest] == digest(digest_value)
  end

  def matches?(order)
    price == order.total && order_id == order.to_param
  end

  def approval?
    !denial?
  end

  def denial?
    # denialId is for subscriptions only
    [:reasonForDeclineCode, :reasonForDecline, :denialId].any? {|key| params[key].present?}
  end

  def order_details
    @order_details ||= get_order_details
  end

  def order_id
    params[:order_id]
  end

  private

  # https://www.ccbill.com/cs/wiki/tiki-index.php?page=Dynamic+Pricing+User+Guide#Postback
  def digest_value
    if approval?
      "#{params[:subscription_id]}1#{salt}" # the `subscriptionId` param in the linked docs is a typo
    else
      "#{params[:denialId]}0#{salt}"
    end
  end

  def digest(value)
    Digest::MD5.hexdigest(value)
  end

  def salt
    EffectiveOrders.ccbill[:dynamic_pricing_salt]
  end

  # in cents
  def price
    return @price if @price.present?
    formatted_price = params[:initialFormattedPrice] # example: "&#36;10.00"
    formatted_price = Nokogiri::HTML::DocumentFragment.parse(formatted_price).to_s # => "$10.00"
    match = formatted_price.match(/^\D(\d*.\d\d)$/) # {a currency symbol}(digits.two digits)
    return false unless match.present?
    formatted_price = match[1] # => "10.00"
    @price = formatted_price.sub('.', '').to_i # => 1000
  end

  def get_order_details
    # ignore some params
    keepable = params.except(*ignorable_params)
    # remove blanks
    keepable.inject({}) do |details, kv_pair|
      details[kv_pair[0]] = kv_pair[1] if kv_pair[1].present?
      details
    end
  end

  def ignorable_params
    [
      # we have these already
      :clientAccnum,
      :clientSubacc,
      :productDesc,
      # a hash of billing information which CCBill doesn't share the format of (afaik)
      :paymentAccount
    ]
  end
end

