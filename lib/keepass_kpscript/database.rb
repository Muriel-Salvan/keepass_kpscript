require 'fileutils'
require 'open3'
require 'secret_string'
require 'time'
require 'keepass_kpscript/select'

module KeepassKpscript

  # KPScript API handling a KeePass database
  class Database

    # Constructor
    #
    # Parameters::
    # * *kpscript* (Kpscript): The KPScript instance handling this database
    # * *database_file* (String): Database file path
    # * *password* (String or nil): Password opening the database, or nil if none [default: nil].
    # * *password_enc* (String or nil): Encrypted password opening the database, or nil if none [default: nil].
    # * *key_file* (String or nil): Key file path opening the database, or nil if none [default: nil].
    def initialize(kpscript, database_file, password: nil, password_enc: nil, key_file: nil)
      @kpscript = kpscript
      @database_file = database_file
      @password = password
      @password_enc = password_enc
      @key_file = key_file
    end

    # Securely select field values from entries.
    # Using this will make sure the entries' values are then erased from memory for security when exiting client code.
    # Try to not clone or extrapolate those values in other String variables, or if you have to call SecretString.erase on those variables to also erase their content.
    #
    # Parameters::
    # * Same parameters as #entries_string
    # * Proc: Code called with the entries retrieved
    #   * Parameters::
    #     * *values* (Array<String>)
    def with_entries_string(*args, **kwargs)
      values = []
      begin
        values = entries_string(*args, **kwargs).map { |str| SecretString.new(str) }
        yield values
      ensure
        values.each(&:erase)
      end
    end

    # Get field string values from entries.
    #
    # Parameters::
    # * *select* (Select): The entries selector
    # * *field* (String): Field to be selected
    # * *fail_if_not_exists* (Boolean): Do we fail if the field does not exist? [default: false]
    # * *fail_if_no_entry* (Boolean): Do we fail if no entry was found? [default: false]
    # * *spr* (Boolean): So we Spr-compile the value of the retrieved field? [default: false]
    # Result::
    # * Array<String>: List of retrieved field values
    def entries_string(
      select,
      field,
      fail_if_not_exists: false,
      fail_if_no_entry: false,
      spr: false
    )
      args = [
        '-c:GetEntryString',
        select.to_s,
        "-Field:\"#{field}\""
      ]
      args << '-FailIfNotExists' if fail_if_not_exists
      args << '-FailIfNoEntry' if fail_if_no_entry
      args << '-Spr' if spr
      execute_kpscript(*args).split("\n")
    end

    # Edit field values from entries.
    #
    # Parameters::
    # * *select* (Select): The entries selector
    # * *fields* (Hash<String or Symbol, String>): Set of { field name => field value } to be set [default: {}]
    # * *icon_idx* (Integer or nil): Set the icon index, or nil if none [default: nil]
    # * *custom_icon_idx* (Integer or nil): Set the custom icon index, or nil if none [default: nil]
    # * *expires* (Boolean or nil): Edit the expires flag, or nil to leave it untouched [default: nil]
    # * *expiry_time* (Time or nil): Expiry time or nil to leave it untouched [default: nil]
    # * *create_backup* (Boolean): Should we create backup of entries before modifying them? [default: false]
    def edit_entries(
      select,
      fields: {},
      icon_idx: nil,
      custom_icon_idx: nil,
      expires: nil,
      expiry_time: nil,
      create_backup: false
    )
      args = [
        '-c:EditEntry',
        select.to_s
      ] + fields.map { |field_name, field_value| "-set-#{field_name}:\"#{field_value}\"" }
      args << "-setx-Icon:#{icon_idx}" if icon_idx
      args << "-setx-CustomIcon:#{custom_icon_idx}" if custom_icon_idx
      args << "-setx-Expires:#{expires ? 'true' : 'false'}" unless expires.nil?
      args << "-setx-ExpiryTime:\"#{expiry_time.strftime('%FT%T')}\"" if expiry_time
      args << '-CreateBackup' if create_backup
      execute_kpscript(*args)
    end

    # Retrieve a password for a given entry title
    #
    # Parameters::
    # * *title* (String): Entry title
    # Result::
    # * String: Corresponding password
    def password_for(title)
      entries_string(@kpscript.select.fields(Title: title), 'Password').first
    end

    # Detach binaries.
    #
    # Parameters::
    # * *copy_to_dir* (String or nil): Specify a directory in which binaries are extracted, or nil to extract next to the database file. [default: nil]
    #     If copy_to_dir is specified, then the directory will be created and a copy of the original database will be used to detach bins, leaving the original database untouched.
    def detach_bins(copy_to_dir: nil)
      if copy_to_dir.nil?
        execute_kpscript('-c:DetachBins')
      else
        # Make a temporary copy of the database (as the KPScript extraction is destructive)
        FileUtils.mkdir_p copy_to_dir
        # Make a copy of the database in the directory first
        tmp_database = "#{copy_to_dir}/#{File.basename(@database_file)}.tmp.kdbx"
        FileUtils.cp @database_file, tmp_database
        begin
          @kpscript.open(tmp_database, password: @password, password_enc: @password_enc, key_file: @key_file).detach_bins
        ensure
          # Remove temporary database
          File.unlink tmp_database
        end
      end
    end

    # Export the database
    #
    # Parameters::
    # * *format* (String): Format to export to (see the KeePass Export dialog for possible values).
    # * *file* (String): File path to export to.
    # * *group_path* (Array<String> or nil): Group path to export, or nil for all [default: nil]
    # * *xsl_file* (String or nil): In case of transforming using XSL, this specifies the XSL file path to be used, or nil for none. [default: nil]
    def export(format, file, group_path: nil, xsl_file: nil)
      args = [
        '-c:Export',
        "-Format:\"#{format}\"",
        "-OutFile:\"#{file}\""
      ]
      args << "-GroupPath:\"#{group_path.join('/')}\"" if group_path
      args << "-XslFile:\"#{xsl_file}\"" if xsl_file
      case execute_kpscript(*args)
      when /E: Unknown format!/
        raise "Unknown format: #{format}"
      end
    end

    private

    # Execute KPScript on our database with a given list of arguments.
    # Handle internally all arguments needed to open the database with the correct secrets.
    #
    # Parameters::
    # * *args* (Array<String>): List of arguments
    # Result::
    # * String: stdout
    def execute_kpscript(*args)
      resulting_stdout = nil
      begin
        kdbx_args = ["\"#{@database_file}\""]
        kdbx_args << SecretString.new("-pw:\"#{@password}\"", silenced_str: '-pw:"XXXXX"') if @password
        kdbx_args << SecretString.new("-pw-enc:\"#{@password_enc}\"", silenced_str: '-pw-env:"XXXXX"') if @password_enc
        kdbx_args << SecretString.new("-keyfile:\"#{@key_file}\"", silenced_str: '-keyfile:"XXXXX"') if @key_file
        resulting_stdout = @kpscript.run(kdbx_args + args.flatten)
      ensure
        # Make sure we erase secrets
        kdbx_args.each(&:erase)
      end
      resulting_stdout
    end

  end

end
