# Homebrew ElasticSearch legacy

Because it's nice to be able to quickly install any version of ElasticSearch, and not the just last two or three major versions at their latest minor revision that are part of [Homebrew Core](https://github.com/Homebrew/homebrew-core).

Just run `brew install wk8/elasticsearch-legacy/elasticsearch@5.5.1`, or any version you want from the [available ones](https://github.com/wk8/homebrew-elasticsearch-legacy/tree/master/Formula).

This repo also includes legacy versions of Kibana's formulae, so you can just `brew install wk8/elasticsearch-legacy/kibana@5.5.1` too.

If there were new versions added to [Homebrew Core](https://github.com/Homebrew/homebrew-core) and you wish to update this repository, simply clone it, run `make`, and create a pull request with the commit that created.
