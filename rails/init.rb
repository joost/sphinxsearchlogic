require 'sphinxsearchlogic'
ActiveRecord::Base.extend(Sphinxsearchlogic::Search::Implementation)

if defined?(ActionController)
  require "rails_helpers"
  ActionController::Base.helper(Sphinxsearchlogic::RailsHelpers)
end