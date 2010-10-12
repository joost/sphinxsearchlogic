# Sphinxsearchlogic
#
# A adapted version of the Searchlogic::Search class to attach to an ActiveRecord::Base#sphinxsearchlogic
# method.
module Sphinxsearchlogic
  class Search
    module Implementation
      # Use like:
      #  Movie.sphinxsearchlogic(params[:search], :page => params[:page], :per_page => [:per_page])
      def sphinxsearchlogic(conditions = {}, pagination = {})
        conditions ||= {} # params[:search] might be nil
        conditions.merge!(pagination)
        # Merge array of hashes, but doesn't work if Hash value is an Array.
        # conditions = Hash[*args.collect {|h| h.to_a}.flatten]
        Search.new(self, scope(:find), conditions)
      end
    end

    # Is an invalid condition is used this error will be raised. Ex:
    #
    #   User.search(:unkown => true)
    #
    # Where unknown is not a valid named scope for the User model.
    class UnknownConditionError < StandardError
      def initialize(condition)
        msg = "The #{condition} is not a valid condition. You may only use conditions that map to a thinking sphinx named scope or attribute."
        super(msg)
      end
    end

    # class OutofboundsError < StandardError
    #   def initialize(page, per_page)
    #     msg = "The page #{page} is out of bounds. Using per_page #{per_page}."
    #     super(msg)
    #   end
    # end

    # Accessors that define this Search object.
    attr_accessor :klass, :current_scope, :with, :without, :with_all, :params, :conditions, :scopes, :all
    undef :id if respond_to?(:id)

    module Pagination
      attr_writer :page, :per_page, :max_matches

      def default_per_page
        default_per_page = 20
        default_per_page = klass.per_page if klass.respond_to?(:per_page)
        default_per_page
      end

      # Returns a set max_matches or 1000.
      def max_matches
        @max_matches || 1000
      end

      # Returns the last page we have in this search based on the max_matches.
      # So we don't get a Riddle error for an offset that is too high.
      def last_page
        (max_matches.to_f / per_page).ceil
      end

      def offset
        (page-1)*per_page
      end

      def page
        page = (@page || 1).to_i
        page = 1 if page < 1 # Fixes pages like -1 and 0.
        # Fix riddle error.. we always return the last page? Think should be handled by application!
        # However this isn't yet the case for pages > total_results.
        # raise OutofboundsError.new(page, per_page) if page > last_page
        page = last_page if page > last_page
        page
      end

      # Returns 20 by default (ThinkingSphinx/Riddle default)
      def per_page
        per_page = (@per_page || default_per_page).to_i
        per_page = default_per_page if per_page < 1 # Fixes per_page like -1 and 0.
        per_page
      end

      def pagination_options
        options = {}
        options[:page] = page
        options[:per_page] = per_page
        options
      end

    end
    include Pagination

    module Ordering
      
      attr_reader :order, :order_direction, :order_attribute

      # Sets the order. If the order is incorrect this won't be set. Similar to pagination the
      # defaults will be used.
      def order=(order)
        @order = order
        return if order.blank?
        if is_sphinx_scope?(order) # We first check for scopes since they might be named ascend_by_scopename.
          scopes[order.to_sym] = true
        elsif order.to_s =~ /^(ascend|descend)_by_(\w+)$/
          @order_direction = ($1 == 'ascend') ? :asc : :desc
          if is_sphinx_attribute?($2)
            @order_attribute = $2.to_sym
          elsif [:weight, :relevance, :rank, :id, :random, :geodist].include?($2.to_sym)
            @order_attribute = "@#{$2} #{@order_direction}"
          end
        end
      end

      def ordering_options
        if order_attribute.blank?
          {}
        elsif order_attribute.is_a?(Symbol)
          {
            :order => order_attribute,
            :sort_mode => order_direction
          }
        else
          {:order => order_attribute}
        end
      end

    end
    include Ordering

    # Creates a new search object for the given class. Ex:
    #
    #   Searchlogic::Search.new(User, {}, {:username_like => "bjohnson"})
    def initialize(klass, current_scope, params = {})
      @with = {}
      @without = {}
      @with_all = {}
      @conditions = {}
      @scopes = {}

      self.klass = klass
      raise "No Sphinx indexes found on #{klass.to_s}!" unless has_sphinx_index?
      self.current_scope = current_scope
      self.params = params if params.is_a?(Hash)
    end

    # Accepts a hash of conditions.
    def params=(values)
      values.each do |param, value|
        value.delete_if { |v| v.blank? } if value.is_a?(Array)
        next if value.blank?
        send("#{param}=", value)
      end
    end

    # Returns actual search results.
    #  Movie.sphinxsearchlogic.results
    def results
      Rails.logger.debug("Sphinxsearchlogic: #{klass.to_s}.search('#{all}', #{search_options.inspect})")
      if scopes.empty?
        klass.search(all, search_options)
      else
        cloned_scopes = scopes.clone # Clone scopes since we're deleting form the hash.
        # Get the first scope and call all others on this one..
        first_scope = cloned_scopes.keys.first
        first_args = cloned_scopes.delete(first_scope)
        result = klass.send(first_scope, first_args)
        # Call remaining scopes on this scope.
        cloned_scopes.each do |scope, args|
          result = result.send(scope, args)
        end
        result.search(all, search_options)
      end
    end

  # private

    # Handles (in order):
    # * with / without / with_all conditions (Filters)
    # * field conditions (Regular searches)
    # * scope conditions
    def method_missing(name, *args, &block)
      name = name.to_s
      if name =~ /^(\w+)=$/ # If we have a setter
        name = $1
        if name =~ /^with(out|_all)?_(\w+)$/
          attribute_name = $2.to_sym
          if is_sphinx_attribute?(attribute_name)
            # Put in with / without / with_all depending on what the regexp matched.
            if $1 == 'out'
              without[attribute_name] = type_cast(args.first, cast_type(attribute_name))
            elsif $1 == '_all'
              with_all[attribute_name] = type_cast(args.first, cast_type(attribute_name))
            else
              with[attribute_name] = type_cast(args.first, cast_type(attribute_name))
            end
          else
            raise UnknownConditionError.new(attribute_name)
          end
        elsif is_sphinx_field?(name)
          conditions[name.to_sym] = args.first
        elsif is_sphinx_scope?(name)
          scopes[name.to_sym] = args.first
        else
          # If we have an unknown setter..
          # raise UnknownConditionError.new(attribute_name)
          super
        end
      else
        if name =~ /^with(out|_all)?_(\w+)$/
          attribute_name = $2
          attribute_name = attribute_name.gsub(/_before_type_cast)$/, '').to_sym
          if is_sphinx_attribute?(attribute_name)
            # Put in with / without / with_all depending on what the regexp matched.
            if $1 == 'out'
              without[attribute_name]
            elsif $1 == '_all'
              with_all[attribute_name]
            else
              with[attribute_name]
            end
          else
            raise UnknownConditionError.new(attribute_name)
          end
        elsif is_sphinx_field?(name)
          conditions[name.to_sym]
        elsif is_sphinx_scope?(name)
          scopes[name.to_sym]
        else
          # If we have something else than a setter..
          # raise UnknownConditionError.new(attribute_name)
          super
        end
      end
    end

    # Returns a hash for the ThinkingSphinx search method. Eg.
    #  {
    #    :with => {:year => 2001}
    #  }
    def attribute_filter_options
      options = {}
      options[:with] = with unless with.blank?
      options[:without] = without unless without.blank?
      options[:with_all] = with_all unless with_all.blank? # See http://www.mailinglistarchive.com/thinking-sphinx@googlegroups.com/msg00351.html
      options
    end
    
    # Returns a hash for the ThinkingSphinx search method. Eg.
    #  {
    #    :conditions => {:name => 'John'}
    #  }
    def search_options
      options = {}
      options[:conditions] = conditions unless conditions.blank?
      options.merge(attribute_filter_options).merge(ordering_options).merge(pagination_options)
    end

    # # cleanup_hash removes empty and nil stuff from params hashes.
    # def cleanup_hash(hash)
    #   hash.collect do |condition, value|
    #     value.delete_if { |v| v.blank? } if value.is_a?(Array)
    #     value unless value.blank?
    #   end.compact
    # end

    # Returns the ThinkingSphinx index for the klass we search on.
    def sphinx_index
      klass.define_indexes if klass.sphinx_indexes.blank?
      klass.sphinx_indexes.first
    end

    # Returns true if the class of this Search has a Sphinx index.
    def has_sphinx_index?
      sphinx_index.is_a?(ThinkingSphinx::Index)
    rescue
      false
    end

    # Returns particular ThinkingSphinx::Attribute.
    def sphinx_attribute(attribute_name)
      sphinx_index.attributes.find do |index_attribute|
        index_attribute.public? && index_attribute.unique_name.to_s =~ /^#{attribute_name}(_sort)?$/ # Also check for :sortable attributes (they are given prefix _sort)
      end
    end

    # Returns true if the class of this search has a public attribute with this name (or name_sort if field is :sortable).
    def is_sphinx_attribute?(attribute_name)
      !!sphinx_attribute(attribute_name)
    end

    # Returns true if the class of this search has a public field with this name.
    def is_sphinx_field?(field_name)
      !sphinx_index.fields.find do |index_field|
        index_field.public? && (index_field.unique_name.to_s == field_name.to_s)
      end.nil?
    end

    # Returns true if class of this search has a sphinx scope with this name.
    def is_sphinx_scope?(scope_name)
      klass.sphinx_scopes.include?(scope_name.to_sym)
    end

    # Returns the type we should type_cast a ThinkingSphinx::Attribute to, eg. :integer.
    def cast_type(name)
      sphinx_attribute(name).type
    end

    # type_cast method of Searchlogic plugin
    def type_cast(value, type)
      case value
      when Array
        value.collect { |v| type_cast(v, type) }
      else
        # Let's leverage ActiveRecord's type casting, so that casting is consistent
        # with the other models.
        column_for_type_cast = ::ActiveRecord::ConnectionAdapters::Column.new("", nil)
        column_for_type_cast.instance_variable_set(:@type, type)
        value = column_for_type_cast.type_cast(value)
        Time.zone && value.is_a?(Time) ? value.in_time_zone : value
      end
    end

  end
end