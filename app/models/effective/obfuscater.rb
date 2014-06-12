require 'scatter_swap'

module Effective
  class Obfuscater
    SPIN = 75025503 # Just a random number

    def self.hide(id)
      ::ScatterSwap.hash(id, SPIN)
    end

    def self.reveal(id)
      ::ScatterSwap.reverse_hash(id, SPIN).to_i
    end
  end
end
