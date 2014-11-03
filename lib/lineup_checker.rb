require_relative 'history.rb'
require_relative 'z3.rb'

module LineUpChecker

  def check(history)
    history.each_linearization do |seq|

      # TODO ask Z3 :-)

    end
  end

end