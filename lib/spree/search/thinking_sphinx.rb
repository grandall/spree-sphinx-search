require 'ransack'
module Spree::Search
  class ThinkingSphinx < Spree::Core::Search::Base
    def search(*args)
      #nil # ... TODO: what should this method do? See https://github.com/spree/spree/blob/master/core/lib/spree/core/search/base.rb#L37 for possible insight
      raise "Thinking Sphinx Search Called with: #{args.inspect}"
      #retrieve_products(*args)
      
    end
    
    def self.retrieve_products
      raise "hello"
    end
    
    protected
    # method should return AR::Relations with conditions {:conditions=> "..."} for Product model
    def get_products_conditions_for(base_scope, keywords) #noticing Spree calls this method with "keywords" as the arg gives us some ideas as to what it should do
      return base_scope #if keywords.blank?
      # see how solr does it: https://github.com/romul/spree-solr-search/blob/master/lib/spree/search/solr.rb
      # see how sunspot does it: https://github.com/jbrien/spree_sunspot_search/blob/master/lib/spree/search/spree_sunspot/search.rb
      puts "query " * 10
      puts query.inspect
      puts "base_scope " * 10
      puts base_scope.to_sql
      
      product_ids = []
      result_scope = base_scope
      
      if order_by_price
        result_scope = base_scope.order("products.price #{order_by_price == 'descend' ? 'desc' : 'asc'}")
      end
      
      if facets_hash && facets_hash.keys.count > 0
        puts "facets hash " * 10
        puts facets_hash.inspect
        result_scope = result_scope.where(facets_hash)
        raise "we finally got a facets hash"
      end
      
      #result_scope = result_scope.with(is_active: 1) # what was this supposed to be doing?
      if taxon
        taxon_ids = taxon.self_and_descendants.map(&:id)
        #products_with_taxon_ids = Product.where("products.id in (select product_id from product_taxons where taxon_id in (?))", taxon_ids)
        result_scope = result_scope.includes(:taxons).where('taxons.id in (?)', taxon_ids)
        #result_scope = result_scope.where("products.id in (select product_id from products_taxons where taxon_id in (?))", taxon_ids)
        #puts "taxon added " * 10
        puts result_scope.to_sql
      end
      
      # what are the following five lines supposed to have been doing?
      #facets = Product.facets(query, search_options)
      #products = facets.for
      
      #@properties[:products] = products
      #@properties[:facets] = parse_facets_hash(facets)
      #@properties[:suggest] = nil if @properties[:suggest] == query
      
      product_ids = result_scope.pluck("products.id")
      
      #raise base_scope.where("products.id in (?)", product_ids).to_sql
      base_scope.where("products.id in (?)", product_ids)
    end
    
    # def get_base_scope
    #       base_scope = Spree::Product.active
    #       #base_scope = base_scope.in_taxon(taxon) unless taxon.blank?
    #       #base_scope = get_products_conditions_for(base_scope, keywords)
    #       base_scope = base_scope.on_hand unless Spree::Config[:show_zero_stock_products]
    #       base_scope = add_search_scopes(base_scope)
    #       base_scope
    #     end
    

    def prepare(params)
      @properties[:facets_hash] = params[:facets] || {}
      @properties[:taxon] = params[:taxon].blank? ? nil : Spree::Taxon.find(params[:taxon])
      @properties[:keywords] = params[:keywords]
      per_page = params[:per_page].to_i
      @properties[:per_page] = per_page > 0 ? per_page : Spree::Config[:products_per_page]
      @properties[:page] = (params[:page].to_i <= 0) ? 1 : params[:page].to_i
      @properties[:manage_pagination] = true
      @properties[:order_by_price] = params[:order_by_price]
      if !params[:order_by_price].blank?
        @product_group = Spree::ProductGroup.new.from_route([params[:order_by_price]+"_by_master_price"])
      elsif params[:product_group_name]
        @cached_product_group = Spree::ProductGroup.find_by_permalink(params[:product_group_name])
        @product_group = Spree::ProductGroup.new
      elsif params[:product_group_query]
        @product_group = Spree::ProductGroup.new.from_route(params[:product_group_query].split("/"))
      else
        @product_group = Spree::ProductGroup.new
      end
      @product_group = @product_group.from_search(params[:search]) if params[:search]
    end

private

    # method should return new scope based on base_scope
    def parse_facets_hash(facets_hash = {})
      facets = []
      price_ranges = YAML::load(Spree::Config[:product_price_ranges])
      facets_hash.each do |name, options|
        next if options.size <= 1
        facet = Facet.new(name)
        options.each do |value, count|
          next if value.blank?
          facet.options << FacetOption.new(value, count)
        end
        facets << facet
      end
      facets
    end
  end

  class Facet
    attr_accessor :options
    attr_accessor :name
    def initialize(name, options = [])
      self.name = name
      self.options = options
    end

    def self.translate?(property)
      return true if property.is_a?(ThinkingSphinx::Field)

      case property.type
      when :string
        true
      when :integer, :boolean, :datetime, :float
        false
      when :multi
        false # !property.all_ints?
      end
    end
  end

  class FacetOption
    attr_accessor :name
    attr_accessor :count
    def initialize(name, count)
      self.name = name
      self.count = count
    end
  end
end
