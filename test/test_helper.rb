require 'rubygems'
require 'active_support'
require 'active_support/test_case'

# Create some test db stuff..
require 'activerecord'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")
ActiveRecord::Base.configurations = true

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define(:version => 1) do
  create_table :books do |t|
    t.string :title
    t.string :description
    t.integer :production_year
    t.timestamps
  end
end
