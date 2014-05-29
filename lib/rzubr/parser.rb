require "rzubr/grammar"

module Rzubr
  class Parser
    attr_reader :table, :errstatus, :symstack, :datstack
    attr_accessor :output, :nerror, :state

    ERRORSKIPTOKEN = 3

    def initialize(table)
      @table = table
      @output = nil
      @nerror = 0
      @errstatus = 0
      @symstack = []
      @datstack = []
      @state = :stop
    end

    def [](x)
      raise "out of context: use Parser#[](x) only in semantic actions." if @semaction_argc.nil?
      i = @datstack.size - @semaction_argc + x - 1
      return nil if i < 0 || i >= @datstack.size
      @datstack[i]
    end

    def error_ok
      @errstatus = 0
      nil
    end

    def next_token(token_type, token_value = nil)
      @token_type = token_type || ENDMARK
      @token_value = token_value || @token_type
      self
    end

    def parse(semactions)
      @output = nil
      @nerror = 0
      @errstatus = 0
      @symstack.clear.push 0
      @datstack.clear.push nil
      @semaction_argc = nil
      yield self
      while true
        x = @table.action[@symstack.last][@token_type]
        case x
        when Integer
          # shift
          @symstack.push x
          @datstack.push @token_value
          if @errstatus > 0
            @errstatus -= 1
          end
          yield self
          next
        when Production
          # reduce
          @semaction_argc = x.rhs.size
          value = if x.action.nil? then self[1] else semactions.send(x.action, self) end
          if @semaction_argc > 0
            @symstack.pop(@semaction_argc)
            @datstack.pop(@semaction_argc)
          end
          @semaction_argc = nil
          @symstack.push @table.goto[@symstack.last][x.lhs]
          @datstack.push value
          next
        when :accept
          @output = @datstack.last
          break
        end
        # error recovery based on the Yacc's yaccpar driver.
        if @errstatus == ERRORSKIPTOKEN
          if @token_type == ENDMARK
            raise "Give up error recovery due to reach end of input."
          end
          yield self
          next
        end
        if @errstatus == 0
          @nerror += 1
        end
        @errstatus = ERRORSKIPTOKEN
        # rollback stack until able to shift for terminal :error
        while not @symstack.empty?
          break if Integer === @table.action[@symstack.last][:error]
          @symstack.pop
          @datstack.pop
        end
        if @symstack.empty?
          raise "Not defined any error recovery productions in the grammar."
        end
        # shift for terminal :error
        @symstack.push @table.action[@symstack.last][:error]
        @datstack.push @token_value
      end
      self
    end
  end
end

