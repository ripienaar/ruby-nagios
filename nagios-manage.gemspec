Gem::Specification.new do |spec|
  files = []
  dirs = %w{lib bin}
  dirs.each do |dir|
    files += Dir["#{dir}/**/*"]
  end

  spec.name = "nagios-manage"
  spec.version = "0.5.1"
  spec.summary = "nagios-manage - a ruby tool for managing your nagios instance"
  spec.description = "Silence alerts, aggregate existing checks, etc."
  spec.files = files
  spec.require_paths << "lib"
  spec.bindir = "bin"
  spec.executables << "check_check.rb"
  spec.executables << "nagsrv.rb"

  spec.author = "R.I. Pienaar, Jordan Sissel"
  spec.email = "rip@devco.net, jls@semicomplete.com"
  spec.homepage = "http://code.google.com/p/ruby-nagios/"
end
