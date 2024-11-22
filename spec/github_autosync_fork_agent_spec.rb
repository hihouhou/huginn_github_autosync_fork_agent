require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::GithubAutosyncForkAgent do
  before(:each) do
    @valid_options = Agents::GithubAutosyncForkAgent.new.default_options
    @checker = Agents::GithubAutosyncForkAgent.new(:name => "GithubAutosyncForkAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
