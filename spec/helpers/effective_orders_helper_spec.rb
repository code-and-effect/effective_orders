require 'spec_helper'

describe EffectiveOrdersHelper, :type => :helper do
  describe '#price_to_currency' do
    it 'converts an integer number of cents to a currency formatted string' do
      price_to_currency(1050).should eq '$10.50'
      price_to_currency(10050).should eq '$100.50'
      price_to_currency(1).should eq '$0.01'
      price_to_currency(99).should eq '$0.99'
      price_to_currency(0).should eq '$0.00'
    end

    it 'raises an error when passed a decimal' do
      expect { price_to_currency(10.00) }.to raise_exception(Exception)
    end

    it 'raises an error when passed nil' do
      expect { price_to_currency(nil) }.to raise_exception(Exception)
    end
  end
end
