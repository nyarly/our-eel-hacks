require 'corundum'
require 'corundum/tasklibs'

module Corundum
  tk = Toolkit.new do |tk|
  end

  tk.in_namespace do
    sanity = GemspecSanity.new(tk)
    rspec = RSpec.new(tk)
    cov = SimpleCov.new(tk, rspec) do |cov|
      cov.threshold = 90
    end
    gem = GemBuilding.new(tk)
    cutter = GemCutter.new(tk,gem)
    email = Email.new(tk)
    vc = Git.new(tk) do |vc|
      vc.branch = "master"
    end
    task tk.finished_files.build => vc["is_checked_in"]
    yd = YARDoc.new(tk)

    docs = DocumentationAssembly.new(tk, yd, rspec, cov)

    pages = GithubPages.new(docs)
  end
end

task :default => [:release, :publish_docs]
