# When we click a stripe plan .panel, make it look selected, and set the radio input value
$(document).on 'click', '.panel-effective-orders-stripe-plan', (event) ->
  $plan = $(event.currentTarget)
  $plans = $plan.closest('.effective-orders-stripe-plans').find('.panel-effective-orders-stripe-plan')

  value = $plan.find('input:radio').val()

  $plans.removeClass('panel-primary')
  $plans.find('input:radio').val([value]) # Set as Array

  $plan.addClass('panel-primary')

  false

$(document).on 'change', "input[name='effective_subscription[has_coupon]']", (event) ->
  $obj = $(event.currentTarget)

  if $obj.is(':checked')
    $obj.closest('.row').find('.coupon').show()
  else
    $obj.closest('.row').find('.coupon').hide().find('input').val('')
