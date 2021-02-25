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

require_relative 'script_helpers'

namespace :proposals do
  namespace :batch do
    include ScriptHelpers

    desc 'Geolocate proposals from a CSV'
    task :geoloc, %i[admin csv] => :environment do |_task, args|
      process_csv(args) do |admin, line|
        processor = ProposalGeolocProcessor.new(admin, normalize(line))
        processor.process!
      end
    end

    class ProposalGeolocProcessor
      def initialize(admin, values)
        raise_if_field_not_found(:address, values)
        @admin = admin
        @values = values
        @proposal = proposal_from_id(values[:id])
        raise AlreadyProcessedError, "Proposal [#{@proposal.id}] has no address!" if values[:address].blank?
        unless @proposal.component.settings.geocoding_enabled?
          raise AlreadyProcessedError, "Proposal [#{@proposal.id}] has gelocating deactivated for component [#{@proposal.component.id}]!"
        end
        if @proposal.latitude.present? && @proposal.longitude.present?
          raise AlreadyProcessedError, "Proposal [#{@proposal.id}] already geolocated to [#{@proposal.latitude},#{@proposal.longitude}] [#{@proposal.address}]!"
        end
      end

      attr_reader :admin, :values, :proposal, :latitude, :longitude

      def process!
        print "Geolocating proposal #{proposal.id} with address [#{values[:address]}]"
        geolocate
        return show_error("ERROR! This couldn't be geolocated.") unless latitude.present? && longitude.present?

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
      rescue StandardError => e
        print " -#{e.message}- "
      end
    end
  end
end
