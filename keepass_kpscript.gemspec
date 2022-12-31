require "#{__dir__}/lib/keepass_kpscript/version"

Gem::Specification.new do |s|
  s.name = 'keepass_kpscript'
  s.version = KeepassKpscript::VERSION
  s.authors = ['Muriel Salvan']
  s.email = ['muriel@x-aeon.com']
  s.license = 'BSD-3-Clause'
  s.summary = 'Keepass KPScript'
  s.description = 'Ruby API to handle Keepass databases using KPScript'
  s.required_ruby_version = '~> 3.1'
  s.metadata['rubygems_mfa_required'] = 'true'

  s.files = Dir['*.md'] + Dir['{bin,docs,examples,lib,spec,tools}/**/*']
  s.executables = Dir['bin/**/*'].map { |exec_name| File.basename(exec_name) }
  s.extra_rdoc_files = Dir['*.md'] + Dir['{docs,examples}/**/*']

  # Dependencies
  # To handle the passwords and keyfiles securely
  s.add_runtime_dependency 'secret_string', '~> 1.1'

  # Test framework
  s.add_development_dependency 'rspec', '~> 3.12'
  # Automatic semantic releasing
  s.add_development_dependency 'sem_ver_components', '~> 0.3'
  # Lint checker
  s.add_development_dependency 'rubocop', '~> 1.41'
  # Lint checker for rspec
  s.add_development_dependency 'rubocop-rspec', '~> 2.16'
end
