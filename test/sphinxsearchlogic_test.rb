require 'test_helper'

# Define classes to test on..
class Book < ActiveRecord::Base

  establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

  define_index do
    indexes title, :sortable => true
    indexes description
    has :production_year
  end

  sphinx_scope(:millenium) do
    {:with => {:production_year => 2000..9999}}
  end

end

class SphinxsearchlogicTest < ActiveSupport::TestCase

  def setup
  end

# General

  test 'book model should have sphinx index' do
    assert Book.sphinxsearchlogic.send(:has_sphinx_index?)
  end

# Attribute Filters

  test 'valid with params' do
    search = Book.sphinxsearchlogic(:with_production_year => '2006')
    assert_equal({:production_year => '2006'}, search.with)
  end

  test 'invalid with params' do
    assert_raise Sphinxsearchlogic::Search::UnknownConditionError do
      search = Book.sphinxsearchlogic(:with_non_existing_stuff => '2006')
    end
  end

  test 'valid without params' do
    search = Book.sphinxsearchlogic(:without_production_year => '2006')
    assert_equal({:production_year => '2006'}, search.without)
  end

  test 'invalid without params' do
    assert_raise Sphinxsearchlogic::Search::UnknownConditionError do
      search = Book.sphinxsearchlogic(:without_non_existing_stuff => '2006')
    end
  end

# Regular field and scope searches

  test 'empty search' do
    search = Book.sphinxsearchlogic()
    assert_equal({}, search.search_options)
  end

  test 'search on all' do
    search = Book.sphinxsearchlogic(:all => 'test')
    assert_equal('test', search.all)
  end

  test 'search on field' do
    search = Book.sphinxsearchlogic(:title => 'test')
    assert_equal('test', search.title)
    assert_equal({:conditions => {:title => 'test'}}, search.search_options)
  end

  test 'scope search' do
    search = Book.sphinxsearchlogic(:millenium => true)
    assert_equal(true, search.millenium)
  end

# Ordering

  test 'invalid ordering by non existing scope' do
    search = Book.sphinxsearchlogic(:order => 'non_existing_scope')
    assert_equal({}, search.ordering_options)
  end

  test 'invalid ordering by non sortable field' do
    search = Book.sphinxsearchlogic(:order => 'ascend_by_description')
    assert_equal({}, search.ordering_options)
  end

  test 'ascend ordering by sortable field' do
    search = Book.sphinxsearchlogic(:order => 'ascend_by_title')
    assert_equal({:order => :title, :sort_mode => :asc}, search.ordering_options)
  end

  test 'descend ordering by sortable field' do
    search = Book.sphinxsearchlogic(:order => 'descend_by_title')
    assert_equal({:order => :title, :sort_mode => :desc}, search.ordering_options)
  end

  test 'ascend ordering by attribute' do
    search = Book.sphinxsearchlogic(:order => 'ascend_by_production_year')
    assert_equal({:order => :production_year, :sort_mode => :asc}, search.ordering_options)
  end

  test 'descend ordering by @relevance' do
    search = Book.sphinxsearchlogic(:order => 'descend_by_relevance')
    assert_equal({:order => '@relevance desc'}, search.ordering_options)
  end

# Pagination

  test 'pagination' do
    search = Book.sphinxsearchlogic(:per_page => '123', :page => '12')
    assert_equal(12, search.page)
    assert_equal(123, search.per_page)
    # We also check if the search_options are correctly set..
    assert_equal(12, search.search_options[:page])
    assert_equal(123, search.search_options[:per_page])
  end

  test 'invalid pagination' do
    search = Book.sphinxsearchlogic(:per_page => 'asdasd', :page => 'as')
    assert_equal(1, search.page)
    assert_equal(10, search.per_page)

    search = Book.sphinxsearchlogic(:per_page => '0', :page => '0')
    assert_equal(1, search.page)
    assert_equal(10, search.per_page)

    search = Book.sphinxsearchlogic(:per_page => '-123', :page => '-12')
    assert_equal(1, search.page)
    assert_equal(10, search.per_page)
  end

  test 'no pagination' do
    search = Book.sphinxsearchlogic(:per_page => '', :page => '')
    assert_equal(nil, search.page)
    assert_equal(nil, search.per_page)
  end

# Other methods

  test 'attribute finding' do
    assert Book.sphinxsearchlogic.is_sphinx_attribute?('title') # sortable so attribute
    assert !Book.sphinxsearchlogic.is_sphinx_attribute?('notitle') # not existing
    assert !Book.sphinxsearchlogic.is_sphinx_attribute?('description') # attribute
  end

  test 'field finding' do
    assert Book.sphinxsearchlogic.is_sphinx_field?('title') # but also field
    assert Book.sphinxsearchlogic.is_sphinx_field?('description')
    assert !Book.sphinxsearchlogic.is_sphinx_field?('production_year')
  end

  test 'scope finding' do
    assert Book.sphinxsearchlogic.is_sphinx_scope?('millenium')
  end

end
