require 'fileutils'
require 'tmpdir'
require 'keepass_kpscript/select'
require 'keepass_kpscript/database'

module KeepassKpscript

  # Drives an instance of KPScript
  class Kpscript

    # Constructor
    #
    # Parameters::
    # * *cmd* (String): The KPScript command line
    # * *debug* (Boolean): Do we activate debugging logs? [default: false]
    #     Warning: Those logs can contain passwords and secrets from your database. Only use it in a local environment.
    def initialize(cmd, debug: false)
      @cmd = cmd
      @debug = debug
    end

    # Open a database using this KPScript instance.
    # At least 1 of password, password_enc or key_file is mandatory.
    #
    # Parameters::
    # * *database_file* (String): Path to the database file
    # * *password* (String or nil): Password opening the database, or nil if none [default: nil].
    # * *password_enc* (String or nil): Encrypted password opening the database, or nil if none [default: nil].
    # * *key_file* (String or nil): Key file path opening the database, or nil if none [default: nil].
    # Result::
    # * Database: The database
    def open(database_file, password: nil, password_enc: nil, key_file: nil)
      Database.new(self, database_file, password: password, password_enc: password_enc, key_file: key_file)
    end

    # Shortcut to get easily access to selectors
    #
    # Result::
    # * Select: A new entries selector
    def select
      Select.new
    end

    # Encrypt a password so that it can be used to open databases without using the real password
    #
    # Parameters:
    # * *password* (String or SecretString): Password to be encrypted
    # Result::
    # * String: The encrypted password
    def encrypt_password(password)
      password_enc = nil
      # We use a temporary database to encypt the password
      tmp_database_file = "#{Dir.tmpdir}/keepass_kpscript.tmp.kdbx"
      FileUtils.cp "#{__dir__}/pass_encryptor.kdbx", tmp_database_file
      begin
        tmp_database = self.open(tmp_database_file, password: 'pass_encryptor')
        selector = select.fields(Title: 'pass_encryptor')
        tmp_database.edit_entries(selector, fields: { Password: password.to_unprotected })
        password_enc = tmp_database.entries_string(selector, 'URL', spr: true).first
      ensure
        File.unlink tmp_database_file
      end
      password_enc
    end

    # Run KPScript with a given list of arguments
    #
    # Parameters::
    # * *args* (Array<String or SecretString>): List of arguments that are given to the KPScript command-line
    # Result::
    # * String: The stdout of the command (without the last status line)
    def run(*args)
      args.flatten!
      resulting_stdout = nil
      SecretString.protect(
        "#{@cmd} #{args.map(&:to_unprotected).join(' ')}",
        silenced_str: "#{@cmd} #{args.join(' ')}"
      ) do |cmd|
        Open3.popen3(cmd.to_unprotected) do |_stdin, stdout, _stderr, wait_thr|
          exit_status = wait_thr.value.exitstatus
          stdout_lines = stdout.read.split("\n")
          log_debug do
            <<~EO_LOGDEBUG
              Execute #{cmd.to_unprotected} =>
              Exit status: #{exit_status}
              STDOUT:
              #{stdout_lines.join("\n")}
            EO_LOGDEBUG
          end
          raise "Error while executing #{cmd} (exit status: #{exit_status})" unless exit_status.zero?
          raise "Error returned by #{cmd}: #{stdout_lines.last}" unless stdout_lines.last == 'OK: Operation completed successfully.'

          resulting_stdout = stdout_lines[0..-2].join("\n")
        end
      end
      resulting_stdout
    end

    # Issue some debugging logs, if debug is activated.
    # Secret strings will be displayed unprotected by those logs.
    #
    # Parameters::
    # * Proc: Code giving the message to be displayed
    #   * Result::
    #     * String: Message to display
    def log_debug
      puts "[ DEBUG ] - #{yield.to_unprotected}" if @debug
    end

  end

end
