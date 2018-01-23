require 'git'

def repo_path(path)
  File.expand_path(path, __dir__)
end

class String
  def to_camel_case
    split('_').collect(&:capitalize).join
  end
end

class VersionMatcher
  def initialize(version_regex, version_regex_group_number = 1)
    @version_regex = version_regex
    @version_regex_group_number = version_regex_group_number
  end

  def extract_version(contents)
    match = @version_regex.match(contents)
    match[@version_regex_group_number] if match
  end
end

class FormulaEnumerator
  def initialize(formula_name, version_matcher)
    @formula_name = formula_name
    @version_matcher = version_matcher
  end

  # calls `block' on each version of the formula found, and the latest formula for it
  # hence `block' should expect 2 arguments: the formula version and the contents of
  # the latest formula for it, both as strings
  def each(&block)
    formula_path = "Formula/#{@formula_name}.rb"
    previous_version = nil

    repo.log(nil).path(formula_path).each do |commit|
      contents = repo.show(commit.sha, formula_path)

      version = @version_matcher.extract_version(contents)
      fail "Could not extract version for formula #{@formula_name} from commit #{commit.sha}" unless version

      if version != previous_version
        previous_version = version
        yield(version, contents)
      end
    end
  end

private

  HOMEBREW_CORE_REPO_PATH = repo_path('vendor/homebrew-core').freeze

  def repo
    @_repo ||= Git.open(HOMEBREW_CORE_REPO_PATH)
  end
end

class Updater
  def initialize(formula_name, version_matcher)
    @formula_name = formula_name
    @version_matcher = version_matcher
  end

  def run
    is_latest_version = true
    formulae_directory = repo_path('Formula')

    FormulaEnumerator.new(@formula_name, @version_matcher).each do |version, contents|
      # the latest version might change in a future update of the core repo
      # and no need to create a formula for it anyway
      if is_latest_version
        is_latest_version = false
      elsif keep_version?(version)
        formula_path = File.join(formulae_directory, "#{@formula_name}@#{version}.rb")
        new_contents = amend_formula(contents, version)

        fail "Could not amend formula for version #{version}" if contents == new_contents

        File.write(formula_path, new_contents)
      end
    end
  end

protected

  def keep_version?(version)
    true
  end

  def amend_formula(contents, version)
    new_class_name = "#{@formula_name.to_camel_case}AT#{version.gsub('.', '')}"
    new_class_beginning = "class #{new_class_name} < Formula\n  keg_only :versioned_formula\n"

    contents.sub("class #{@formula_name.to_camel_case} < Formula\n", new_class_beginning)
  end
end

class ElasticsearchUpdater < Updater
  def initialize
    super('elasticsearch', VersionMatcher.new(VERSION_REGEX, 2))
  end

protected

  VERSION_REGEX = /\n\s+url\s+(['"])https?:\/\/[0-9a-zA-Z\$\-_.+!*'()\/]+elasticsearch-((?:[0-9]+\.){2}[0-9]+)[a-z\.]+\1\s*\n/.freeze

  # versions prior to 1.5.2 use sha1 signatures, which are now deprecated
  MINIMUM_VERSION = '1.5.2'.freeze

  def keep_version?(version)
    p "wkpo #{version}"
    Gem::Version.new(version) >= Gem::Version.new(MINIMUM_VERSION)
  end
end

[ElasticsearchUpdater].each { |klass| klass.new.run }
