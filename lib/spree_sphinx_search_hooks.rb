class SphinxSearchHooks < Spree::ThemeSupport::HookListener
  Deface::Override.new(:virtual_path => "products/index",
                       :name => "converted_search_results_901265565",
                       :insert_before => "[data-hook='search_results'], #search_results[data-hook]",
                       :partial => "products/facets",
                       :disabled => false)

  Deface::Override.new(:virtual_path => "products/index",
                       :name => "converted_search_results_722345125",
                       :insert_before => "[data-hook='search_results'], #search_results[data-hook]",
                       :partial => "products/suggestion",
                       :disabled => false)
end
