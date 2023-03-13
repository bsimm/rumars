# frozen_string_literal: true

require_relative 'lib/rumars/version'

Gem::Specification.new do |spec|
  spec.name = 'rumars'
  spec.version = RuMARS::VERSION
  spec.authors = ['Chris Schlaeger']
  spec.email = ['chris@linux.com']

  spec.summary = 'Ruby Memory Array Redcode Simulator '
  spec.description = 'Simulator for REDCODE programs (Core Wars)'
  spec.homepage = 'https://github.com/scrapper/rumars'
  spec.required_ruby_version = '>= 2.6.0'

#  spec.metadata['allowed_push_host'] = 'TODO: Set to your gem server 'https://example.com''

  spec.metadata['homepage_uri'] = spec.homepage
#  spec.metadata['source_code_uri'] = 'TODO: Put your gem's public repo URL here.'
#  spec.metadata['changelog_uri'] = 'TODO: Put your gem's CHANGELOG.md URL here.'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency 'example-gem', '~> 1.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
