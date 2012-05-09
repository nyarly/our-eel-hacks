Gem::Specification.new do |spec|
  spec.name		= "our-eel-hacks"
  spec.version		= "0.0.9"
  author_list = {
    "Judson Lester" => "nyarly@gmail.com"
  }
  spec.authors		= author_list.keys
  spec.email		= spec.authors.map {|name| author_list[name]}
  spec.summary		= "Heroku autoscaling"
  spec.description	= <<-EndDescription
  Middleware for Rack and Sidekiq to scale heroku.

  A heroku process knows everything it needs in order to scale itself.  A little configuration, and you're set.
  EndDescription

  spec.rubyforge_project= spec.name.downcase
  spec.homepage        = "http://nyarly.github.com/our-eel-hacks"
  spec.required_rubygems_version = Gem::Requirement.new(">= 0") if spec.respond_to? :required_rubygems_version=

  # Do this: y$@"
  # !!find lib bin doc spec spec_help -not -regex '.*\.sw.' -type f 2>/dev/null
  spec.files		= %w[
    lib/our-eel-hacks/autoscaler.rb
    lib/our-eel-hacks/rack.rb
    lib/our-eel-hacks/defer/event-machine.rb
    lib/our-eel-hacks/defer/celluloid.rb
    lib/our-eel-hacks/sidekiq.rb
    lib/our-eel-hacks/middleware.rb
    spec/autoscaler.rb
    spec/rack.rb
    spec_help/spec_helper.rb
    spec_help/gem_test_suite.rb
    spec_help/cassettes/OurEelHacks_Rack.yml
    spec_help/cassettes/OurEelHacks_Autoscaler.yml
    spec_help/file-sandbox.rb
  ]

  spec.test_file        = "spec_help/gem_test_suite.rb"
  spec.licenses = ["MIT"]
  spec.require_paths = %w[lib/]
  spec.rubygems_version = "1.3.5"

  if spec.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    spec.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      spec.add_development_dependency "corundum", "~> 0.0.1"
    else
      spec.add_development_dependency "corundum", "~> 0.0.1"
    end
  else
    spec.add_development_dependency "corundum", "~> 0.0.1"
  end

  spec.has_rdoc		= true
  spec.extra_rdoc_files = Dir.glob("doc/**/*")
  spec.rdoc_options	= %w{--inline-source }
  spec.rdoc_options	+= %w{--main doc/README }
  spec.rdoc_options	+= ["--title", "#{spec.name}-#{spec.version} RDoc"]

  spec.add_dependency("heroku", "> 0")

  spec.post_install_message = "Another tidy package brought to you by Judson"
end
