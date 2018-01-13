require 'formula'

class ElasticsearchAT0110 < Formula
  keg_only :versioned_formula
  url 'https://github.com/downloads/elasticsearch/elasticsearch/elasticsearch-0.11.0.zip'
  homepage 'http://www.elasticsearch.com'
  md5 'ef19e6fc7bad8f76e4371a94de7e0da7'

  def install
    rm_f Dir["bin/*.bat"]
    prefix.install %w[bin config lib]
  end
end