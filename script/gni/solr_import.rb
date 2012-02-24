#!/usr/bin/env ruby

ENV["RAILS_ENV"] ||= 'production'
require File.expand_path("../../../config/environment", __FILE__)

[Gni::SolrCoreCanonicalForm.new, Gni::SolrCoreNameStringIndex.new].each do |core|
  si = Gni::SolrIngest.new(core)
  si.delete_all
  si.ingest
end
