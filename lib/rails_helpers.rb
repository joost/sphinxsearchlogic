module Sphinxsearchlogic
  module RailsHelpers

    # Creates a form with a :search scope. Use to create search form in your views.
    def sphinxsearchlogic_form_for(*args, &block)
      if search_obj = args.find { |arg| arg.is_a?(Sphinxsearchlogic::Search) }
        options = args.extract_options!
        options[:html] ||= {}
        options[:html][:method] ||= :get
        options[:url] ||= url_for
        args.unshift(:search) if args.first == search_obj
        args << options
      end
      form_for(*args, &block)
    end

    # Similar to the Searchlogic order helper.
    def order(search, options = {}, html_options = {})
      options[:params_scope] ||= :search
      options[:as] ||= options[:by].to_s.humanize
      options[:ascend_scope] ||= "ascend_by_#{options[:by]}"
      options[:descend_scope] ||= "descend_by_#{options[:by]}"
      ascending = search.order.to_s == options[:ascend_scope]
      new_scope = ascending ? options[:descend_scope] : options[:ascend_scope]
      selected = [options[:ascend_scope], options[:descend_scope]].include?(search.order.to_s)
      if selected
        css_classes = html_options[:class] ? html_options[:class].split(" ") : []
        if ascending
          options[:as] = "&#9650;&nbsp;#{options[:as]}"
          css_classes << "ascending"
        else
          options[:as] = "&#9660;&nbsp;#{options[:as]}"
          css_classes << "descending"
        end
        html_options[:class] = css_classes.join(" ")
      end
      params = controller.params.clone
      params[options[:params_scope]] ||= {}
      params[options[:params_scope]].merge!(:order => new_scope)
      url_options = {:controller => params[:controller], :action => params[:action], options[:params_scope] => params[options[:params_scope]]}
      link_to(options[:as], url_options, html_options)
    end

  end
end