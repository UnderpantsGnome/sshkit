require 'shellwords'
require 'securerandom'

module Deploy

  module CommandHelper

    def rake(tasks=[])
      execute :rake, tasks
    end

    def make(tasks=[])
      execute :make, tasks
    end

    def execute(command, args=[])
      Command.new(command, args)
    end

    private

      def map(command)
        Deploy.config.command_map[command.to_sym]
      end

  end

  class Command

    attr_reader :command, :args, :options

    attr_accessor :exit_status, :stdout, :stderr

    def initialize(*args)
      @options = args.extract_options!
      @command = args.shift.to_s.strip.to_sym
      @args    = args
      @options.symbolize_keys!
      sanitize_command!
      @stdout, @stderr = String.new, String.new
    end

    def complete?
      !exit_status.nil?
    end

    def uuid
      @uuid ||= SecureRandom.uuid
    end

    def success?
      exit_status.nil? ? false : exit_status.to_i == 0
    end
    alias :successful? :success?

    def failure?
      exit_status.to_i > 0
    end
    alias :failed? :failure?

    def to_hash
      {
        command:     command,
        args:        args,
        options:     options,
        exit_status: exit_status,
        stdout:      stdout,
        stderr:      stderr
      }
    end

    def host
      options[:host]
    end

    def to_s
      return command if command.match /\s/
      String.new.tap do |cs|
        if options[:in]
          cs << sprintf("cd %s && ", options[:in])
        end
        if options[:env]
          cs << '( '
          options[:env].each do |k,v|
            cs << k.to_s.upcase
            cs << "="
            cs << v.to_s.shellescape
          end
          cs << ' '
        end
        if options[:user]
          cs << "( sudo su -u #{options[:user]} "
        end
        cs << Deploy.config.command_map[command.to_sym]
        if args.any?
          cs << ' '
          cs << args.join(' ')
        end
        if options[:user]
          cs << ' )'
        end
        if options[:env]
          cs << ' )'
        end
      end
    end

    private

      def sanitize_command!
        command.to_s.strip!
        if command.to_s.match("\n")
          @command = String.new.tap do |cs|
            command.to_s.lines.each do |line|
              cs << line.strip
              cs << '; ' unless line == command.to_s.lines.to_a.last
            end
          end
        end
      end

  end

end
