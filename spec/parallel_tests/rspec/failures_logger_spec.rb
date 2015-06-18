require 'spec_helper'

describe ParallelTests::RSpec::FailuresLogger do
  def silence_warnings
    old_verbose, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = old_verbose
  end

  before do
    @output     = OutputLogger.new([])
    @example1   = double( 'example', :location => "#{Dir.pwd}/spec/path/to/example:123", :full_description => 'should do stuff', :description => 'd' )
    @example2   = double( 'example', :location => "#{Dir.pwd}/spec/path/to/example2:456", :full_description => 'should do other stuff', :description => 'd')
    @exception1 = double( :to_s => 'exception', :backtrace => [ '/path/to/error/line:33' ] )
    @failure1   = double( 'example', :location => "#{Dir.pwd}/example:123", :header => 'header', :exception => @exception1 )
    @logger = ParallelTests::RSpec::FailuresLogger.new(@output)
  end

  after do
    silence_warnings{ ParallelTests::RSpec::LoggerBase::RSPEC_1 = false }
  end

  def clean_output
    @output.output.join("\n").gsub(/\e\[\d+m/,'')
  end

  it "should produce a list of command lines for failing examples" do
    @logger.example_failed @example1
    @logger.example_failed @example2

    @logger.dump_failures
    @logger.dump_summary(1,2,3,4)

    expect(clean_output).to match(/^rspec .*? should do stuff/)
    expect(clean_output).to match(/^rspec .*? should do other stuff/)
  end

  it "should invoke spec for rspec 1" do
    silence_warnings{ ParallelTests::RSpec::LoggerBase::RSPEC_1 = true }
    allow(ParallelTests).to receive(:bundler_enabled?).and_return true
    allow(ParallelTests::RSpec::Runner).to receive(:run).with("bundle show rspec-core").and_return "Could not find gem 'rspec-core'."
    @logger.example_failed @example1

    @logger.dump_failures
    @logger.dump_summary(1,2,3,4)

    expect(clean_output).to match(/^bundle exec spec/)
  end

  it "should invoke rspec for rspec 2" do
    allow(ParallelTests).to receive(:bundler_enabled?).and_return true
    allow(ParallelTests::RSpec::Runner).to receive(:run).with("bundle show rspec").and_return "/foo/bar/rspec-core-2.0.2"
    @logger.example_failed @example1

    @logger.dump_failures
    @logger.dump_summary(1,2,3,4)

    expect(clean_output).to match(/^rspec/)
  end

  it "should return relative paths" do
    @logger.example_failed @example1
    @logger.example_failed @example2

    @logger.dump_failures
    @logger.dump_summary(1,2,3,4)

    expect(clean_output).to match(%r(\./spec/path/to/example:123))
    expect(clean_output).to match(%r(\./spec/path/to/example2:456))
  end


  # should not longer be a problem since its using native rspec methods
  xit "should not log examples without location" do
    example = double('example', :location => 'bla', :full_description => 'before :all')
    @logger.example_failed example
    @logger.dump_failures
    @logger.dump_summary(1,2,3,4)
    expect(clean_output).to eq('')
  end
end
