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
  def initialize(formula_name, *version_matchers)
    @formula_name = formula_name
    @version_matchers = version_matchers
  end

  # calls `block' on each version of the formula found, and the latest formula for it
  # hence `block' should expect 2 arguments: the formula version and the contents of
  # the latest formula for it, both as strings
  def each(&block)
    formula_path = "Formula/#{@formula_name}.rb"
    previous_version = nil

    repo.log(nil).path(formula_path).each do |commit|
      contents = repo.show(commit.sha, formula_path)

      version = extract_version(contents, commit)

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

  def extract_version(contents, commit)
    @version_matchers.each do |version_matcher|
      version = version_matcher.extract_version(contents)
      return version if version
    end

    fail "Could not extract version for formula #{@formula_name} from commit #{commit.sha}"
  end
end

class Updater
  def initialize(formula_name)
    @formula_name = formula_name
  end

  def run
    is_latest_version = true
    formulae_directory = repo_path('Formula')

    FormulaEnumerator.new(@formula_name, *version_matchers).each do |version, contents|
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

  URL_PREFIX_REGEX = %(https?:\/\/)
  URL_CHARS_REGEX = %([0-9a-zA-Z\\$\\-_.+!*'()\/]+)
  VERSION_REGEX = '((?:[0-9]+\.){2}[0-9]+)'

  def version_matchers
    default_version_regex = /\n\s+url\s+(['"])#{URL_PREFIX_REGEX}#{URL_CHARS_REGEX}#{Regexp.escape(@formula_name)}#{URL_CHARS_REGEX}#{VERSION_REGEX}[a-z\.]+\1\s*\n/
    [VersionMatcher.new(default_version_regex, 2)]
  end

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
    super('elasticsearch')
  end

protected

  # versions prior to 1.5.2 use sha1 signatures, which are now deprecated
  MINIMUM_VERSION = '1.5.2'.freeze

  def keep_version?(version)
    Gem::Version.new(version) >= Gem::Version.new(MINIMUM_VERSION)
  end
end

class KibanaUpdater < Updater
  def initialize
    super('kibana')
  end

protected

  def version_matchers
    super << tag_version_matcher
  end

private

  # matches
  # url "https://github.com/elastic/kibana.git", :tag => "v4.3.1", :revision => "d6e412dc2fa54666bf6ceb54a197508a4bc70baf"
  # AND
  # url "https://github.com/elastic/kibana.git",
  #     :tag => "v5.6.5",
  #     :revision => "80f98787eb860a4e7ef9b6500cf84b65e331d1fc"
  # AND
  # url "https://github.com/elastic/kibana.git",
  #   tag: "v4.5.1",
  #   revision: "addb28966a74b61791ceda352cd5b8b1200f2b2a"
  def tag_version_matcher
    tag_version_regex = /\n\s+url\s+(['"])#{URL_PREFIX_REGEX}#{URL_CHARS_REGEX}kibana#{URL_CHARS_REGEX}+\1,[\s\n]*(?::tag =>|tag:)\s*(['"])v#{VERSION_REGEX}\2,[\n ]/
    VersionMatcher.new(tag_version_regex, 3)
  end
end

[ElasticsearchUpdater, KibanaUpdater].each { |klass| klass.new.run }
