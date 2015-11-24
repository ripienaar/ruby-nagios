require 'bundler'
Bundler::GemHelper.install_tasks

namespace :spec do
  desc 'Run production configuration test'
  task :config do
    ENV['RSPEC_ENV'] = 'production'
    sh %(rspec -f d --color --fail-fast spec/00_configuration_spec.rb)
  end

  namespace :test do
    desc 'Run configuration test in `test` environment'
    task :config do
      ENV['RSPEC_ENV'] = 'test'
      sh %(rspec -f d --color spec/00_configuration_spec.rb)
    end
  end
end
