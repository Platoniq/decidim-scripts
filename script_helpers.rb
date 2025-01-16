# frozen_string_literal: true

require 'csv'

module ScriptHelpers
  HELP_TEXT = "
You need to specifiy an admin user (use the email) and a CSV to process:
ie: rails \"proposals:batch:ACTION[admin@example.org,../some-file.csv]\"

Not found proposals will be skipped"

  CSV_TEXT = "
CSV format must follow this specification:

1st line is treated as header and must containt the fields: id, state, text_ca, text_es, text_.., address
Rest of the lines must containt values for the corresponding headers
"

  def process_csv(args)
    raise ArgumentError if args.admin.blank?
    raise ArgumentError if args.csv.blank?

    admin = Decidim::User.find_by(admin: true, email: args.admin)
    raise AdminError, "#{args.admin} not found or not and admin" unless admin

    table = CSV.parse(File.read(args.csv), headers: true)

    table.each_with_index do |line, index|
      print "##{index} (#{100 * (index + 1) / table.count}%): "
      begin
        yield(admin, line)
      rescue UnprocessableError => e
        show_error(e.message)
      rescue ActiveRecord::RecordInvalid => e
        show_error(e.message)
      rescue AlreadyProcessedError => e
        show_warning(e.message)
      end
    end
  rescue ArgumentError => e
    puts
    show_error(e.message)
    show_help
  rescue CSV::MalformedCSVError => e
    puts
    show_error(e.message)
    show_csv_format
  rescue AdminError => e
    show_error(e.message)
  end

  def proposal_from_id(id)
    proposal = Decidim::Proposals::Proposal.find_by(id: id)
    raise UnprocessableError, "Proposal [#{id}] not found!" unless proposal

    proposal
  end

  def show_error(msg)
    puts "\e[31mERROR:\e[0m #{msg}"
  end

  def show_warning(msg)
    puts "\e[33mWARN:\e[0m #{msg}"
  end

  def show_success(msg)
    puts " \e[32m#{msg}\e[0m"
  end

  def normalize(line)
    values = { answer: {}, cost_report: {}, execution_period: {} }
    line.each do |key, value|
      case key
      when /^id$/i
        values[:id] = value
      when /^estat$|^status$|^state$/i
        values[:state] = value
      when /^text (.*)catal[à|a](.*)|^text_ca$|^answer\/ca$/i
        values[:answer][:ca] = value
      when /^text (.*)castell[a|à](.*)|^text_es$|^answer\/es$/i
        values[:answer][:es] = value
      when /^adreça$|^dirección$|^address$/i
        values[:address] = value
      when /^cost$/i
        values[:cost] = value
      when /^informe de cost$/i
        values[:cost_report][:ca] = value
      when /^per[ií]ode d['’]execuci[oó]$/i
        values[:execution_period][:ca] = value
      end
    end
    raise_if_field_not_found(:id, values)
    values
  end

  def emails_from(text)
    text.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i)
  end

  def url_for_proposal(proposal)
    # "https://#{proposal.organization.host}/processes/#{proposal.participatory_space.slug}/f/#{proposal.component.id}/proposals/#{proposal.id}"
    "https://www.decidim.barcelona/processes/#{proposal.participatory_space.slug}/f/#{proposal.component.id}/proposals/#{proposal.id}"
  end

  def raise_if_field_not_found(field, values)
    raise UnprocessableError, "#{field.upcase} field not found for [#{values[:id]}]" unless values[field].present?
  end

  def normalize_state(state)
    case state
    when /^evaluating|En avaluació|En evaluación|Acceptada parcialment|Aceptada parcialmente$/i
      'en_avaluacio'
    when /^accepted|Acceptada|Aceptada$/i
      'acceptada'
    when /^rejected|Rebutjada|Rechazada$/i
      'rebutjada'
    when /^withdrawn|retirat|retirada$/i
      'withdrawn'
    else
      raise UnprocessableError, "State [#{state}] cannot be parsed"
    end
  end

  def parse_links(texts)
    texts.map do |lang, text|
      [lang, text.nil? ? nil : Decidim::ContentRenderers::LinkRenderer.new((text).strip).render.gsub("\n", "<br>")]
    end.to_h
  end

  def show_help
    puts HELP_TEXT
  end

  def show_csv_format
    puts CSV_TEXT
  end

  class AdminError < StandardError
  end

  class UnprocessableError < StandardError
  end

  class AlreadyProcessedError < StandardError
  end
end
