spec = Gem::Specification.new do |s|
  s.name = 'ruby-nagios'
  s.version = "0.0.1"
  s.author = 'R.I.Pienaar'
  s.email = 'rip@devco.net'
  s.homepage = 'http://devco.net/'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Ruby library for managing Nagios'
  s.description = "Manage alerts, checks and acks in bulk"
  s.files         = `git ls-files`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']
  s.has_rdoc = false
  s.add_development_dependency('rake')
end
