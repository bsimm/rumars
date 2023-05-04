# frozen_string_literal: true

require 'tmpdir'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def tmp_dir_name(caller_file)
  dir_name = nil

  loop do
    dir_name = File.join(Dir.tmpdir,
                         "#{File.basename(caller_file)}.#{rand(2**32)}")
    break unless File.exist?(dir_name)
  end

  dir_name
end

def create_working_dirs
  @work_dir = tmp_dir_name(__FILE__)
  Dir.mkdir(@work_dir)
  @fit_dir = File.join(@work_dir, 'fit')
  Dir.mkdir(@fit_dir)
  @html_dir = File.join(@work_dir, 'html')
  Dir.mkdir(@html_dir)
end

def cleanup
  FileUtils.rm_rf(@work_dir)
end
