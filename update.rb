require 'git'

def repo_path(path)
  File.expand_path(path, __dir__)
end

class FormulaEnumerator
  # calls `block' on each version of ES found, and the latest formula for it
  # hence `block' should expect 2 arguments: the ES version and the contents of
  # the latest formula for it, both as strings
  def each(&block)
    previous_version = nil

    repo.log(nil).path(ELASTICSEARCH_FORMULA_PATH).each do |commit|
      contents = repo.show(commit.sha, ELASTICSEARCH_FORMULA_PATH)

      version = extract_version(contents)
      fail "Could not extract version from commit #{commit.sha}" unless version

      if version != previous_version
        previous_version = version
        yield(version, contents)
      end
    end
  end

private

  HOMEBREW_CORE_REPO_PATH = repo_path('vendor/homebrew-core').freeze
  ELASTICSEARCH_FORMULA_PATH = 'Formula/elasticsearch.rb'.freeze
  VERSION_LINE_REGEX = /\n\s+url\s+(['"])https?:\/\/[0-9a-zA-Z\$\-_.+!*'()\/]+elasticsearch-((?:[0-9]+\.){3})[a-z\.]+\1\s*\n/.freeze

  def repo
    @_repo ||= Git.open(HOMEBREW_CORE_REPO_PATH)
  end

  def extract_version(contents)
    match = VERSION_LINE_REGEX.match(contents)
    match[2][0..-2] if match
  end
end

class Updater
  def run
    is_latest_version = true
    formulae_directory = repo_path('Formula')

    FormulaEnumerator.new.each do |version, contents|
      # the latest version might change in a future update of the core repo
      # and no need to create a formula for it anyway
      if is_latest_version
        is_latest_version = false
      elsif keep_version?(version)
        formula_path = File.join(formulae_directory, "elasticsearch@#{version}.rb")
        File.write(formula_path, amend_formula(contents, version))
      end
    end
  end

private

  # need to update the class name, and make it a versioned formula
  def amend_formula(contents, version)
    new_class_name = "ElasticsearchAT#{version.gsub('.', '')}"
    new_class_beginning = "class #{new_class_name} < Formula\n  keg_only :versioned_formula\n"

    contents.sub("class Elasticsearch < Formula\n", new_class_beginning).tap do |new_formula|
      fail "Could not amend formula for version #{version}" if contents == new_formula
    end
  end

  # versions prior to 1.5.2 use sha1 signatures, which are now deprecated
  MINIMUM_VERSION = '1.5.2'.freeze

  def keep_version?(version)
    Gem::Version.new(version) >= Gem::Version.new(MINIMUM_VERSION)
  end
end

Updater.new.run
