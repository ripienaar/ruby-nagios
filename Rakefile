task :default => [:package]

task :package do
  system("gem build nagios-manage.gemspec")
end

task :publish do
  latest_gem = %x{ls -t nagios-manage-*.gem}.split("\n").first
  system("gem push #{latest_gem}")
end

