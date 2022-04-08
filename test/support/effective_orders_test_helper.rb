module EffectiveOrdersTestHelper

  def sign_in(user = create_user!)
    login_as(user, scope: :user); user
  end

  def as_user(user, &block)
    sign_in(user); yield; logout(:user)
  end

  # assert_email :new_user_sign_up
  # assert_email :new_user_sign_up, to: 'newuser@example.com'
  # assert_email from: 'admin@example.com'
  def assert_email(action = nil, to: nil, from: nil, subject: nil, body: nil, message: nil, count: nil, &block)
    retval = nil

    if block_given?
      before = ActionMailer::Base.deliveries.length
      retval = yield

      difference = (ActionMailer::Base.deliveries.length - before)

      if count.present?
        assert (difference == count), "(assert_email) Expected #{count} email to have been delivered, but #{difference} were instead"
      else
        assert (difference > 0), "(assert_email) Expected at least one email to have been delivered"
      end
    end

    if (action || to || from || subject || body).nil?
      assert ActionMailer::Base.deliveries.present?, message || "(assert_email) Expected email to have been delivered"
      return retval
    end

    actions = ActionMailer::Base.instance_variable_get(:@mailer_actions)

    ActionMailer::Base.deliveries.each do |message|
      matches = true

      matches &&= (actions.include?(action.to_s)) if action
      matches &&= (Array(message.to).include?(to)) if to
      matches &&= (Array(message.from).include?(from)) if from
      matches &&= (message.subject == subject) if subject
      matches &&= (message.body == body) if body

      return retval if matches
    end

    expected = [
      ("action: #{action}" if action),
      ("to: #{to}" if to),
      ("from: {from}" if from),
      ("subject: #{subject}" if subject),
      ("body: #{body}" if body),
    ].compact.to_sentence

    assert false, message || "(assert_email) Expected email with #{expected} to have been delivered"
  end

end
