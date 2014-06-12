require 'spec_helper'

# # Attributes
describe Effective::Obfuscater do
  it 'can obfuscate and then unobfuscate an ID' do
    hidden = Effective::Obfuscater.hide(123)
    hidden.should_not eq 123

    Effective::Obfuscater.reveal(hidden).should eq 123
  end

end
