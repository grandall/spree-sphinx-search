module Spree
  Product.class_eval do
    class_attribute :indexed_options
    self.indexed_options = []

    define_index do
      is_active_sql = "(spree_products.deleted_at IS NULL AND spree_products.available_on <= NOW() #{'AND (spree_products.count_on_hand > 0)' unless Spree::Config[:allow_backorders]} )"
      option_sql = lambda do |option_name|
        sql = <<-eos
          SELECT DISTINCT p.id, ov.id
          FROM spree_option_values AS ov
          LEFT JOIN spree_option_types AS ot ON (ov.option_type_id = ot.id)
          LEFT JOIN spree_option_values_variants AS ovv ON (ovv.option_value_id = ov.id)
          LEFT JOIN spree_variants AS v ON (ovv.variant_id = v.id)
          LEFT JOIN spree_products AS p ON (v.product_id = p.id)
          WHERE (ot.name = '#{option_name}' AND p.id>=$start AND p.id<=$end);
          #{source.to_sql_query_range}
        eos
        sql.gsub("\n", ' ').gsub('  ', '')
      end

      indexes :cat_number
      indexes :name
      indexes :description
      indexes taxons.name, :as => :taxon, :facet => true
      indexes variants.sku, :as => :variant_sku
      indexes variants.manufacturer_number, :as => :variant_manufacturer_number
      indexes variants.details, :as => :variant_details
      has taxons(:id), :as => :taxon_ids
      has variants(:id), :as => :variant_ids
      group_by "spree_products.deleted_at"
      group_by "spree_products.available_on"
      has is_active_sql, :as => :is_active, :type => :boolean
      source.model.indexed_options.each do |opt|
        has option_sql.call(opt.to_s), :as => :"#{opt}_option", :source => :ranged_query, :type => :multi, :facet => true
      end
    
      set_property :delta => (Spree::Config[:use_sphinx_delta_index] == "0" ? false : true)
    end
    # @@superdone = 0
    #   def self.facets(query, search_options)
    #     puts "***" * 20
    #     puts query
    #     puts search_options.inspect
    #     puts "***" * 20
    #     @@superdone += 1
    #     if @@superdone == 1
    #       results = super 
    #     else
    #       return results
    #     end
    #     
    #   end
  end
end