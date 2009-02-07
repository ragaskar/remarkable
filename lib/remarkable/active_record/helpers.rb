module Remarkable # :nodoc:
  module ActiveRecord # :nodoc:
    module Helpers # :nodoc:
      include Remarkable::Default::Helpers
      
      def pretty_error_messages(obj) # :nodoc:
        obj.errors.map do |a, m| 
          msg = "#{a} #{m}" 
          msg << " (#{obj.send(a).inspect})" unless a.to_sym == :base
        end
      end

      def get_instance_of(object_or_klass) # :nodoc:
        if object_or_klass.is_a?(Class)
          klass = object_or_klass
          instance_variable_get("@#{instance_variable_name_for(klass)}") || klass.new
        else
          object_or_klass
        end
      end
      
      def instance_variable_name_for(klass)
        klass.to_s.split('::').last.underscore
      end

      # Asserts that an Active Record model validates with the passed
      # <tt>value</tt> by making sure the <tt>error_message_to_avoid</tt> is not
      # contained within the list of errors for that attribute.
      #
      #   assert_good_value(User.new, :email, "user@example.com")
      #   assert_good_value(User.new, :ssn, "123456789", /length/)
      #
      # If a class is passed as the first argument, a new object will be
      # instantiated before the assertion.  If an instance variable exists with
      # the same name as the class (underscored), that object will be used
      # instead.
      #
      #   assert_good_value(User, :email, "user@example.com")
      #
      #   @product = Product.new(:tangible => false)
      #   assert_good_value(Product, :price, "0")
      #
      def assert_good_value(object_or_klass, attribute, value, error_message_to_avoid = //) # :nodoc:
        object = get_instance_of(object_or_klass)
        object.send("#{attribute}=", value)

        return true if object.valid?

        error_message_to_avoid = error_message_from_model(object, attribute, error_message_to_avoid)

        assert_does_not_contain(object.errors.on(attribute), error_message_to_avoid)
      end
      
      # Asserts that an Active Record model invalidates the passed
      # <tt>value</tt> by making sure the <tt>error_message_to_expect</tt> is
      # contained within the list of errors for that attribute.
      #
      #   assert_bad_value(User.new, :email, "invalid")
      #   assert_bad_value(User.new, :ssn, "123", /length/)
      #
      # If a class is passed as the first argument, a new object will be
      # instantiated before the assertion.  If an instance variable exists with
      # the same name as the class (underscored), that object will be used
      # instead.
      #
      #   assert_bad_value(User, :email, "invalid")
      #
      #   @product = Product.new(:tangible => true)
      #   assert_bad_value(Product, :price, "0")
      #
      def assert_bad_value(object_or_klass, attribute, value, error_message_to_expect = :invalid) # :nodoc:
        object = get_instance_of(object_or_klass)
        object.send("#{attribute}=", value)
        
        return false if object.valid?
        return false unless object.errors.on(attribute)

        error_message_to_expect = error_message_from_model(object, attribute, error_message_to_expect)

        assert_contains(object.errors.on(attribute), error_message_to_expect)
      end

      # Return the error message to be checked. If the message is not a Symbol
      # neither a Hash, it returns the own message.
      #
      # But the nice thing is that when the message is a Symbol or a Hash we
      # get the error messsage from within the model, using already existent
      # structure inside ActiveRecord.
      #
      # This allows a couple things from the user side:
      #
      #   1. Specify symbols in their tests:
      #
      #     should_allow_values_for(:shirt_size, 'S', 'M', 'L', :message => :inclusion)
      #
      #   As we know, allow_values_for searches for a :invalid message. So if we
      #   were testing a validates_inclusion_of with allow_values_for, previously
      #   we had to do something like this:
      #
      #     should_allow_values_for(:shirt_size, 'S', 'M', 'L', :message => 'not included in list')
      #
      #   Now everything gets resumed to a Symbol.
      #
      #   2. Do not worry with specs if their are using I18n API properly.
      #
      #   As we know, I18n API provides several interpolation options besides
      #   fallback when creating error messages. If the user changed the message,
      #   macros would start to pass when they shouldn't.
      #
      #   Using the underlying mechanism inside ActiveRecord makes us free from
      #   all thos errors.
      #
      # When the message is hash, it means that it has some interpolations options.
      # This is used, for example in :too_short messages:
      #
      #   error_message_from_model(user, :age, :too_short => { :count => 18 })
      #
      def error_message_from_model(model, attribute, message)
        values = {}
        message, values = message.keys.first.to_sym, message.values.first if message.is_a?(Hash)

        if message.is_a? Symbol
          if Object.const_defined?(:I18n) # Rails >= 2.2
            model.errors.generate_message(attribute, message, values)
          else # Rails <= 2.1
            ::ActiveRecord::Errors.default_error_messages[message] % values[:count]
          end
        else
          message
        end
      end

    end
  end
end
