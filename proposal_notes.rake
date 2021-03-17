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
  namespace :export do
    task :notes, %i[component csv] => :environment do |_task, args|
      proposals = Decidim::Proposals::Proposal.where(component: args.component)
      notes = Decidim::Proposals::ProposalNote.where(proposal: proposals)
      headers = ["Note ID", "Proposal ID", "Proposal title", "Nota", "Emails", "URL"]
      CSV.open(args.csv, "wb") do |csv|
        csv << headers
        notes.find_each do |note|
          csv << [note.id, note.proposal.id, note.proposal.title["ca"] || note.proposal.title["es"], note.body, emails_from(note.body).join("\n"), url_for_proposal(note.proposal)]
        end
      end
    end
  end
end