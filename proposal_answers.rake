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

require_relative 'script_helpers'

namespace :proposals do
  namespace :batch do
    include ScriptHelpers

    desc 'Import answers to proposals from a CSV'
    task :answer, %i[admin csv] => :environment do |_task, args|
      process_csv(args) do |admin, line|
        processor = ProposalAnswerProcessor.new(admin, normalize(line))
        processor.process!
      end
    end

    class ProposalAnswerProcessor
      def initialize(admin, values)
        raise_if_field_not_found(:state, values)
        raise_if_field_not_found(:answer, values)
        values[:state] = normalize_state(values[:state]) # throws UnprocessableError if fails
        values[:answer] = parse_links(values[:answer])
        @admin = admin
        @values = values
        @proposal = proposal_from_id(values[:id])
        # if @proposal.answered_at.present?
        #   raise AlreadyProcessedError, "Proposal [#{@proposal.id}] already answered at #{@proposal.answered_at} as [#{@proposal.internal_state}]!"
        # end
        if @proposal.component.current_settings.answers_with_costs?
          raise UnprocessableError, "Proposal [#{@proposal.id}] requires costs definition!"
        end
      end

      attr_reader :admin, :values, :proposal

      def process!
        print "Updating proposal #{proposal.id} with state [#{values[:state]}]"
        form = OpenStruct.new(values.merge({ current_user: admin, publish_answer?: proposal.component.current_settings.publish_answers_immediately? }))
        Decidim::Proposals::Admin::AnswerProposal.call(form, proposal) do
          on(:ok) do
            show_success('ANSWERED!')
          end
          on(:invalid) do
            show_error('NOT ANSWERED!')
          end
        end
      end
    end
  end
end
