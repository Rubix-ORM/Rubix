module Rubix
  module Testing
    class TestCase
      attr_reader :assertions, :failures, :errors

      def initialize(test_method = nil)
        @test_method = test_method
        @assertions = 0
        @failures = []
        @errors = []
        @passed = true
      end

      def run
        begin
          send(@test_method) if @test_method
        rescue => e
          @errors << e
          @passed = false
        end
        self
      end

      def passed?
        @passed && @failures.empty? && @errors.empty?
      end

      def assert(test, message = "Failed assertion")
        @assertions += 1
        unless test
          @failures << StandardError.new(message)
          @passed = false
        end
        test
      end

      def assert_equal(expected, actual, message = nil)
        message ||= "Expected #{expected.inspect}, but got #{actual.inspect}"
        assert(expected == actual, message)
      end

      def assert_nil(object, message = nil)
        message ||= "Expected #{object.inspect} to be nil"
        assert(object.nil?, message)
      end

      def assert_not_nil(object, message = nil)
        message ||= "Expected #{object.inspect} to not be nil"
        assert(!object.nil?, message)
      end
    end

    class TestSuite
      attr_reader :tests, :results

      def initialize
        @tests = []
        @results = { passed: 0, failed: 0, errors: 0 }
      end

      def add_test(test_class, test_method = nil)
        if test_method
          @tests << test_class.new(test_method)
        else
          test_class.instance_methods.grep(/^test_/).each do |method|
            @tests << test_class.new(method)
          end
        end
      end

      def run
        puts "Running test suite with #{@tests.size} tests..."

        @tests.each do |test|
          begin
            result = test.run
            if result.passed?
              @results[:passed] += 1
              print '.'
            elsif !result.failures.empty?
              @results[:failed] += 1
              print 'F'
            elsif !result.errors.empty?
              @results[:errors] += 1
              print 'E'
            end
          rescue => e
            @results[:errors] += 1
            print 'E'
          end
        end

        puts "\n\nTest Results:"
        puts "Passed: #{@results[:passed]}"
        puts "Failed: #{@results[:failed]}"
        puts "Errors: #{@results[:errors]}"

        @results
      end

      def run_test_directory(dir_path)
        Dir.glob(File.join(dir_path, '**/*_test.rb')).each do |file|
          load file
          test_class = File.basename(file, '.rb').camelize.constantize
          add_test(test_class)
          run
        end
      end
    end
  end
end
