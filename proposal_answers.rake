# frozen_string_literal: true

# Run this script without parameter to show some help
#
#   bin/rails proposals:batch:import
#
#   bin/rails "proposals:batch:answer[admin@example.org,../pam-ciutat.csv]"
#
# In heroku you must copy first the script and the files, you can use the command nc to do that (see README.md)
#
#   heroku run rake "proposals:batch:answer[admin@example.org,../pam-ciutat.csv]"
#

require_relative "script_helpers"

namespace :proposals do
  namespace :batch do
    include ScriptHelpers

    desc "Import answers to proposals from a CSV"
    task :answer, [:admin,:csv] => :environment do |_task, args|
      process_csv(args) do |admin, table|
        table.each_with_index do |line, index|
          print "##{index} (#{100*(index+1)/table.count}%): "
          begin
            processor = ProposalAnswerProcessor.new(admin, normalize(line))
            processor.process!
          rescue UnprocessableError => e
            show_error(e.message)
          rescue AlreadyProcessedError => e
            show_warning(e.message)
          end
        end
      end
    end

    class ProposalAnswerProcessor
      def initialize(admin, values)
        raise_if_field_not_found(:state, values)
        raise_if_field_not_found(:answer, values)
        values[:state] = normalize_state(values[:state]) # throws UnprocessableError if fails
        @admin = admin
        @values = values
        @proposal = proposal_from_id(values[:id])
        raise AlreadyProcessedError.new("Proposal [#{@proposal.id}] already answered at #{@proposal.answered_at} as [#{@proposal.internal_state}]!") if @proposal.answered_at.present?
        raise UnprocessableError.new("Proposal [#{@proposal.id}] requires costs definition!") if @proposal.component.current_settings.answers_with_costs?
      end

      attr_reader :admin, :values, :proposal

      def process!
        print "Updating proposal #{proposal.id} with state [#{values[:state]}]"
        form = OpenStruct.new(values.merge({current_user: admin, publish_answer?: proposal.component.current_settings.publish_answers_immediately?}))
        Decidim::Proposals::Admin::AnswerProposal.call(form, proposal) do
          on(:ok) do
            show_success("ANSWERED!")
          end
          on(:invalid) do
            show_error("NOT ANSWERED!")
          end
        end
      end
    end
  end
end