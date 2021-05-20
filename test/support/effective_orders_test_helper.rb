module EffectiveOrdersTestHelper

  def sign_in(user = create_user!)
    login_as(user, scope: :user); user
  end

  def as_user(user, &block)
    sign_in(user); yield; logout(:user)
  end

  def assert_email(count: 1, &block)
    before = ActionMailer::Base.deliveries.length
    yield
    after = ActionMailer::Base.deliveries.length

    assert (after - before == count), "expected one email to have been delivered"
  end

end
