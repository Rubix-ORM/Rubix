# run_tests.rb
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require 'rubix'
require 'rubix/testing' # Assuming this path based on docs

# Initialize the test suite
suite = Rubix::Testing::TestSuite.new

# Option A: Run all tests in the 'test' directory
suite.run_test_directory('test')
