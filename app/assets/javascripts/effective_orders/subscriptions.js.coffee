# Add selected_class to each plans content
$(document).on 'change', "input[name$='[subscripter][stripe_plan_id]']", (event) ->
  $plans = $(event.currentTarget).closest('.effective-orders-stripe-plans')

  selected_class = $plans.data('selected-class')

  $plans.find("input[name$='[subscripter][stripe_plan_id]']").each (_, item) =>
    if $(item).is(':checked')
      $(item).siblings('.panel').addClass(selected_class)
    else
      $(item).siblings('.panel').removeClass(selected_class)

# When the 'Select' button is clicked, set the radio button input
$(document).on 'click', '.effective-orders-stripe-plan .btn-select-plan', (event) ->
  val = $(event.currentTarget).closest('.effective-orders-stripe-plan').find('input:radio').val()
  $(event.currentTarget).closest('.effective-orders-stripe-plans').find('input:radio').val([val]).trigger('change')
  false
