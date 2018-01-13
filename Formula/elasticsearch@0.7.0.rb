require 'formula'

class ElasticsearchAT070 < Formula
  keg_only :versioned_formula
  url 'http://github.com/downloads/elasticsearch/elasticsearch/elasticsearch-0.7.0.zip'
  homepage 'http://www.elasticsearch.com'
  md5 '6f71e1306d7fba1b1fc1c3d48641feb9'

  def install
    FileUtils.rm_f Dir["bin/*.bat"]
    prefix.install %w[bin config lib]
  end
end