# frozen_string_literal: true

# Run this script without parameter to show some help
#
#   bin/rails proposals:batch:import
#
#   bin/rails "proposals:batch:cost[admin@example.org,../pam-ciutat.csv]"
#
# In heroku you must copy first the script and the files, you can use the command nc to do that (see README.md)
#
#   heroku run rake "proposals:batch:cost[admin@example.org,../pam-ciutat.csv]"
#

require_relative 'script_helpers'

namespace :proposals do
  namespace :batch do
    include ScriptHelpers

    desc 'Import costs to proposals from a CSV'
    task :cost, %i[admin csv] => :environment do |_task, args|
      process_csv(args) do |admin, line|
        processor = ProposalCostProcessor.new(admin, normalize(line))
        processor.process!
      end
    end

    class ProposalCostProcessor
      def initialize(admin, values)
        # raise_if_field_not_found(:cost, values)
        # raise_if_field_not_found(:cost_report, values)
        # raise_if_field_not_found(:execution_period, values)
        @admin = admin
        @values = values
        @proposal = proposal_from_id(values[:id])
        unless @proposal.component.current_settings.answers_with_costs?
          raise UnprocessableError, "Component for proposal [#{@proposal.id}] needs to have costs enabled!"
        end
      end
      
      attr_reader :admin, :values, :proposal, :latitude, :longitude
      
      def process!
        print "Updating proposal #{proposal.id} with cost [#{values[:cost]}]"
        fields = {
          cost: values[:cost],
          cost_report: values[:cost_report],
          execution_period: values[:execution_period]
        }
        if(values[:address])
          geolocate
          fields[:address] = values[:address]
          fields[:latitude] = latitude
          fields[:longitude] = longitude
        end
        Decidim.traceability.update!(
          proposal,
          admin,
          fields
        )
        show_success('Cost updated!')
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
