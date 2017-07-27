# Add .panel-primary to the selected stripe_plan_id panels
$(document).on 'change', "input[name$='[subscripter][stripe_plan_id]']", (event) ->
  $plans = $(event.currentTarget).closest('.effective-orders-stripe-plans')

  $plans.find("input[name$='[subscripter][stripe_plan_id]']").each ->
    if $(this).is(':checked')
      $(this).siblings('.panel').addClass('panel-primary selected')
    else
      $(this).siblings('.panel').removeClass('panel-primary selected')

$(document).on 'click', '.effective-orders-stripe-plan .btn-select', (event) ->
  val = $(event.currentTarget).closest('.effective-orders-stripe-plan').find('input:radio').val()
  $(event.currentTarget).closest('.effective-orders-stripe-plans').find('input:radio').val([val]).trigger('change')
  false
