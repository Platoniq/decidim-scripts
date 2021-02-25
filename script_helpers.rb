# frozen_string_literal: true

require "csv"

module ScriptHelpers
  HELP_TEXT="
You need to specifiy an admin user (use the email) and a CSV to process:
ie: rails \"proposals:batch:ACTION[admin@example.org,../some-file.csv]\"

Not found proposals will be skipped"

  CSV_TEXT="
CSV format must follow this specification:

1st line is treated as header and must containt the fields: id, state, text_ca, text_es, text_.., address
Rest of the lines must containt values for the corresponding headers
"

  def process_csv(args)
    begin
      raise ArgumentError if args.admin.blank?
      raise ArgumentError if args.csv.blank?
      admin = Decidim::User.find_by(admin: true, email: args.admin)
      raise AdminError.new("#{args.admin} not found or not and admin") unless admin

      table = CSV.parse(File.read(args.csv), headers: true)

      yield(admin, table)
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
  end

  def proposal_from_id(id)
    proposal = Decidim::Proposals::Proposal.find_by(id: id)
    raise UnprocessableError.new("Proposal [#{id}] not found!") unless proposal

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
    values = {answer: {}}
    line.each do |key, value|
      case key
      when /^id$/i
        values[:id] = value
      when /^estat$|^status$|^state$/i
        values[:state] = value
      when /^text (.*)catal[à|a](.*)|^text_ca$/i
        values[:answer][:ca] = value
      when /^text (.*)castell[a|à](.*)|^text_es$/i
        values[:answer][:es] = value
      when /^adreça$|^dirección$|^address$/i
        values[:address] = value
      end
    end
    raise_if_field_not_found(:id, values)
    values
  end

  def raise_if_field_not_found(field, values) 
    raise UnprocessableError.new("#{field.upcase} field not found for [#{values[:id]}]") unless values[field].present?
  end

  def normalize_state(state)
    case state
    when /^accepted|Acceptada|Aceptada$/i
      "accepted"
    when /^rejected|Rebutjada|Rechazada$/i
      "rejected"
    when /^evaluating|En avaluació|En evaluación$/i
      "evaluating"
    when /^withdrawn|retirat|retirada$/i
      "withdrawn"
    else
      raise UnprocessableError.new("State [#{state}] cannot be parsed")
    end
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
