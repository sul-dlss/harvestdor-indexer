# Harvestdor::Indexer
[![Build Status](https://travis-ci.org/sul-dlss/harvestdor-indexer.png?branch=master)](https://travis-ci.org/sul-dlss/harvestdor-indexer) | [![Code Climate Test Coverage](https://codeclimate.com/github/sul-dlss/harvestdor-indexer/badges/coverage.svg)](https://codeclimate.com/github/sul-dlss/harvestdor-indexer/coverage) | [![Gem Version](https://badge.fury.io/rb/blacklight-harvestdor-indexer.png)](http://badge.fury.io/rb/blacklight-harvestdor-indexer) 

A Gem to harvest meta/data from DOR and the skeleton code to index it and write to Solr.

## Installation

Add this line to your application's Gemfile:

    gem 'harvestdor-indexer'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install harvestdor-indexer

## Usage

You must override the index method and provide configuration options.  It is recommended to write a script to run it, too - example below.

### Configuration / Set up

Create a yml config file for your collection going to a Solr index.

See  spec/config/ap.yml for an example.
You will want to copy that file and change the following settings:

* whitelist
* dor fetcher service_url
* solr url
* harvestdor log_dir, log_nam


#### Whitelist

The whitelist is how you specify which objects to index.  The whitelist can be

* an Array of druids inline in the config yml file
* a filename containing a list of druids (one per line)

If a druid, per the object's identityMetadata at purl page, is for a

* collection record:  then we process all the item druids in that collection (as if they were included individually in the whitelist)
* non-collection record: then we process the druid as an individual item

### Override the Harvestdor::Indexer.index method

In your code, override this method from the Harvestdor::Indexer class

    # create Solr doc for the druid and add it to Solr
    #  NOTE: don't forget to send commit to Solr, either once at end (already in harvest_and_index), or for each add, or ...
    def index resource

      benchmark "Indexing #{resource.druid}" do
        logger.debug "About to index #{resource.druid}"
        doc_hash = {}
        doc_hash[:id] = resource.druid

        # you might add things from Indexer level class here
        #  (e.g. things that are the same across all documents in the harvest)
        solr.add doc_hash
        # TODO: provide call to code to update DOR object's workflow datastream??
      end
    end


### Run it

(bundle install)

You may want to write a script to run the code.  Your script might look like this:

  #!/usr/bin/env ruby
  $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))
  $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
  require 'rubygems'
    begin
      require 'your_indexer'
    rescue LoadError
      require 'bundler/setup'
      require 'your_indexer'
    end
  config_yml_path = ARGV.pop
  if config_yml_path.nil?
    puts "** You must provide the full path to a collection config yml file **"
    exit
  end
  indexer = Harvestdor::Indexer.new(config_yml_path, opts)
  indexer.harvest_and_index

Then you run the script like so:

	 $ ./bin/indexer config/(your coll).yml

Run from deployed instance, as that box is already set up to be able to talk to DOR Fetcher service and to SUL Solr indexes.

## Contributing

* Fork it (https://help.github.com/articles/fork-a-repo/)
* Create your feature branch (`git checkout -b my-new-feature`)
* Write code and tests.
* Commit your changes (`git commit -am 'Added some feature'`)
* Push to the branch (`git push origin my-new-feature`)
* Create new Pull Request (https://help.github.com/articles/creating-a-pull-request/)
