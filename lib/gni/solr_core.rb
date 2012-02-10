module Gni
  class SolrIngest
    # @queue = :solr_ingest

    # def self.perform(solr_injest_id, solr_url = Gni::Config.solr_url)
    #   classification = SolrIk.first(:id => classification_id)    
    #   raise RuntimeError, "No classification with id #{classification_id}" unless classification
    #   si = SolrIngest.new(classification, solr_url)
    #   si.ingest
    # end

    def initialize(core)
      @core = core
      @solr_client = SolrClient.new(solr_url: core.solr_url, update_csv_params: core.update_csv_params)
      @temp_file = "solr_" + @core.name + "_"
    end

    def ingest
      id_start = 0
      id_end = id_start + Gni::Config.batch_size
      while true
        rows = @core.get_rows(id_start, id_end)
        break if rows.blank?
        @csv_file_name = File.join(Gni::Config.temp_dir, (@temp_file + "%s_%s" % [id_start, id_end]))
        csv_file = create_csv_file
        rows.each do |row|
          csv_file << row
        end
        csv_file.close
        @solr_client.delete("name_string_id:[%s TO %s]" % [id_start, id_end])
        @solr_client.update_with_csv(@csv_file_name)
        FileUtils.rm(@csv_file_name)
        id_start = id_end
        id_end += Gni::Config.batch_size
      end
    end
    
    private
    
    def create_csv_file
      csv_file = CSV.open(@csv_file_name, "w:utf-8")
      csv_file << @core.fields
      csv_file
    end

  end

  class SolrCoreCanonicalForm
    attr :update_csv_params, :fields, :name, :solr_url

    def initialize
      @atomizer = Taxamatch::Atomizer.new
      @name = "canonical_forms"
      @solr_url = Gni::Config.solr_url + "/" + @name
      @fields = %w(name_string_id canonical_form_id name_string canonical_form uninomial_auth uninomial_yr genus_auth genus_yr species_auth species_yr infraspecies_auth infraspecies_yr)
      @update_csv_params = "&" + @fields[4..-1].map { |f| "f.%s.split=true" % f }.join("&")
    end

    def get_rows(id_start, id_end)
      q = "select ns.id as name_string_id, cf.id as canonical_form_id, ns.name as name_string, cf.name as canonical_form, pns.data from name_strings ns join parsed_name_strings pns on pns.id=ns.id join canonical_forms cf on cf.id = ns.canonical_form_id where ns.canonical_form_id is not null and ns.id > %s and ns.id <= %s" % [id_start, id_end]
      rows = NameString.connection.select_rows(q)
      rows.each do |row|
        data = JSON.parse(row.pop, :symbolize_names => true)[:scientificName]
        next unless data[:details]
        res = @atomizer.organize_results(data)
        uninomial_auth = res[:uninomial] ? res[:uninomial][:normalized_authors] : []
        uninomial_years = res[:uninomial] ? res[:uninomial][:years] : []
        genus_auth = res[:genus] ? res[:genus][:normalized_authors] : []
        genus_years = res[:genus] ? res[:genus][:years] : []
        species_auth = res[:species] ? res[:species][:normalized_authors] : []
        species_years = res[:species] ? res[:species][:years] : []
        infraspecies_auth = res[:infraspecies] ? res[:infraspecies][0][:normalized_authors] : []
        infraspecies_years = res[:infraspecies] ? res[:infraspecies][0][:years] : []
        [uninomial_auth, uninomial_years, genus_auth, genus_years, species_auth, species_years, infraspecies_auth, infraspecies_years].each do |var|
          row << var.join(",")
        end
      end
      rows
    end
  end
  
  class SolrCoreCanonicalFormIndex < SolrCoreCanonicalForm
    def initialize
      super
      @name = "canonical_forms_data_sources"
      @solr_url = Gni::Config.solr_url + "/" + @name
      @fields += %w(data_source_id taxon_id classification_path classification_path_verbatim)
      @update_params += "&f.classification_path.split=true"
    end

    def get_rows(id_start, id_end)
      rows = super
      indices = []
      rows.each do |row|
        q = "select data_source_id, taxon_id, classification_path from name_string_indices where name_string_id = %s" % row[0]
        indices_rows = NameString.connection.select_rows(q)
        if indices_rows.blank? do
          indices << row[0..-1] + ["", "", "", ""]
        else
          indices_rows.each do |index|
            indices << row[0..-1] + index.map { |i| [i[0], i[1], i[2].gsub("|", ","), i[2]] }
          end
        end
      end
      indices
    end
  end
end
