# frozen_string_literal: true

# Run this script without parameter to show some help
#
#   bin/rails proposals:batch:import
#
#   bin/rails "proposals:batch:geoloc[admin@example.org,../geolocs.csv]"
#
# In heroku you must copy first the script and the files, you can use the command nc to do that (see README.md)
#
#   heroku run rake "proposals:batch:geoloc[admin@example.org,../geolocs.csv]"
#

require_relative "script_helpers"

namespace :proposals do
  namespace :batch do
    include ScriptHelpers

    desc "Geolocate proposals from a CSV"
    task :geoloc, [:admin,:csv] => :environment do |_task, args|
      process_csv(args) do |admin, table|
        table.each_with_index do |line, index|
          print "##{index} (#{100*(index+1)/table.count}%): "
          begin
            processor = ProposalProcessor.new(admin, normalize(line))
            processor.process!
          rescue UnprocessableError => e
            show_error(e.message)
          rescue AlreadyProcessedError => e
            show_warning(e.message)
          end
        end
      end
    end

    class ProposalProcessor
      def initialize(admin, values)
        raise_if_field_not_found(:address, values)
        @admin = admin
        @values = values
        @proposal = proposal_from_id(values[:id])
        raise AlreadyProcessedError.new("Proposal [#{@proposal.id}] has no address!") if values[:address].blank?
        raise AlreadyProcessedError.new("Proposal [#{@proposal.id}] has gelocating deactivated for component [#{@proposal.component.id}]!") unless @proposal.component.settings.geocoding_enabled?
        raise AlreadyProcessedError.new("Proposal [#{@proposal.id}] already geolocated to [#{@proposal.latitude},#{@proposal.longitude}] [#{@proposal.address}]!") if (@proposal.latitude.present? && @proposal.longitude.present?)
      end

      attr_reader :admin, :values, :proposal, :latitude, :longitude

      def process!
        print "Geolocating proposal #{proposal.id} with address [#{values[:address]}]"
        geolocate
        return show_error("ERROR! couldn't geolocate") unless (latitude.present? && longitude.present?)
        Decidim.traceability.update!(
          proposal,
          admin,
          address: values[:address],
          latitude: latitude,
          longitude: longitude
        )
        show_success("GEOLOCATED ad [#{latitude}, #{longitude}]!")
      end

      def geolocate
        results = Geocoder.search(values[:address])
        @latitude = results.first.latitude
        @longitude = results.first.longitude
      end
    end    
  end
end